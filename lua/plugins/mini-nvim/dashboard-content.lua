-- =============================================================================
-- MINI.NVIM DASHBOARD CONTENT
-- PURPOSE: Dashboard content generation for mini.nvim with caching
-- =============================================================================

local config = require("plugins.mini-nvim.config")
local utils = require("plugins.mini-nvim.utils")
local plugin_manager = require("plugins.mini-nvim.plugin-manager")

local M = {}

-- Cache for recent projects and files
local cached_projects = nil
local cached_recent_files = nil
local cache_timestamp = 0
local CACHE_DURATION = 120000 -- 2 minutes

-- Get recent projects from oldfiles with caching
function M.get_recent_projects(limit)
	-- Check cache first
	local current_time = vim.loop.now()
	if cached_projects and (current_time - cache_timestamp) < CACHE_DURATION then
		return vim.list_slice(cached_projects, 1, limit)
	end

	local dirs, order = {}, {}
	local oldfiles = vim.v.oldfiles or {}

	-- Limit the number of oldfiles to process
	local max_oldfiles = math.min(#oldfiles, 10)

	for i = 1, max_oldfiles do
		local f = oldfiles[i]
		if type(f) == "string" and #f > 0 then
			local abs = utils.get_absolute_path(f)
			if abs ~= "" and utils.is_file_accessible(abs) then
				local dir = utils.get_dirname(abs)
				if dir and dir ~= "" and dirs[dir] == nil and utils.is_file_accessible(dir) then
					dirs[dir] = true
					table.insert(order, dir)
					if #order >= limit then
						break
					end
				end
			end
		end
	end

	-- Update cache only if we found results
	if #order > 0 then
		cached_projects = order
		cache_timestamp = current_time
	end

	return order
end

-- OPTIMISED: Get recent files from oldfiles with caching
function M.get_recent_files(limit)
	-- Check cache first
	local current_time = vim.loop.now()
	if cached_recent_files and (current_time - cache_timestamp) < CACHE_DURATION then
		return vim.list_slice(cached_recent_files, 1, limit)
	end

	local files, order = {}, {}
	local oldfiles = vim.v.oldfiles or {}

	-- Limit the number of oldfiles to process
	local max_oldfiles = math.min(#oldfiles, 10)

	for i = 1, max_oldfiles do
		local f = oldfiles[i]
		if type(f) == "string" and #f > 0 then
			local abs = utils.get_absolute_path(f)
			if abs ~= "" and utils.is_file_accessible(abs) and files[abs] == nil then
				files[abs] = true
				table.insert(order, abs)
				if #order >= limit then
					break
				end
			end
		end
	end

	-- Update cache only if we found results
	if #order > 0 then
		cached_recent_files = order
		cache_timestamp = current_time
	end

	return order
end

-- Create shortcuts section with deferred plugin manager
function M.create_shortcuts()
	return {
		{
			name = "Find files",
			action = "Telescope find_files",
			section = "Shortcuts",
		},
		{
			name = "Grep",
			action = "Telescope live_grep",
			section = "Shortcuts",
		},
		{
			name = "Quit",
			action = "confirm qall",
			section = "Shortcuts",
		},
		{
			name = "Update plugins",
			action = function()
				-- Defer plugin manager call to avoid blocking
				vim.defer_fn(function()
					if plugin_manager and plugin_manager.update_plugins then
						plugin_manager.update_plugins()
					else
						vim.notify("Plugin manager not available", vim.log.levels.WARN)
					end
				end, 100)
			end,
			section = "Shortcuts",
		},
	}
end

-- Create projects section with caching
function M.create_projects()
	local projects = {}
	local idx = 1

	-- Use cached projects if available
	local recent_projects = M.get_recent_projects(config.DASHBOARD.MAX_PROJECTS)

	for _, dir in ipairs(recent_projects) do
		local label = string.format("%d. ", idx)
		local name = label .. " " .. utils.get_basename(dir)
		local action = string.format("lua require('telescope.builtin').find_files({ cwd = [[%s]] })", dir)
		table.insert(projects, { name = name, action = action, section = "Projects" })
		idx = idx + 1
	end

	return projects
end

-- Create recent files section with caching
function M.create_recent_files()
	local recent_files = {}

	-- Use cached recent files if available
	local recent_file_list = M.get_recent_files(config.DASHBOARD.MAX_RECENT_FILES)

	for i, file in ipairs(recent_file_list) do
		local key = config.DASHBOARD.RECENT_FILE_KEYS[i]
		local label = string.format("%s. ", key)
		local name = label .. " " .. utils.get_basename(file)
		local action = "edit " .. utils.escape_filename(file)
		table.insert(recent_files, { name = name, action = action, section = "Recent files" })
	end

	return recent_files
end

-- Prewarm cache for faster subsequent loads
function M.prewarm_cache()
	-- Only prewarm if we have oldfiles available and cache is empty
	local oldfiles = vim.v.oldfiles or {}
	if #oldfiles > 0 and (not cached_projects or not cached_recent_files) then
		-- Force cache population
		M.get_recent_projects(config.DASHBOARD.MAX_PROJECTS)
		M.get_recent_files(config.DASHBOARD.MAX_RECENT_FILES)
	end
end

-- Create Forge section — adapts to whether the CLI is installed.
function M.create_forge_items()
	local forge_ok, forge = pcall(require, "plugins.forge-nvim")
	local keys = config.DASHBOARD.FORGE_KEYS

	if not forge_ok or not forge.is_available() then
		local has_script = forge_ok and forge.has_setup_script()
		if has_script then
			return {
				{
					name = keys[1] .. ".  Set up Forge",
					action = "ForgeSetup",
					section = "Forge",
				},
			}
		end
		return {}
	end

	return {
		{
			name = keys[1] .. ".  Inbox",
			action = "edit " .. vim.fn.fnameescape(require("core.platform").forge_dir() .. "/inbox.md"),
			section = "Forge",
		},
		{
			name = keys[2] .. ".  Status",
			action = "ForgeStatus",
			section = "Forge",
		},
		{
			name = keys[3] .. ".  Board",
			action = "ForgeBoard",
			section = "Forge",
		},
		{
			name = keys[4] .. ".  Move project",
			action = "ForgeMove",
			section = "Forge",
		},
	}
end

-- Create all dashboard items with immediate generation for core items
function M.create_all_items()
	local items = {}

	-- Add shortcuts (lightweight, always immediate)
	for _, item in ipairs(M.create_shortcuts()) do
		table.insert(items, item)
	end

	-- Add Forge actions
	for _, item in ipairs(M.create_forge_items()) do
		table.insert(items, item)
	end

	-- Load recent files and projects immediately but with optimizations
	-- Add projects immediately
	for _, item in ipairs(M.create_projects()) do
		table.insert(items, item)
	end

	-- Add recent files immediately
	for _, item in ipairs(M.create_recent_files()) do
		table.insert(items, item)
	end

	return items
end

-- Clear cache function for manual refresh
function M.clear_cache()
	cached_projects = nil
	cached_recent_files = nil
	cache_timestamp = 0
end

return M

