-- Plugin management keymaps for Blink.cmp
-- This plugin provides fast, extensible autocompletion for Neovim.
-- See https://github.com/glepnir/blink.nvim for more details and advanced usage.

local map = vim.keymap.set -- For custom keymaps if needed

-- Blink.cmp completion setup with simplified config
-- Neovim 0.13 LSP commitCharacters are honoured by the client; blink surfaces
-- them through its accept path. Do not set completeopt+=preselect here — it
-- fights blink's menu selection model (see config.lua completeopt).
local ok, blink = pcall(require, "blink.cmp")
if ok then
	local frecency_path = vim.fn.stdpath("state") .. "/blink/cmp/frecency.dat"
	-- Repair older state where this path was created as a directory.
	if vim.fn.isdirectory(frecency_path) == 1 then
		vim.fn.delete(frecency_path, "rf")
	end

	blink.setup({
		keymap = {
			preset = "default", -- Use default keymap preset
			["<C-Space>"] = { "show", "show_documentation", "hide_documentation" }, -- Show completion/documentation
			["<C-e>"] = { "hide" }, -- Hide completion menu
			["<CR>"] = { "accept", "fallback" }, -- Accept completion
			["<Tab>"] = { "select_next", "fallback" }, -- Next item
			["<S-Tab>"] = { "select_prev", "fallback" }, -- Previous item
		},
		appearance = {
			use_nvim_cmp_as_default = false, -- Do not override nvim-cmp if present
			nerd_font_variant = "mono", -- Use monospaced nerd font icons
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "codecompanion" }, -- Completion sources
			providers = {
				codecompanion = {
					name = "CodeCompanion",
					module = "codecompanion.providers.completion.blink",
					enabled = true,
				},
			},
		},
		completion = {
			accept = {
				auto_brackets = {
					enabled = true, -- Auto-insert brackets for functions
				},
			},
			menu = {
				enabled = true,
				auto_show = true, -- Show menu automatically
			},
			documentation = {
				auto_show = true, -- Show docs automatically
				auto_show_delay_ms = 200, -- Delay for docs popup
			},
			ghost_text = {
				enabled = true, -- Show ghost text for suggestions
			},
		},
		signature = {
			enabled = true, -- Enable signature help
		},
		fuzzy = {
			implementation = "prefer_rust", -- Use Rust for fuzzy matching if available
			frecency = {
				enabled = true,
				path = frecency_path,
			},
		},
	})
end
