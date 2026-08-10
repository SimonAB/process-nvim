-- Core Neovim Configuration

local opt = vim.opt

-- ============================================================================
-- CORE EDITOR SETTINGS
-- ============================================================================

-- Line numbers
opt.number = true -- Show line numbers
opt.relativenumber = true -- Show relative line numbers
opt.signcolumn = "yes" -- Show sign column

-- Indentation
opt.tabstop = 4    -- Configure tabs
opt.shiftwidth = 4 -- Set indentation width
opt.expandtab = true -- Expand tabs to spaces
opt.smartindent = true -- Smart indentation

-- Search
opt.ignorecase = true -- Ignore case in search
opt.smartcase = true -- Smart case in search
opt.hlsearch = true -- Highlight search matches
opt.incsearch = true -- Incremental search

-- Visual
opt.cursorline = false -- Disable current line highlight
opt.wrap = true      -- Enable line wrapping
opt.linebreak = true -- Wrap at word boundaries
opt.scrolloff = 8 -- Scroll offset
opt.sidescrolloff = 8 -- Side scroll offset
-- Keep the cursor vertically centred near EOF (Neovim 0.13+).
opt.scrolloffpad = 1
opt.conceallevel = 2 -- Enable concealment for Obsidian.nvim and VimTex

-- Behavior
opt.mouse = "a" -- Enable mouse
opt.clipboard = "unnamedplus" -- Use system clipboard
opt.splitbelow = true -- Split below
opt.splitright = true -- Split right
opt.hidden = true -- Hide buffers instead of closing them
-- LSP goto (0.13+) follows 'switchbuf'; prefer an existing window/tab.
opt.switchbuf = "usetab,uselast"
-- Native completion UI only; blink.cmp drives most menus and ignores preselect.
opt.completeopt = "menu,menuone,noselect"

-- Performance
opt.updatetime = 250 -- Update time
opt.timeoutlen = 300 -- Timeout length

-- Files
opt.swapfile = false -- Disable swap file
opt.backup = false -- Disable backup file
opt.undofile = true -- Enable undo file
-- OS file watchers (0.13+) reload buffers in real time; no polling needed.
opt.autoread = true
-- Explicit lock path for vim.pack (default, but pin it for clarity across machines).
opt.packlockfile = vim.fn.stdpath("config") .. "/nvim-pack-lock.json"

-- Security
opt.modeline = false -- Disable modeline
opt.exrc = false -- Disable exrc file

-- Language and spell checking
-- Configure spell directories FIRST (before enabling spell checking)
local config_dir = vim.fn.stdpath('config')
-- Add private directory to runtimepath so Neovim can find base spell files
vim.opt.runtimepath:prepend(config_dir .. '/private')
opt.spellfile = config_dir .. '/private/spell/en.utf-8.add' -- Default to English, switches with language
-- NOW enable spell checking after paths are configured
opt.spelllang = "en_gb" -- Set British English spelling
opt.spell = true -- Enable spell checking by default

-- Terminal colours (enables true colour support)
opt.termguicolors = true

-- Enable mouse move events for bufferline hover functionality
opt.mousemoveevent = true

-- Font configuration
opt.guifont = "LigaSFMonoNerdFont-Regular:h10" -- Set font

-- ============================================================================
-- GLOBAL VARIABLES
-- ============================================================================

-- Configuration file paths for hot-reloading
local config_dir = vim.fn.stdpath('config')
local config_files = {
  init = config_dir .. '/init.lua',
  plugins = config_dir .. '/lua/require.lua',
  keymaps = config_dir .. '/lua/keymaps.lua',
  custom = config_dir .. '/lua/config.lua',
}

-- Expose config files globally for keymaps module
_G.nvim_config_files = config_files

-- Enable filetype detection
vim.cmd("filetype plugin indent on")

-- VimTeX core settings live in lua/plugins/vimtex.lua.
-- Keep this file focused on editor-global behaviour only.

-- Per-instance RPC server for VimTeX inverse search (Skim/Zathura → VimtexInverseSearch).
do
	if vim.v.servername == "" then
		pcall(vim.fn.serverstart)
	end
end

