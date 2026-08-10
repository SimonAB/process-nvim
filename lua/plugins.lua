-- Plugin Management with vim.pack (Neovim 0.13-dev / 0.12+)
-- Purpose: Declare plugins for vim.pack and register build hooks

local plugins = {
	-- Core functionality
	{ src = "https://github.com/nvim-lua/plenary.nvim", name = "plenary.nvim" },
	{ src = "https://github.com/nvim-tree/nvim-web-devicons", name = "nvim-web-devicons" },
	{ src = "https://github.com/Saghen/blink.lib", name = "blink.lib" },
	{ src = "https://github.com/Saghen/blink.cmp", name = "blink.cmp", data = { build = "cargo build --release" } },

	-- LSP / language tooling
	{ src = "https://github.com/mason-org/mason.nvim", name = "mason.nvim" },
	{ src = "https://github.com/mason-org/mason-lspconfig.nvim", name = "mason-lspconfig.nvim" },
	{ src = "https://github.com/neovim/nvim-lspconfig", name = "nvim-lspconfig" },
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", name = "nvim-treesitter" },

	-- UI and workflow
	{ src = "https://github.com/folke/trouble.nvim", name = "trouble.nvim" },
	{ src = "https://github.com/akinsho/bufferline.nvim", name = "bufferline.nvim" },
	{ src = "https://github.com/nvim-lualine/lualine.nvim", name = "lualine.nvim" },
	{ src = "https://github.com/nvim-tree/nvim-tree.lua", name = "nvim-tree.lua" },
	{ src = "https://github.com/nvim-telescope/telescope.nvim", name = "telescope.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope-ui-select.nvim", name = "telescope-ui-select.nvim" },
	{ src = "https://github.com/olimorris/codecompanion.nvim", name = "codecompanion.nvim" },
	{
		src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim",
		name = "telescope-fzf-native.nvim",
		data = {
			-- Prevent Conda/SDK toolchain leakage (common on macOS) from breaking link step.
			build = 'make clean && env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin" make CC=/usr/bin/clang CFLAGS="-Wall -fpic -std=gnu99"',
		},
	},
	{ src = "https://github.com/nvim-telescope/telescope-frecency.nvim", name = "telescope-frecency.nvim" },
	{ src = "https://github.com/kkharji/sqlite.lua", name = "sqlite.lua" },
	{ src = "https://github.com/folke/which-key.nvim", name = "which-key.nvim" },
	{ src = "https://github.com/akinsho/toggleterm.nvim", name = "toggleterm.nvim" },
	{ src = "https://github.com/lewis6991/gitsigns.nvim", name = "gitsigns.nvim" },
	{ src = "https://github.com/echasnovski/mini.nvim", name = "mini.nvim" },

	-- Writing / documents
	{ src = "https://github.com/lervag/vimtex", name = "vimtex" },
	{
		src = "https://github.com/iamcco/markdown-preview.nvim",
		name = "markdown-preview.nvim",
		data = { build = { cmd = "./install.sh", cwd = "app" } },
	},
	{ src = "https://github.com/chomosuke/typst-preview.nvim", name = "typst-preview.nvim" },
	{ src = "https://github.com/epwalsh/obsidian.nvim", name = "obsidian.nvim" },
	{ src = "https://github.com/3rd/image.nvim", name = "image.nvim" },
	{ src = "https://github.com/gaoDean/autolist.nvim", name = "autolist.nvim" },
	{ src = "https://github.com/SCJangra/table-nvim", name = "table-nvim" },
	{ src = "https://github.com/folke/zen-mode.nvim", name = "zen-mode.nvim" },
	{ src = "https://github.com/jmbuhr/otter.nvim", name = "otter.nvim" },
	{ src = "https://github.com/quarto-dev/quarto-nvim", name = "quarto-nvim" },

	-- Misc
	{ src = "https://github.com/f-person/auto-dark-mode.nvim", name = "auto-dark-mode.nvim" },
	{ src = "https://github.com/JuliaEditorSupport/julia-vim", name = "julia-vim" },
	{ src = "https://github.com/SimonAB/flexoki-neovim", name = "flexoki-neovim" },
	{ src = "https://github.com/folke/tokyonight.nvim", name = "tokyonight.nvim" },
	{ src = "https://github.com/arcticicestudio/nord-vim", name = "nord-vim" },
	{ src = "https://github.com/projekt0n/github-nvim-theme", name = "github-nvim-theme" },
	{ src = "https://github.com/navarasu/onedark.nvim", name = "onedark.nvim" },
	{ src = "https://github.com/ellisonleao/gruvbox.nvim", name = "gruvbox.nvim" },
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
	{ src = "https://github.com/rafi/awesome-vim-colorschemes", name = "awesome-vim-colorschemes" },
}

local augroup = vim.api.nvim_create_augroup("VimPackHooks", { clear = true })
local PluginReload = require("core.plugin-reload")

---Run a plugin build hook, if configured.
---@param ev table
local function run_build_hook(ev)
	local spec = (ev.data or {}).spec or {}
	local data = spec.data or {}
	local build = data.build

	if not build or (ev.data.kind ~= "install" and ev.data.kind ~= "update") then
		return
	end

	local cmd = nil
	local cwd = ev.data.path

	if type(build) == "string" then
		cmd = build
	elseif type(build) == "table" then
		cmd = build.cmd
		if build.cwd and build.cwd ~= "" then
			cwd = cwd .. "/" .. build.cwd
		end
	end

	if not cmd or cmd == "" then
		return
	end

	local shell = "/opt/homebrew/bin/zsh"
	local result = vim.system({ shell, "-lc", cmd }, { cwd = cwd, text = true }):wait()
	if result.code ~= 0 then
		vim.notify(
			string.format("Build failed for %s: %s", spec.name or "unknown plugin", (result.stderr or ""):gsub("%s+$", "")),
			vim.log.levels.WARN
		)
	end
end

vim.api.nvim_create_autocmd("PackChanged", {
	group = augroup,
	desc = "vim.pack install/update: build hooks and Lua module cache hygiene",
	callback = function(ev)
		run_build_hook(ev)
		PluginReload.on_pack_changed(ev)
	end,
})

-- Install/register plugins, but defer loading to core/plugin-loader.lua phases.
vim.pack.add(plugins, { load = false, confirm = true })

_G.neovim_plugins = plugins

return plugins
