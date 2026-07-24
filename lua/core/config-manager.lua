-- =============================================================================
-- CENTRALIZED CONFIGURATION MANAGER
-- PURPOSE: Shared/global configurations (themes, LSP, UI, performance)
-- NOTE: Detailed plugin configurations are in their respective plugin files
-- =============================================================================

local ConfigManager = {
	themes = {},
	lsp = {},
	ui = {},
	performance = {}
}

-- =============================================================================
-- THEME CONFIGURATIONS
-- =============================================================================

-- Shared defaults consumed by ThemeManager/ThemePicker for system appearance + UI opacity.
ConfigManager.themes.active = {
	defaults = {
		-- Follow system appearance with a light/dark pair.
		dark = "flexoki-dark",
		light = "flexoki-light",
	},
	opacity = 0.9,
}

ConfigManager.themes.catppuccin = {
	flavour = "auto",
	background = {
		light = "latte",
		dark = "mocha",
	},
	transparent_background = true,
	show_end_of_buffer = false,
	term_colors = true,
	dim_inactive = {
		enabled = false,
		shade = "dark",
		percentage = 0.15,
	},
	styles = {
		comments = { "italic" },
		conditionals = { "italic" },
		loops = {},
		functions = {},
		keywords = {},
		strings = {},
		variables = {},
		numbers = {},
		booleans = {},
		properties = {},
		types = {},
		operators = {},
	},
	integrations = {
		cmp = true,
		gitsigns = true,
		nvimtree = true,
		telescope = true,
		treesitter = true,
		native_lsp = {
			enabled = true,
			virtual_text = {
				errors = { "italic" },
				hints = { "italic" },
				warnings = { "italic" },
				information = { "italic" },
			},
			underlines = {
				errors = { "underline" },
				hints = { "underline" },
				warnings = { "underline" },
				information = { "underline" },
			},
		},
	},
}

ConfigManager.themes.onedark = {
	style = "dark",
	transparent = false,
	term_colors = true,
	ending_tildes = false,
	cmp_itemkind_reverse = false,
	code_style = {
		comments = "italic",
		keywords = "none",
		functions = "none",
		strings = "none",
		variables = "none",
	},
	diagnostics = {
		darker = true,
		undercurl = true,
		background = true,
	},
}

ConfigManager.themes.tokyonight = {
	style = "night",
	light_style = "day",
	transparent = false,
	terminal_colors = true,
	styles = {
		comments = { italic = true },
		keywords = { italic = true },
		functions = {},
		variables = {},
		sidebars = "dark",
		floats = "dark",
	},
	day_brightness = 0.3,
	hide_inactive_statusline = false,
	dim_inactive = false,
	lualine_bold = false,
}

-- =============================================================================
-- LSP CONFIGURATIONS
-- =============================================================================

ConfigManager.lsp.servers = {
	-- Core academic servers
	pyright = {
		settings = {
			python = {
				analysis = {
					typeCheckingMode = "basic",
					autoSearchPaths = true,
					useLibraryCodeForTypes = true,
					diagnosticMode = "workspace",
				},
			},
		},
	},
	texlab = {
		settings = {
			texlab = {
				auxDirectory = ".",
				bibtexFormatter = "texlab",
				build = {
					executable = "latexmk",
					args = {
						"-lualatex", "-interaction=nonstopmode",
						"-synctex=1", "-file-line-error", "%f"
					},
					onSave = false,
					forwardSearchAfter = false,
				},
				chktex = { onOpenAndSave = false, onEdit = false },
				diagnosticsDelay = 300,
				formatterLineLength = 80,
				latexFormatter = "latexindent",
				latexindent = { ["local"] = nil, modifyLineBreaks = false },
			},
		},
	},
	tinymist = {}, -- Typst LSP
	lua_ls = {
		settings = {
			Lua = {
				runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
				diagnostics = { globals = { "vim" } },
				workspace = {
					library = {
						[vim.fn.expand("$VIMRUNTIME/lua")] = true,
						[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
					},
				},
			},
		},
	},
	r_language_server = {
		settings = {
			r = { lsp = { rich_documentation = false } },
		},
	},
}

-- =============================================================================
-- UI CONFIGURATIONS
-- =============================================================================

ConfigManager.ui.which_key = {
	preset = "classic",
	delay = 500,
	plugins = {
		marks = true,
		registers = true,
		spelling = { enabled = true, suggestions = 20 },
		presets = {
			operators = true, motions = true, text_objects = true,
			windows = true, nav = true, z = true, g = true
		},
	},
	win = {
		border = "rounded",
		padding = { 1, 2 },
		wo = { winblend = 0 },
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
		mappings = false,
		colors = false,
		keys = {
			Up = " ", Down = " ", Left = " ", Right = " ",
			C = "󰘴 ", M = "󰘵 ", D = "󰘳 ", S = "󰘶 ",
			CR = "󰌑 ", Esc = "󱊷 ", ScrollWheelDown = "󱕐 ", ScrollWheelUp = "󱕑 ",
			NL = "󰌑 ", BS = "󰁮", Space = "󱁐 ", Tab = "󰌒 ",
		},
	},
}

-- =============================================================================
-- PERFORMANCE SETTINGS
-- =============================================================================

ConfigManager.performance = {
	-- Plugin loading phases (in milliseconds)
	loading_phases = {
		immediate = 0,
		deferred = 100,
		lazy = 500,
	},
	-- Update intervals
	update_debounce = {
		which_key = 100,
		lsp = 250,
		git = 1000,
	},
	-- Cache settings
	cache = {
		theme_highlights = true,
		file_icons = true,
		lsp_capabilities = true,
	},
}

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

function ConfigManager.load_theme_config(theme_name)
	return ConfigManager.themes[theme_name] or {}
end


function ConfigManager.load_lsp_config(server_name)
	return ConfigManager.lsp.servers[server_name] or {}
end

function ConfigManager.get_performance_setting(key)
	local keys = vim.split(key, ".", { plain = true })
	local value = ConfigManager.performance
	for _, k in ipairs(keys) do
		value = value[k]
		if not value then return nil end
	end
	return value
end

function ConfigManager.validate_config()
	-- Basic validation to ensure configurations are well-formed
	local function validate_section(section_name, section)
		if type(section) ~= "table" then
			vim.notify("Config validation failed: " .. section_name .. " must be a table", vim.log.levels.ERROR)
			return false
		end
		return true
	end

	local valid = true
	valid = valid and validate_section("themes", ConfigManager.themes)
	valid = valid and validate_section("lsp", ConfigManager.lsp)
	valid = valid and validate_section("ui", ConfigManager.ui)
	valid = valid and validate_section("performance", ConfigManager.performance)

	if valid then
		vim.notify("Configuration validation passed", vim.log.levels.INFO)
	else
		vim.notify("Configuration validation failed", vim.log.levels.ERROR)
	end

	return valid
end

-- Initialize configuration validation
vim.defer_fn(function()
	ConfigManager.validate_config()
end, 100)

return ConfigManager

