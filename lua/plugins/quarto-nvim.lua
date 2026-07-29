-- Configuration for quarto-nvim
-- Quarto document authoring support with multi-language LSP via otter.nvim.
-- Interactive chunk execution uses the Julia REPL send mappings (<C-c>), not Molten.

local ok, quarto = pcall(require, "quarto")
if ok then
	quarto.setup({
		debug = false,
		closePreviewOnExit = true,
		lspFeatures = {
			enabled = true,
			chunks = "curly",
			languages = { "r", "python", "julia", "bash", "html" },
			diagnostics = {
				enabled = true,
				triggers = { "BufWritePost" },
			},
			completion = {
				enabled = true,
			},
		},
		-- Prefer toggleterm Julia REPL (<C-c> / <C-i> / <C-s>) over quarto-nvim runners.
		codeRunner = {
			enabled = false,
			default_method = nil,
			ft_runners = {},
			never_run = { "yaml" },
		},
	})
end
