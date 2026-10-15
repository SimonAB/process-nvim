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
			section = "Actions",
		},
		{
			name = "Grep",
			action = "Telescope live_grep",
			section = "Actions",
		},
		{
			name = "Quit",
			action = "confirm qall",
			section = "Actions",
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
			section = "Actions",
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
		table.insert(projects, { name = name, action = action, section = "Recent projects" })
		idx = idx + 1
	end

	return projects
end

---Create history entries outside the current directory tree.
---@return table items Recent files with paths to distinguish matching names
function M.create_recent_files()
	local items = {}
	local cwd = vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
	for _, file in ipairs(vim.v.oldfiles or {}) do
		local path = vim.uv.fs_realpath(file)
		if path and path ~= cwd and path:sub(1, #cwd + 1) ~= cwd .. "/"
			and vim.fn.filereadable(path) == 1 then
			table.insert(items, {
				name = vim.fn.fnamemodify(path, ":~"),
				action = "edit " .. utils.escape_filename(path),
				section = "Recent files elsewhere",
			})
			if #items >= config.DASHBOARD.MAX_RECENT_FILES then
				break
			end
		end
	end
	return items
end

---Create items for visible text files directly in the working directory.
---Read a small prefix to exclude binary files without loading whole documents.
---@return table items Dashboard entries, newest modification first
function M.create_cwd_files()
	local cwd = vim.fn.getcwd()
	local scan = vim.uv.fs_scandir(cwd)
	if not scan then
		return {}
	end

	local files = {}
	while true do
		local name, kind = vim.uv.fs_scandir_next(scan)
		if not name then
			break
		end
		if kind == "file" and name:sub(1, 1) ~= "." then
			local path = vim.fs.joinpath(cwd, name)
			local stat = vim.uv.fs_stat(path)
			local fd = vim.uv.fs_open(path, "r", 0)
			if fd then
				local prefix = vim.uv.fs_read(fd, 8192, 0)
				vim.uv.fs_close(fd)
				if stat and prefix and not prefix:find("%z") then
					table.insert(files, { name = name, path = path, mtime = stat.mtime })
				end
			end
		end
	end

	table.sort(files, function(a, b)
		if a.mtime.sec ~= b.mtime.sec then
			return a.mtime.sec > b.mtime.sec
		end
		if a.mtime.nsec ~= b.mtime.nsec then
			return a.mtime.nsec > b.mtime.nsec
		end
		return a.name < b.name
	end)

	local items = {}
	for i = 1, math.min(#files, config.DASHBOARD.MAX_CWD_FILES) do
		local file = files[i]
		table.insert(items, {
			name = config.DASHBOARD.CWD_FILE_KEYS[i] .. ".  " .. file.name,
			action = function()
				vim.cmd.edit(vim.fn.fnameescape(file.path))
			end,
			section = "Current directory",
		})
	end
	return items
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
					section = "Actions",
					forge_action = true,
				},
			}
		end
		return {}
	end

	return {
		{
			name = keys[1] .. ".  Inbox",
			action = "edit " .. vim.fn.fnameescape(require("core.platform").forge_dir() .. "/inbox.md"),
			section = "Actions",
			forge_action = true,
		},
		{
			name = keys[2] .. ".  Status",
			action = "ForgeStatus",
			section = "Actions",
			forge_action = true,
		},
		{
			name = keys[3] .. ".  Board",
			action = "ForgeBoard",
			section = "Actions",
			forge_action = true,
		},
		{
			name = keys[4] .. ".  Move project",
			action = "ForgeMove",
			section = "Actions",
			forge_action = true,
		},
	}
end

-- Create all dashboard items with immediate generation for core items
function M.create_all_items()
	local items = {}

	-- Order sections around the current work before navigation and housekeeping.
	for _, create_items in ipairs({
		M.create_cwd_files,
		M.create_projects,
		M.create_recent_files,
		M.create_shortcuts,
		M.create_forge_items,
	}) do
		vim.list_extend(items, create_items())
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

