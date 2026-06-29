-- =============================================================================
-- THEME MANAGER
-- PURPOSE: Centralised theme management with performance optimisations
-- =============================================================================

local ThemeManager = {}
local highlight_cache = {}
local formatting_cache = {}
---Last `Cursor`/`TermCursor` palette signature applied by `apply_flexoki_cursor_highlights` (avoids redundant `nvim_set_hl`).
local flexoki_cursor_hl_sig = nil
local ThemePicker = nil -- Lazy load to avoid circular dependencies
local ok_settings, ThemeSettings = pcall(require, "core.theme-settings")
if not ok_settings then
	vim.notify("core.theme-settings not found", vim.log.levels.WARN)
	return ThemeManager
end

---Strip GUI/cterm background from a highlight group while keeping other attrs (Vim merge rules).
---Using `:highlight` avoids `nvim_set_hl` clearing unspecified fields (e.g. PmenuSel fg).
---@param group string
local function merge_highlight_transparent_bg(group)
	pcall(vim.cmd, string.format("silent! highlight %s guibg=NONE ctermbg=NONE", group))
end

---Ensure floating highlight groups stay transparent after theme changes.
local function ensure_transparent_highlights()
	-- If the user has configured any non-opaque UI opacity, treat that as intent to
	-- keep the editor background transparent (bg=none) across themes and machines.
	-- Some colourschemes set `Normal`/`NormalNC` solid even when they support
	-- transparent floats, leading to device-specific differences.
	if ThemeSettings.get_opacity() < 1 then
		for _, group in ipairs({
			"Normal",
			"NormalNC",
			"SignColumn",
			"FoldColumn",
		}) do
			pcall(vim.api.nvim_set_hl, 0, group, { bg = "none" })
		end
	end

	for _, group in ipairs(ThemeSettings.get_float_highlight_groups()) do
		pcall(vim.api.nvim_set_hl, 0, group, { bg = "none" })
	end
	for _, group in ipairs(ThemeSettings.get_completion_menu_highlight_groups()) do
		merge_highlight_transparent_bg(group)
	end
	-- MsgArea covers the command-line / message row(s) below the status line; themes
	-- often keep a solid Normal-like bg there while the editor body is transparent.
	pcall(vim.api.nvim_set_hl, 0, "MsgArea", { bg = "none" })
end

-- Detect system appearance with caching
local system_theme_cache = nil
local cache_timeout = 5000 -- 5 seconds
local last_detection_time = 0

function ThemeManager.detect_system_theme()
	local current_time = vim.loop.hrtime() / 1000000 -- Convert to milliseconds

	-- Return cached result if still valid
	if system_theme_cache and (current_time - last_detection_time) < cache_timeout then
		return system_theme_cache
	end

	local ok, result = pcall(vim.fn.system, { "defaults", "read", "-g", "AppleInterfaceStyle" })
	if ok and type(result) == "string" then
		local trimmed = vim.trim(result)
		-- Light appearance: the global key is absent, so `defaults read` often yields empty stdout.
		-- Treating empty as light avoids wrongly forcing dark after a dark→light switch.
		if trimmed == "" or not trimmed:match("Dark") then
			system_theme_cache = "light"
		else
			system_theme_cache = "dark"
		end
		last_detection_time = current_time
		return system_theme_cache
	end

	system_theme_cache = "dark" -- fallback when `defaults` cannot run
	last_detection_time = current_time
	return system_theme_cache
end

-- Herdr PTY coloured-undercurl support: nil = unknown, boolean after XTGETTCAP probe.
local herdr_coloured_undercurl_support = nil
local herdr_coloured_undercurl_probe_started = false
local HERDR_UNDERCURL_CAPS = { "Smulx", "Setulc" }

---Convert a highlight colour id to a hex string.
---@param colour integer|string|nil
---@return string|nil
local function hl_colour_to_hex(colour)
	if type(colour) == "number" then
		return string.format("#%06x", colour)
	end
	if type(colour) == "string" and colour ~= "" then
		return colour
	end
	return nil
end

