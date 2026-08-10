-- Configuration for nvim-tree.lua
-- File explorer with enhanced visual features

local ok, nvim_tree = pcall(require, "nvim-tree")
if ok then
	nvim_tree.setup({
	view = {
		side = "left", -- Show tree on the left
		width = 30, -- Set width of the tree window
		-- Match global `cursorline` off; avoids a solid `NvimTreeCursorLine` row under Flexoki.
		cursorline = false,
	},
	-- Let Neovim 0.13+ `dir.lua` own `:edit` / `nvim .` on directories.
	-- Sidebar browsing stays on `<leader>e` (NvimTreeToggle).
	hijack_directories = {
		enable = false,
	},
	hijack_netrw = true,
	renderer = {
		icons = {
			show = {
				git = true, -- Show git status icons
				folder = true, -- Show folder icons
				file = true, -- Show file icons
			},
		},
	},
	filters = {
		dotfiles = false, -- Show dotfiles by default
		git_ignored = false, -- Show gitignored paths (e.g. Forge tasks/)
	},
	-- You can add more config here (e.g., actions, git integration, etc.)
	})

	-- Keep the tree background transparent to match the rest of the UI.
	local function apply_transparent_tree_highlights()
		for _, group in ipairs({
			"NvimTreeNormal",
			"NvimTreeNormalNC",
			"NvimTreeEndOfBuffer",
			"NvimTreeWinSeparator",
			"NvimTreeStatusLine",
			"NvimTreeStatusLineNC",
			"NvimTreeCursorLine",
			"NvimTreeCursorLineNr",
		}) do
			pcall(vim.api.nvim_set_hl, 0, group, { bg = "none" })
		end
	end

	apply_transparent_tree_highlights()

	local augroup = vim.api.nvim_create_augroup("NvimTreeTransparency", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = augroup,
		desc = "Reapply nvim-tree transparency after theme changes",
		callback = function()
			vim.defer_fn(apply_transparent_tree_highlights, 20)
		end,
	})
end
