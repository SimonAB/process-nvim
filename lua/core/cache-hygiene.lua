-- =============================================================================
-- CACHE HYGIENE
-- PURPOSE: Bound undo history and trim leftover Neovim logs on startup.
-- =============================================================================

local M = {}

local UNDO_MAX_AGE_SEC = 90 * 24 * 60 * 60
local LOG_MAX_BYTES = 2 * 1024 * 1024

---@param path string
---@return integer
local function file_size(path)
	local stat = vim.uv.fs_stat(path)
	return (stat and stat.size) or 0
end

---Delete undofiles older than UNDO_MAX_AGE_SEC.
---@return integer removed
local function prune_old_undofiles()
	local undo_dir = vim.fn.stdpath("state") .. "/undo"
	if vim.fn.isdirectory(undo_dir) ~= 1 then
		return 0
	end

	local now = os.time()
	local removed = 0
	for name, ftype in vim.fs.dir(undo_dir) do
		if ftype == "file" then
			local path = undo_dir .. "/" .. name
			local mtime = vim.fn.getftime(path)
			if mtime > 0 and (now - mtime) > UNDO_MAX_AGE_SEC then
				if vim.fn.delete(path) == 0 then
					removed = removed + 1
				end
			end
		end
	end
	return removed
end

---Truncate a log file when it exceeds LOG_MAX_BYTES.
---@param path string
---@return boolean truncated
local function truncate_large_log(path)
	if vim.fn.filereadable(path) ~= 1 then
		return false
	end
	if file_size(path) <= LOG_MAX_BYTES then
		return false
	end
	local ok = pcall(function()
		local f = assert(io.open(path, "w"))
		f:close()
	end)
	return ok
end

---Remove profiling leftovers and bound LSP / Neovim logs.
---@return integer deleted, integer truncated
local function tidy_logs()
	local deleted = 0
	local truncated = 0

	local startup_log = vim.fn.stdpath("cache") .. "/startup.log"
	if vim.fn.filereadable(startup_log) == 1 then
		if vim.fn.delete(startup_log) == 0 then
			deleted = deleted + 1
		end
	end

	local candidates = {
		vim.fn.stdpath("state") .. "/lsp.log", -- legacy path
		vim.fn.stdpath("log") .. "/lsp.log",
		vim.fn.stdpath("log") .. "/nvim.log",
	}
	if vim.lsp and type(vim.lsp.get_log_path) == "function" then
		-- Prefer the non-deprecated API when present (Neovim 0.13+).
		local path = nil
		if vim.lsp.log and type(vim.lsp.log.get_filename) == "function" then
			local ok, p = pcall(vim.lsp.log.get_filename)
			if ok then
				path = p
			end
		end
		if not path then
			local ok, p = pcall(vim.lsp.get_log_path)
			if ok then
				path = p
			end
		end
		if type(path) == "string" and path ~= "" then
			candidates[#candidates + 1] = path
		end
	end

	local seen = {}
	for _, path in ipairs(candidates) do
		if not seen[path] then
			seen[path] = true
			if truncate_large_log(path) then
				truncated = truncated + 1
			end
		end
	end

	return deleted, truncated
end

---Run hygiene tasks once (safe to call deferred from startup).
function M.run()
	local undo_removed = prune_old_undofiles()
	local logs_deleted, logs_truncated = tidy_logs()

	if vim.g.nvim_cache_hygiene_debug and (undo_removed > 0 or logs_deleted > 0 or logs_truncated > 0) then
		vim.notify(
			string.format(
				"Cache hygiene: %d old undofile(s), %d log(s) deleted, %d log(s) truncated",
				undo_removed,
				logs_deleted,
				logs_truncated
			),
			vim.log.levels.DEBUG
		)
	end
end

return M