---Resolve a theme-appropriate red for spell-error underlines.
---@return string
local function get_spell_bad_colour()
	for _, group in ipairs({ "SpellBad", "DiagnosticError", "Error" }) do
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
		if ok and hl then
			local sp_hex = hl_colour_to_hex(hl.sp)
			if sp_hex then
				return sp_hex
			end
			local fg_hex = hl_colour_to_hex(hl.fg)
			if fg_hex then
				return fg_hex
			end
		end
	end

	if (vim.g.colors_name or "") == "flexoki" then
		local ok, flexoki_palette = pcall(require, "flexoki.palette")
		if ok and type(flexoki_palette.palette) == "function" then
			local ok_palette, c = pcall(flexoki_palette.palette)
			if ok_palette and type(c) == "table" then
				if c["re-2"] then
					return c["re-2"]
				end
				if c["re"] then
					return c["re"]
				end
			end
		end
	end

	return "#d14d41"
end

local function apply_spell_bad_highlight(use_plain_red_underline)
	local spell_red = get_spell_bad_colour()
	if use_plain_red_underline then
		pcall(vim.api.nvim_set_hl, 0, "SpellBad", { underline = true, undercurl = false, fg = spell_red })
	else
		pcall(vim.api.nvim_set_hl, 0, "SpellBad", { undercurl = true, sp = spell_red })
	end
end

local function probe_herdr_coloured_undercurl_support()
	if herdr_coloured_undercurl_probe_started or vim.env.HERDR_ENV ~= "1" then
		return
	end
	if not vim.tty or type(vim.tty.query) ~= "function" then
		herdr_coloured_undercurl_support = false
		return
	end

	herdr_coloured_undercurl_probe_started = true
	local remaining = #HERDR_UNDERCURL_CAPS
	local supported = { Smulx = false, Setulc = false }

	vim.tty.query(HERDR_UNDERCURL_CAPS, function(cap, found)
		if found then
			supported[cap] = true
		end
		remaining = remaining - 1
		if remaining > 0 then
			return
		end

		-- Both curly underline (Smulx) and coloured underline (Setulc) are required.
		herdr_coloured_undercurl_support = supported.Smulx and supported.Setulc
		vim.schedule(function()
			ThemeManager.apply_spell_undercurl()
		end)
	end)
end

-- Apply red underline for misspelled words (undercurl when the terminal supports it).
function ThemeManager.apply_spell_undercurl()
	local use_plain_red_underline = vim.env.TERM_PROGRAM == "WarpTerminal"

	if vim.env.HERDR_ENV == "1" then
		if herdr_coloured_undercurl_support == nil then
			probe_herdr_coloured_undercurl_support()
			-- Workaround until XTGETTCAP probe completes (or while caps are still missing).
			use_plain_red_underline = true
		else
			use_plain_red_underline = not herdr_coloured_undercurl_support
		end
	end

	apply_spell_bad_highlight(use_plain_red_underline)
end

-- Apply formatting parity with Gruvbox (italics/neutral choices)
function ThemeManager.apply_formatting_parity()
  local theme = vim.g.colors_name or "default"

  -- Only apply for GitHub light variants to match Gruvbox formatting
  if not theme:match("^github") then
    return
  end

  if formatting_cache[theme] then
    return
  end

  -- Match Gruvbox defaults:
  -- - Comments: italic
  -- - Strings: not italic
  -- - Operators: not italic
  -- - Folds: italic
  local groups_to_set = {
    { name = "Comment", opts = { italic = true } },
    { name = "@comment", opts = { italic = true } },

    { name = "String", opts = { italic = false } },
    { name = "@string", opts = { italic = false } },

    { name = "Operator", opts = { italic = false } },
    { name = "@operator", opts = { italic = false } },

    { name = "Folded", opts = { italic = true } },
  }

  for _, group in ipairs(groups_to_set) do
    pcall(vim.api.nvim_set_hl, 0, group.name, group.opts)
  end

  formatting_cache[theme] = true
end

