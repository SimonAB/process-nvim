-- Essential Core Key Mappings
-- PURPOSE: Provide fast, plugin-independent keymaps for early startup
--
-- Maintenance notes:
-- - Keep this file strictly plugin-free: no `require()` calls for external plugins and no
--   commands that only exist when plugins are loaded.
-- - If a mapping depends on a plugin, move it to `keymaps-plugins.lua` instead.

local map = vim.keymap.set

-- ============================================================================
-- GENERAL KEYMAPS (NO PLUGIN DEPENDENCIES)
-- ============================================================================

-- Better window navigation (works from normal and terminal mode)
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Terminal mode window navigation (allows moving out of terminal)
map("t", "<C-h>", "<C-\\><C-N><C-w>h", { desc = "Move to left window from terminal" })
map("t", "<C-j>", "<C-\\><C-N><C-w>j", { desc = "Move to bottom window from terminal" })
map("t", "<C-k>", "<C-\\><C-N><C-w>k", { desc = "Move to top window from terminal" })
map("t", "<C-l>", "<C-\\><C-N><C-w>l", { desc = "Move to right window from terminal" })

-- Window resizing
map("n", "<S-Up>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<S-Down>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<S-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<S-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

map("n", "<leader>Wk", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<leader>Wj", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<leader>Wh", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<leader>Wl", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Alternative resize bindings for terminals/macOS quirks
map("n", "<A-Up>", "<cmd>resize -2<CR>", { desc = "Decrease window height (Alt)" })
map("n", "<A-Down>", "<cmd>resize +2<CR>", { desc = "Increase window height (Alt)" })
map("n", "<A-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width (Alt)" })
map("n", "<A-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width (Alt)" })

map("n", "<M-Up>", "<cmd>resize -2<CR>", { desc = "Decrease window height (Meta)" })
map("n", "<M-Down>", "<cmd>resize +2<CR>", { desc = "Increase window height (Meta)" })
map("n", "<M-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width (Meta)" })
map("n", "<M-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width (Meta)" })

map("n", "<Esc>[1;3A", "<cmd>resize -2<CR>", { desc = "Decrease window height (ESC seq)" })
map("n", "<Esc>[1;3B", "<cmd>resize +2<CR>", { desc = "Increase window height (ESC seq)" })
map("n", "<Esc>[1;3C", "<cmd>vertical resize +2<CR>", { desc = "Increase window width (ESC seq)" })
map("n", "<Esc>[1;3D", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width (ESC seq)" })

---Check whether an Ex command exists.
---@param cmd string
---@return boolean
local function cmd_exists(cmd)
	return vim.fn.exists(":" .. cmd) == 2
end

---Go to the next buffer, preferring BufferLine when available.
local function goto_next_buffer()
	if cmd_exists("BufferLineCycleNext") then
		vim.cmd("BufferLineCycleNext")
		return
	end

	vim.cmd("bnext")
end

---Go to the previous buffer, preferring BufferLine when available.
local function goto_previous_buffer()
	if cmd_exists("BufferLineCyclePrev") then
		vim.cmd("BufferLineCyclePrev")
		return
	end

	vim.cmd("bprevious")
end

map("n", "<S-l>", goto_next_buffer, { desc = "Next buffer" })
map("n", "<S-h>", goto_previous_buffer, { desc = "Previous buffer" })

-- Clear search highlights
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- Better indenting
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move text up and down
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Better paste
map("v", "p", '"_dP', { desc = "Paste without yanking" })

-- ============================================================================
-- CORE LEADER KEYMAPS (NO PLUGIN DEPENDENCIES)
-- ============================================================================

map("n", "<leader>w", "<cmd>w<CR>", { desc = "Write" })
map("n", "<C-s>", "<cmd>w<CR>", { desc = "Quick save" })
map("n", "<leader>q", "<cmd>bdelete<CR>", { desc = "Close Buffer" })
map("n", "<leader>h", "<cmd>nohlsearch<CR>", { desc = "Hide Highlight" })

-- Split commands in Split group (using | since S is for Search)
map("n", "<leader>|v", "<cmd>vsplit<CR>", { desc = "Split Vertical" })
map("n", "<leader>|h", "<cmd>split<CR>", { desc = "Split Horizontal" })

-- Toggle options (using Y prefix since T is for Terminal)
map("n", "<leader>Yw", "<cmd>set wrap!<CR>", { desc = "Toggle wrap" })
map("n", "<leader>Yn", "<cmd>set number!<CR>", { desc = "Toggle line numbers" })

map("n", "<leader>Ys", "<cmd>set spell!<CR>", { desc = "Toggle spell check" })
map("n", "<leader>Yse", function()
	local config_dir = vim.fn.stdpath("config")

	-- Disable first to clear spell cache, then re-enable with the new language.
	vim.cmd("set nospell")
	vim.opt.spellfile = config_dir .. "/private/spell/en.utf-8.add"
	vim.cmd("set spelllang=en_gb")
	vim.cmd("set spell")

	vim.notify("Spell language: English (British)", vim.log.levels.INFO)
end, { desc = "Spell: English (British)" })

map("n", "<leader>Ysf", function()
	local config_dir = vim.fn.stdpath("config")

	vim.cmd("set nospell")
	vim.opt.spellfile = config_dir .. "/private/spell/fr.utf-8.add"
	vim.cmd("set spelllang=fr")
	vim.cmd("set spell")

	vim.notify("Spell language: French", vim.log.levels.INFO)
end, { desc = "Spell: French" })

-- Configuration reload
map("n", "<leader>Cs", function()
	local config_path = vim.fn.stdpath("config")

	local modules_to_clear = {
		"config",
		"keymaps",
		"keymaps-core",
		"keymaps-plugins",
		"plugins",
	}

	for _, module in ipairs(modules_to_clear) do
		package.loaded[module] = nil
	end

	local ok_reload, PluginReload = pcall(require, "core.plugin-reload")
	if ok_reload then
		PluginReload.reload_gitsigns_if_stale()
	end

	vim.cmd("source " .. config_path .. "/init.lua")
	print("✓ Configuration reloaded!")
end, { desc = "Reload configuration" })

-- Session resilience (Neovim 0.13+: :restart restores layout; :detach! survives UI loss)
map("n", "<leader>Cr", function()
	vim.cmd("restart")
end, { desc = "Restart Neovim (restore session)" })

map("n", "<leader>CR", function()
	vim.cmd("restart!")
end, { desc = "Restart Neovim (no session restore)" })

map("n", "<leader>Cd", function()
	vim.cmd("detach!")
	vim.notify(
		"UI marked detachable. If the terminal closes, reconnect with :connect",
		vim.log.levels.INFO
	)
end, { desc = "Mark UI detachable (:detach!)" })

-- LSP operations (built-in)
map("n", "<leader>Ll", function()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if #clients == 0 then
		print("No LSP servers running")
		return
	end

	print("Active LSP servers:")
	for _, client in ipairs(clients) do
		print(string.format("  %s (ID: %d)", client.name, client.id))
	end
end, { desc = "LSP: List servers" })

map("n", "<leader>Lr", function()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if #clients == 0 then
		print("No active LSP clients to restart")
		return
	end
	vim.notify("Restarting LSP...", vim.log.levels.INFO)
	vim.cmd("LspRestart")
end, { desc = "LSP: Restart" })

map("n", "<leader>Lf", function()
	vim.lsp.buf.format({ async = true })
end, { desc = "LSP: Format" })

map("n", "<leader>LR", function()
	vim.lsp.buf.references()
end, { desc = "LSP: References" })

return {}

