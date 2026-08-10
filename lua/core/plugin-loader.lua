-- =============================================================================
-- OPTIMIZED PLUGIN LOADER
-- PURPOSE: Consolidated plugin loading with 3 optimized phases
-- =============================================================================

local PluginLoader = {}

---Return true if startup debug notifications are enabled.
---@return boolean
local function is_startup_debug()
	return vim.g.startup_debug == 1 or vim.g.startup_debug == true
end

-- Map plugin config modules ("lua/plugins/<module>.lua") to vim.pack plugin names.
-- This keeps phased loading while using vim.pack's opt-only install location.
local MODULE_TO_PACK = {
	["plenary-nvim"] = "plenary.nvim",
	["nvim-web-devicons"] = "nvim-web-devicons",
	["blink-lib"] = "blink.lib",
	["blink-cmp"] = "blink.cmp",
	["mason-nvim"] = "mason.nvim",
	["mason-lspconfig-nvim"] = "mason-lspconfig.nvim",
	["nvim-lspconfig"] = "nvim-lspconfig",
	["nvim-treesitter"] = "nvim-treesitter",
	["mini-nvim"] = "mini.nvim",
	["codecompanion-nvim"] = "codecompanion.nvim",

	["bufferline-nvim"] = "bufferline.nvim",
	["lualine-nvim"] = "lualine.nvim",
	["nvim-tree"] = "nvim-tree.lua",
	["telescope"] = "telescope.nvim",
	["telescope-ui-select-nvim"] = "telescope-ui-select.nvim",
	["telescope-fzf-native-nvim"] = "telescope-fzf-native.nvim",
	["telescope-frecency-nvim"] = "telescope-frecency.nvim",
	["sqlite-lua"] = "sqlite.lua",
	["trouble-nvim"] = "trouble.nvim",
	["gitsigns-nvim"] = "gitsigns.nvim",
	["toggleterm-nvim"] = "toggleterm.nvim",
	["markdown-preview-nvim"] = "markdown-preview.nvim",
	["zen-mode-nvim"] = "zen-mode.nvim",
	["vimtex"] = "vimtex",
	["typst-preview-nvim"] = "typst-preview.nvim",
	["obsidian-nvim"] = "obsidian.nvim",
	["image-nvim"] = "image.nvim",
	["autolist-nvim"] = "autolist.nvim",
	["table-nvim"] = "table-nvim",
	["otter-nvim"] = "otter.nvim",
	["quarto-nvim"] = "quarto-nvim",
	["julia-vim"] = "julia-vim",

	["which-key-nvim"] = "which-key.nvim",
	["auto-dark-mode-nvim"] = "auto-dark-mode.nvim",
	["gruvbox-nvim"] = "gruvbox.nvim",
	["tokyonight-nvim"] = "tokyonight.nvim",
	["nord-vim"] = "nord-vim",
	["github-nvim-theme"] = "github-nvim-theme",
	["flexoki-nvim"] = "flexoki-neovim",
	["awesome-vim-colorschemes"] = "awesome-vim-colorschemes",
	["onedark-nvim"] = "onedark.nvim",
	["catppuccin"] = "catppuccin",
}

---Ensure a plugin is on runtimepath before requiring its config.
---@param module_name string
local function ensure_packadd(module_name)
	local pack_name = MODULE_TO_PACK[module_name]
	if not pack_name then
		return
	end
	pcall(vim.cmd.packadd, pack_name)
end

---Notify about config drift between vim.pack specs and phased loader lists.
---This helps catch "installed but never loaded" and "loader references missing plugin" issues.
local function notify_drift()
	local declared = {}
	if type(_G.neovim_plugins) == "table" then
		for _, spec in ipairs(_G.neovim_plugins) do
			local name = (spec or {}).name
			if type(name) == "string" and name ~= "" then
				declared[name] = true
			end
		end
	end

	local referenced = {}
	for _, pack_name in pairs(MODULE_TO_PACK) do
		referenced[pack_name] = true
	end

	local missing_from_specs = {}
	for pack_name in pairs(referenced) do
		if not declared[pack_name] then
			table.insert(missing_from_specs, pack_name)
		end
	end
	table.sort(missing_from_specs)

	local missing_from_loader = {}
	for name in pairs(declared) do
		if not referenced[name] then
			table.insert(missing_from_loader, name)
		end
	end
	table.sort(missing_from_loader)

	if #missing_from_specs == 0 and #missing_from_loader == 0 then
		return
	end

	local lines = { "vim.pack drift detected:" }
	if #missing_from_specs > 0 then
		table.insert(lines, "")
		table.insert(lines, "In loader mapping but not in `lua/plugins.lua`:")
		for _, name in ipairs(missing_from_specs) do
			table.insert(lines, "  - " .. name)
		end
	end
	if #missing_from_loader > 0 then
		table.insert(lines, "")
		table.insert(lines, "In `lua/plugins.lua` but not in phased loader mapping:")
		for _, name in ipairs(missing_from_loader) do
			table.insert(lines, "  - " .. name)
		end
	end

	vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN)
end