--- Extract the link colour from the current colourscheme.
--- Checks treesitter link groups, the standard Underlined group, and common blue groups.
---@return number|string|nil colour The foreground colour for links
local function get_link_colour()
  -- Priority order for extracting link colour:
  -- 1. Treesitter link groups (most semantic)
  -- 2. Standard Underlined group (Vim convention for links)
  -- 3. Common "blue" groups as fallback
  local groups_to_check = {
    "@markup.link.url",      -- Treesitter: URL part of links
    "@markup.link",          -- Treesitter: general link
    "@string.special.url",   -- Treesitter: URLs as special strings
    "@text.uri",             -- Treesitter: older name for URLs
    "Underlined",            -- Standard Vim group for hyperlinks
    "Special",               -- Often blue in many themes
    "Function",              -- Commonly blue
  }

  for _, group_name in ipairs(groups_to_check) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group_name, link = false })
    if ok and hl and hl.fg then
      return hl.fg
    end
  end

  return nil
end

---Darken an RGB channel towards black.
---@param channel integer
---@param factor number
---@return integer
local function darken_channel(channel, factor)
	if factor <= 0 then
		return channel
	end
	if factor >= 1 then
		return 0
	end
	return math.floor(channel * (1 - factor) + 0.5)
end

---Darken a highlight group's foreground colour (if set).
---@param group string
---@param factor number
---@return boolean applied
local function darken_hl_fg(group, factor)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
	if not ok or not hl or not hl.fg then
		return false
	end

	local colour = hl.fg
	if type(colour) ~= "number" then
		return false
	end

	local r = bit.rshift(bit.band(colour, 0xFF0000), 16)
	local g = bit.rshift(bit.band(colour, 0x00FF00), 8)
	local b = bit.band(colour, 0x0000FF)

	r = darken_channel(r, factor)
	g = darken_channel(g, factor)
	b = darken_channel(b, factor)

	local hex = string.format("#%02x%02x%02x", r, g, b)
	pcall(vim.api.nvim_set_hl, 0, group, { fg = hex })
	return true
end

---Increase contrast for Flexoki in light mode.
---Flexoki's light palette can render some “secondary” text too lightly for a
---transparent terminal background; this nudges those groups darker.
---@return nil
function ThemeManager.apply_flexoki_light_contrast()
	if (vim.g.colors_name or "") ~= "flexoki" then
		return
	end
	if (vim.o.background or "dark") ~= "light" then
		return
	end

	-- Increase contrast for secondary UI text, but keep it clearly “secondary”.
	-- Tuned halfway between “subtle” and “too dark”.
	local base_factor = 0.34

	-- Dashboard section labels (mini.starter): "Shortcuts", "Forge", "Projects", etc.
	-- These tend to use MiniStarterSection.
	darken_hl_fg("MiniStarterSection", 0.28)

	-- General secondary UI text.
	for _, group in ipairs({
		"Comment",
		"@comment",
		"LineNr",
		"NonText",
		"Folded",
	}) do
		darken_hl_fg(group, base_factor)
	end
end

---Reapply Flexoki cursor highlights from the active palette variant.
---Ensures `Cursor`/`TermCursor` match ink and paper after colours load; some terminals
---leave the cell cursor black if highlights race transparency or deferred loads.
---@param opts { force?: boolean }|nil When `force` is true, clears the highlight signature
---	cache so the next apply always runs (e.g. after `FocusGained` when updates were skipped
---	while unfocused).
---@return nil
function ThemeManager.apply_flexoki_cursor_highlights(opts)
	opts = opts or {}
	if opts.force then
		flexoki_cursor_hl_sig = nil
	end
	if (vim.g.colors_name or "") ~= "flexoki" then
		flexoki_cursor_hl_sig = nil
		return
	end

	local ok, flexoki_palette = pcall(require, "flexoki.palette")
	if not ok or type(flexoki_palette) ~= "table" or type(flexoki_palette.palette) ~= "function" then
		return
	end

	local ok_palette, c = pcall(flexoki_palette.palette)
	if not ok_palette or type(c) ~= "table" or not c["bg"] or not c["tx"] then
		return
	end

	local sig = table.concat({
		tostring(c["bg"]),
		tostring(c["tx"]),
		tostring(c["tx-3"] or ""),
	}, "\1")
	if sig == flexoki_cursor_hl_sig then
		return
	end
	flexoki_cursor_hl_sig = sig

	local cursor = { fg = c["bg"], bg = c["tx"] }
	pcall(vim.api.nvim_set_hl, 0, "Cursor", cursor)
	pcall(vim.api.nvim_set_hl, 0, "lCursor", cursor)
	pcall(vim.api.nvim_set_hl, 0, "CursorIM", cursor)
	pcall(vim.api.nvim_set_hl, 0, "TermCursor", cursor)

	local term_nc = { fg = c["bg"], bg = c["tx-3"] }
	pcall(vim.api.nvim_set_hl, 0, "TermCursorNC", term_nc)