-- Ensure VimTeX uses the correct local leader (must match init.lua setting)
vim.g.vimtex_mappings_enabled = 0 -- Disable VimTeX default mappings (we define our own in keymaps.lua)
vim.g.vimtex_imaps_enabled = 1    -- Enable insert mode mappings

-- Note: VimTeX spell configuration moved to lua/plugins/vimtex.lua
-- to ensure proper initialization timing

-- Markdown preview configuration (handled in plugins/markdown-preview-nvim.lua)

-- Create user command for manual VimTeX initialisation
vim.api.nvim_create_user_command('InitVimTeX', function()
  vim.cmd("runtime! autoload/vimtex.vim")
  if vim.fn.exists('*vimtex#init') == 1 then
    vim.fn['vimtex#init']()
    print("VimTeX initialised manually")
  else
    print("VimTeX initialisation failed - autoload not found")
  end
end, { desc = "Manually initialise VimTeX" })

-- Automatically initialise VimTeX for TeX buffers
-- This runs only when opening TeX files and skips if VimTeX already initialised
local vimtex_auto_group = vim.api.nvim_create_augroup('VimTeXAutoInit', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = vimtex_auto_group,
  pattern = 'tex',
  desc = 'Automatically initialise VimTeX on TeX buffers and ensure spell configuration',
  callback = function()
    -- Ensure spell configuration is applied (defensive programming)
    vim.g.vimtex_syntax_custom_cmds = vim.g.vimtex_syntax_custom_cmds or {
      { name = 'cite', argspell = false },
      { name = 'supercite', argspell = false },
      { name = 'citep', argspell = false },
      { name = 'citet', argspell = false },
      { name = 'citealp', argspell = false },
      { name = 'citealt', argspell = false },
      { name = 'citeauthor', argspell = false },
      { name = 'citeyear', argspell = false },
      { name = 'parencite', argspell = false },
      { name = 'footcite', argspell = false },
      { name = 'textcite', argspell = false },
      { name = 'autocite', argspell = false },
    }

    -- If VimTeX has not attached a buffer-local state yet, trigger initialisation
    if vim.b.vimtex == nil then
      vim.defer_fn(function()
        pcall(vim.cmd, 'InitVimTeX')
      end, 50)
    end
  end,
})

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================

local augroup = vim.api.nvim_create_augroup("Config", { clear = true })

---Reload buffers whose files changed on disk (`autoread` + `:checktime`).
---@param force_redraw boolean|nil Force screen refresh after check (e.g. on focus restore)
local function check_files_changed_on_disk(force_redraw)
	if vim.fn.getcmdwintype() ~= "" then
		return
	end
	vim.cmd("checktime")
	if force_redraw then
		vim.cmd("redraw")
	end
end

