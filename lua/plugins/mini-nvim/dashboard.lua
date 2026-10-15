-- =============================================================================
-- MINI.NVIM DASHBOARD
-- PURPOSE: Dashboard setup, configuration, and keymaps for mini.nvim
-- =============================================================================

local config = require("plugins.mini-nvim.config")
local utils = require("plugins.mini-nvim.utils")
local dashboard_content = require("plugins.mini-nvim.dashboard-content")

local width_ok, dashboard_width = pcall(require, "plugins.mini-nvim.dashboard-width")
if not width_ok then
	vim.notify("Dashboard width helper not found", vim.log.levels.WARN)
	return {}
end

local M = {}

-- Setup the dashboard
function M.setup()
	local starter_ok, starter = utils.safe_require("mini.starter")
	if not starter_ok then
		return
	end

	-- Ensure mini.starter is properly loaded
	vim.g.mini_starter_loaded = true

	-- Setup sessions if available
	local sessions_ok, mini_sessions = utils.safe_require("mini.sessions")
	if sessions_ok and not vim.g._mini_sessions_setup_done then
		mini_sessions.setup()
		vim.g._mini_sessions_setup_done = true
	end

	-- Prewarm cache before creating items for optimal performance
	dashboard_content.prewarm_cache()
	local items = dashboard_content.create_all_items()

	-- Add sessions if available
	local sections = starter.sections or starter.gen_section or {}
	if sessions_ok and sections.sessions then
		local ok_sess, sess = pcall(sections.sessions, 5, true)
		if ok_sess and type(sess) == "table" then
			for _, item in ipairs(sess) do
				table.insert(items, item)
			end
		end
	end

	-- Add builtin actions
	if sections.builtin_actions then
		local ok, builtins = pcall(sections.builtin_actions)
		if ok and type(builtins) == "table" then
			for _, item in ipairs(builtins) do
				table.insert(items, item)
			end
		end
	end

	-- Compose header with startup stats (LazyVim-style)
	local function build_header()
		local ascii = config.HEADER
		local ms = nil
		local ok_hr = (vim.loop and vim.loop.hrtime and type(vim.loop.hrtime) == "function")
		if ok_hr and _G.__nvim_start_ts then
			local now = vim.loop.hrtime()
			if type(now) == "number" and now > _G.__nvim_start_ts then
				ms = math.floor((now - _G.__nvim_start_ts) / 1e6)
			end
		end
		local prefix = ms and ("⚡ Startup: " .. tostring(ms) .. " ms") or "⚡ Startup: n/a"
		return ascii .. "\n" .. prefix .. "\n"
			.. dashboard_width.shorten(
				vim.fn.fnamemodify(vim.fn.getcwd(), ":~"),
				math.max(1, math.floor(vim.api.nvim_win_get_width(0) * 0.7) - 15)
			) .. " · newest first"
	end

	-- Exclude hjkl from query filtering so they move the current item; exclude q so
	-- it can quit Neovim (mini.starter otherwise binds every query_updater
	-- character to MiniStarter.add_to_query).
	local reserved_dashboard_keys = { h = true, j = true, k = true, l = true, q = true }
	local query_updaters_no_hjkl = (function()
		local out = {}
		for b = string.byte("a"), string.byte("z") do
			local c = string.char(b)
			if not reserved_dashboard_keys[c] then
				table.insert(out, c)
			end
		end
		return table.concat(out) .. "0123456789_-."
	end)()

	starter.setup({
		evaluate_single = true,
		query_updaters = query_updaters_no_hjkl,
		header = build_header,
		items = items,
		content_hooks = (function()
			local hooks = starter.gen_hook or {}
			return {
				dashboard_width.fit_content,
				hooks.adding_bullet and hooks.adding_bullet() or function(x)
					return x
				end,
				hooks.indexing and hooks.indexing(
					"all",
					config.INDEXED_SECTIONS
				) or function(x)
					return x
				end,
				hooks.aligning and hooks.aligning('center', 'center') or function(x)
					return x
				end,
				hooks.padding and hooks.padding(3, 2) or function(x)
					return x
				end,
			}
		end)(),
		autoopen = true,
	})

	-- Configure header colour
	pcall(vim.api.nvim_set_hl, 0, "MiniStarterHeader", { fg = config.DASHBOARD.HEADER_COLOUR, bold = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = function()
			pcall(vim.api.nvim_set_hl, 0, "MiniStarterHeader", { fg = config.DASHBOARD.HEADER_COLOUR, bold = true })
		end,
	})

	-- Ensure theme post-processing (e.g. Flexoki light contrast tweaks) runs after
	-- mini.starter has created its highlight groups and rendered content.
	vim.api.nvim_create_autocmd("User", {
		pattern = "MiniStarterOpened",
		callback = function()
			pcall(function()
				require("core.theme-manager").apply_flexoki_light_contrast()
			end)
		end,
	})
