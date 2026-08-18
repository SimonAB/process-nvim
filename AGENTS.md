# AGENTS.md - Configuration Maintenance Rules

This document defines the conventions, patterns, and rules for maintaining this Neovim configuration. All AI agents and contributors must follow these guidelines when modifying the codebase.

## Table of Contents

1. [Code Style & Formatting](#code-style--formatting)
2. [File Structure & Organisation](#file-structure--organisation)
3. [Plugin Configuration Patterns](#plugin-configuration-patterns)
4. [Error Handling](#error-handling)
5. [Documentation Standards](#documentation-standards)
6. [Naming Conventions](#naming-conventions)
7. [Performance Guidelines](#performance-guidelines)
8. [Keymap Conventions](#keymap-conventions)
9. [Autocmd Patterns](#autocmd-patterns)
10. [Testing & Validation](#testing--validation)

---

## Code Style & Formatting

### Indentation
- **Use tabs for indentation** (not spaces)
- **One tab = one level of indentation**
- **No mixing of tabs and spaces**

### Line Length
- **Prefer lines under 100 characters** when possible
- **Break long lines at logical points** (after commas, operators, etc.)
- **Use string concatenation** for very long strings rather than single-line strings

### Spacing
- **Single space after commas** in function arguments and table definitions
- **No trailing whitespace**
- **Blank lines between logical sections** (functions, table definitions, etc.)
- **Two blank lines between major sections** (e.g., between different plugin configurations)

### Comments
- **Use `--` for single-line comments**
- **Use `---` for documentation comments** (LuaDoc style)
- **Place comments above the code they describe**, not inline
- **Use descriptive comments** that explain "why" not just "what"
- **Section headers use `-- =============================================================================`** with descriptive text

### Example:
```lua
-- Configuration for plugin-name
-- Brief description of what this plugin does

local ok, plugin = pcall(require, "plugin-name")
if not ok then
	vim.notify("plugin-name not found", vim.log.levels.WARN)
	return
end

-- Configure plugin with specific options
plugin.setup({
	option1 = value1,
	option2 = value2,
})
```

---

## File Structure & Organisation

### Directory Structure
```
nvim/
├── init.lua                 # Entry point, minimal setup
├── lua/
│   ├── config.lua           # Core editor settings
│   ├── keymaps.lua          # Loads keymaps-core + keymaps-plugins
│   ├── keymaps-core.lua     # Plugin-independent keymaps
│   ├── keymaps-plugins.lua  # Plugin keymaps (deferred)
│   ├── plugins.lua          # vim.pack definitions and PackChanged hooks
│   ├── core/                # Core functionality modules
│   │   ├── plugin-loader.lua
│   │   ├── plugin-manager.lua
│   │   ├── plugin-reload.lua
│   │   ├── theme-manager.lua
│   │   ├── theme-picker.lua
│   │   └── typst-project.lua
│   └── plugins/             # Individual plugin configurations
│       ├── plugin-name.lua
│       └── ...
├── docs/                    # VitePress documentation
└── scripts/                 # Utility scripts (see scripts/README.md)
```

### File Naming
- **Use kebab-case for file names**: `plugin-name.lua`, `theme-manager.lua`
- **Match module name to file name**: `lua/plugins/telescope.lua` → `require("plugins.telescope")`
- **Core modules in `lua/core/`**: `lua/core/theme-manager.lua` → `require("core.theme-manager")`

### File Headers
Every configuration file should start with:
```lua
-- Configuration for plugin-name
-- Brief description of purpose and functionality
```

Core modules should use:
```lua
-- =============================================================================
-- MODULE NAME
-- PURPOSE: Brief description of module purpose
-- =============================================================================
```

---

## Plugin Configuration Patterns

### Standard Plugin Setup Pattern

**Always use this pattern for plugin configurations:**

**Target environment and package manager:**
- **Neovim 0.13-dev (Homebrew HEAD) is recommended** for this configuration; **0.12+ is the minimum** for `vim.pack`.
- **Use the built-in `vim.pack` package manager only** (no `lazy.nvim`, `packer.nvim`, etc.).
- **Do not introduce alternative plugin managers**; extend the existing `vim.pack` and `plugin-loader.lua` mechanisms instead.
	- On macOS, install with `brew install neovim --HEAD` to get 0.13-dev features (OS-watcher `'autoread'`, `dir.lua`, `vim.ui.img`, `:restart` / `:detach!`). Revisit the stable bottle once Homebrew ships 0.13+.

```lua
-- Configuration for plugin-name
-- Brief description

local ok, plugin = pcall(require, "plugin-name")
if not ok then
	vim.notify("plugin-name not found", vim.log.levels.WARN)
	return
end

plugin.setup({
	-- Configuration options
})
```

### Error Handling
- **Always use `pcall(require, ...)`** to safely load plugins
- **Check `ok` before proceeding** with plugin setup
- **Use `vim.notify()` with appropriate log levels**:
  - `vim.log.levels.ERROR` - Critical failures
  - `vim.log.levels.WARN` - Missing plugins, non-critical issues
  - `vim.log.levels.INFO` - Informational messages
  - `vim.log.levels.DEBUG` - Debug information

### Plugin Loading Phases
Plugins are loaded in three phases (defined in `lua/core/plugin-loader.lua`):

1. **IMMEDIATE (0ms)**: Core essentials (LSP, completion, syntax)
2. **DEFERRED (100ms)**: UI and functionality (telescope, file tree, statusline)
3. **LAZY (500ms)**: Non-essentials (which-key, themes)

**When adding new plugins:**
- Add to appropriate phase in `plugin-loader.lua`
- Consider performance impact
- Essential functionality → immediate
- UI enhancements → deferred
- Optional features → lazy

### Plugin Registration
- **Add plugin to `lua/plugins.lua`** in the `essential_plugins` table
- **Format**: `{ url = "https://github.com/user/repo", name = "repo-name" }`
- **Include build commands** if needed: `build = "make"` or `build = "cargo build --release"`
- **Add configuration file** in `lua/plugins/plugin-name.lua`

---

## Error Handling

### Safe Require Pattern
**Always use this pattern:**
```lua
local ok, module = pcall(require, "module-name")
if not ok then
	vim.notify("module-name not found", vim.log.levels.WARN)
	return
end
```

### Safe Function Calls
**For functions that might fail:**
```lua
local success, result = pcall(function()
	-- Potentially failing code
end)
if not success then
	vim.notify("Operation failed: " .. tostring(result), vim.log.levels.ERROR)
	return
end
```

### Safe Command Execution
**For Vim commands:**
```lua
pcall(vim.cmd, "CommandName")
-- Or with error handling:
local success = pcall(vim.cmd, "CommandName")
if not success then
	vim.notify("Command failed", vim.log.levels.WARN)
end
```

### Buffer/Window Validation
**Always validate buffers and windows before operations:**
```lua
local bufnr = vim.api.nvim_get_current_buf()
if not vim.api.nvim_buf_is_valid(bufnr) then
	return
end

local win = vim.api.nvim_get_current_win()
if not vim.api.nvim_win_is_valid(win) then
	return
end
```

---

## Documentation Standards

### Function Documentation
**Use LuaDoc-style comments for functions:**
```lua
---Brief description of function purpose.
---@param param1 type Description of param1
---@param param2 type Description of param2
---@return type Description of return value
local function example_function(param1, param2)
	-- Implementation
end
```

### Module Documentation
**At the top of core modules:**
```lua
-- =============================================================================
-- MODULE NAME
-- PURPOSE: Detailed description of module purpose
-- =============================================================================
```

### Inline Comments
- **Explain "why" not "what"** - code should be self-documenting
- **Use comments for non-obvious logic** or workarounds
- **Document assumptions** and constraints
- **Note platform-specific behaviour** (macOS vs Linux)

### Example:
```lua
-- On macOS, the window manager automatically applies blur to transparent windows.
-- This requires winblend to be set appropriately.
vim.o.winblend = blend
```

---

## Naming Conventions

### Variables
- **Use `snake_case`** for variable names: `plugin_name`, `current_theme`
- **Use descriptive names**: `bufnr` not `b`, `current_window` not `w`
- **Prefix boolean variables** with `is_`, `has_`, `should_`: `is_valid`, `has_content`
- **Use `local`** for all variables unless they need to be global

### Functions
- **Use `snake_case`** for function names: `setup_plugin`, `get_theme_name`
- **Use verb-noun pattern**: `load_plugins`, `apply_theme`, `toggle_terminal`
- **Prefix helper functions** with module name if needed: `ThemeManager.apply_theme()`

### Constants
- **Use `UPPER_SNAKE_CASE`** for constants: `DEFAULT_THEME`, `MAX_RETRIES`
- **Define at module level** or in a dedicated constants section

### Global Variables
- **Minimise global variables**
- **Prefix with `_G.`** if necessary: `_G.nvim_config_files`
- **Document why it's global** in comments

### Module Names
- **Match file names**: `theme-manager.lua` → `ThemeManager`
- **Use PascalCase** for module tables: `ThemeManager`, `PluginLoader`

---

## Performance Guidelines

### Deferred Loading
**Use `vim.defer_fn()` for non-critical initialisation:**
```lua
vim.defer_fn(function()
	require("plugins.non-critical-plugin")
end, 100) -- Delay in milliseconds
```

### Lazy Loading
**Load plugins on-demand when possible:**
```lua
-- In keymap:
map("n", "<leader>X", function()
	local ok, plugin = pcall(require, "plugin-name")
	if ok then
		plugin.action()
	end
end, { desc = "Action" })
```

### Caching
**Cache expensive operations:**
```lua
local cache = {}
local function expensive_operation(input)
	if cache[input] then
		return cache[input]
	end
	local result = -- expensive computation
	cache[input] = result
	return result
end
```

### Optimised Autocmds
**Use lookup tables and single autocmds:**
```lua
-- Good: Single autocmd with lookup table
local filetype_configs = {
	tex = function() vim.g.vimtex_enabled = 1 end,
	python = function() -- setup
	end,
}
vim.api.nvim_create_autocmd("FileType", {
	pattern = vim.tbl_keys(filetype_configs),
	callback = function(args)
		local config = filetype_configs[args.match]
		if config then config() end
	end,
})

-- Bad: Multiple autocmds for similar patterns
vim.api.nvim_create_autocmd("FileType", { pattern = "tex", ... })
vim.api.nvim_create_autocmd("FileType", { pattern = "python", ... })
```

### Minimise API Calls
**Batch operations when possible:**
```lua
-- Good: Single call
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

-- Bad: Multiple calls
for i, line in ipairs(lines) do
	vim.api.nvim_buf_set_lines(bufnr, i-1, i, false, {line})
end
```

---

## Keymap Conventions

### Keymap Structure
**Use this pattern for all keymaps:**
```lua
local map = vim.keymap.set

map("n", "<leader>X", function()
	-- Action
end, { desc = "Description" })
```

### Keymap Groups
**Organise keymaps by functionality with consistent prefixes:**

**Group prefix rule:**
- **Group keys (the first letter after `<leader>`) must always be uppercase** (e.g. `<leader>B`, `<leader>Q`, `<leader>T`).
- **Sub-keys within a group may be lower-case or mixed**, but the group designator itself is always a capital letter.

| Prefix | Group | Example |
|--------|-------|---------|
| `<leader>B` | Buffer operations | `<leader>Bn` = Next buffer |
| `<leader>C` | Configuration | `<leader>Cs` = Reload configuration; `<leader>Cr` = `:restart`; `<leader>Cd` = `:detach!` |
| `<leader>F` | Forge (kanban / projects) | `<leader>Fs` = Status |
| `<leader>R` | Frecency (recent files) | `<leader>Rf` = Find files (frecency) |
| `<leader>G` | Git operations | `<leader>Gs` = Git status |
| `<leader>J` | Julia operations | `<leader>Jrh` = Julia REPL horizontal |
| `<leader>K` | Markdown / images | `<leader>Kp` = Preview; `<leader>Ki` = refresh cursor media popup; `<leader>Ko` = open attachment |
| `<leader>L` | LSP operations | `<leader>Ll` = List servers |
| `<leader>M` | Mason operations | `<leader>Mm` = Open Mason |
| `<leader>O` | Obsidian operations | `<leader>On` = New note |
| `<leader>O!` | Obsidian callouts | `<leader>O!n` = Note callout |
| `<leader>CU` | Plugin updates (vim.pack) | `<leader>CUa` = Update all |
| `<leader>Q` | Quarto operations | `<leader>Qp` = Preview |
| `<leader>S` | Search operations | `<leader>Sp` = Search in project |
| `<leader>T` | Terminal operations | `<leader>Tt` = Toggle terminal |
| `<leader>W` | Window operations | `<leader>Wh` = Decrease width |
| `<leader>X` | Diagnostics (Trouble) | `<leader>Xw` = Workspace diagnostics |
| `<leader>A` | AI (CodeCompanion) | `<leader>Ac` = Chat |
| `<leader>Y` | Toggle options | `<leader>Yw` = Toggle wrap |
| `<localleader>l` | LaTeX (VimTeX) | `<localleader>ll` = Compile |
| `<localleader>t` | Typst | `<localleader>tp` = Preview toggle, `tc` = `typst c`, `tw` = `typst w` |

### Keymap Descriptions
- **Always include `desc`** for which-key integration
- **Use clear, concise descriptions**: "Toggle terminal" not "toggles terminal"
- **Use consistent terminology**: "Toggle" not "Switch" or "Enable/Disable"

### Helper Functions
**Create helper functions for complex keymap logic:**
```lua
local function safe_cmd(cmd, desc)
	return function()
		local success, err = pcall(vim.cmd, cmd)
		if not success then
			vim.notify("Command failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
		end
	end
end

map("n", "<leader>X", safe_cmd("CommandName", "Description"), { desc = "Description" })
```

---

## Autocmd Patterns

### Autocmd Groups
**Always use named groups:**
```lua
local augroup = vim.api.nvim_create_augroup("GroupName", { clear = true })

vim.api.nvim_create_autocmd("EventName", {
	group = augroup,
	pattern = "pattern",
	callback = function()
		-- Handler
	end,
})
```

### Pattern Organisation
**Use lookup tables for multiple patterns:**
```lua
local filetype_configs = {
	tex = function() vim.g.vimtex_enabled = 1 end,
	python = function() -- setup
	end,
}

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = vim.tbl_keys(filetype_configs),
	callback = function(args)
		local config = filetype_configs[args.match]
		if config then config() end
	end,
})
```

### Buffer Validation
**Always validate buffers in autocmds:**
```lua
vim.api.nvim_create_autocmd("BufWritePre", {
	group = augroup,
	pattern = "*",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		if not vim.bo[bufnr].modifiable then
			return
		end
		-- Process buffer
	end,
})
```

### View Preservation
**Preserve cursor position and view when modifying buffers:**
```lua
local view = vim.fn.winsaveview()
-- Modify buffer
vim.fn.winrestview(view)
```

---

## Testing & Validation

### Before Committing Changes

1. **Syntax Check**
   ```bash
   nvim --headless -c "lua require('config')" -c "qa"
   ```

2. **Load Test**
   - Open Neovim and verify no errors
   - Check `:messages` for warnings/errors
   - Verify keymaps work with `:which-key`

3. **Plugin Test**
   - Verify plugins load correctly
   - Test critical functionality
   - Check LSP servers start

4. **Performance Test**
   - Measure startup time: `nvim --startuptime /tmp/startup.log`
   - Compare before/after changes

### Validation Checklist

- [ ] All `pcall()` checks have proper error handling
- [ ] All keymaps have `desc` for which-key
- [ ] No hardcoded paths (use `vim.fn.stdpath()`)
- [ ] British spelling used throughout
- [ ] Comments explain "why" not "what"
- [ ] No trailing whitespace
- [ ] Consistent indentation (tabs)
- [ ] Functions are documented with LuaDoc comments
- [ ] Autocmds use named groups
- [ ] Buffer/window validation in autocmds

---

## British Spelling

**Always use British English spelling:**
- `colour` not `color`
- `optimise` not `optimize`
- `organise` not `organize`
- `initialise` not `initialize`
- `customisation` not `customization`
- `behaviour` not `behavior`
- `centre` not `center`

**Exception**: Use American spelling for:
- Technical terms that are standardised (e.g., "color" in CSS/HTML contexts)
- Plugin/API names that use American spelling
- Variable names that match external APIs

---

## Common Patterns

### Plugin Configuration Template
```lua
-- Configuration for plugin-name
-- Brief description

local ok, plugin = pcall(require, "plugin-name")
if not ok then
	vim.notify("plugin-name not found", vim.log.levels.WARN)
	return
end

plugin.setup({
	-- Options
})
```

### Helper Function Template
```lua
---Brief description of function.
---@param param type Description
---@return type Description
local function helper_function(param)
	-- Implementation
end
```

### Autocmd Template
```lua
local augroup = vim.api.nvim_create_augroup("GroupName", { clear = true })

vim.api.nvim_create_autocmd("EventName", {
	group = augroup,
	pattern = "pattern",
	desc = "Description",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		-- Validation
		-- Implementation
	end,
})
```

### Keymap Template
```lua
map("n", "<leader>X", function()
	-- Action
end, { desc = "Description" })
```

---

## Enforcement

### Pre-commit Checks
- Run syntax validation
- Check for common errors (missing `pcall`, missing `desc`, etc.)
- Verify British spelling in comments and strings

### Code Review
- Verify adherence to conventions
- Check error handling patterns
- Validate performance considerations
- Ensure documentation is complete

### Automated Tools
Consider adding:
- Lua linter (luacheck)
- Spell checker for British English
- Pre-commit hooks for validation

---

## Questions or Updates

If you encounter patterns not covered here or need clarification:
1. Check existing code for similar patterns
2. Follow the principle of consistency with existing codebase
3. Document new patterns in this file
4. Update this document when establishing new conventions

---

**Last Updated**: 2026-08-18
**Maintained By**: Configuration maintainers

---

## Learned User Preferences

- Prefer transparent which-key-style floats (body and border) with no buffer glyph bleed-through; strongly reject opaque float backgrounds.
- Keep floating UI consistent across which-key, Mason, Telescope (including grep preview), theme picker, plugin-update, floating terminal, and media/URL peeks; prefer shared helpers over one-off winhl tweaks.
- Theme appearance should track macOS light/dark (auto-dark-mode / Ghostty); avoid yellow-ish light themes; dark preference aligns with Catppuccin Mocha, light with high-contrast options (e.g. GitHub Light High Contrast / Flexoki Light).
- When reverting a brittle fix, retain unrelated speed and robustness improvements unless asked to discard them.
- Prefer screenshot-driven iteration for float transparency; do not “improve” a working transparent look into opacity.
- Finish feature work with docs/changelog updates when relevant; commit and push only when explicitly asked.
- Prefer cursor/popup media peeks over inline embeds so previews do not shift lines, flicker, or loop on refresh.
- Media/URL peeks: dismiss with Esc; open externally with Enter (avoid `o` / `Ctrl-o` clashes with Vim navigation); favour wide readable popups (≈70% window width, content-centred, height fits image; PDFs fit page width with multipage scroll).
- For website peeks, keep strong Open Graph images when they work; when OG/icons are missing, use a Microlink **landscape mobile** viewport screenshot (`isMobile` + `isLandscape`), not a cropped desktop thumbnail.
- Prefer a minimal lualine statusline: no LSP status; keep filetype and separate conditional indicators (macro recording, visual selection size with units and word count, search count, spell language); keep original `┃` / powerline separators — do not merge extras into one segment.
- Show spell language as flag emoji (🇬🇧 for `en_gb`, 🇫🇷 for `fr`), not EN/FR text.
- Disable native `showmode`, `showcmd`, and `shortmess` `S` so lualine owns mode, selection, and search display without duplicate echo below the bar.

## Learned Workspace Facts

- This repo is the nested Neovim config at `~/Documents/etc/dotfiles/config/nvim` (vim.pack; Neovim 0.12+ required, with 0.13-dev features such as multicursor/graphics under active adoption).
- Flexoki colourscheme is loaded from the fork `SimonAB/flexoki-neovim` (not stock kepano), including transparent editor/float options.
- CodeCompanion ACP is wired for Cursor and local Ollama; AI keymaps live under the `<leader>A` which-key group.
- Julia REPL workflow uses Iron / `<leader>J` (e.g. `<leader>Jrv`); OhMyREPL colours should follow the terminal; `# %%` cells are supported for sending code; watch for bracket auto-pair glitches when sending `[` lines to the REPL.
- LaTeX Skim inverse/forward search lives under `scripts/` (Ghostty-aware); inverse search should auto-raise the terminal and works with both Herdr and tmux.
- Floating-window styling is centralised via theme helpers (e.g. which-key float winhl) so popups stay aligned after theme switches.
- Dashboard shortcuts reserve letter movement (e.g. `lj`) and map `q` to quit (not merely close buffer).
- VitePress docs live under `docs/`; `.cursor/` and `.vscode/` are gitignored in this repo.
- Markdown/Obsidian media peeks use image.nvim plus `vim-ui-img` helpers (`<leader>Ki` / `Kx` / `Ko`): raster embeds, PDF pages via pdftoppm (cached ~24h), and HTTP(S) link peeks (OG image or page screenshot). `image.nvim` is a Kitty backend only; stock document integrations are disabled in `lua/plugins/image-nvim.lua` (themed cursor peek handles previews).
- Startup cache hygiene (`core.cache-hygiene`) prunes undofiles older than 90 days, truncates oversized LSP logs, and removes leftover `startup.log`; media caches live under `~/.cache/nvim/vim-ui-img/`.
- `BufWritePre` in `config.lua` enforces two empty lines at EOF on save.
- Custom lualine text must be `stl_escape`d so `%` is not parsed as a statusline format item; visual word count uses `vim.fn.wordcount().visual_words`, not `substitute(..., "gn")`.