-- Optimised autocmd patterns for better performance
local function create_optimised_autocmds()
  -- `g:_nvim_os_window_focused`: Lualine `cond` for noisy segments; needs tmux `focus-events on`.
  vim.g._nvim_os_window_focused = vim.g._nvim_os_window_focused or 1

  local guicursor_saved_os_focus = nil
  ---Saved while the OS window is unfocused so we can restore bufferline hover (`mousemoveevent`).
  local mousemove_saved_os_focus = nil
  ---Saved while unfocused; `lazyredraw` coalesces screen updates during background churn.
  local lazyredraw_saved_os_focus = nil

  -- Neovim 0.13+ 'autoread' uses OS file watchers. Keep FocusGained `:checktime`
  -- as a cheap safety net after resume; do not poll on a timer.

  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = augroup,
    desc = "Notify when a buffer was reloaded from disk",
    callback = function()
      vim.notify("Reloaded file changed on disk", vim.log.levels.INFO)
    end,
  })

  vim.api.nvim_create_autocmd("FocusLost", {
    group = augroup,
    desc = "Unfocused: trim Lualine segments, pause GUI cursor blink (idempotent for focus spam)",
    callback = function()
      -- Ghostty / some hosts can emit repeated FocusLost; avoid tearing Lualine down repeatedly.
      if vim.g._nvim_os_window_focused == 0 then
        return
      end
      vim.g._nvim_os_window_focused = 0
      -- `mousemoveevent` drives bufferline’s `<MouseMove>` hover path; the terminal can keep
      -- delivering moves while the window looks unfocused, which retriggers tabline redraws and
      -- makes the block cursor appear to strobe in transparent terminals.
      if mousemove_saved_os_focus == nil then
        mousemove_saved_os_focus = vim.o.mousemoveevent
      end
      vim.o.mousemoveevent = false
      if lazyredraw_saved_os_focus == nil then
        lazyredraw_saved_os_focus = vim.o.lazyredraw
      end
      vim.o.lazyredraw = true
      if guicursor_saved_os_focus == nil then
        guicursor_saved_os_focus = vim.o.guicursor
      end
      if not vim.o.guicursor:find("blinkon0", 1, true) then
        vim.cmd("set guicursor+=a:blinkon0")
      end
      -- Drop any in-flight bufferline hover state so the tabline does not keep refreshing.
      pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "BufferLineHoverOut", data = {} })
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    desc = "Focused: restore cursor blink and Lualine segments (idempotent for focus spam)",
    callback = function()
      if vim.g._nvim_os_window_focused == 1 then
        return
      end
      vim.g._nvim_os_window_focused = 1
      if lazyredraw_saved_os_focus ~= nil then
        vim.o.lazyredraw = lazyredraw_saved_os_focus
        lazyredraw_saved_os_focus = nil
      end
      if mousemove_saved_os_focus ~= nil then
        vim.o.mousemoveevent = mousemove_saved_os_focus
        mousemove_saved_os_focus = nil
      end
      if guicursor_saved_os_focus ~= nil then
        vim.o.guicursor = guicursor_saved_os_focus
        guicursor_saved_os_focus = nil
      end
      -- After lazyredraw is restored so reloaded buffer content is visible immediately.
      check_files_changed_on_disk(true)
      vim.schedule(function()
        pcall(function()
          local ok_tm, theme_manager = pcall(require, "core.theme-manager")
          if ok_tm and theme_manager then
            -- Re-sync cursor hl and per-window blends after skipping them while unfocused.
            theme_manager.apply_flexoki_cursor_highlights({ force = true })
            theme_manager.apply_global_opacity()
            theme_manager.apply_cursorline_suppression()
          end
        end)
        pcall(function()
          require("lualine").refresh({
            force = true,
            place = { "statusline" },
          })
        end)
      end)
    end,
  })

  -- Highlight yanked text (vim.hl.hl_op replaces deprecated vim.hl.on_yank).
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = augroup,
    desc = "Briefly highlight yanked region",
    callback = function()
      pcall(vim.hl.hl_op, { timeout = 200 })
    end,
  })

  -- Remove trailing whitespace and enforce single newline at EOF on save
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    pattern = "*",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      
      -- Skip if buffer is not modifiable
      if not vim.bo[bufnr].modifiable then
        return
      end
      
      -- Preserve window view and cursor position while we normalise whitespace.
      local view = vim.fn.winsaveview()

      -- Remove trailing whitespace (existing functionality)
      local has_trailing = vim.fn.search('\\s\\+$', 'n') > 0
      if has_trailing then
        vim.cmd([[%s/\s\+$//e]])
      end

      -- Collapse multiple consecutive empty lines into single empty lines
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local collapsed_lines = {}
      local prev_line_empty = false

      for _, line in ipairs(lines) do
        local is_empty = line:match("^%s*$") ~= nil
        if not (is_empty and prev_line_empty) then
          collapsed_lines[#collapsed_lines + 1] = line
        end
        prev_line_empty = is_empty
      end

      -- Only update buffer if changes were made
      if #collapsed_lines ~= #lines then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, collapsed_lines)
      end

      -- Enforce exactly one newline at end of file
      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      if #lines > 0 then
        local non_empty_lines = {}

        -- Find the last non-empty line
        for i = #lines, 1, -1 do
          if lines[i]:match("%S") then -- line contains non-whitespace
            non_empty_lines = { unpack(lines, 1, i) }
            break
          end
        end

        -- Ensure exactly one empty line at the end
        if #non_empty_lines > 0 then
          non_empty_lines[#non_empty_lines + 1] = "" -- Add exactly one empty line
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, non_empty_lines)
        end
      end

      -- Restore original view and cursor to avoid any scroll jumps on save.
      vim.fn.winrestview(view)
    end,
  })

  -- Ensure one empty line before and after lists in markdown files
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup,
    pattern = { "*.md", "*.Rmd", "*.qmd" },
    desc = "Ensure empty lines before and after lists in markdown files",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      
      -- Skip if buffer is not modifiable
      if not vim.bo[bufnr].modifiable then
        return
      end
      
      local view = vim.fn.winsaveview()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      
      if #lines == 0 then
        return
      end

      -- Patterns for detecting list items (matches autolist patterns)
      local list_patterns = {
        unordered = "^%s*[-+*]%s+",  -- - + *
        ordered = "^%s*%d+[.)]%s+",   -- 1. 2. 3. or 1) 2) 3)
        ascii = "^%s*%a[.)]%s+",      -- a) b) c)
        roman = "^%s*%u+[.)]%s+",     -- I. II. III.
      }

      -- Function to check if a line is a list item
      local function is_list_item(line)
        if not line or line:match("^%s*$") then
          return false
        end
        for _, pattern in pairs(list_patterns) do
          if line:match(pattern) then
            return true
          end
        end
        return false
      end

      -- Function to check if a line is empty (or only whitespace)
      local function is_empty(line)
        return not line or line:match("^%s*$") ~= nil
      end

      -- Function to get the indentation level of a list item
      local function get_list_indent(line)
        local indent = line:match("^(%s*)")
        return #indent
      end

      -- Function to check if a line is a continuation of a list item
      -- (indented content that's part of the list item)
      local function is_list_continuation(line, list_indent)
        if is_empty(line) then
          return true -- Empty lines can be part of list items
        end
        local line_indent = line:match("^(%s*)")
        return #line_indent > list_indent
      end

      -- Function to check if a line contains math block delimiters
      local function has_math_delimiters(line)
        if not line then
          return false
        end
        -- Check for display math blocks ($$)
        return line:match("%$%$") ~= nil
      end

      -- Function to track math block state
      -- Returns new state: true if inside math block, false otherwise
      local function update_math_block_state(line, currently_inside)
        if not line then
          return currently_inside
        end
        -- Count $$ delimiters (display math blocks)
        local dollar_count = 0
        for _ in line:gmatch("%$%$") do
          dollar_count = dollar_count + 1
        end
        -- If we have an odd number of $$, we're toggling the state
        if dollar_count % 2 == 1 then
          return not currently_inside
        end
        return currently_inside
      end

      -- Find all list blocks and track where to insert empty lines
      local modifications = {}
      local i = 1
      local line_count = #lines

      while i <= line_count do
        local line = lines[i]
        
        if is_list_item(line) then
          -- Found the start of a list block
          local list_start = i
          local list_end = i
          local list_indent = get_list_indent(line)
          local in_math_block = false
          
          -- Find the end of this list block
          -- Continue through list items, continuations, and math blocks
          while list_end < line_count do
            local next_line = lines[list_end + 1]
            
            -- Update math block state
            in_math_block = update_math_block_state(next_line, in_math_block)
            
            -- If we're inside a math block or the line contains math delimiters, continue
            -- (math delimiters are part of the list item content)
            if in_math_block or has_math_delimiters(next_line) then
              list_end = list_end + 1
            elseif is_list_item(next_line) then
              -- Another list item at the same or less indentation level
              local next_indent = get_list_indent(next_line)
              if next_indent <= list_indent then
                list_end = list_end + 1
                list_indent = next_indent -- Update for nested lists
              else
                -- More indented list item - continuation of current item
                list_end = list_end + 1
              end
            elseif is_list_continuation(next_line, list_indent) then
              -- Continuation line (indented content or empty line)
              list_end = list_end + 1
            else
              -- Truly separate content - end the list block
              break
            end
          end
          
          -- Skip trailing empty lines at the end of the list block
          while list_end > list_start and is_empty(lines[list_end]) and not in_math_block do
            list_end = list_end - 1
          end
          
          -- Check if we need an empty line before the list
          if list_start > 1 then
            local prev_line = lines[list_start - 1]
            if not is_empty(prev_line) then
              table.insert(modifications, { pos = list_start, type = "before" })
            end
          end
          
          -- Check if we need an empty line after the list
          if list_end < line_count then
            local next_line = lines[list_end + 1]
            if not is_empty(next_line) then
              table.insert(modifications, { pos = list_end + 1, type = "after" })
            end
          end
          
          i = list_end + 1
        else
          i = i + 1
        end
      end

      -- Apply modifications in reverse order to maintain correct line numbers
      if #modifications > 0 then
        table.sort(modifications, function(a, b)
          return a.pos > b.pos
        end)
        
        for _, mod in ipairs(modifications) do
          if mod.type == "before" then
            vim.api.nvim_buf_set_lines(bufnr, mod.pos - 1, mod.pos - 1, false, { "" })
          elseif mod.type == "after" then
            vim.api.nvim_buf_set_lines(bufnr, mod.pos, mod.pos, false, { "" })
          end
        end
      end

      vim.fn.winrestview(view)
    end,
  })

  -- Auto-save on focus loss/exit
  vim.api.nvim_create_autocmd({ "FocusLost", "VimLeavePre" }, {
    group = augroup,
    desc = "Auto-save on focus loss or exit",
    callback = function()
      pcall(function() vim.cmd("silent! wa") end)
    end,
  })

  -- Restore cursor position
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup,
    callback = function()
      local pos = vim.fn.line("'\"")
      if pos > 1 and pos <= vim.fn.line("$") then
        vim.api.nvim_win_set_cursor(0, { pos, 0 })
      end
    end,
  })

  -- File-specific settings with lookup table for better performance
  local file_settings = {
    ["*.json"] = function() vim.cmd("setlocal wrap") end,
    ["*.jsonc"] = function() vim.cmd("setlocal wrap") end,
    ["*.md"] = function() vim.cmd("setlocal wrap") end,
  }

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    pattern = vim.tbl_keys(file_settings),
    desc = "File-specific settings",
    callback = function(args)
      local setting = file_settings[args.match]
      if setting then
        setting()
      end
    end,
  })

  -- File type specific settings with improved performance
  local filetype_settings = {
    -- 2-space indentation
    ["html,css,javascript,typescript,json,yaml"] = function()
      opt.tabstop = 2
      opt.shiftwidth = 2
    end,
    -- Zsh syntax highlighting
    ["zsh"] = function()
      pcall(function()
        require("nvim-treesitter.highlight").attach(0, "bash")
      end)
    end,
  }

  for pattern, config in pairs(filetype_settings) do
    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      pattern = pattern,
      callback = config,
    })
  end
