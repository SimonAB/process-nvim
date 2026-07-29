-- LSP Configuration with Mason Integration
-- This file sets up language server protocol (LSP) support for multiple languages in Neovim using nvim-lspconfig.
-- Mason handles server installation and management automatically.
-- Keymaps for LSP actions are set per buffer on attach. Completion is enhanced if blink.cmp is available.

-- Use the new vim.lsp.config API (Neovim 0.11+)
-- No need to require lspconfig anymore

-- Set up LSP client capabilities with performance optimisations
local capabilities = vim.lsp.protocol.make_client_capabilities()

-- Minimal capabilities by default for better performance
capabilities.textDocument.completion.completionItem.snippetSupport = false
capabilities.textDocument.completion.completionItem.resolveSupport = nil

-- Match which-key float styling for built-in LSP/diagnostic popups.
do
	local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")
	local float_winhl = (ok_ts and ThemeSettings and ThemeSettings.get_which_key_float_winhl)
		and ThemeSettings.get_which_key_float_winhl()
		or "Normal:WhichKeyFloat,FloatBorder:WhichKeyBorder,FloatTitle:WhichKeyTitle"

	vim.diagnostic.config({
		float = {
			border = "rounded",
			winhl = float_winhl,
		},
	})

	-- Neovim 0.12 deprecates `vim.lsp.with()` and no longer routes hover/signature
	-- through global handlers in the same way. Styling the shared preview opener
	-- keeps borders/highlights consistent without per-keymap wrappers.
	if not vim.g._which_key_float_preview_wrapped then
		vim.g._which_key_float_preview_wrapped = true
		local default_open = vim.lsp.util.open_floating_preview
		vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
			opts = opts or {}
			opts = vim.tbl_deep_extend("force", opts, {
				border = "rounded",
				winhl = float_winhl,
			})
			return default_open(contents, syntax, opts, ...)
		end
	end
end

-- Enhance capabilities only for specific servers that need them
local blink_ok, blink_lsp = pcall(require, "blink.cmp.lsp")
if blink_ok then
	-- Create enhanced capabilities for servers that need full features
	local enhanced_capabilities = blink_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())
	enhanced_capabilities.textDocument.completion.completionItem.resolveSupport = {
		properties = { "documentation", "detail", "additionalTextEdits" },
	}
	-- Store enhanced capabilities for use with specific servers
	_G.enhanced_lsp_capabilities = enhanced_capabilities
end

-- Common on_attach function for all LSP servers
local function on_attach(client, bufnr)
	vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc" -- Enable omnifunc for completion
	local opts = { noremap = true, silent = true, buffer = bufnr }

	-- LSP keymaps for navigation and actions
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	
	-- Hover keymap - NOTE: Currently not working with LanguageServer.jl (upstream issue)
	-- The server doesn't respond to hover requests. Use 'gd' for go-to-definition instead.
	vim.keymap.set("n", "K", function()
		vim.notify("Hover not available: LanguageServer.jl doesn't respond to hover requests.", vim.log.levels.WARN)
		vim.notify("Use 'gd' for go-to-definition, or check Julia docs manually.", vim.log.levels.INFO)
		-- Still try hover in case it gets fixed in future versions
		vim.lsp.buf.hover()
	end, opts)
	
	vim.keymap.set("n", "<localleader>rn", vim.lsp.buf.rename, opts)
	vim.keymap.set("n", "<localleader>ca", vim.lsp.buf.code_action, opts)
	
	-- Diagnostic keymaps
	vim.keymap.set("n", "<localleader>d", vim.diagnostic.open_float, opts)
	vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
	vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
	
	-- Completion trigger
	vim.keymap.set("i", "<C-Space>", function()
		require("blink.cmp").show() -- Manual completion trigger
	end, { buffer = bufnr })
	
	-- Enable diagnostics signs in the gutter
	vim.diagnostic.config({
		virtual_text = true, -- Show inline diagnostics
		signs = true, -- Show diagnostic signs in gutter
		update_in_insert = false, -- Don't update while typing
		underline = true, -- Underline problematic code
		severity_sort = true, -- Sort by severity
	})
end

-- Note: Most LSP server configurations are now handled by mason-lspconfig
-- This file contains only custom configurations that extend the default Mason setup

-- Additional LSP servers not covered by Mason's ensure_installed
-- or servers that need custom configuration beyond the defaults

-- Julia LSP setup (bypass Mason due to current instability)
-- Uses @nvim-lspconfig environment which needs LanguageServer.jl installed
--
-- KNOWN LIMITATION: Hover (K key) does not work with LanguageServer.jl
-- The server accepts hover requests but never responds. This is a known upstream issue.
-- Workarounds: Use 'gd' for go-to-definition, or check Julia documentation manually.
local function build_julia_lsp_cmd(project_env, root_dir)
  -- Escape the root_dir path for use in Julia string (handle both Unix and Windows paths)
  local escaped_root = root_dir:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("'", "\\'")
  
  return {
    "julia",
    "--project=" .. project_env,
    "--startup-file=no",
    "--history-file=no",
    "-e",
    string.format([[
      try
        using LanguageServer
        project_path = "%s"
        server = LanguageServer.LanguageServerInstance(stdin, stdout, project_path, "")
        run(server)
      catch err
        Base.println(stderr, err)
        Base.println(stderr, sprint(showerror, err, catch_backtrace()))
        flush(stderr)
        exit(1)
      end
    ]], escaped_root),
  }
