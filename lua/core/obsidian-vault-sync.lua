---Headless Obsidian Sync while Neovim uses a Sync-managed vault (no Obsidian GUI).
---Only vaults listed by `ob sync-list-local` count; the platform Notebook fallback
---(e.g. Synology Drive) does not start sync on its own.
---State: `stdpath("state")/obsidian-sync/` (`sync.pid`, `sessions/`, `sync.log`).
local M = {}

local warned = false
local exiting = false
---@type integer|nil
local sync_job = nil

local STATE_SUBDIR = "obsidian-sync"
local SYNC_ENABLED_FILE = "sync-enabled"

---Cached `ob sync-list-local` paths (normalised).
---@type { paths: string[], fetched_at: number }|nil
local managed_cache = nil
local MANAGED_CACHE_TTL_SEC = 30

---@param path string|nil
---@return string
local function normalise(path)
	if not path or path == "" then
		return ""
	end
	local absolute = vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/+$", "")
	if absolute == "" then
		return ""
	end
	-- Resolve symlinks when present so ~/Notebook and its real path match.
	return vim.fn.resolve(absolute):gsub("/+$", "")
end

---Vault roots linked for headless Sync on this machine (`ob sync-list-local`).
---@param force boolean|nil
---@return string[]
local function managed_vault_roots(force)
	local now = vim.uv.hrtime() / 1e9
	if not force and managed_cache and (now - managed_cache.fetched_at) < MANAGED_CACHE_TTL_SEC then
		return managed_cache.paths
	end

	local paths = {}
	local ob = vim.fn.exepath("ob")
	if ob == "" then
		managed_cache = { paths = paths, fetched_at = now }
		return paths
	end

	local result = vim.system({ ob, "sync-list-local", "--json" }, { text = true }):wait()
	if result.code == 0 and result.stdout and result.stdout ~= "" then
		local ok, decoded = pcall(vim.json.decode, result.stdout)
		if ok and type(decoded) == "table" then
			local vaults = decoded.vaults or decoded
			if type(vaults) == "table" then
				for _, entry in ipairs(vaults) do
					local raw = type(entry) == "table" and entry.path or nil
					local root = normalise(raw)
					if root ~= "" then
						paths[#paths + 1] = root
					end
				end
			end
		end
	end

	-- Fall back to plain-text listing when --json is unavailable.
	if #paths == 0 then
		result = vim.system({ ob, "sync-list-local" }, { text = true }):wait()
		if result.code == 0 and result.stdout and not result.stdout:find("No vaults configured", 1, true) then
			for line in result.stdout:gmatch("[^\r\n]+") do
				local raw = line:match("^%s*Path:%s*(%S.+)%s*$")
				local root = normalise(raw)
				if root ~= "" then
					paths[#paths + 1] = root
				end
			end
		end
	end

	managed_cache = { paths = paths, fetched_at = now }
	return paths
end

---@param path string|nil
---@return string|nil managed_root
local function managed_root_for_path(path)
	local candidate = normalise(path)
	if candidate == "" then
		return nil
	end
	for _, root in ipairs(managed_vault_roots()) do
		if candidate == root or vim.startswith(candidate, root .. "/") then
			return root
		end
	end
	return nil
end

---@return boolean
local function using_vault()
	if managed_root_for_path(vim.fn.getcwd()) then
		return true
	end
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and managed_root_for_path(name) then
				return true
			end
		end
	end
	return false
end

---Managed vault this session is editing, if any.
---@return string|nil
local function active_managed_vault()
	local from_cwd = managed_root_for_path(vim.fn.getcwd())
	if from_cwd then
		return from_cwd
	end
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			local root = name ~= "" and managed_root_for_path(name) or nil
			if root then
				return root
			end
		end
	end
	return nil
end

---@return string
local function state_dir()
	local dir = vim.fs.joinpath(vim.fn.stdpath("state"), STATE_SUBDIR)
	vim.fn.mkdir(dir, "p")
	return dir
end

---@return boolean
local function sync_toggle_on()
	local file = vim.fs.joinpath(state_dir(), SYNC_ENABLED_FILE)
	if vim.fn.filereadable(file) ~= 1 then
		return true
	end
	local line = (vim.fn.readfile(file)[1] or ""):lower()
	return line ~= "0" and line ~= "false" and line ~= "off" and line ~= "no"
end

---@param enabled boolean
local function write_sync_toggle(enabled)
	vim.fn.writefile({ enabled and "1" or "0" }, vim.fs.joinpath(state_dir(), SYNC_ENABLED_FILE))
end

---@param pid integer|nil
---@return boolean
local function alive(pid)
	return pid ~= nil and pid > 0 and vim.system({ "kill", "-0", tostring(pid) }, { text = true }):wait().code == 0
end

---@return integer|nil
local function read_sync_pid()
	local file = vim.fs.joinpath(state_dir(), "sync.pid")
	if vim.fn.filereadable(file) ~= 1 then
		return nil
	end
	return tonumber(vim.fn.readfile(file)[1])
end

---@param pid integer|nil
local function write_sync_pid(pid)
	local file = vim.fs.joinpath(state_dir(), "sync.pid")
	if pid then
		vim.fn.writefile({ tostring(pid) }, file)
	elseif vim.fn.filereadable(file) == 1 then
		vim.fn.delete(file)
	end
end

---@param present boolean
local function set_session_lock(present)
	local locks = vim.fs.joinpath(state_dir(), "sessions")
	vim.fn.mkdir(locks, "p")
	local mine = vim.fs.joinpath(locks, tostring(vim.fn.getpid()))
	if present then
		vim.fn.writefile({ "1" }, mine)
	elseif vim.fn.filereadable(mine) == 1 then
		vim.fn.delete(mine)
	end
end

---Prune stale locks and return live Neovim session count.
---@return integer
local function nvim_sessions_in_vault()
	local locks = vim.fs.joinpath(state_dir(), "sessions")
	vim.fn.mkdir(locks, "p")
	local count = 0
	for name, kind in vim.fs.dir(locks) do
		if kind == "file" then
			local pid = tonumber(name)
			if alive(pid) then
				count = count + 1
			else
				vim.fn.delete(vim.fs.joinpath(locks, name))
			end
		end
	end
	return count
end

---@return boolean
local function gui_running()
	return vim.system({ "pgrep", "-x", "Obsidian" }, { text = true }):wait().code == 0
end

---@return string|nil
local function sync_runner()
	for _, path in ipairs({
		vim.fn.expand("~/dotfiles/bin/obsidian-headless-sync"),
		vim.fn.expand("~/.local/bin/obsidian-headless-sync"),
	}) do
		if vim.fn.executable(path) == 1 then
			return path
		end
	end
	return nil
end

---@param message string
local function warn_once(message)
	if warned then
		return
	end
	warned = true
	vim.notify(message, vim.log.levels.WARN)
end

---@param vault string
local function setup_hint(vault)
	return string.format(
		'Headless Obsidian Sync is not ready. Run: ob login && obsidian-headless-sync-setup "%s"',
		vault
	)
end

---@return boolean stopped
local function stop_headless_sync()
	local stopped = false

	if sync_job then
		local status = vim.fn.jobwait({ sync_job }, 0)
		if status[sync_job] == -1 then
			vim.fn.jobstop(sync_job)
			stopped = true
		end
		sync_job = nil
	end

	local pid = read_sync_pid()
	write_sync_pid(nil)
	if alive(pid) then
		vim.system({ "kill", tostring(pid) }, { text = true }):wait()
		stopped = true
	end

	return stopped
end

---Drop stale session locks; stop sync when no Neovim still uses the vault.
function M.cleanup_stale_state()
	if nvim_sessions_in_vault() == 0 then
		stop_headless_sync()
		return
	end
	local pid = read_sync_pid()
	if pid and not alive(pid) then
		write_sync_pid(nil)
	end
end

---@param vault string
local function start_headless_sync(vault)
	if vault == "" then
		return
	end
	if alive(read_sync_pid()) or sync_job then
		return
	end

	local runner = sync_runner()
	if not runner then
		warn_once("obsidian-headless-sync not found (symlink from dotfiles bin)")
		return
	end

	local log_file = vim.fs.joinpath(state_dir(), "sync.log")
	vim.fn.writefile({}, log_file)

	sync_job = vim.fn.jobstart({
		"/bin/bash",
		"-c",
		string.format(
			"exec env OBSIDIAN_VAULT_PATH=%s %s >>%s 2>&1",
			vim.fn.shellescape(vault),
			vim.fn.shellescape(runner),
			vim.fn.shellescape(log_file)
		),
	}, {
		-- Kill the sync job when this Neovim exits (`detach` would orphan `ob sync`).
		detach = false,
		on_exit = function(_, code)
			sync_job = nil
			write_sync_pid(nil)
			if code == 0 then
				return
			end
			local detail = setup_hint(vault)
			if vim.fn.filereadable(log_file) == 1 then
				local tail = table.concat(vim.fn.readfile(log_file), " ")
				if tail ~= "" then
					detail = tail
				end
			end
			warn_once(detail)
		end,
	})

	if not sync_job or sync_job <= 0 then
		sync_job = nil
		warn_once("Could not start headless vault sync")
		return
	end

	write_sync_pid(vim.fn.jobpid(sync_job))
	vim.defer_fn(function()
		if sync_job and alive(read_sync_pid()) then
			vim.notify("Vault sync started (headless)", vim.log.levels.INFO)
		end
	end, 600)
end

local function reconcile()
	local vault = active_managed_vault()
	set_session_lock(vault ~= nil)
	if nvim_sessions_in_vault() == 0 then
		if stop_headless_sync() then
			vim.notify("Vault sync stopped (headless)", vim.log.levels.INFO)
		end
		return
	end

	if gui_running() then
		stop_headless_sync()
		return
	end

	if not sync_toggle_on() then
		stop_headless_sync()
		return
	end

	-- Another Neovim session may hold the lock; only start when this session is in-vault.
	if not vault then
		return
	end

	if vim.fn.isdirectory(vault) ~= 1 then
		warn_once(
			string.format(
				"Obsidian Sync vault path is missing: %s (fix the link or re-run obsidian-headless-sync-setup)",
				vault
			)
		)
		return
	end

	start_headless_sync(vault)
end

local function on_vim_exit()
	if exiting then
		return
	end
	exiting = true
	set_session_lock(false)
	if nvim_sessions_in_vault() == 0 then
		stop_headless_sync()
	end
end

---@return string[]
function M.status_lines()
	local managed = managed_vault_roots(true)
	local active = active_managed_vault()
	local platform = normalise(require("core.platform").obsidian_vault_path())
	local pid = read_sync_pid()
	local managed_display = #managed == 0 and "(none)" or table.concat(managed, ", ")
	local lines = {
		"Platform Notebook path: " .. platform,
		"Sync-managed vaults: " .. managed_display,
		"Active managed vault (this session): " .. (active or "(none)"),
		"Using managed vault (this session): " .. (using_vault() and "yes" or "no"),
		"Neovim vault sessions: " .. tostring(nvim_sessions_in_vault()),
		"Sync toggle (headless): " .. (sync_toggle_on() and "on" or "off"),
		"Obsidian GUI: " .. (gui_running() and "running" or "not running"),
		"sync.pid: " .. (pid and tostring(pid) or "none"),
		"Sync process: " .. (pid and alive(pid) and "running" or "stopped"),
		"State: " .. state_dir(),
	}
	return lines
end

---@return boolean
function M.sync_enabled()
	return sync_toggle_on()
end

---@param opts? { notify?: boolean }
---@return boolean enabled New toggle state (on = headless sync may run).
function M.toggle_sync(opts)
	opts = opts or {}
	local enabled = not sync_toggle_on()
	write_sync_toggle(enabled)
	if not enabled then
		stop_headless_sync()
	end
	reconcile()
	if opts.notify ~= false then
		vim.notify(
			"Headless vault sync " .. (enabled and "enabled" or "disabled"),
			vim.log.levels.INFO,
			{ title = "Obsidian vault sync" }
		)
	end
	return enabled
end

---@param enabled boolean
---@param opts? { notify?: boolean }
function M.set_sync_enabled(enabled, opts)
	opts = opts or {}
	local was = sync_toggle_on()
	write_sync_toggle(enabled)
	if not enabled then
		stop_headless_sync()
	end
	if was ~= enabled then
		reconcile()
	end
	if opts.notify ~= false and was ~= enabled then
		vim.notify(
			"Headless vault sync " .. (enabled and "enabled" or "disabled"),
			vim.log.levels.INFO,
			{ title = "Obsidian vault sync" }
		)
	end
end

---Return the current module, reloading when an older copy is still in `package.loaded`.
---@return table
function M.get()
	local cached = package.loaded["core.obsidian-vault-sync"]
	if cached and type(cached.toggle_sync) == "function" then
		return cached
	end
	if cached then
		package.loaded["core.obsidian-vault-sync"] = nil
	end
	cached = require("core.obsidian-vault-sync")
	cached.install()
	return cached
end

function M.install()
	M.cleanup_stale_state()

	local group = vim.api.nvim_create_augroup("obsidian_vault_sync", { clear = true })
	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained", "BufEnter", "BufDelete", "BufWipeout" }, {
		group = group,
		callback = reconcile,
		desc = "Headless Obsidian Sync while a Sync-managed vault is open in Neovim",
	})
	for _, event in ipairs({ "VimLeavePre", "QuitPre", "VimLeave" }) do
		vim.api.nvim_create_autocmd(event, {
			group = group,
			callback = on_vim_exit,
			desc = "Stop headless Obsidian Sync when Neovim exits",
		})
	end

	vim.api.nvim_create_user_command("ObsidianSyncStatus", function()
		local sync = M.get()
		vim.notify(table.concat(sync.status_lines(), "\n"), vim.log.levels.INFO, { title = "Obsidian vault sync" })
	end, { desc = "Show headless vault sync state" })

	vim.api.nvim_create_user_command("ObsidianSyncCleanup", function()
		local sync = M.get()
		sync.cleanup_stale_state()
		vim.notify("Vault sync state cleaned up", vim.log.levels.INFO)
	end, { desc = "Stop orphan headless sync and prune stale locks" })

	vim.api.nvim_create_user_command("ObsidianSyncToggle", function(cmd)
		local sync = M.get()
		local arg = (cmd.fargs[1] or ""):lower()
		if arg == "" then
			sync.toggle_sync()
			return
		end
		if vim.tbl_contains({ "on", "enable", "yes", "1", "true" }, arg) then
			sync.set_sync_enabled(true)
			return
		end
		if vim.tbl_contains({ "off", "disable", "no", "0", "false" }, arg) then
			sync.set_sync_enabled(false)
			return
		end
		vim.notify("Usage: ObsidianSyncToggle [on|off|enable|disable]", vim.log.levels.WARN)
	end, {
		desc = "Toggle headless vault sync (persisted under state dir)",
		nargs = "?",
		complete = function()
			return { "on", "off", "enable", "disable" }
		end,
	})

	reconcile()
end

return M