end

-- Refresh dashboard content
function M.refresh()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "ministarter" then
		return
	end
	local ok_mini, MiniStarter = pcall(function()
		return _G.MiniStarter
	end)

	if ok_mini and MiniStarter then
		-- Prewarm cache before creating new items for consistent behaviour
		dashboard_content.prewarm_cache()
		local new_items = dashboard_content.create_all_items()
		MiniStarter.config.items = new_items

		if type(MiniStarter.refresh) == "function" then
			MiniStarter.refresh(buf)
			M.bind_buffer_keys(buf)
		end
	end
end

-- Setup dashboard keymaps
function M.setup_keymaps()
	local map = vim.keymap.set
	map("n", "<leader>H", function()
		local ok, starter = pcall(require, "mini.starter")
		if not ok then
			vim.notify("mini.starter not found", vim.log.levels.WARN)
			return
		end
		starter.config.items = dashboard_content.create_all_items()
		local success, err = pcall(starter.open)
		if not success then
			vim.notify("Could not open dashboard: " .. tostring(err), vim.log.levels.ERROR)
		end
	end, { desc = "Home dashboard" })

	-- mini.starter suppresses FileType, so bind after its explicit open event.
	local group = vim.api.nvim_create_augroup("DashboardKeymaps", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "MiniStarterOpened",
		nested = true,
		callback = function()
			M.bind_buffer_keys(vim.api.nvim_get_current_buf())
		end,
	})
end