end

-- Note: Julia LSP is now started via autocommand below
-- The autocommand handles actual startup with proper project path detection

local JULIA_LSP_PROJECT = "@nvim-lspconfig"

---Run a Julia command for LanguageServer.jl maintenance.
---@param julia_code string Julia code to execute
---@param notify_start string Message shown when the job starts
---@param notify_success string Message shown on success
---@param notify_failure string Message shown on failure
local function run_julia_lsp_job(julia_code, notify_start, notify_success, notify_failure)
  vim.notify(notify_start, vim.log.levels.INFO)
  vim.fn.jobstart({
    "julia",
    "--project=" .. JULIA_LSP_PROJECT,
    "--startup-file=no",
    "--history-file=no",
    "-e",
    julia_code,
  }, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify(notify_success, vim.log.levels.INFO)
      else
        vim.notify(notify_failure, vim.log.levels.ERROR)
      end
    end,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            print(line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            print(line)
          end
        end
      end
    end,
  })
end

-- Create user command to install LanguageServer.jl in the @nvim-lspconfig environment
vim.api.nvim_create_user_command("JuliaLspInstall", function()
  run_julia_lsp_job(
    'using Pkg; Pkg.add("LanguageServer"); Pkg.instantiate(); using LanguageServer',
    "Installing LanguageServer.jl in @nvim-lspconfig environment...",
    "LanguageServer.jl installed successfully! Restart Neovim or reopen Julia files to use it.",
    "Failed to install LanguageServer.jl. Run: julia --project=@nvim-lspconfig --startup-file=no -e 'using Pkg; Pkg.instantiate()'"
  )
end, { desc = "Install Julia LanguageServer.jl in @nvim-lspconfig environment" })

-- Update LanguageServer.jl and its recorded dependencies
vim.api.nvim_create_user_command("JuliaLspUpdate", function()
  run_julia_lsp_job(
    'using Pkg; Pkg.instantiate(); Pkg.update("LanguageServer"); using LanguageServer',
    "Updating LanguageServer.jl in @nvim-lspconfig environment...",
    "LanguageServer.jl updated successfully! Restart Neovim or reopen Julia files to use it.",
    "Failed to update LanguageServer.jl. Run: julia --project=@nvim-lspconfig --startup-file=no -e 'using Pkg; Pkg.instantiate(); Pkg.update(\"LanguageServer\")'"
  )
end, { desc = "Update LanguageServer.jl in @nvim-lspconfig environment" })

-- Command to update LanguageServer.jl to dev version
vim.api.nvim_create_user_command("JuliaLspUpdateDev", function()
  run_julia_lsp_job(
    'using Pkg; Pkg.rm("LanguageServer"); Pkg.add(PackageSpec(name="LanguageServer", url="https://github.com/julia-vscode/LanguageServer.jl", rev="master")); Pkg.instantiate(); using LanguageServer',
    "Updating LanguageServer.jl to dev version (master branch)...",
    "LanguageServer.jl updated to dev version! Restart Neovim and reopen Julia files.",
    "Failed to update LanguageServer.jl to dev version."
  )
end, { desc = "Update LanguageServer.jl to dev version (master branch)" })