end

---Soften `CursorLine` after colourschemes that paint a solid row (e.g. Flexoki `c.ui`).
---`vim.o.cursorline` stays off, but plugins such as VimTeX TOC use `setlocal cursorline`,
---which would otherwise show a full-width stripe.
---@return nil
function ThemeManager.apply_cursorline_suppression()
	if vim.o.cursorline then
		return
	end
	pcall(vim.api.nvim_set_hl, 0, "CursorLine", { bg = "none", blend = 0 })
end

-- Apply link highlighting (blue and underlined) for markdown links, wiki links, and URLs
-- Note: No caching - this is fast and must re-apply reliably after theme changes
function ThemeManager.apply_link_highlights()
  local link_colour = get_link_colour()

  -- Build highlight options: always underline, use theme colour if found
  local hl_opts = { underline = true }
  if link_colour then
    hl_opts.fg = link_colour
    hl_opts.sp = link_colour -- Underline colour matches foreground
  end

  -- Markdown link highlights (traditional vim syntax)
  pcall(vim.api.nvim_set_hl, 0, "markdownLinkText", hl_opts)
  pcall(vim.api.nvim_set_hl, 0, "markdownUrl", hl_opts)
  pcall(vim.api.nvim_set_hl, 0, "markdownUrlTitle", hl_opts)

  -- Wiki link highlight (for Obsidian-style [[links]])
  pcall(vim.api.nvim_set_hl, 0, "markdownWikiLink", hl_opts)

  -- Treesitter link highlights (ensures consistency with modern syntax highlighting)
  pcall(vim.api.nvim_set_hl, 0, "@markup.link", hl_opts)
  pcall(vim.api.nvim_set_hl, 0, "@markup.link.url", hl_opts)
  pcall(vim.api.nvim_set_hl, 0, "@markup.link.label", hl_opts)
  pcall(vim.api.nvim_set_hl, 0, "@string.special.url", hl_opts)
  pcall(vim.api.nvim_set_hl, 0, "@text.uri", hl_opts) -- Older treesitter name
end

---Apply LaTeX lua-ul [soul] style highlights (\st, \hl) for OpenType-friendly display.
---Strikethrough uses gui=strikethrough; highlight uses underline + optional bg (like link styling).
function ThemeManager.apply_tex_style_highlights()
  -- Strikethrough: \st{}, \sout{} — visible in all fonts
  pcall(vim.api.nvim_set_hl, 0, "texStyleStrike", {
    strikethrough = true,
  })

  -- Highlight: \hl{} — underline for OpenType visibility; bg from Search if available
  local hl_opts = { underline = true }
  local ok, search_hl = pcall(vim.api.nvim_get_hl, 0, { name = "Search", link = false })
  if ok and search_hl and search_hl.bg then
    hl_opts.bg = search_hl.bg
  end
  pcall(vim.api.nvim_set_hl, 0, "texStyleHl", hl_opts)
end

---Apply the configured UI opacity across Neovim.
---Note: Blur effects are handled by the terminal emulator/window manager when transparency is enabled.
---On macOS, the window manager automatically applies blur to transparent windows.
---@param opts { apply_window_blends?: boolean }|nil If `apply_window_blends` is false, skip iterating every window (still sets global winblend/pumblend and transparent highlight groups).
function ThemeManager.apply_global_opacity(opts)
	opts = opts or {}
	local blend = ThemeSettings.get_winblend()
	vim.o.winblend = blend -- Transparency for floating windows (enables blur if terminal supports it)
	vim.o.pumblend = blend -- Transparency for popup menus/completion (enables blur if terminal supports it)
	ensure_transparent_highlights()
	-- Per-window `winblend` touches every split; skip while the OS window is unfocused so
	-- transparent hosts (e.g. Ghostty) do not keep recompositing the buffer cursor cell.
	if opts.apply_window_blends ~= false and vim.g._nvim_os_window_focused ~= 0 then
		ThemeSettings.apply_all_window_blends()
	end
end

