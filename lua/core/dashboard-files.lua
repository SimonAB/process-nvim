-- =============================================================================
-- DASHBOARD FILES
-- PURPOSE: Discover recent editable files without blocking the editor
-- =============================================================================

local DashboardFiles = {}
local CACHE_DURATION = 10000
local MAX_DIRECTORIES = 8
local STAT_WORKERS = 16
local MAX_FILES = 5
local cache = {}
local start_scan

---Discard old completed entries while retaining in-flight work and the active key.
---@param keep string Directory that must remain available to the caller
local function prune_cache(keep)
	local count = vim.tbl_count(cache)
	while count > MAX_DIRECTORIES do
		local oldest_key, oldest_time = nil, math.huge
		for key, entry in pairs(cache) do
			if key ~= keep and not entry.pending and entry.used < oldest_time then
				oldest_key, oldest_time = key, entry.used
			end
		end
		if not oldest_key then
			break
		end
		cache[oldest_key] = nil
		count = count - 1
	end
end

---Normalise directory keys without depending on the active window's cwd.
---@param path string
---@return string
local function normalise_path(path)
	local absolute = vim.fs.normalize(vim.fs.abspath(path))
	local real = vim.uv.fs_realpath(absolute)
	if real then
		return real
	end
	-- Deleted files still need to invalidate caches reached through symlinked paths.
	local parent = vim.uv.fs_realpath(vim.fs.dirname(absolute))
	return parent and vim.fs.joinpath(parent, vim.fs.basename(absolute)) or absolute
end

---Publish only results from the current generation, restarting invalidated scans.
---@param cwd string
---@param entry table
---@param generation integer
---@param files table|nil
---@param err string|nil
local function finish_scan(cwd, entry, generation, files, err)
	vim.schedule(function()
		entry.pending = false
		if entry.generation ~= generation then
			start_scan(cwd, entry)
			return
		end
		if files then
			entry.files = files
		end
		entry.expires = vim.uv.now() + (err and 1000 or CACHE_DURATION)
		if err then
			vim.notify("Dashboard file discovery: " .. err, vim.log.levels.WARN)
		end
		local callbacks = entry.callbacks
		entry.callbacks = {}
		for callback in pairs(callbacks) do
			callback(cwd)
		end
		prune_cache(cwd)
	end)
end

---Read only leading candidates until five non-binary readable files are found.
---@param cwd string
---@param entry table
---@param generation integer
---@param candidates table
local function select_text_files(cwd, entry, generation, candidates)
	table.sort(candidates, function(a, b)
		if a.mtime.sec ~= b.mtime.sec then
			return a.mtime.sec > b.mtime.sec
		end
		if a.mtime.nsec ~= b.mtime.nsec then
			return a.mtime.nsec > b.mtime.nsec
		end
		return a.name < b.name
	end)
	local selected, index = {}, 0
	local read_next
	read_next = function()
		index = index + 1
		local file = candidates[index]
		if not file or #selected >= MAX_FILES then
			finish_scan(cwd, entry, generation, selected)
			return
		end
		vim.uv.fs_open(file.path, "r", 0, function(_, fd)
			if not fd then
				read_next()
				return
			end
			vim.uv.fs_read(fd, 8192, 0, function(_, prefix)
				vim.uv.fs_close(fd, function()
					if prefix and not prefix:find("%z") then
						table.insert(selected, file)
					end
					read_next()
				end)
			end)
		end)
	end
	read_next()
end

---Check metadata using a bounded pool instead of synchronous calls on the UI thread.
---@param cwd string
---@param entry table
---@param generation integer
---@param stdout string
local function collect_metadata(cwd, entry, generation, stdout)
	local names, candidates = {}, {}
	for name in stdout:gmatch("([^%z]+)%z") do
		table.insert(names, name)
	end
	if #names == 0 then
		finish_scan(cwd, entry, generation, {})
		return
	end
	local next_index, completed = 0, 0
	local check_next
	check_next = function()
		next_index = next_index + 1
		local name = names[next_index]
		if not name then
			return
		end
		local path = vim.fs.joinpath(cwd, name)
		vim.uv.fs_stat(path, function(_, stat)
			if stat and stat.type == "file" then
				table.insert(candidates, { name = name, path = path, mtime = stat.mtime })
			end
			completed = completed + 1
			if completed == #names then
				vim.schedule(function()
					select_text_files(cwd, entry, generation, candidates)
				end)
			else
				check_next()
			end
		end)
	end
	for _ = 1, math.min(STAT_WORKERS, #names) do
		check_next()
	end
end

---Start an ignore-aware background walk, coalescing requests for this directory.
---@param cwd string
---@param entry table
start_scan = function(cwd, entry)
	entry.pending = true
	local generation = entry.generation
	local ok, err = pcall(vim.system, { "rg", "--files", "--null" }, {
		cwd = cwd,
		timeout = 2000,
	}, function(result)
		if result.code ~= 0 and result.code ~= 1 then
			finish_scan(cwd, entry, generation, nil, "ripgrep failed or timed out")
			return
		end
		vim.schedule(function()
			collect_metadata(cwd, entry, generation, result.stdout or "")
		end)
	end)
	if not ok then
		finish_scan(cwd, entry, generation, nil, tostring(err))
	end
end

---Return cached files immediately and refresh expired entries in the background.
---@param cwd string
---@param on_update function|nil Called once fresh results are available
---@return table files Last completed results, possibly empty or stale
function DashboardFiles.get(cwd, on_update)
	cwd = normalise_path(cwd)
	local entry = cache[cwd]
	if not entry then
		entry = { files = {}, expires = 0, generation = 0, callbacks = {} }
		cache[cwd] = entry
	end
	entry.used = vim.uv.now()
	prune_cache(cwd)
	if entry.pending or entry.expires <= entry.used then
		if on_update then
			entry.callbacks[on_update] = true
		end
		if not entry.pending then
			start_scan(cwd, entry)
		end
	end
	return entry.files
end

---Expire directory caches containing a saved, renamed or deleted file.
---@param path string|nil Nil expires all cached directories
function DashboardFiles.invalidate(path)
	path = path and normalise_path(path)
	for cwd, entry in pairs(cache) do
		local prefix = cwd == "/" and cwd or cwd .. "/"
		if not path or path == cwd or path:sub(1, #prefix) == prefix then
			entry.expires = 0
			entry.generation = entry.generation + 1
		end
	end
end

return DashboardFiles
