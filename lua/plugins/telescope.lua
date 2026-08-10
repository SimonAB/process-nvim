-- Configuration for telescope.nvim
-- Fuzzy finder with enhanced features

local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")

---Apply opaque which-key float chrome to Telescope float windows.
---@param winid integer
local function style_telescope_float_window(winid)
	if not ok_ts or not ThemeSettings.style_float_like_which_key then
		return
	end
	if not winid or not vim.api.nvim_win_is_valid(winid) then
		return
	end
	if vim.fn.win_gettype(winid) ~= "popup" then
		return
	end
	ThemeSettings.style_float_like_which_key(winid)
end

local ok, telescope = pcall(require, "telescope")
if ok then
	-- Safely get sorters
	local sorters_ok, sorters = pcall(require, "telescope.sorters")
	local file_sorter = sorters_ok and sorters.fuzzy_with_index_bias or nil

	telescope.setup({
		defaults = {
			debounce = 50,
			path_display = { "truncate" },
			file_sorter = file_sorter,
			layout_strategy = "horizontal",
			layout_config = {
				horizontal = {
					prompt_position = "bottom",
					preview_width = 0.55,
					results_width = 0.8,
				},
			},
			preview = {
				treesitter = false,
			},
		},
		pickers = {
			find_files = {
				hidden = false,
				file_ignore_patterns = {
					"%.git/",
					"node_modules/",
					"%.DS_Store",
					"%.cache/",
					"%.local/",
					"%.pdf$",
					"%.jpg$", "%.jpeg$", "%.png$", "%.gif$", "%.bmp$", "%.tiff$", "%.svg$", "%.ico$", "%.webp$",
					"%.mp3$", "%.mp4$", "%.avi$", "%.mov$", "%.wmv$", "%.flv$", "%.mkv$", "%.webm$",
					"%.zip$", "%.tar$", "%.gz$", "%.rar$", "%.7z$", "%.bz2$",
					"%.exe$", "%.dmg$", "%.pkg$", "%.deb$", "%.rpm$",
					"%.doc$", "%.docx$", "%.xls$", "%.xlsx$", "%.ppt$", "%.pptx$",
					"%.odt$", "%.ods$", "%.odp$",
					"%.class$", "%.o$", "%.so$", "%.dll$", "%.dylib$",
					"%.pyc$", "%.pyo$", "%.pyd$",
					"%.log$", "%.tmp$", "%.temp$",
				},
			},
			live_grep = {
				additional_args = function()
					return { "--hidden" }
				end,
			},
		},
		extensions = {
			fzf = {
				fuzzy = true,
				override_generic_sorter = true,
				override_file_sorter = true,
				case_mode = "smart_case",
			},
			frecency = {
				show_scores = false,
				show_unindexed = true,
				ignore_patterns = { "*.git/*", "*/tmp/*", "term://*" },
				-- Reduce background work and avoid shutdown-time prompts/noise.
				-- The database will be built as you use it, without importing oldfiles.
				bootstrap = false,
				auto_validate = false,
				db_safe_mode = false,
			},
			["ui-select"] = (function()
				local ok_themes, themes = pcall(require, "telescope.themes")
				if ok_themes then
					return themes.get_dropdown({})
				end
				return {}
			end)(),
		},
	})

	-- Load telescope extensions
	pcall(telescope.load_extension, "fzf")
	pcall(telescope.load_extension, "frecency")
	-- Neovim 0.13 builtins (:browse oldfiles, z=, :tselect, :recover) use vim.ui.select.
	pcall(telescope.load_extension, "ui-select")

	-- Telescope uses multiple floating windows (prompt/results/preview). Restyle on attach.
	local augroup = vim.api.nvim_create_augroup("TelescopeFloatStyle", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = { "TelescopePrompt", "TelescopeResults", "TelescopePreview" },
		desc = "Align Telescope floats with which-key styling",
		callback = function()
			style_telescope_float_window(vim.api.nvim_get_current_win())
		end,
	})

	-- The preview window's buffer filetype is usually the *previewed* filetype, not "TelescopePreview".
	-- Restyle the window(s) displaying the preview buffer when Telescope loads it.
	vim.api.nvim_create_autocmd("User", {
		group = augroup,
		pattern = { "TelescopePreviewerLoaded", "TelescopePreviewLoaded" },
		desc = "Align Telescope grep preview with which-key styling",
		callback = function(args)
			-- In most versions, Telescope provides args.data.{bufnr,bufname,filetype}.
			-- Fall back to the current buffer/window if the payload is missing.
			local bufnr = nil
			if args and args.data then
				if args.data.bufnr and type(args.data.bufnr) == "number" then
					bufnr = args.data.bufnr
				elseif args.data.bufname and type(args.data.bufname) == "string" then
					bufnr = vim.fn.bufnr(args.data.bufname)
				end
			end

			if not bufnr or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
				bufnr = vim.api.nvim_get_current_buf()
			end

			-- Style the current window first (often the preview window at event time).
			style_telescope_float_window(vim.api.nvim_get_current_win())

			-- Also style any window(s) currently displaying the preview buffer.
			for _, winid in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
					style_telescope_float_window(winid)
				end
			end
		end,
	})
end
