-- Capture process start time as early as possible for dashboard stats
_G.__nvim_start_ts = _G.__nvim_start_ts or (vim.loop and vim.loop.hrtime and vim.loop.hrtime() or nil)

-- Modern Neovim Configuration with vim.pack (Performance Optimised)

-- Set leader keys early (must be before loading plugins)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Cache frequently used paths
local config_path = vim.fn.stdpath("config")
local data_path = vim.fn.stdpath("data")
local cache_path = vim.fn.stdpath("cache")

-- Wrap vim.notify to always run outside fast event contexts to avoid E5560
do
	-- Preserve the original notify function
	local original_notify = vim.notify
	--- Safely schedule notifications outside of fast event contexts.
	--- This prevents errors such as E5560 (nvim_echo in fast event).
	--- Also suppresses known upstream deprecation warnings until plugins update
	--- to Neovim 0.13 API changes. Adjust patterns below to re-enable if needed.
	---@param msg any
	---@param level? integer
	---@param opts? table
	vim.notify = function(msg, level, opts)
		vim.schedule(function()
			local safe_msg = msg
			if type(msg) ~= "string" and type(msg) ~= "table" then
				safe_msg = vim.inspect(msg)
			end
			-- Suppress specific upstream deprecation notices (temporary)
			if type(safe_msg) == "string" then
				if safe_msg:match("client%.stop is deprecated") then
					return
				end
				if safe_msg:match("vim%.validate") and safe_msg:match("is deprecated") then
					return
				end
			end
			original_notify(safe_msg, level, opts)
		end)
	end
end

-- Load plugins first (install and add to runtime path)
local project_plugins = config_path .. "/lua/plugins.lua"
local ok, err = pcall(dofile, project_plugins)
if not ok then
	vim.notify("Failed to load project plugins.lua: " .. tostring(err), vim.log.levels.ERROR)
end

-- Load plugin orchestration system
local project_require = config_path .. "/lua/require.lua"
pcall(dofile, project_require)

-- Load core configuration
require("config")

-- Keymaps are split to keep startup fast and predictable:
-- - `keymaps-core` contains only plugin-independent mappings and is safe to load immediately.
-- - `keymaps-plugins` contains mappings which call into plugins (Telescope, Mason, etc.).
--   Those are deferred slightly so they don't run before plugins are available.
require("keymaps-core")

-- Defer plugin-dependent keymaps to avoid startup overhead and plugin availability issues.
-- This delay is chosen to run after your deferred plugin phase has started, but before which-key
-- (which is loaded later) so the which-key menu sees the mappings on first use.
vim.defer_fn(function()
	require("keymaps-plugins")
end, 300)

-- Consolidated autocmds with improved performance
local function setup_optimized_autocmds()
	local augroup = vim.api.nvim_create_augroup("OptimizedConfig", { clear = true })

	-- Filetype-specific configurations
	local filetype_configs = {
		tex = function() vim.g.vimtex_enabled = 1 end,
		julia = function()
			-- Julia-specific setup if needed
		end,
		python = function()
			-- Python-specific setup if needed
		end,
		r = function()
			-- R-specific setup if needed
		end,
		qmd = function()
			-- Quarto-specific setup if needed
		end,
	}

	-- Single autocmd for multiple filetypes with lookup table
	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = vim.tbl_keys(filetype_configs),
		callback = function(args)
			local config = filetype_configs[args.match]
			if config then
				config()
			end
		end,
	})
end

setup_optimized_autocmds()

-- Defer theme manager initialisation
vim.defer_fn(function()
	local ThemeManager = require("core.theme-manager")
	ThemeManager.init()
end, 50)

-- Defer plugin manager initialisation
vim.defer_fn(function()
	local ok, PluginManager = pcall(require, "core.plugin-manager")
	if ok then
		PluginManager.init()
	else
		vim.notify("Enhanced Plugin Manager not available: " .. tostring(PluginManager), vim.log.levels.WARN)
	end
end, 100)

-- Defer theme picker initialisation
vim.defer_fn(function()
	local ok, ThemePicker = pcall(require, "core.theme-picker")
	if ok then
		ThemePicker.init()
	end
end, 200)

-- Defer dashboard setup
vim.defer_fn(function()
	local ok, dashboard = pcall(require, "plugins.mini-nvim.dashboard")
	if ok then
		dashboard.setup()
		dashboard.setup_keymaps()
		dashboard.setup_autocommands()
	end
end, 300)

