-- Configuration for typst-preview-nvim
-- Low latency Typst preview for Neovim

local typst_project = require("core.typst-project")

local ok, typst_preview = pcall(require, "typst-preview")
if ok then
	typst_preview.setup({
		debug = false,
		port = 0, -- Use random port
		-- Follow the browser dark mode. The plugin always passes this flag;
		-- its own default is "never", which keeps the preview on the light palette.
		invert_colors = "auto",
		follow_cursor = true,
		extra_args = nil,
		-- System tinymist (Homebrew on macOS, pacman on Arch/Omarchy); skip plugin download.
		dependencies_bin = {
			tinymist = "tinymist",
		},
		get_root = typst_project.find_root,
		-- Get main Typst file
		get_main_file = function(path)
			return path
		end,
	})
end