-- Command to check Julia LSP status
vim.api.nvim_create_user_command('JuliaLspStatus', function()
  local clients = vim.lsp.get_clients({ name = 'julials' })
  if #clients == 0 then
    vim.notify("Julia LSP is not running. Open a Julia file to start it.", vim.log.levels.WARN)
    return
  end
  
  for _, client in ipairs(clients) do
    local buffers = vim.lsp.get_buffers_by_client_id(client.id)
    local status = client.is_stopped() and "stopped" or "running"
    vim.notify(string.format("Julia LSP: %s (ID: %d, %d buffers attached)", status, client.id, #buffers), vim.log.levels.INFO)
    
    -- Check capabilities
    local caps = client.server_capabilities
    vim.notify(string.format("Hover support: %s", caps.hoverProvider and "YES" or "NO"), vim.log.levels.INFO)
    
    -- Check if attached to current buffer
    local attached = false
    for _, buf in ipairs(buffers) do
      if buf == vim.api.nvim_get_current_buf() then
        attached = true
        break
      end
    end
    
    if attached then
      vim.notify("✓ Julia LSP is attached to current buffer", vim.log.levels.INFO)
    else
      vim.notify("⚠ Julia LSP is running but NOT attached to current buffer", vim.log.levels.WARN)
    end
  end
end, { desc = "Check Julia LSP status" })

-- Command to test hover manually with detailed diagnostics
vim.api.nvim_create_user_command('JuliaLspHover', function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  
  if #clients == 0 then
    vim.notify("No LSP client attached to current buffer", vim.log.levels.ERROR)
    return
  end
  
  -- Check for julials specifically
  local julia_client = nil
  for _, client in ipairs(clients) do
    if client.name == 'julials' then
      julia_client = client
      break
    end
  end
  
  if not julia_client then
    vim.notify("Julia LSP not found in attached clients", vim.log.levels.ERROR)
    return
  end
  
  -- Check hover capability
  local caps = julia_client.server_capabilities
  vim.notify("Server capabilities: " .. vim.inspect(caps.hoverProvider), vim.log.levels.INFO)
  
  if not caps.hoverProvider then
    vim.notify("Julia LSP does not support hover", vim.log.levels.ERROR)
    return
  end
  
  -- Get current word under cursor
  local word = vim.fn.expand('<cword>')
  local pos = vim.api.nvim_win_get_cursor(0)
  
  vim.notify(string.format("Testing hover on: '%s' at line %d, col %d", word, pos[1], pos[2]), vim.log.levels.INFO)
  
  -- Check if server is ready
  if julia_client.is_stopped() then
    vim.notify("Julia LSP server is stopped", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Client ID: " .. julia_client.id .. ", offset_encoding: " .. julia_client.offset_encoding, vim.log.levels.INFO)
  
  -- Use vim.lsp.buf_request which is the proper way to make requests
  local params = vim.lsp.util.make_position_params(0, julia_client.offset_encoding)
  
  vim.notify("Sending hover request via vim.lsp.buf_request...", vim.log.levels.INFO)
  
  -- Set timeout to detect non-responsive server
  local timeout_timer = vim.defer_fn(function()
    vim.notify("❌ Hover request timed out after 10 seconds. The server may not be responding.", vim.log.levels.ERROR)
  end, 10000)
  
  vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(err, result, ctx, config)
    -- Cancel timeout
    if timeout_timer then
      timeout_timer:stop()
    end
    vim.notify("Hover callback called", vim.log.levels.INFO)
    if err then
      vim.notify("Hover request error: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    
    if not result or not result.contents then
      vim.notify("Hover returned no result or empty contents. Result: " .. vim.inspect(result), vim.log.levels.WARN)
      return
    end
    
    -- Parse and display hover content
    local contents = result.contents
    local lines = {}
    
    if type(contents) == "string" then
      lines = vim.split(contents, "\n")
    elseif type(contents) == "table" then
      if contents.value then
        lines = vim.split(contents.value, "\n")
      elseif contents[1] then
        if type(contents[1]) == "string" then
          lines = vim.split(contents[1], "\n")
        elseif contents[1].value then
          lines = vim.split(contents[1].value, "\n")
        end
      end
    end
    
    if #lines > 0 then
      vim.lsp.util.open_floating_preview(lines, "markdown", { border = "single" })
      vim.notify("Hover info displayed successfully!", vim.log.levels.INFO)
    else
      vim.notify("Hover returned empty content", vim.log.levels.WARN)
    end
  end)
  
  vim.notify("Hover request sent (waiting for response...)", vim.log.levels.INFO)
end, { desc = "Test Julia LSP hover manually" })

-- Autocommand to start julials when Julia files are opened
-- vim.lsp.enable() registers the config but doesn't auto-start, so we need this
vim.api.nvim_create_autocmd("FileType", {
  pattern = "julia",
  callback = function(args)
    -- Check if julials is already attached to this buffer
    local clients = vim.lsp.get_clients({ name = 'julials', bufnr = args.buf })
    if #clients > 0 then
      return -- Already attached, no need to start again
    end
    
    local bufname = vim.api.nvim_buf_get_name(args.buf)
    if bufname == "" then
      return -- Skip unnamed buffers
    end
    
    local util = require('lspconfig.util')
    local found_root = util.root_pattern('Project.toml', 'JuliaProject.toml', '.git')(bufname)
    local root_dir = found_root or vim.fn.fnamemodify(bufname, ':p:h')
    local project_env = "@nvim-lspconfig"
    
    -- Notify user that LSP is starting (Julia LSP can take 15-20 seconds to initialize)
    vim.notify("Starting Julia LSP... This may take 15-20 seconds to initialize.", vim.log.levels.INFO)
    
    vim.lsp.start({
      name = 'julials',
      cmd = build_julia_lsp_cmd(project_env, root_dir),
      root_dir = root_dir,
      on_attach = on_attach,
      capabilities = _G.enhanced_lsp_capabilities or capabilities,
    })
  end,
})

-- Lua LSP setup (if not handled by Mason)
vim.lsp.config('lua_ls', {
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
				path = vim.split(package.path, ";"),
			},
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
				},
			},
		},
	},
})
vim.lsp.enable('lua_ls')

-- Additional language servers can be added here as needed
-- Mason will handle the installation, and this file can provide custom configuration

-- Example: Custom configuration for a specific server
-- vim.lsp.config('some_server', {
--     capabilities = capabilities,
--     on_attach = on_attach,
--     settings = {
--         -- Custom settings here
--     },
-- })
-- vim.lsp.enable('some_server')
