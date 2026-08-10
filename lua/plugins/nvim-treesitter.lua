-- Configuration for nvim-treesitter
-- Syntax highlighting and code parsing

local ok, treesitter = pcall(require, "nvim-treesitter.configs")
if ok then
	treesitter.setup({
		ensure_installed = {
			"lua", "vim", "vimdoc", "javascript", "typescript",
			"python", "julia", "r", "bash", "json", "yaml",
			"markdown", "html", "css", "scss", "latex", "bibtex",
			"toml", "dockerfile", "gitignore", "comment", "regex",
			-- Bundled on Neovim 0.13+; keep listed so ensure_installed stays explicit.
			"diff",
		},
		highlight = {
			enable = true,
			-- Enable additional vim regex highlighting to support spell checking regions
			-- These filetypes need traditional syntax to define where spell check should look
			additional_vim_regex_highlighting = {
				"latex", "tex", "markdown",  -- Documents
				"python", "r", "julia",       -- Data science languages
				"javascript", "typescript",   -- Web languages
				"html", "css",                -- Web markup
				"bash", "sh",                 -- Shell scripts
			},
		},
		indent = { enable = true },
		-- Core 0.13 sibling maps: visual `]N` / `[N` expand to sibling nodes.
		-- Do not remap them here — they would clash with textobject `]m` / `]]` moves.
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "<CR>",
				node_incremental = "<CR>",
				node_decremental = "<BS>",
				scope_incremental = "<TAB>",
			},
		},
		textobjects = {
			enable = true,
			select = {
				enable = true,
				lookahead = true,
				keymaps = {
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["ac"] = "@class.outer",
					["ic"] = "@class.inner",
				},
			},
			move = {
				enable = true,
				set_jumps = true,
				goto_next_start = {
					["]m"] = "@function.outer",
					["]]"] = "@class.outer",
				},
				goto_next_end = {
					["]M"] = "@function.outer",
					["]["] = "@class.outer",
				},
				goto_previous_start = {
					["[m"] = "@function.outer",
					["[["] = "@class.outer",
				},
				goto_previous_end = {
					["[M"] = "@function.outer",
					["[]"] = "@class.outer",
				},
			},
		},
	})
end
