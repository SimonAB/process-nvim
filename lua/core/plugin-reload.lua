-- =============================================================================
-- PLUGIN RELOAD / CACHE HYGIENE
-- Clears stale Lua module caches after vim.pack updates so on-disk code matches
-- package.loaded (e.g. gitsigns manager.handle_on_lines after refactors).
-- =============================================================================

local M = {}

---Pack name -> Lua require prefix (when it differs from the plugin folder name).
---@type table<string, string>
M.MODULE_PREFIX = {
	["blink.cmp"] = "blink.cmp",
	["blink.lib"] = "blink.lib",
	["bufferline.nvim"] = "bufferline",
	["codecompanion.nvim"] = "codecompanion",
	["gitsigns.nvim"] = "gitsigns",
	["github-nvim-theme"] = "github_theme",
	["gruvbox.nvim"] = "gruvbox",
	["lualine.nvim"] = "lualine",
	["mason-lspconfig.nvim"] = "mason-lspconfig",
	["mason.nvim"] = "mason",
	["mini.nvim"] = "mini",
	["nvim-lspconfig"] = "lspconfig",
	["nvim-tree.lua"] = "nvim-tree",
	["nvim-treesitter"] = "nvim-treesitter",
	["nvim-web-devicons"] = "nvim-web-devicons",
	["obsidian.nvim"] = "obsidian",
	["onedark.nvim"] = "onedark",
	["plenary.nvim"] = "plenary",
	["quarto-nvim"] = "quarto",
	["sqlite.lua"] = "sqlite",
	["telescope-frecency.nvim"] = "telescope-frecency",
	["telescope-fzf-native.nvim"] = "telescope-fzf-native",
	["telescope.nvim"] = "telescope",
	["toggleterm.nvim"] = "toggleterm",
	["tokyonight.nvim"] = "tokyonight",
	["trouble.nvim"] = "trouble",
	["typst-preview.nvim"] = "typst-preview",
	["vimtex"] = "vimtex",
	["which-key.nvim"] = "which-key",
	["zen-mode.nvim"] = "zen",
}

---Plugins that should not be hot-reloaded after an in-session update.
---@type table<string, boolean>
M.RESTART_RECOMMENDED = {
	["blink.cmp"] = true,
	["gitsigns.nvim"] = true,
	["markdown-preview.nvim"] = true,
	["nvim-treesitter"] = true,
	["telescope-fzf-native.nvim"] = true,
	["vimtex"] = true,
}

---Derive Lua module prefix from a vim.pack plugin name.
---@param plugin_name string
---@return string
function M.module_prefix(plugin_name)
	if M.MODULE_PREFIX[plugin_name] then
		return M.MODULE_PREFIX[plugin_name]
	end
	return plugin_name:gsub("%.nvim$", ""):gsub("%.lua$", "")
end

---Clear package.loaded entries for a module prefix.
---@param prefix string
---@return integer cleared
function M.clear_modules(prefix)
	if prefix == "" then
		return 0
	end

	local escaped = vim.pesc(prefix)
	local pattern = "^" .. escaped .. "(%.|$)"
	local cleared = 0

	for name in pairs(package.loaded) do
		if name == prefix or name:match(pattern) then
			package.loaded[name] = nil
			cleared = cleared + 1
		end
	end

	return cleared
end

---Clear caches for one or more plugin names.
---@param plugin_names string|string[]
---@return integer cleared
function M.clear_plugins(plugin_names)
	if type(plugin_names) == "string" then
		plugin_names = { plugin_names }
	end

	local total = 0
	for _, name in ipairs(plugin_names) do
		total = total + M.clear_modules(M.module_prefix(name))
	end
	return total
end

---True when gitsigns attach/manager APIs are inconsistent (post-update stale cache).
---@return boolean
function M.gitsigns_stale()
	local mgr = package.loaded["gitsigns.manager"]
	if type(mgr) ~= "table" then
		return false
	end
	if type(mgr.handle_on_lines) == "function" then
		return false
	end
	return type(mgr.on_lines) == "function" or type(mgr.on_update) == "function"
end

---Reload gitsigns modules if a stale manager table is cached.
---@return boolean reloaded
function M.reload_gitsigns_if_stale()
	if not M.gitsigns_stale() then
		return false
	end
	M.clear_plugins("gitsigns.nvim")
	return true
end

---Verify gitsigns loaded with the current API.
---@return boolean
function M.gitsigns_healthy()
	local ok, mgr = pcall(require, "gitsigns.manager")
	return ok and type(mgr.handle_on_lines) == "function"
end

---Handle vim.pack update/install: clear module cache for the plugin.
---@param ev table
function M.on_pack_changed(ev)
	local data = ev.data or {}
	local kind = data.kind
	if kind ~= "install" and kind ~= "update" then
		return
	end

	local name = (data.spec or {}).name
	if not name or name == "" then
		return
	end

	M.clear_plugins(name)
end

---Return plugin names that need a full Neovim restart after update.
---@param updated_names string[]
---@return string[]
function M.restart_recommended(updated_names)
	local out = {}
	for _, name in ipairs(updated_names) do
		if M.RESTART_RECOMMENDED[name] then
			out[#out + 1] = name
		end
	end
	return out
end

---Notify when updated plugins need a restart for a clean load.
---@param updated_names string[]
function M.notify_restart_advice(updated_names)
	local restart = M.restart_recommended(updated_names)
	if #restart == 0 then
		return
	end

	local list = table.concat(restart, ", ")
	vim.notify(
		string.format(
			"Updated: %s. Quit and restart Neovim so Lua caches match the new plugin code.",
			list
		),
		vim.log.levels.WARN,
		{ title = "Plugin update", timeout = 12000 }
	)
end

return M
