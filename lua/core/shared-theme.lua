-- =============================================================================
-- SHARED THEME
-- PURPOSE: Read the portable application theme selection and refresh running editors
-- =============================================================================

local SharedTheme = {}
local timer

---Locate the selection beside the real configuration, including symlinked installs.
---@return string
local function selection_path()
	if vim.env.SHARED_THEME_FILE then
		return vim.env.SHARED_THEME_FILE
	end
	local config = vim.uv.fs_realpath(vim.fn.stdpath("config")) or vim.fn.stdpath("config")
	return vim.fs.joinpath(vim.fs.dirname(config), "theme", "selection.json")
end

---Read a validated selection; absent or incomplete files retain local defaults.
---@return table|nil
function SharedTheme.read()
	local ok_read, lines = pcall(vim.fn.readfile, selection_path())
	if not ok_read then
		return nil
	end
	local ok_json, selection = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok_json or type(selection) ~= "table" or type(selection.nvim) ~= "table" then
		return nil
	end
	if selection.appearance ~= "auto" and selection.appearance ~= "light"
		and selection.appearance ~= "dark" then
		return nil
	end
	for _, appearance in ipairs({ "light", "dark" }) do
		local name = selection.nvim[appearance]
		if type(name) ~= "string" or not name:match("^[%w_%-]+$") then
			return nil
		end
	end
	return selection
end

---Watch a small selection file without rewriting configuration or touching buffers.
function SharedTheme.setup()
	if timer then
		timer:stop()
		timer:close()
	end
	local previous = vim.inspect(SharedTheme.read())
	timer = vim.uv.new_timer()
	if not timer then
		vim.notify("Unable to watch shared theme selection", vim.log.levels.WARN)
		return
	end
	timer:start(1000, 1000, vim.schedule_wrap(function()
		local current = vim.inspect(SharedTheme.read())
		if current == previous then
			return
		end
		previous = current
		local ok_theme, manager = pcall(require, "core.theme-manager")
		if ok_theme then
			manager.load_immediate()
		end
	end))
	local group = vim.api.nvim_create_augroup("SharedTheme", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		desc = "Close shared theme watcher",
		callback = function()
			if timer and not timer:is_closing() then
				timer:stop()
				timer:close()
			end
		end,
	})
end

return SharedTheme
