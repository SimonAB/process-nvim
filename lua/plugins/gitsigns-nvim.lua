-- Configuration for gitsigns.nvim
-- Git integration with enhanced visual indicators

local PluginReload = require("core.plugin-reload")
local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")

PluginReload.reload_gitsigns_if_stale()

local ok, gitsigns = pcall(require, "gitsigns")
if ok then
	gitsigns.setup({
		signs = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
			untracked = { text = "┆" },
		},
		signcolumn = true,
		numhl = false,
		linehl = false,
		word_diff = false,
		watch_gitdir = { interval = 1000, follow_files = true },
		attach_to_untracked = true,
		current_line_blame = false,
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol",
			delay = 1000,
			ignore_whitespace = false,
		},
		current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
		sign_priority = 6,
		update_debounce = 100,
		status_formatter = nil,
		max_file_length = 40000,
		preview_config = {
			border = "rounded",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
	})

	if not PluginReload.gitsigns_healthy() then
		vim.notify(
			"gitsigns did not load cleanly. Quit and restart Neovim.",
			vim.log.levels.WARN,
			{ title = "gitsigns", timeout = 10000 }
		)
	end

	-- Ensure gitsigns preview floats match which-key styling.
	local group = vim.api.nvim_create_augroup("GitsignsUIStyle", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "gitsigns",
		desc = "Style gitsigns preview floats to match which-key",
		callback = function()
			local winid = vim.api.nvim_get_current_win()
			if ok_ts and ThemeSettings and ThemeSettings.style_float_like_which_key then
				ThemeSettings.style_float_like_which_key(winid)
			end
		end,
	})
end
