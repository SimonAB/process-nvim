-- Configuration for lualine.nvim
-- Status line with comprehensive information display

local ok, lualine = pcall(require, "lualine")
if ok then
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
			lualine_x = { "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
	})
end

