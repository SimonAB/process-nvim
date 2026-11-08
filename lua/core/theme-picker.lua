-- =============================================================================
-- THEME PICKER
-- PURPOSE: Enhanced theme selection with floating window interface
-- =============================================================================

local ThemePicker = {}
local ThemeSettings = require("core.theme-settings")

-- Filter modes for the picker
local FilterMode = { ALL = "all", DARK = "dark", LIGHT = "light" }
local current_filter_mode = FilterMode.ALL

-- Notification helper
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Theme Picker", timeout = 2000 })
end

-- Get available colorschemes from runtime
local function get_themes()
	local themes = {
		"default", "blue", "darkblue", "delek", "desert", "elflord", "evening",
		"habamax", "industry", "koehler", "lunaperche", "morning", "murphy",
		"pablo", "peachpuff", "quiet", "ron", "shine", "slate", "torte", "zellner"
	}

	-- Get colorschemes from runtime paths
	for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
		local colors_dir = path .. "/colors"
		if vim.fn.isdirectory(colors_dir) == 1 then
			for _, pattern in ipairs({"*.vim", "*.lua"}) do
				for _, file in ipairs(vim.fn.glob(colors_dir .. "/" .. pattern, true, true)) do
					local name = vim.fn.fnamemodify(file, ":t:r")
					if not vim.tbl_contains(themes, name) then
						table.insert(themes, name)
					end
				end
			end
		end
	end

	table.sort(themes)
	return themes
end

-- Classify a theme name as "dark", "light" or "special" (fallback)
local function classify_theme(name)
	local n = (name or ""):lower()
	-- Generated Rex schemes record their appearance in the palette file.
	if n:find("^rex%-") then
		local file = vim.api.nvim_get_runtime_file("colors/" .. n .. ".lua", false)[1]
		local lines = file and vim.fn.readfile(file, "", 6) or {}
		local appearance = table.concat(lines, "\n"):match('appearance = "(%a+)"')
		if appearance == "dark" or appearance == "light" then
			return appearance
		end
	end
	if n:find("dark") or n:find("night") or n:find("midnight") or n:find("onedark") or n:find("nord") or n:find("twilight256") then

		return "dark"
	end
	if n:find("light") or n:find("day") or n:find("morning") then
		return "light"
	end
	if n:find("github_") then
		if n:find("light") then return "light" end
		return "dark"
	end
    if n:find("tokyonight") then return "dark" end
    if n:find("gruvbox") then return "dark" end
	if n == "catppuccin" then return "dark" end
	return "special"
end

-- Create theme entry
local function create_entry(theme)
	local is_current = theme == (vim.g.colors_name or "default")
	local category = classify_theme(theme)
	local icon = is_current and "●" or "○"
	local category_icon = category == "dark" and "🌙" or category == "light" and "☀️" or "🎨"

	return {
		value = theme,
		display = string.format("%s %s %s", icon, category_icon, theme:gsub("_", " "):gsub("-", " ")),
		ordinal = theme,
	}
end

-- Load Telescope modules safely
local function load_telescope_modules()
	-- Proactively load user Telescope configuration (respects vim.pack lazy load)
	pcall(require, "plugins.telescope")

	-- Helper to retry require with small waits
	local function try_require(module_name, retries, delay_ms)
		local attempts = retries or 8
		local delay = delay_ms or 25
		for _ = 1, attempts do
			local ok, mod = pcall(require, module_name)
			if ok and mod then
				return mod
			end
			vim.wait(delay)
		end
		return nil
	end

	-- Ensure core telescope is present
	local telescope_core = try_require("telescope", 10, 30)
	if not telescope_core then
		return nil
	end

	local module_names = {
		pickers = "telescope.pickers",
		finders = "telescope.finders",
		actions = "telescope.actions",
		action_state = "telescope.action_state",
		entry_display = "telescope.pickers.entry_display",
		previewers = "telescope.previewers",
	}

	local loaded = {}
	for key, module_name in pairs(module_names) do
		local mod = try_require(module_name, 10, 30)
		if not mod then
			return nil
		end
		loaded[key] = mod
	end

	local config_mod = try_require("telescope.config", 10, 30)
	if not config_mod or not config_mod.values then
		return nil
	end
	loaded.config = config_mod.values

	return loaded
end

-- Create floating window picker
function ThemePicker.show_picker(filter_mode)
	if filter_mode and (filter_mode == FilterMode.ALL or filter_mode == FilterMode.DARK or filter_mode == FilterMode.LIGHT) then
		current_filter_mode = filter_mode
	end
	local themes = get_themes()

	if #themes == 0 then
		notify("No themes found!", vim.log.levels.ERROR)
		return
	end

	-- Always use the fallback picker
	ThemePicker.show_fallback_picker(themes)
end

