-- Configuration for mason.nvim
-- Portable package manager for Neovim that runs everywhere Neovim runs
-- Easily install and manage LSP servers, DAP servers, linters, and formatters

local ok, mason = pcall(require, "mason")
if ok then
	mason.setup({
		-- The directory in which to install packages
		install_root_dir = vim.fn.stdpath("data") .. "/mason",

		-- Where Mason should put its bin location in your PATH
		-- Can be "prepend" (default), "append", or "skip"
		PATH = "prepend",

		-- Controls to which degree logs are written to the log file
		log_level = vim.log.levels.INFO,

		-- Limit for the maximum amount of packages to be installed at the same time
		max_concurrent_installers = 4,

		-- The registries to source packages from
		registries = {
			"github:mason-org/mason-registry",
		},

		-- The provider implementations to use for resolving supplementary package metadata
		providers = {
			"mason.providers.registry-api",
			"mason.providers.client",
		},

		-- GitHub configuration for downloading assets
		github = {
			download_url_template = "https://github.com/%s/releases/download/%s/%s",
		},

		-- pip configuration
		pip = {
			upgrade_pip = false,
			install_args = {},
		},

		-- UI configuration
		ui = {
			-- Whether to automatically check for new versions when opening the :Mason window
			check_outdated_packages_on_open = true,

			-- The border to use for the UI window
			border = "rounded",

			-- The backdrop opacity. 0 is fully opaque, 100 is fully transparent
			backdrop = 0,

			-- Width of the window (0.8 = 80% of screen width)
			width = 0.8,

			-- Height of the window (0.9 = 90% of screen height)
			height = 0.9,

			-- Icons for different package states
			icons = {
				package_installed = "✓",
				package_pending = "⟳",
				package_uninstalled = "✗",
			},

			-- Keymaps for the Mason UI
			keymaps = {
				toggle_package_expand = "<CR>",
				install_package = "i",
				update_package = "u",
				check_package_version = "c",
				update_all_packages = "U",
				check_outdated_packages = "C",
				uninstall_package = "X",
				cancel_installation = "<C-c>",
				apply_language_filter = "<C-f>",
				toggle_package_install_log = "<CR>",
				toggle_help = "g?",
			},
		},
	})

	-- ============================================================================
	-- UI styling parity with which-key
	-- ============================================================================

	local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")

	---Apply Mason highlight links so its UI matches which-key's float palette.
	local function apply_mason_highlights()
		local links = {
			MasonNormal = "WhichKeyFloat",
			MasonBorder = "WhichKeyBorder",
			MasonHeader = "WhichKeyTitle",
			MasonHeading = "WhichKeyTitle",
			MasonMuted = "Comment",
			MasonHighlight = "WhichKey",
			MasonHighlightBlock = "WhichKeyGroup",
			MasonHighlightBlockBold = "WhichKeyGroup",
			MasonHighlightSecondary = "WhichKeySeparator",
			MasonHighlightBlockSecondary = "WhichKeySeparator",
			MasonError = "DiagnosticError",
			MasonWarning = "DiagnosticWarn",
		}

		for group, target in pairs(links) do
			pcall(vim.api.nvim_set_hl, 0, group, { link = target })
		end
	end

	---Force Mason windows to use which-key's float winhl mapping.
	---@param winid integer
	local function style_mason_window(winid)
		if not winid or not vim.api.nvim_win_is_valid(winid) then
			return
		end

		if ok_ts and ThemeSettings and ThemeSettings.style_float_like_which_key then
			ThemeSettings.style_float_like_which_key(winid)
		end
	end

	local group = vim.api.nvim_create_augroup("MasonUIStyle", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		desc = "Reapply Mason UI highlight links after theme changes",
		callback = function()
			apply_mason_highlights()
		end,
	})
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "mason",
		desc = "Style Mason window to match which-key float appearance",
		callback = function()
			apply_mason_highlights()
			style_mason_window(vim.api.nvim_get_current_win())
		end,
	})

	apply_mason_highlights()
else
	vim.notify("❌ Mason not available - LSP server management will be limited", vim.log.levels.WARN)
end

-- Mason LSP Config integration (deferred for performance)
vim.defer_fn(function()
	local ok_mason_lspconfig, mason_lspconfig = pcall(require, "mason-lspconfig")
	if ok_mason_lspconfig then
		mason_lspconfig.setup({
			-- Automatically install configured servers (with lspconfig)
			automatic_installation = true, -- Enable auto-install for LSP servers

		-- Ensure these servers are installed (minimal set for startup)
		ensure_installed = {
			-- Core language servers for your academic workflow
			-- "julials",           -- Julia language server (managed manually via nvim-lspconfig)
			"pyright",           -- Python language server (preferred)
			"texlab",            -- LaTeX language server
            "tinymist",          -- Typst language server
			"lua_ls",            -- Lua language server
			"bashls",            -- Bash language server
			"jsonls",            -- JSON language server
			"yamlls",            -- YAML language server
			"marksman",          -- Markdown language server
			"html",              -- HTML language server
			"cssls",             -- CSS language server
			"ts_ls", 			 -- TypeScript/JavaScript language server
		},

		-- Optional: Configure specific servers
		handlers = {
			-- Default handler for installing servers
			function(server_name)
				vim.lsp.enable(server_name)
			end,



			-- Do not let Mason configure Julia; handled manually in nvim-lspconfig
			["julials"] = function()
				-- Explicitly do nothing - custom config in nvim-lspconfig.lua will handle it
			end,

			-- Custom handler for Python LSP
			["pyright"] = function()
				vim.lsp.config('pyright', {
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
				})
				vim.lsp.enable('pyright')
			end,

			-- Custom handler for R LSP
			["r-languageserver"] = function()
				vim.lsp.config('r_language_server', {
					settings = {
						r = {
							lsp = {
								rich_documentation = false,
							},
						},
					},
				})
				vim.lsp.enable('r_language_server')
			end,

			-- Custom handler for LaTeX LSP
			["texlab"] = function()
				vim.lsp.config('texlab', {
					settings = {
						texlab = {
							auxDirectory = ".",
							bibtexFormatter = "texlab",
							build = {
								executable = "latexmk",
								args = {
									"-lualatex",
									"-interaction=nonstopmode",
									"-synctex=1",
									"-file-line-error",
									"%f",
								},
								onSave = false,
								forwardSearchAfter = false,
							},
							chktex = {
								onOpenAndSave = false,
								onEdit = false,
							},
							diagnosticsDelay = 300,
							formatterLineLength = 80,
							forwardSearch = {
								executable = nil,
								args = {},
							},
							latexFormatter = "latexindent",
							latexindent = {
								["local"] = nil,
								modifyLineBreaks = false,
							},
						},
					},
				})
				vim.lsp.enable('texlab')
			end,
		},
	})
	else
		vim.notify("❌ Mason LSP Config not available - LSP server installation will be manual", vim.log.levels.WARN)
	end
end, 500) -- Defer LSP setup for better startup performance

-- =============================================================================
-- ENHANCED MASON UI INTEGRATION
-- =============================================================================

-- Initialize enhanced Mason UI
vim.defer_fn(function()
	local ok, MasonUI = pcall(require, "plugins.mason-enhanced")
	if ok then
		MasonUI.init()
	else
		vim.notify("Mason Enhanced UI not available", vim.log.levels.WARN)
	end
end, 1000) -- Load after Mason is fully initialized
