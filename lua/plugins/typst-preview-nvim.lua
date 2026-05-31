-- Configuration for typst-preview-nvim
-- Low latency Typst preview for Neovim

local typst_project = require("core.typst-project")

local ok, typst_preview = pcall(require, "typst-preview")
if ok then
	typst_preview.setup({
		debug = false,
		port = 0, -- Use random port
		invert_colors = 'never',
		follow_cursor = true,
		extra_args = nil,
		get_root = typst_project.find_root,
		-- Get main Typst file
		get_main_file = function(path)
			return path
		end,
	})
end