-- Fallback theme picker with scrolling and live preview
function ThemePicker.show_fallback_picker(themes)
	local current_index = 1
	local current_preview_theme = nil
	local top_padding = 1
	local bottom_padding = 1
	local left_padding = "  "

	-- Create theme display entries with filtering
	local theme_entries = {}
	local filtered_entries = {}

	local function build_entries()
		filtered_entries = {}
		for i, theme in ipairs(themes) do
			local is_current = theme == (vim.g.colors_name or "default")
			local category = classify_theme(theme)
			if current_filter_mode == FilterMode.ALL or current_filter_mode == category then
				local category_icon = category == "dark" and "🌙" or category == "light" and "☀️" or "🎨"
				local entry = {
					index = i,
					theme = theme,
					display = string.format("%s %s %s",
						is_current and "●" or "○",
						category_icon,
						theme:gsub("_", " "):gsub("-", " ")
					)
				}
				table.insert(filtered_entries, entry)
				if is_current then
					current_index = #filtered_entries
				end
			end
		end
		if #filtered_entries == 0 then
			filtered_entries = { { index = 1, theme = nil, display = "(No themes for current filter)" } }
		end
		theme_entries = filtered_entries
	end

	build_entries()

	-- Create floating window
	local width = 50
	local height = math.min(#theme_entries + top_padding + bottom_padding, 15 + top_padding + bottom_padding)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	local function title_for_filter()
		local label = (current_filter_mode == FilterMode.DARK and "Dark")
			or (current_filter_mode == FilterMode.LIGHT and "Light") or "All"
		return string.format("🎨 Select Theme (Live Preview) — [%s]", label)
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = title_for_filter(),
		title_pos = "center",
	})

	-- Match which-key float styling (opaque + shared float highlight mapping).
	if ThemeSettings and ThemeSettings.style_float_like_which_key then
		ThemeSettings.style_float_like_which_key(win)
	end

	-- Set buffer content helpers
	local function update_buffer_lines()
		local lines = {}
		for _ = 1, top_padding do
			table.insert(lines, "")
		end
		for _, entry in ipairs(theme_entries) do
			table.insert(lines, left_padding .. entry.display)
		end
		for _ = 1, bottom_padding do
			table.insert(lines, "")
		end
		local was_modifiable = vim.bo[buf].modifiable
		if not was_modifiable then
			vim.bo[buf].modifiable = true
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		if not was_modifiable then
			vim.bo[buf].modifiable = false
		end
	end
	update_buffer_lines()

	-- Highlight current selection
	local function update_highlight()
		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
		local line = (math.max(1, math.min(current_index, #theme_entries)) - 1) + top_padding
		vim.api.nvim_buf_add_highlight(buf, -1, "CursorLine", line, 0, -1)

		-- Live preview
		local current_entry = theme_entries[current_index]
		if current_entry and current_entry.theme and current_entry.theme ~= current_preview_theme then
			current_preview_theme = current_entry.theme
			ThemePicker.preview_theme(current_entry.theme)
		end
	end

	-- Set initial highlight
	update_highlight()

	-- Key mappings
	local function close_window()
		pcall(vim.api.nvim_win_close, win, true)
		local buf_exists = pcall(vim.api.nvim_buf_is_valid, buf)
		if buf_exists then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end

	local function select_current()
		local current_entry = theme_entries[current_index]
		if current_entry and current_entry.theme then
			ThemePicker.select_theme(current_entry.theme)
		end
		close_window()
	end

	local function move_selection(direction)
		current_index = current_index + direction
		if current_index < 1 then
			current_index = #theme_entries
		elseif current_index > #theme_entries then
			current_index = 1
		end
		update_highlight()
		local first_visible = vim.fn.line('w0', win)
		local last_visible = vim.fn.line('w$', win)
		if current_index < first_visible then
			vim.api.nvim_win_set_cursor(win, {current_index, 0})
		elseif current_index > last_visible then
			local new_top = current_index - (last_visible - first_visible)
			vim.api.nvim_win_set_cursor(win, {new_top, 0})
		end
		vim.api.nvim_win_set_cursor(win, {current_index, 0})
	end

	-- Filter helpers
	local function set_filter(mode)
		if mode ~= FilterMode.ALL and mode ~= FilterMode.DARK and mode ~= FilterMode.LIGHT then return end
		current_filter_mode = mode
		build_entries()
		vim.api.nvim_win_set_config(win, { title = title_for_filter() })
		update_buffer_lines()
		current_preview_theme = nil
		update_highlight()
	end

	local function cycle_filter()
		if current_filter_mode == FilterMode.ALL then
			set_filter(FilterMode.DARK)
		elseif current_filter_mode == FilterMode.DARK then
			set_filter(FilterMode.LIGHT)
		else
			set_filter(FilterMode.ALL)
		end
	end

	-- Buffer-local keymaps
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', { callback = close_window, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', { callback = select_current, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', { callback = close_window, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'j', '', { callback = function() move_selection(1) end, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'k', '', { callback = function() move_selection(-1) end, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Down>', '', { callback = function() move_selection(1) end, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', '<Up>', '', { callback = function() move_selection(-1) end, noremap = true, silent = true })

	-- Filter controls in-window
	vim.api.nvim_buf_set_keymap(buf, 'n', 'f', '', { callback = cycle_filter, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'd', '', { callback = function() set_filter(FilterMode.DARK) end, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'l', '', { callback = function() set_filter(FilterMode.LIGHT) end, noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, 'n', 'a', '', { callback = function() set_filter(FilterMode.ALL) end, noremap = true, silent = true })

	-- Numeric prefix navigation
	for i = 1, 9 do
		vim.api.nvim_buf_set_keymap(buf, 'n', tostring(i) .. 'j', '', {
			callback = function()
				for _ = 1, i do move_selection(1) end
			end,
			noremap = true,
			silent = true
		})
		vim.api.nvim_buf_set_keymap(buf, 'n', tostring(i) .. 'k', '', {
			callback = function()
				for _ = 1, i do move_selection(-1) end
			end,
			noremap = true,
			silent = true
		})
	end

	-- Set cursor to current selection
	vim.api.nvim_win_set_cursor(win, {current_index, 0})

	-- Set buffer options
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].bufhidden = 'wipe'
end

-- Preview theme (temporary application) with debouncing
local preview_timer = nil
local last_preview_theme = nil

function ThemePicker.preview_theme(theme_name)
	-- Avoid redundant previews
	if theme_name == last_preview_theme then
		return
	end

	-- Clear any pending preview
	if preview_timer then
		vim.loop.timer_stop(preview_timer)
	end

	-- Debounce theme preview to avoid flickering
	preview_timer = vim.defer_fn(function()
		local ok, err = pcall(vim.cmd.colorscheme, theme_name)
		if ok then
			last_preview_theme = theme_name
			-- Only show notification for manual previews, not auto-previews
			vim.notify("Previewing: " .. theme_name:gsub("_", " "):gsub("-", " "), vim.log.levels.INFO, { timeout = 500 })
		else
			notify("Failed to preview theme: " .. theme_name, vim.log.levels.WARN)
		end
		preview_timer = nil
	end, 50) -- 50ms debounce for smooth experience
end

-- Select and apply theme permanently
function ThemePicker.select_theme(theme_name)
	-- Clear any pending preview
	if preview_timer then
		vim.loop.timer_stop(preview_timer)
		preview_timer = nil
	end

	local ok, err = pcall(vim.cmd.colorscheme, theme_name)
	if ok then
		current_theme = theme_name
		last_preview_theme = theme_name -- Update preview state
		notify("Theme changed to: " .. theme_name:gsub("_", " "):gsub("-", " "), vim.log.levels.INFO)

		-- Update theme manager cache
		local ThemeManager = require("core.theme-manager")
		ThemeManager.clear_highlight_cache()
		ThemeManager.update_which_key_highlights()
		ThemeManager.apply_global_opacity()
	else
		notify("Failed to apply theme: " .. theme_name, vim.log.levels.ERROR)
	end
end

-- Get current theme
function ThemePicker.get_current_theme()
	return vim.g.colors_name or "default"
end

-- Cycle through themes (legacy support)
function ThemePicker.cycle_theme()
	local available_themes = get_themes()
	if #available_themes == 0 then return end

	local current = ThemePicker.get_current_theme()
	local current_index = 1

	-- Find current theme index
	for i, theme in ipairs(available_themes) do
		if theme == current then
			current_index = i
			break
		end
	end

	-- Move to next theme
	local next_index = current_index % #available_themes + 1
	local next_theme = available_themes[next_index]

	ThemePicker.select_theme(next_theme)
end

-- Initialize theme picker
function ThemePicker.init()
	current_theme = ThemePicker.get_current_theme()
	notify("Theme Picker initialized", vim.log.levels.INFO)
end

-- Public filter API
function ThemePicker.get_filter()
	return current_filter_mode
end

function ThemePicker.set_filter(mode)
	if mode == FilterMode.ALL or mode == FilterMode.DARK or mode == FilterMode.LIGHT then
		current_filter_mode = mode
	else
		vim.notify("Invalid filter mode: " .. tostring(mode), vim.log.levels.WARN)
	end
end

function ThemePicker.cycle_filter()
	if current_filter_mode == FilterMode.ALL then
		current_filter_mode = FilterMode.DARK
	elseif current_filter_mode == FilterMode.DARK then
		current_filter_mode = FilterMode.LIGHT
	else
		current_filter_mode = FilterMode.ALL
	end
end

return ThemePicker