---Resolve the default colourscheme for the active appearance and sync `vim.o.background`.
---@param opts { appearance?: "dark"|"light" }|nil When `appearance` is set (e.g. from auto-dark-mode),
---	it is trusted over `detect_system_theme()` so we avoid stale cache / empty `defaults read` races.
---@return string theme_name
function ThemeManager.get_active_theme(opts)
	opts = opts or {}
	local appearance = opts.appearance
	if appearance ~= "light" and appearance ~= "dark" then
		appearance = ThemeManager.detect_system_theme()
	else
		-- Align cache with OS-driven callbacks so the next unprompted detection stays consistent.
		system_theme_cache = appearance
		last_detection_time = vim.loop.hrtime() / 1000000
	end
	vim.o.background = appearance
	return ThemeSettings.get_default_theme(appearance)
end

---Load and apply the default colourscheme for the current (or given) appearance.
---@param opts { appearance?: "dark"|"light" }|nil
---@return string theme_name
function ThemeManager.load_immediate(opts)
	opts = opts or {}
	local theme = ThemeManager.get_active_theme({ appearance = opts.appearance })
	local ok = pcall(vim.cmd.colorscheme, theme)
	if not ok then
		vim.notify("Failed to load theme: " .. theme, vim.log.levels.WARN)
	end
	return theme
end

-- Setup lazy theme loading for non-active themes
function ThemeManager.setup_lazy_loading()
	vim.api.nvim_create_autocmd("ColorSchemePre", {
		pattern = { "tokyonight", "nord", "github_*" },
		callback = function(ev)
			-- GitHub theme exposes many `github_*` colourschemes but shares one setup module.
			if ev.match:match("^github_") then
				pcall(require, "plugins.github-nvim-theme")
				return
			end

			local theme_name = ev.match:gsub("-", "_")
			pcall(require, "plugins." .. theme_name)
		end,
	})
end

-- Optimized highlight management with caching
function ThemeManager.update_which_key_highlights()
	local theme = vim.g.colors_name or "default"
	local background = vim.o.background or "dark"
	local cache_key = theme .. "|" .. background

	-- Return early if already cached
	if highlight_cache[cache_key] then
		return
	end

	local highlights = {}

	---Convert an integer highlight colour to hex (e.g. 0xff00ff -> "#ff00ff").
	---@param colour integer|string|nil
	---@return string|nil
	local function colour_to_hex(colour)
		if type(colour) ~= "number" then
			return nil
		end
		return string.format("#%06x", colour)
	end

	---Return a single "surface" palette for floating UIs, derived from the active theme.
	---This keeps which-key's float, border, and title visually consistent without hard-coding theme names.
	---@return { surface_bg: string, border_fg: string, title_fg: string, title_bold: boolean }
	local function get_float_surface_palette()
		local surface_bg = nil
		for _, group in ipairs({ "NormalFloat", "Pmenu", "Normal" }) do
			local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
			if ok and hl and hl.bg then
				surface_bg = colour_to_hex(hl.bg)
				break
			end
		end

		-- Sensible fallbacks when a colourscheme leaves float backgrounds unset.
		if not surface_bg then
			surface_bg = (background == "light") and "#f0f0f0" or "#2b2f3a"
		end

		local border_fg = nil
		local ok_border, float_border_hl = pcall(vim.api.nvim_get_hl, 0, { name = "FloatBorder", link = false })
		if ok_border and float_border_hl and float_border_hl.fg then
			border_fg = colour_to_hex(float_border_hl.fg)
		end
		if not border_fg then
			border_fg = (background == "light") and "#c0c0c0" or "#4b5263"
		end

		local title_fg = nil
		local title_bold = true
		local ok_title, float_title_hl = pcall(vim.api.nvim_get_hl, 0, { name = "FloatTitle", link = false })
		if ok_title and float_title_hl then
			if float_title_hl.fg then
				title_fg = colour_to_hex(float_title_hl.fg)
			end
			if float_title_hl.bold ~= nil then
				title_bold = float_title_hl.bold
			end
		end
		if not title_fg then
			title_fg = border_fg
		end

		return {
			surface_bg = surface_bg,
			border_fg = border_fg,
			title_fg = title_fg,
			title_bold = title_bold,
		}
	end

	local surface = get_float_surface_palette()

	-- Keep the title text unboxed: do not paint a background.
	vim.api.nvim_set_hl(0, "WhichKeyTitle", {
		fg = surface.title_fg,
		bg = "none",
		bold = surface.title_bold,
	})

	-- Theme-specific highlight configurations
	if theme:match("catppuccin") then
		highlights = {
			WhichKey = { link = "Function" },
			WhichKeyGroup = { link = "Keyword" },
			WhichKeyDesc = { link = "Comment" },
			WhichKeySeparator = { link = "String" },
			WhichKeyFloat = { bg = "none" },
			WhichKeyBorder = { fg = surface.border_fg, bg = "none" },
		}
	elseif theme:match("onedark") then
		highlights = {
			WhichKey = { fg = "#61AFEF" },
			WhichKeyGroup = { fg = "#C678DD" },
			WhichKeyDesc = { fg = "#5C6370" },
			WhichKeySeparator = { fg = "#98C379" },
			WhichKeyFloat = { bg = "none" },
			WhichKeyBorder = { fg = surface.border_fg, bg = "none" },
		}
	elseif theme:match("tokyonight") then
		highlights = {
			WhichKey = { link = "Function" },
			WhichKeyGroup = { link = "Keyword" },
			WhichKeyDesc = { link = "Comment" },
			WhichKeySeparator = { link = "String" },
			WhichKeyFloat = { bg = "none" },
			WhichKeyBorder = { fg = surface.border_fg, bg = "none" },
		}
	else
		-- Default fallback
		highlights = {
			WhichKey = { link = "Function" },
			WhichKeyGroup = { link = "Keyword" },
			WhichKeyDesc = { link = "Comment" },
			WhichKeySeparator = { link = "Delimiter" },
			WhichKeyFloat = { bg = "none" },
			WhichKeyBorder = { fg = surface.border_fg, bg = "none" },
		}
	end

	-- Batch apply all highlights
	for group, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, opts)
	end

	-- Footer parity: footer window uses `Normal:WhichKeyNormal`.
	vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = "none" })

	-- Cache the result
	highlight_cache[cache_key] = true
