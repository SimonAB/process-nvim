---Headless Obsidian Sync while Neovim uses the vault (no Obsidian GUI).
---State: `stdpath("state")/obsidian-sync/` (`sync.pid`, `sessions/`, `sync.log`).
local M = {}

local warned = false
local exiting = false
---@type integer|nil
local sync_job = nil

local STATE_SUBDIR = "obsidian-sync"

---@return string
local function vault_root()
	return require("core.platform").obsidian_vault_path()
end

---@param path string|nil
---@return string
local function normalise(path)
	if not path or path == "" then
		return ""
	end
	return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/+$", "")
end

---@param path string|nil
---@return boolean
local function path_in_vault(path)
	local root = normalise(vault_root())
	local candidate = normalise(path)
	if root == "" or candidate == "" then
		return false
	end
	return candidate == root or vim.startswith(candidate, root .. "/")
end

---@return boolean
local function using_vault()
	if path_in_vault(vim.fn.getcwd()) then
		return true
	end
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and path_in_vault(name) then
				return true
			end
		end
	end
	return false
end

---@return string
local function state_dir()
	local dir = vim.fs.joinpath(vim.fn.stdpath("state"), STATE_SUBDIR)
	vim.fn.mkdir(dir, "p")
	return dir
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

---@return boolean
local function headless_configured()
	local ob = vim.fn.exepath("ob")
	if ob == "" then
		return false
	end
	local vault = normalise(vault_root())
	local result = vim.system({ ob, "sync-list-local" }, { text = true }):wait()
	if result.code ~= 0 or not result.stdout or result.stdout:find("No vaults configured", 1, true) then
		return false
	end
	return result.stdout:find(vault, 1, true) ~= nil
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

local function setup_hint()
	return string.format(
		'Headless Obsidian Sync is not ready. Run: ob login && obsidian-headless-sync-setup "%s"',
		normalise(vault_root())
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

local function start_headless_sync()
	if alive(read_sync_pid()) or sync_job then
		return
	end

	if not headless_configured() then
		warn_once(setup_hint())
		return
	end

	local runner = sync_runner()
	if not runner then
		warn_once("obsidian-headless-sync not found (symlink from dotfiles bin)")
		return
	end

	local vault = normalise(vault_root())
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
			local detail = setup_hint()
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
	set_session_lock(using_vault())
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

	start_headless_sync()
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
	local vault = normalise(vault_root())
	local pid = read_sync_pid()
	local lines = {
		"Vault: " .. vault,
		"Using vault (this session): " .. (using_vault() and "yes" or "no"),
		"Neovim vault sessions: " .. tostring(nvim_sessions_in_vault()),
		"Obsidian GUI: " .. (gui_running() and "running" or "not running"),
		"Headless configured: " .. (headless_configured() and "yes" or "no"),
		"sync.pid: " .. (pid and tostring(pid) or "none"),
		"Sync process: " .. (pid and alive(pid) and "running" or "stopped"),
		"State: " .. state_dir(),
	}
	return lines
end

function M.install()
	M.cleanup_stale_state()

	local group = vim.api.nvim_create_augroup("obsidian_vault_sync", { clear = true })
	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained", "BufEnter", "BufDelete", "BufWipeout" }, {
		group = group,
		callback = reconcile,
		desc = "Headless Obsidian Sync while the vault is open in Neovim",
	})
	for _, event in ipairs({ "VimLeavePre", "QuitPre", "VimLeave" }) do
		vim.api.nvim_create_autocmd(event, {
			group = group,
			callback = on_vim_exit,
			desc = "Stop headless Obsidian Sync when Neovim exits",
		})
	end

	vim.api.nvim_create_user_command("ObsidianSyncStatus", function()
		vim.notify(table.concat(M.status_lines(), "\n"), vim.log.levels.INFO, { title = "Obsidian vault sync" })
	end, { desc = "Show headless vault sync state" })

	vim.api.nvim_create_user_command("ObsidianSyncCleanup", function()
		M.cleanup_stale_state()
		vim.notify("Vault sync state cleaned up", vim.log.levels.INFO)
	end, { desc = "Stop orphan headless sync and prune stale locks" })

	reconcile()
end

return M
