-- Configuration for lualine.nvim
-- Status line with comprehensive information display

local ok, lualine = pcall(require, "lualine")
if ok then
	local lualine_utils = require("lualine.utils.utils")

	---Escape `%` so custom statusline text is not parsed as format items.
	---@param text string
	---@return string
	local function stl_escape(text)
		return lualine_utils.stl_escape(text)
	end

	---Wrap a statusline component so its output is safe for `%{}` parsing.
	---@param fn fun(): string
	---@return fun(): string
	local function stl_component(fn)
		return function()
			return stl_escape(fn())
		end
	end

	-- Lualine refresh-queue poll (default 16 ms). Higher = fewer wakeups next to the cursor.
	local refresh_check_ms = 200
	-- Flexoki: only remap V-BLOCK to the replace strip (purple). V-LINE and char-wise VISUAL keep
	-- lualine’s default `_visual` row — distinct from INSERT (cyan) and COMMAND (blue). Mapping
	-- V-LINE to `_command` made it identical to COMMAND mode.
	do
		local hl_mod = require("lualine.highlight")
		if not vim.g._lualine_flexoki_visual_mode_suffix then
			vim.g._lualine_flexoki_visual_mode_suffix = true
			local orig_get_mode_suffix = hl_mod.get_mode_suffix
			function hl_mod.get_mode_suffix()
				if vim.g.colors_name == "flexoki" then
					local api_mode = vim.api.nvim_get_mode().mode
					local mode_name = require("lualine.utils.mode").get_mode()
					if api_mode == "\22" or api_mode == "\22s" or mode_name == "V-BLOCK" then
						return "_replace"
					end
				end
				return orig_get_mode_suffix()
			end
		end
	end

	-- Custom component for pretty path formatting (similar to LazyVim)
	--- Formats file paths intelligently, showing only necessary parent directories
	---@param opts table Component options
	---@return string Formatted path
	local function pretty_path(opts)
		local filepath = vim.api.nvim_buf_get_name(0)
		
		-- Handle buffers without files (scratch buffers, etc.)
		if filepath == "" then
			return "[No Name]"
		end

		local path_sep = package.config:sub(1, 1) -- Get path separator for OS
		local cwd = vim.fn.getcwd()
		
		-- Normalise paths
		filepath = vim.fn.fnamemodify(filepath, ":p")
		cwd = vim.fn.fnamemodify(cwd, ":p")

		-- Make path relative to cwd if possible
		if vim.startswith(filepath, cwd) then
			filepath = filepath:sub(#cwd + 1)
			if filepath:sub(1, 1) == path_sep then
				filepath = filepath:sub(2)
			end
		else
			-- If not in cwd, use home directory as reference
			local home = vim.fn.expand("~")
			if vim.startswith(filepath, home) then
				filepath = "~" .. filepath:sub(#home + 1)
			end
		end

		-- Handle empty path (file in cwd root)
		if filepath == "" or filepath == nil then
			return vim.fn.expand("%:t")
		end

		-- Split path into components
		local parts = {}
		for part in filepath:gmatch("[^" .. path_sep .. "]+") do
			if part ~= "" then
				table.insert(parts, part)
			end
		end

		-- If only one part (just filename), return it
		if #parts == 1 then
			return parts[1]
		end

		-- Get filename (last part)
		local filename = parts[#parts]
		table.remove(parts)

		-- If only one directory, show it with filename
		if #parts == 1 then
			return parts[1] .. path_sep .. filename
		end

		-- For multiple directories, show first letter of intermediate dirs
		-- and full name of last directory (similar to LazyVim)
		local result = {}
		for i = 1, #parts - 1 do
			local dir = parts[i]
			if #dir > 0 then
				table.insert(result, dir:sub(1, 1))
			end
		end
		-- Add last directory in full
		table.insert(result, parts[#parts])
		-- Add filename
		table.insert(result, filename)

		return table.concat(result, path_sep)
	end

	---Return lualine theme: Flexoki (light or dark) uses the same orange normal-mode strip
	---(#DA702C / ink on `a`; section `b` uses each mode’s `ui` surface).
	---V-BLOCK uses the replace strip via `get_mode_suffix` (see above); V-LINE uses default `visual`.
	---Other modes keep `auto` semantics (insert cyan, char VISUAL / V-LINE muted, command blue).
	---@return string|table
	local function lualine_theme()
		if vim.g.colors_name ~= "flexoki" then
			return "auto"
		end
		package.loaded["lualine.themes.auto"] = nil
		local auto = require("lualine.themes.auto")
		local theme = vim.deepcopy(auto)
		-- orange-400 / flexoki-black — same accent for light and dark (SimonAB/flexoki-neovim palette)
		theme.normal.a = { bg = "#DA702C", fg = "#100F0F", gui = "bold" }
		if vim.o.background == "light" then
			theme.normal.b = { bg = "#E6E4D9", fg = "#DA702C" }
		else
			theme.normal.b = { bg = "#282726", fg = "#DA702C" }
		end
		return theme
	end

	---Volatile Lualine segments (branch, diff, diagnostics) only when the terminal
	---window is focused; see `g:_nvim_os_window_focused` in `config.lua`.
	---@return boolean
	local function lualine_when_os_window_focused()
		return (vim.g._nvim_os_window_focused or 1) ~= 0
	end

	---Diff counts from gitsigns (sync). Default `diff` uses async `git diff`, which flickers.
	---@return { added: integer, modified: integer, removed: integer }
	local function lualine_diff_from_gitsigns()
		local ok_gs, gs = pcall(require, "gitsigns")
		if not ok_gs or gs.get_hunks == nil then
			return { added = 0, modified = 0, removed = 0 }
		end
		local bufnr = vim.api.nvim_get_current_buf()
		local hunks = gs.get_hunks(bufnr)
		if hunks == nil then
			return { added = 0, modified = 0, removed = 0 }
		end
		local summary = require("gitsigns.hunks").get_summary(hunks)
		return {
			added = summary.added,
			modified = summary.changed,
			removed = summary.removed,
		}
	end

	---Show which register is being recorded; empty when idle.
	---@return string
	local function lualine_macro_recording()
		local reg = vim.fn.reg_recording()
		if reg == "" then
			return ""
		end
		return "REC @" .. reg
	end

	---Spell-language flag when spell is on (🇬🇧 / 🇫🇷).
	---@return string
	local function lualine_spell_lang()
		if not vim.wo.spell then
			return ""
		end
		local primary = (vim.bo.spelllang or ""):match("^([^,]+)") or ""
		local spell_flags = {
			en_gb = "🇬🇧",
			en_us = "🇺🇸",
			en = "🇬🇧",
			fr = "🇫🇷",
		}
		if spell_flags[primary] then
			return spell_flags[primary]
		end
		if primary:match("^en") then
			return "🇬🇧"
		elseif primary:match("^fr") then
			return "🇫🇷"
		end
		return "📝"
	end

	---Visual selection size with units; empty outside visual mode.
	---@param count integer
	---@return string
	local function format_word_count(count)
		return count .. (count == 1 and " word" or " words")
	end

	---@return string
	local function visual_selection_text()
		local mode = vim.fn.mode(true)
		local region_type = mode == "V" and "V" or (mode:match("\22") and "\22" or "v")
		local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = region_type })
		if not ok or not region or #region == 0 then
			return ""
		end
		if mode:match("\22") then
			return table.concat(region, " ")
		end
		return table.concat(region, "\n")
	end

	---@return string
	local function lualine_visual_selection()
		local mode = vim.fn.mode(true)
		if mode ~= "v" and mode ~= "V" and not mode:match("\22") then
			return ""
		end

		local line_start = vim.fn.line("v")
		local line_end = vim.fn.line(".")
		local col_start = vim.fn.col("v")
		local col_end = vim.fn.col(".")

		local text = visual_selection_text()
		local words = vim.fn.wordcount().visual_words or 0
		local word_suffix = " - " .. format_word_count(words)

		if mode == "V" then
			local n = math.abs(line_end - line_start) + 1
			return n .. (n == 1 and " line" or " lines") .. word_suffix
		end

		if mode:match("\22") then
			local rows = math.abs(line_end - line_start) + 1
			local cols = math.abs(col_end - col_start) + 1
			return string.format("%d×%d%s", rows, cols, word_suffix)
		end

		local chars = text ~= "" and vim.fn.strcharlen(text) or math.abs(col_end - col_start) + 1
		return chars .. (chars == 1 and " char" or " chars") .. word_suffix
	end

	---Search match index with unit; empty when hlsearch is off.
	---@return string
	local function lualine_search_count()
		if vim.v.hlsearch == 0 then
			return ""
		end
		local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 500 })
		if not ok or not result or result.total == 0 then
			return ""
		end
		local total = math.min(result.total, result.maxcount)
		return result.current .. "/" .. total .. " matches"
	end

	---Force a statusline redraw for indicators that change outside the slow poll.
	local function refresh_statusline()
		pcall(function()
			lualine.refresh({ force = true, place = { "statusline" } })
		end)
	end

	local refresh_augroup = vim.api.nvim_create_augroup("LualineConditionalRefresh", { clear = true })
	vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
		group = refresh_augroup,
		desc = "Refresh statusline when macro recording starts or stops",
		callback = refresh_statusline,
	})
	vim.api.nvim_create_autocmd("OptionSet", {
		group = refresh_augroup,
		pattern = { "spell", "spelllang" },
		desc = "Refresh statusline when spell options change",
		callback = refresh_statusline,
	})

	-- Debounce visual-mode CursorMoved refreshes: force-refreshing lualine on every
	-- motion races screen redraw with opaque syntax backgrounds (e.g. VimTeX proof
	-- todos) and leaves ghost selection / uncleared wrapped lines.
	local visual_refresh_pending = false
	local function schedule_visual_statusline_refresh()
		if visual_refresh_pending then
			return
		end
		visual_refresh_pending = true
		vim.defer_fn(function()
			visual_refresh_pending = false
			local mode = vim.fn.mode(true)
			if mode == "v" or mode == "V" or mode:match("\22") then
				refresh_statusline()
			end
		end, 120)
	end

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = refresh_augroup,
		desc = "Refresh statusline on mode change (visual selection enter/leave)",
		callback = refresh_statusline,
	})
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = refresh_augroup,
		desc = "Debounced statusline refresh while visual selection changes",
		callback = function()
			local mode = vim.fn.mode(true)
			if mode == "v" or mode == "V" or mode:match("\22") then
				schedule_visual_statusline_refresh()
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "CursorMoved", "CmdlineChanged", "CmdlineLeave" }, {
		group = refresh_augroup,
		desc = "Refresh statusline when search position or pattern changes",
		callback = function()
			if vim.v.hlsearch == 1 or vim.fn.mode() == "c" then
				refresh_statusline()
			end
		end,
	})

	lualine.setup({
		options = {
			theme = lualine_theme,
			component_separators = "┃",
			section_separators = { left = '', right = '' },
			refresh = {
				refresh_time = refresh_check_ms,
				statusline = 3000,
				tabline = 3000,
				winbar = 3000,
			},
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = {
				{ "branch", cond = lualine_when_os_window_focused },
				{ "diff", source = lualine_diff_from_gitsigns, cond = lualine_when_os_window_focused },
				{ "diagnostics", cond = lualine_when_os_window_focused },
			},
			lualine_c = { { pretty_path, path = 1 } },
			lualine_x = {
				{ stl_component(lualine_macro_recording) },
				{ stl_component(lualine_visual_selection) },
				{ stl_component(lualine_search_count) },
				{ stl_component(lualine_spell_lang) },
				"filetype",
			},
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
	})
end

