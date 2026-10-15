-- =============================================================================
-- MODIFIED FILE PICKER
-- PURPOSE: Show newest files first while preserving Telescope's fuzzy search
-- =============================================================================

local ModifiedFilePicker = {}

---Use modification dates for an empty query and the original sorter otherwise.
---Keep the same sorter object so native fuzzy-sorter lifecycle hooks still run.
---@param sorter table Telescope file sorter
---@param cwd string Directory used to resolve finder results
---@return table sorter
function ModifiedFilePicker.with_modification_order(sorter, cwd)
	local fuzzy_score = sorter.scoring_function
	local scores = {}
	sorter.scoring_function = function(self, prompt, line, ...)
		if prompt ~= "" then
			return fuzzy_score(self, prompt, line, ...)
		end
		if scores[line] == nil then
			local path = vim.fs.abspath(vim.fs.joinpath(cwd, line))
			if line:sub(1, 1) == "/" then
				path = line
			end
			local stat = vim.uv.fs_stat(path)
			local modified = stat and (stat.mtime.sec + stat.mtime.nsec / 1e9) or 0
			-- Telescope ranks smaller non-negative scores first.
			scores[line] = 1 / (math.max(0, modified) + 1)
		end
		return scores[line]
	end
	return sorter
end

---Open the standard file picker with modification ordering for an empty query.
function ModifiedFilePicker.open()
	local builtin_ok, builtin = pcall(require, "telescope.builtin")
	local config_ok, config = pcall(require, "telescope.config")
	if not builtin_ok or not config_ok then
		vim.notify("Telescope not found", vim.log.levels.WARN)
		return
	end
	local opts = { cwd = vim.fn.getcwd(), prompt_title = "Find files · newest first" }
	opts.sorter = ModifiedFilePicker.with_modification_order(config.values.file_sorter(opts), opts.cwd)
	local success, err = pcall(builtin.find_files, opts)
	if not success then
		vim.notify("Could not open file picker: " .. tostring(err), vim.log.levels.ERROR)
	end
end

return ModifiedFilePicker