end

-- Clear highlight cache (useful when reloading config)
function ThemeManager.clear_highlight_cache()
	highlight_cache = {}
	formatting_cache = {}
	flexoki_cursor_hl_sig = nil
end

-- Theme picker integration
function ThemeManager.show_theme_picker()
	if not ThemePicker then
		local ok, picker = pcall(require, "core.theme-picker")
		if not ok then
			vim.notify("Theme Picker not available", vim.log.levels.ERROR)
			return
		end
		ThemePicker = picker
	end

	if ThemePicker.show_picker then
		ThemePicker.show_picker()
	else
		vim.notify("Theme picker show function not available", vim.log.levels.ERROR)
	end
end

-- Cycle through themes (legacy support)
function ThemeManager.cycle_theme()
	if not ThemePicker then
		local ok, picker = pcall(require, "core.theme-picker")
		if ok then
			ThemePicker = picker
		end
	end

	if ThemePicker and ThemePicker.cycle_theme then
		ThemePicker.cycle_theme()
	else
		-- Fallback to original cycling logic
		local themes = { "catppuccin", "onedark", "tokyonight", "nord", "github_dark", "github_light_high_contrast" }
		local current = vim.g.colors_name or "default"
		local current_index = 1

		for i, theme in ipairs(themes) do
			if theme == current then
				current_index = i
				break
			end
		end

		local next_index = current_index % #themes + 1
		local next_theme = themes[next_index]

		local success = pcall(vim.cmd.colorscheme, next_theme)
		if success then
			vim.notify("Switched to " .. next_theme .. " theme", vim.log.levels.INFO)
		else
			vim.notify("Failed to switch to " .. next_theme .. " theme", vim.log.levels.WARN)
		end
	end
end

-- Get current theme
function ThemeManager.get_current_theme()
	if ThemePicker and ThemePicker.get_current_theme then
		return ThemePicker.get_current_theme()
	end
	return vim.g.colors_name or "default"
end

