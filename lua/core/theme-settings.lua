-- ============================================================================
-- THEME SETTINGS
-- PURPOSE: Shared helpers for opacity and floating highlight preferences
-- ============================================================================

local ok_config, ConfigManager = pcall(require, "core.config-manager")
if not ok_config then
	vim.notify("core.config-manager not found", vim.log.levels.WARN)
	return {}
end

---Buffer-local flag used so opacity autocmds keep plugin-update / progress floats opaque.
local PROGRESS_POPUP_BUF_VAR = "_nvim_progress_popup"

local ThemeSettings = {
	float_highlights = {
		"NormalFloat",
		"FloatBorder",
		"FloatTitle",

		-- Shared float chrome targets (used via winhl mappings).
		"WhichKeyFloat",
		"WhichKeyBorder",
		"WhichKeyTitle",

		-- Common plugin float groups (defensive; some themes set backgrounds here).
		"MasonNormal",
		"MasonBorder",
		"LazyNormal",
		"LazyBorder",

		-- Telescope float groups.
		"TelescopeNormal",
		"TelescopeBorder",
		"TelescopePromptNormal",
		"TelescopePromptBorder",
		"TelescopeResultsNormal",
		"TelescopeResultsBorder",
		"TelescopePreviewNormal",
		"TelescopePreviewBorder",
	},
	---Cmdline / wildmenu popup (`wildoptions` pum) and legacy wildmenu row highlights.
	---Backgrounds cleared in the theme manager while preserving fg and selection attrs.
	completion_menu_highlights = {
		"WildMenu",
		"Pmenu",
		"PmenuSel",
		"PmenuSbar",
		"PmenuThumb",
		"PmenuKind",
		"PmenuKindSel",
		"PmenuExtra",
		"PmenuExtraSel",
	},
	---Window-local highlight map shared with which-key, Mason, and other float UIs.
	which_key_float_winhl = "Normal:WhichKeyFloat,FloatBorder:WhichKeyBorder,FloatTitle:WhichKeyTitle",
}

---Return the shared which-key float `winhl` mapping.
---@return string
function ThemeSettings.get_which_key_float_winhl()
	return ThemeSettings.which_key_float_winhl
end

---Return the active theme configuration block.
---@return table
function ThemeSettings.get_active_config()
	return ConfigManager.themes.active or {}
end

---Return the configured opacity value for UI elements.
---@return number opacity
function ThemeSettings.get_opacity()
	local config = ThemeSettings.get_active_config()
	return config.opacity or 1
end

---Convert the configured opacity into a Vim winblend value.
---@return integer winblend
function ThemeSettings.get_winblend()
	local opacity = ThemeSettings.get_opacity()
	local blend = math.floor((1 - opacity) * 100 + 0.5)
	return math.max(0, math.min(100, blend))
end

---Return the list of highlight groups that should stay transparent.
---@return string[]
function ThemeSettings.get_float_highlight_groups()
	return vim.deepcopy(ThemeSettings.float_highlights)
end

---Return completion menu / wildmenu groups that should use a transparent background.
---@return string[]
function ThemeSettings.get_completion_menu_highlight_groups()
	return vim.deepcopy(ThemeSettings.completion_menu_highlights)
end

---Mark a buffer as the core progress popup (`core.progress-popup`) so window-blend logic
---matches Mason / which-key / floating terminal instead of editor transparency.
---@param bufnr integer
function ThemeSettings.mark_progress_popup_buffer(bufnr)
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.api.nvim_buf_set_var, bufnr, PROGRESS_POPUP_BUF_VAR, true)
	end
end

---@param bufnr integer
---@return boolean
local function buffer_is_progress_popup(bufnr)
	local ok, value = pcall(vim.api.nvim_buf_get_var, bufnr, PROGRESS_POPUP_BUF_VAR)
	return ok and value == true
end

---Opaque float window + which-key float chrome (border/title/body link targets).
---@param winid integer
---@return boolean applied
function ThemeSettings.style_float_like_which_key(winid)
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		return false
	end
	pcall(vim.api.nvim_set_option_value, "winblend", 0, { win = winid })
	pcall(
		vim.api.nvim_set_option_value,
		"winhl",
		ThemeSettings.which_key_float_winhl,
		{ win = winid }
	)
	return true
end

---Apply winblend to a specific window, safeguarding against invalid IDs.
---@param winid integer|nil
---@return boolean applied
function ThemeSettings.apply_window_blend(winid)
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		return false
	end
	local bufnr = vim.api.nvim_win_get_buf(winid)
	if vim.api.nvim_buf_is_valid(bufnr) then
		-- Treat any popup/floating window as intentional UI chrome and keep it aligned with which-key.
		-- This prevents `WinEnter` opacity sync from re-blending Telescope/FZF and similar float UIs.
		if vim.fn.win_gettype(winid) == "popup" then
			return ThemeSettings.style_float_like_which_key(winid)
		end

		if buffer_is_progress_popup(bufnr) then
			return ThemeSettings.style_float_like_which_key(winid)
		end

		local ft = vim.bo[bufnr].filetype
		-- which-key.nvim uses filetype = "wk" for both its popup and footer helper windows.
		-- Keep these fully opaque to prevent any buffer glyph bleed-through in terminals.
		--
		-- Mason's UI is also best kept opaque so it visually matches which-key and avoids
		-- terminal blur/backdrop artefacts.
		if ft == "wk" or ft == "mason" then
			return pcall(vim.api.nvim_set_option_value, "winblend", 0, { win = winid })
		end
		-- Floating ToggleTerm windows: same opaque + winhl parity as Mason/which-key.
		if vim.bo[bufnr].buftype == "terminal" and vim.fn.win_gettype(winid) == "popup" then
			return ThemeSettings.style_float_like_which_key(winid)
		end
	end

	local ok = pcall(vim.api.nvim_set_option_value, "winblend", ThemeSettings.get_winblend(), { win = winid })
	return ok
end

---Apply window blend to every currently listed window.
function ThemeSettings.apply_all_window_blends()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		ThemeSettings.apply_window_blend(win)
	end
end

---Return the colourscheme name for a given appearance.
---@param appearance "dark"|"light"
---@return string
function ThemeSettings.get_default_theme(appearance)
	if appearance ~= "light" and appearance ~= "dark" then
		appearance = "dark"
	end
	local ok_shared, shared = pcall(require, "core.shared-theme")
	local selection = ok_shared and shared.read() or nil
	local config = ThemeSettings.get_active_config()
	local defaults = selection and selection.nvim or config.defaults or {}
	if appearance == "light" then
		return defaults.light or "catppuccin"
	end
	return defaults.dark or "catppuccin"
end

return ThemeSettings