---Rebind dashboard actions after asynchronous results change their order.
---@param buf integer Dashboard buffer
function M.bind_buffer_keys(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "ministarter" then
		return
	end
	-- Remove shortcuts whose entries disappeared during a refresh.
	local keys = vim.list_extend(vim.deepcopy(config.DASHBOARD.CWD_FILE_KEYS), config.DASHBOARD.FORGE_KEYS)
	for i = 1, 9 do
		table.insert(keys, tostring(i))
	end
	for _, key in ipairs(keys) do
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end
	local items = (_G.MiniStarter and _G.MiniStarter.config and _G.MiniStarter.config.items) or {}
	local projects = {}
	local cwd_files = {}
	local forge_items = {}

	for _, item in ipairs(items) do
		if item and item.section == "Recent projects" then
			table.insert(projects, item)
		elseif item and item.section == "Current directory" then
			table.insert(cwd_files, item)
		elseif item and item.forge_action then
			table.insert(forge_items, item)
		end
	end

	local function exec_action(action)
		if type(action) == "string" then
			local current_buf = vim.api.nvim_get_current_buf()
			local was_modifiable = vim.bo[current_buf].modifiable

			if not was_modifiable then
				vim.bo[current_buf].modifiable = true
			end

			vim.cmd(action)

			if not was_modifiable then
				vim.bo[current_buf].modifiable = was_modifiable
			end
		elseif type(action) == "function" then
			pcall(action)
		end
	end

	-- Project shortcuts (1-9)
	for i = 1, math.min(#projects, 9) do
		vim.keymap.set("n", tostring(i), function()
			exec_action(projects[i].action)
		end, { buffer = buf, nowait = true, silent = true, desc = "Open Project " .. i })
	end

	-- Working-directory file shortcuts (a-e)
	for i = 1, math.min(#cwd_files, #config.DASHBOARD.CWD_FILE_KEYS) do
		vim.keymap.set("n", config.DASHBOARD.CWD_FILE_KEYS[i], function()
			exec_action(cwd_files[i].action)
		end, { buffer = buf, nowait = true, silent = true, desc = "Open cwd file " .. config.DASHBOARD.CWD_FILE_KEYS[i] })
	end

	-- Forge shortcuts (I, N, B, R)
	for i = 1, math.min(#forge_items, #config.DASHBOARD.FORGE_KEYS) do
		vim.keymap.set("n", config.DASHBOARD.FORGE_KEYS[i], function()
			exec_action(forge_items[i].action)
		end, { buffer = buf, nowait = true, silent = true, desc = "Forge: " .. config.DASHBOARD.FORGE_KEYS[i] })
	end

	-- Vim-style movement (mini.starter defaults to arrows / <C-n> / <M-j>).
	local function map_nav(key, dir, description)
		vim.keymap.set("n", key, function()
			pcall(function()
				local ms = _G.MiniStarter
				if ms and ms.update_current_item then
					ms.update_current_item(dir)
				end
			end)
		end, { buffer = buf, nowait = true, silent = true, desc = description })
	end

	map_nav("h", "prev", "Dashboard: previous item")
	map_nav("k", "prev", "Dashboard: previous item")
	map_nav("j", "next", "Dashboard: next item")
	map_nav("l", "next", "Dashboard: next item")

	vim.keymap.set("n", "q", function()
		pcall(vim.cmd, "confirm qall")
	end, { buffer = buf, nowait = true, silent = true, desc = "Dashboard: quit Neovim" })
end

-- Setup autocommands
function M.setup_autocommands()
	local cache_group = vim.api.nvim_create_augroup("DashboardFileCache", { clear = true })
	vim.api.nvim_create_autocmd({ "BufWritePost", "BufFilePost" }, {
		group = cache_group,
		callback = function(args)
			if not vim.api.nvim_buf_is_valid(args.buf) then
				return
			end
			local ok, discovery = pcall(require, "core.dashboard-files")
			if ok then
				-- Renames can affect both the old and new directory trees.
				local path = args.event == "BufWritePost" and vim.api.nvim_buf_get_name(args.buf) or nil
				discovery.invalidate(path)
			end
		end,
	})
	-- Combined VimEnter autocmd
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			if vim.fn.argc() == 0 then
				local ok = pcall(vim.cmd, "MiniStarter")
				if not ok then
					vim.defer_fn(function()
						pcall(vim.cmd, "MiniStarter")
					end, 100)
				end
			end
			vim.defer_fn(M.refresh, 50) -- Reduced since items load immediately now
		end,
	})

	-- UIEnter fallback
	vim.api.nvim_create_autocmd("UIEnter", {
		once = true,
		callback = function()
			if vim.fn.argc() == 0 and vim.bo.filetype ~= "ministarter" then
				vim.defer_fn(function()
					pcall(vim.cmd, "MiniStarter")
				end, 50)
			end
		end,
	})

	local resize_group = vim.api.nvim_create_augroup("DashboardResize", { clear = true })
	vim.api.nvim_create_autocmd("WinResized", {
		group = resize_group,
		callback = function()
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(win) then
					local buf = vim.api.nvim_win_get_buf(win)
					if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "ministarter" then
						vim.api.nvim_win_call(win, function()
							pcall(function()
								_G.MiniStarter.refresh(buf)
							end)
						end)
					end
				end
			end
		end,
	})

	-- Directory change refresh
	vim.api.nvim_create_autocmd("DirChanged", { callback = M.refresh })
end

-- Setup debug and testing
function M.setup_debug()
	vim.defer_fn(function()
		if vim.g.mini_starter_loaded then
			print("✓ Mini.starter loaded successfully")
		else
			print("⚠ Mini.starter not loaded")
		end
	end, 1000)

	vim.api.nvim_create_user_command('TestDashboard', function()
		if vim.g.mini_starter_loaded then
			vim.cmd('MiniStarter')
			print("Dashboard should be visible now")
		else
			print("Mini.starter not loaded - check plugin installation")
		end
	end, { desc = "Test mini.starter dashboard" })
end

return M
