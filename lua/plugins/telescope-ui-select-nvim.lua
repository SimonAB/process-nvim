-- Configuration for telescope-ui-select.nvim
-- Ensures the extension is on runtimepath; setup/load lives in plugins.telescope.

local ok = pcall(vim.cmd.packadd, "telescope-ui-select.nvim")
if not ok then
	vim.notify("telescope-ui-select.nvim not found", vim.log.levels.WARN)
	return
end

-- If Telescope already ran setup before this module loaded, ensure the extension is active.
local ok_ts, telescope = pcall(require, "telescope")
if ok_ts then
	pcall(telescope.load_extension, "ui-select")
end
