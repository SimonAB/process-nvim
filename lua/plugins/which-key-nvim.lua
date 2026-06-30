-- Configuration for which-key.nvim
-- Keymap popup helper with comprehensive keybindings

local ok, wk = pcall(require, "which-key")
if ok then
	local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")
	local float_winhl = (ok_ts and ThemeSettings and ThemeSettings.get_which_key_float_winhl)
		and ThemeSettings.get_which_key_float_winhl()
		or "Normal:WhichKeyFloat,FloatBorder:WhichKeyBorder,FloatTitle:WhichKeyTitle"

	wk.setup({
		preset = "classic",
		delay = 500,
		-- Disable the internal footer helper window ("esc close / back") to avoid any
		-- bleed-through in terminal UIs while keeping the popup body/border fully transparent.
		show_help = false,
		show_keys = false,
		plugins = {
			marks = true,
			registers = true,
			spelling = {
				enabled = true,
				suggestions = 20,
			},
			presets = {
				operators = true,
				motions = true,
				text_objects = true,
				windows = true,
				-- nav preset disabled to prevent which-key from intercepting ]s/[s
				-- This sacrifices bracket motion hints but preserves spell navigation
				nav = false,
				z = true,
				g = true,
			},
		},
		win = {
			border = "rounded",
			padding = { 1, 2 },
			wo = {
				winblend = 0,
				winhl = float_winhl,
			},
		},
		layout = {
			height = { min = 4, max = 25 },
			width = { min = 20, max = 50 },
			spacing = 3,
			align = "center",
		},
		icons = {
			breadcrumb = "»",
			separator = "→",
			group = "+",
			ellipsis = "...",
			mappings = false, -- Disable icon mappings for a cleaner look
			rules = {},
			colors = false, -- Disable icon colors for text-only
			keys = {
				Up = " ",
				Down = " ",
				Left = " ",
				Right = " ",
				C = "󰘴 ",
				M = "󰘵 ",
				D = "󰘳 ",
				S = "󰘶 ",
				CR = "󰌑 ",
				Esc = "󱊷 ",
				ScrollWheelDown = "󱕐 ",
				ScrollWheelUp = "󱕑 ",
				NL = "󰌑 ",
				BS = "󰁮",
				Space = "󱁐 ",
				Tab = "󰌒 ",
				F1 = "󱊫",
				F2 = "󱊬",
				F3 = "󱊭",
				F4 = "󱊮",
				F5 = "󱊯",
				F6 = "󱊰",
				F7 = "󱊱",
				F8 = "󱊲",
				F9 = "󱊳",
				F10 = "󱊴",
				F11 = "󱊵",
				F12 = "󱊶",
			},
		},
	})

	-- which-key groups for localleader keymaps
	-- These provide display/help for keymaps defined in keymaps.lua
	wk.add({
		{ "<localleader>l", group = "VimTeX" },
		{ "<localleader>t", group = "Typst" },
	})

	-- Clarify descriptor for built-in gx without changing its mapping
	wk.add({
		{ "gx", desc = "Open URL/URI/file path under cursor", mode = "n" },
	})

	-- Centralised function to open Julia REPL with specified direction
	local function open_julia_repl(direction)
		local Terminal = require("toggleterm.terminal").Terminal
		local project_path = vim.fn.shellescape(vim.fn.getcwd())
		local julia_repl = Terminal:new({
			cmd = "julia --project=" .. project_path,
			hidden = true,
			direction = direction,
			close_on_exit = false,
			on_open = function(_)
				vim.cmd("startinsert!")
			end,
		})
		julia_repl:toggle()
	end

	-- Register leader keymap groups for which-key display
	-- Individual keymaps are defined in keymaps.lua with desc fields
	-- Convention: Capital letters = groups with sub-commands, lowercase = direct commands
	wk.add({
		-- Buffer operations
		{ "<leader>B", group = "Buffer" },
		-- AI / CodeCompanion
		{ "<leader>A", group = "AI" },
		-- Configuration
		{ "<leader>C", group = "Config" },
		-- Frecency operations (capital F for group with sub-commands)
		{ "<leader>F", group = "Forge" },
		-- Git operations
		{ "<leader>G", group = "Git" },
		-- Obsidian operations
		{ "<leader>O", group = "Obsidian" },
		{ "<leader>O!", group = "Callout" },
		-- Search operations (grep with location options)
		{ "<leader>S", group = "Search" },
		-- Toggle options
		{ "<leader>Y", group = "Toggle" },
		-- LSP operations
		{ "<leader>L", group = "LSP" },
		{ "<leader>Lu", function()
			vim.notify("Updating all LSP servers...", vim.log.levels.INFO)
			-- Update Mason LSP servers
			local ok, MasonUI = pcall(require, "plugins.mason-enhanced")
			if ok then
				MasonUI.update_all_packages()
			end
			-- Update Julia LanguageServer.jl
			vim.cmd("JuliaLspUpdate")
		end, desc = "Update All LSP Servers" },
		-- Quarto operations
		{ "<leader>Q", group = "Quarto" },
		{ "<leader>QR", group = "Render" },
		{ "<leader>QM", group = "Molten" },
		-- Split operations
		{ "<leader>|", group = "Split" },
		-- Terminal operations
		{ "<leader>T", group = "Terminal" },
		-- Window operations
		{ "<leader>W", group = "Window" },
		-- Trouble diagnostics
		{ "<leader>X", group = "Trouble" },
		-- Julia-specific operations
		{ "<leader>J", group = "Julia" },
		{ "<leader>Jl", "<cmd>JuliaLspUpdate<cr>", desc = "Update LanguageServer.jl" },
		-- Mason operations (enhanced with batch operations)
		{ "<leader>M", group = "Mason" },
		{ "<leader>MA", function()
			local ok, MasonUI = pcall(require, "plugins.mason-enhanced")
			if ok then
				MasonUI.install_academic_servers()
			else
				vim.notify("Mason Enhanced UI not available", vim.log.levels.WARN)
			end
		end, desc = "Install Academic LSP Servers" },
		{ "<leader>MR", function()
			local ok, MasonUI = pcall(require, "plugins.mason-enhanced")
			if ok then
				MasonUI.install_all_recommended()
			else
				vim.notify("Mason Enhanced UI not available", vim.log.levels.WARN)
			end
		end, desc = "Install All Recommended Servers" },
		{ "<leader>MU", function()
			local ok, MasonUI = pcall(require, "plugins.mason-enhanced")
			if ok then
				MasonUI.update_all_packages()
			else
				vim.notify("Mason Enhanced UI not available", vim.log.levels.WARN)
			end
		end, desc = "Update All Packages" },
		{ "<leader>MS", function()
			local ok, MasonUI = pcall(require, "plugins.mason-enhanced")
			if ok then
				MasonUI.check_status()
			else
				vim.notify("Mason Enhanced UI not available", vim.log.levels.WARN)
			end
		end, desc = "Mason Status" },
		-- Forge kanban / project manager
		{ "<leader>R", group = "Frecency" },
		-- Markdown group (preview + list operations)
		{ "<leader>K", group = "Markdown" },
		{ "<leader>Kl", group = "List" },
		{ "<leader>Kln", desc = "Autolist: Next list style" },
		{ "<leader>Klp", desc = "Autolist: Previous list style" },

		-- Theme management (enhanced with floating picker)
		{ "<leader>YT", group = "Themes" },

		-- Plugin management (enhanced with progress feedback)
		{ "<leader>CU", group = "Update" },
	})

	-- Individual keymaps are defined in `keymaps-core.lua` / `keymaps-plugins.lua` with `desc` fields
	-- which-key automatically discovers and displays them
end