-- Setup auto-updating highlights when theme changes
function ThemeManager.setup_highlight_autocmd()
	local group = vim.api.nvim_create_augroup("ThemeManagerHighlights", { clear = true })

	---Apply theme-manager highlight tweaks after `ColorScheme` (and similar).
	---@param opts { apply_cursor?: boolean, apply_window_blends?: boolean }|nil When both false, skip Flexoki cursor overrides and per-window `winblend` sync (still runs global opacity + transparent groups).
	local function apply_all_highlights(opts)
		opts = opts or {}
		local apply_cursor = opts.apply_cursor ~= false
		local apply_window_blends = opts.apply_window_blends ~= false
		-- OS-unfocused: avoid repeated `Cursor`/`TermCursor` overrides (see `apply_global_opacity`
		-- for winblend); together these aggravate buffer cursor flicker in transparent terminals.
		if vim.g._nvim_os_window_focused == 0 then
			apply_cursor = false
			apply_window_blends = false
		end
		ThemeManager.update_which_key_highlights()
		ThemeManager.apply_formatting_parity()
		ThemeManager.apply_spell_undercurl()
		ThemeManager.apply_flexoki_light_contrast()
		if apply_cursor then
			ThemeManager.apply_flexoki_cursor_highlights()
		end
		ThemeManager.apply_link_highlights()
		ThemeManager.apply_tex_style_highlights()
		ThemeManager.apply_global_opacity({ apply_window_blends = apply_window_blends })
		ThemeManager.apply_cursorline_suppression()
	end

	-- Primary trigger: ColorScheme change
	-- Use multiple deferred calls to ensure we run after treesitter and other plugins
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			ThemeManager.clear_highlight_cache()
			-- Stagger full cursor + per-window winblend work so early passes skip heavy hl churn.
			vim.defer_fn(function()
				apply_all_highlights({ apply_cursor = false, apply_window_blends = false })
			end, 10)
			vim.defer_fn(function()
				apply_all_highlights({ apply_cursor = false, apply_window_blends = false })
			end, 100)
			vim.defer_fn(function()
				apply_all_highlights()
			end, 300)
		end,
	})

	-- Secondary trigger: when background option changes (auto-dark-mode sets this first)
	vim.api.nvim_create_autocmd("OptionSet", {
		group = group,
		pattern = "background",
		callback = function()
			ThemeManager.clear_highlight_cache()
			vim.defer_fn(apply_all_highlights, 150)
		end,
	})

	-- Tertiary trigger: re-apply when entering markdown buffers
	-- This catches cases where treesitter re-highlights the buffer
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = { "markdown", "quarto", "pandoc" },
		callback = function()
			vim.defer_fn(ThemeManager.apply_link_highlights, 50)
		end,
	})
end

---Keep opacity synced when new windows appear.
function ThemeManager.setup_opacity_autocmds()
	local group = vim.api.nvim_create_augroup("ThemeManagerOpacity", { clear = true })
	vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter", "TermOpen" }, {
		group = group,
		callback = function(event)
			-- Skip while the OS window is unfocused: repeated blends + redraws aggravate cursor
			-- flicker in transparent terminals (e.g. Ghostty) without improving the UI.
			if vim.g._nvim_os_window_focused == 0 then
				return
			end
			if event and event.win and vim.api.nvim_win_is_valid(event.win) then
				ThemeSettings.apply_window_blend(event.win)
			else
				ThemeSettings.apply_all_window_blends()
			end
		end,
	})
end

-- Main initialization function
function ThemeManager.init()
	-- Load active theme immediately
	local active_theme = ThemeManager.load_immediate()

	-- Setup lazy loading for other themes
	ThemeManager.setup_lazy_loading()

	-- Setup highlight management
	ThemeManager.setup_highlight_autocmd()
	ThemeManager.setup_opacity_autocmds()
	ThemeManager.update_which_key_highlights()
	ThemeManager.apply_formatting_parity()
	ThemeManager.apply_spell_undercurl()
	if vim.g._nvim_os_window_focused ~= 0 then
		ThemeManager.apply_flexoki_cursor_highlights()
	end
	ThemeManager.apply_link_highlights()
	ThemeManager.apply_tex_style_highlights()
	ThemeManager.apply_global_opacity()
	ThemeManager.apply_cursorline_suppression()

	vim.notify("Theme system initialized: " .. active_theme, vim.log.levels.INFO)
end

return ThemeManager