end

-- Create optimised autocmds
create_optimised_autocmds()

-- Setup syntax matching for wiki links and bare URLs in markdown files
-- Note: Standard markdown links [text](url) are already handled by built-in syntax
local function setup_markdown_link_syntax()
  local markdown_group = vim.api.nvim_create_augroup("MarkdownLinks", { clear = true })
  
  vim.api.nvim_create_autocmd("FileType", {
    group = markdown_group,
    pattern = { "markdown", "pandoc", "quarto" },
    callback = function()
      -- Create syntax match for wiki links [[...]] (Obsidian-style)
      -- Exclude from code blocks and inline code to avoid false matches
      vim.cmd('syntax match markdownWikiLink /\\[\\[[^\\]]\\+\\]\\]/ containedin=ALLBUT,markdownCodeBlock,markdownCodeDelimiter,markdownInlineCode')
      vim.cmd('highlight link markdownWikiLink markdownWikiLink')
      
      -- Create syntax match for bare URLs (http://, https://, www.)
      -- Only if not already matched by existing markdown syntax
      -- Exclude from code blocks and inline code
      vim.cmd('syntax match markdownBareUrl /https\\?:\\/\\/[^\\s<>"{}|\\\\^`\\[\\]]\\+/ containedin=ALLBUT,markdownCodeBlock,markdownCodeDelimiter,markdownInlineCode,markdownLinkText,markdownUrl')
      vim.cmd('syntax match markdownBareUrl /www\\.[^\\s<>"{}|\\\\^`\\[\\]]\\+/ containedin=ALLBUT,markdownCodeBlock,markdownCodeDelimiter,markdownInlineCode,markdownLinkText,markdownUrl')
      vim.cmd('highlight link markdownBareUrl markdownUrl')
    end,
  })
end

setup_markdown_link_syntax()
