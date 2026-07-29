-- Minimal configuration for otter.nvim
-- Multi-language LSP support for Quarto / markdown embedded chunks.
-- Interactive execution stays on the Julia REPL send mappings (<C-c>).

-- Only load otter if it's available and not already loaded
local ok, otter = pcall(require, "otter")
if ok and not otter._setup_done then
	otter.setup({
		-- Minimal configuration to avoid circular dependencies
		lsp = {
			-- Don't auto-activate to avoid conflicts
			auto_activate = false,
		},
		-- Disable automatic features that might cause issues
		automatic_activation = false,
	})
	otter._setup_done = true
end