-- Optimized loading phases (reduced from 8 to 3)
local LOAD_PHASES = {
	-- Phase 1: IMMEDIATE (0ms) - Core essentials
	immediate = {
		"plenary-nvim",        -- Utility library
		"nvim-web-devicons",   -- File icons
		"catppuccin",          -- Catppuccin Mocha; must load before ThemeManager (~50ms)
		"flexoki-nvim",        -- Flexoki (transparent base + float styling)
		"blink-lib",          -- blink.cmp v2 dependency
		"blink-cmp",          -- Completion engine
		"mason-nvim",         -- LSP server manager
		"mason-lspconfig-nvim", -- Mason-LSP bridge (used by mason-nvim config)
		"nvim-lspconfig",     -- LSP configurations
		"nvim-treesitter",    -- Syntax highlighting
		"mini-nvim",          -- Dashboard and text objects
		"mason-enhanced",     -- Enhanced Mason UI
	},

	-- Phase 2: DEFERRED (100ms) - UI and functionality
	deferred = {
		"nvim-tree",          -- File explorer (before bufferline so sidebar offsets see the tree)
		"nvim-dir",           -- Built-in dir.lua tweaks (:edit on a folder)
		"bufferline-nvim",    -- Buffer tabs
		"lualine-nvim",       -- Status line
		"telescope",          -- Fuzzy finder
		"telescope-ui-select-nvim", -- vim.ui.select → Telescope (0.13 builtins)
		"vim-ui-img",         -- PDF→PNG cache + attachment open helper
		"image-nvim",         -- Markdown/PDF cursor popup via image.nvim (Kitty)
		"web-peek",           -- Markdown http(s) link peeks (title / OG image)
		"codecompanion-nvim", -- AI chat (ACP + HTTP)
		"telescope-fzf-native-nvim", -- Telescope native sorter (extension)
		"telescope-frecency-nvim", -- Telescope frecency (extension)
		"sqlite-lua",         -- SQLite dependency for frecency
		"trouble-nvim",       -- Diagnostics viewer
		"gitsigns-nvim",      -- Git integration
		"toggleterm-nvim",    -- Terminal management
		"markdown-preview-nvim", -- Markdown preview
		"zen-mode-nvim",      -- Distraction-free writing for prose
		"vimtex",             -- LaTeX support
		"typst-preview-nvim", -- Typst preview
		"obsidian-nvim",      -- Obsidian vault support
		"autolist-nvim",      -- List continuation
		"table-nvim",         -- Markdown tables
		"otter-nvim",         -- Embedded LSP for Quarto chunks
		"quarto-nvim",        -- Quarto support
		"julia-vim",          -- Julia syntax/indent
		"forge-nvim",         -- Forge task & project manager
	},

	-- Phase 3: LAZY (500ms) - Non-essentials and themes
	lazy = {
		"which-key-nvim",     -- Keymap discovery
		"auto-dark-mode-nvim", -- Auto theme switching
		-- Themes (loaded on-demand)
		"gruvbox-nvim",
		"tokyonight-nvim",
		"nord-vim",
		"github-nvim-theme",
		"awesome-vim-colorschemes",
		"onedark-nvim",
	}
}

-- Optimized loading function with error handling
function PluginLoader.load_with_phase(phase_name, plugins)
	local phase_delay = {
		immediate = 0,
		deferred = 100,
		lazy = 500
	}

	local delay = phase_delay[phase_name] or 0

	if delay == 0 then
		-- Load immediately
		for _, plugin in ipairs(plugins) do
			ensure_packadd(plugin)
			local ok, err = pcall(require, "plugins." .. plugin)
			if not ok then
				vim.notify("Failed to load " .. plugin .. ": " .. tostring(err), vim.log.levels.WARN)
			end
		end
	else
		-- Load with delay
		vim.defer_fn(function()
			for _, plugin in ipairs(plugins) do
				ensure_packadd(plugin)
				local ok, err = pcall(require, "plugins." .. plugin)
				if not ok then
					vim.notify("Failed to load " .. plugin .. ": " .. tostring(err), vim.log.levels.WARN)
				end
			end
		end, delay)
	end
end

-- Load all plugins in optimized phases
function PluginLoader.load_all()
	if is_startup_debug() then
		vim.notify("Loading plugins in optimized phases...", vim.log.levels.INFO)
	end

	notify_drift()

	-- Phase 1: Immediate
	PluginLoader.load_with_phase("immediate", LOAD_PHASES.immediate)

	-- Phase 2: Deferred
	PluginLoader.load_with_phase("deferred", LOAD_PHASES.deferred)

	-- Phase 3: Lazy
	PluginLoader.load_with_phase("lazy", LOAD_PHASES.lazy)

	if is_startup_debug() then
		vim.notify("Plugin loading complete", vim.log.levels.INFO)
	end
end

-- Get loading statistics
function PluginLoader.get_stats()
	local stats = {
		immediate = #LOAD_PHASES.immediate,
		deferred = #LOAD_PHASES.deferred,
		lazy = #LOAD_PHASES.lazy,
		total = 0
	}

	stats.total = stats.immediate + stats.deferred + stats.lazy
	return stats
end

return PluginLoader
