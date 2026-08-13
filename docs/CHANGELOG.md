# Changelog

## [Latest] - Neovim 0.13-dev adoption

### Runtime
- **Homebrew HEAD**: Config targets Neovim **0.13.0-dev** (`brew install neovim --HEAD`). Minimum remains 0.12+ for `vim.pack`.
- **`'autoread'`**: Removed the 500 ms `:checktime` poll; rely on OS file watchers with a FocusGained safety net.
- **`dir.lua` hybrid**: `:edit` on a directory uses the built-in browser; nvim-tree stays the `<leader>e` sidebar (`hijack_directories = false`).
- **Editor opts**: `'scrolloffpad'`, `'switchbuf'`, explicit `'packlockfile'`.
- **Session**: `<leader>Cr` / `<leader>CR` for `:restart` / `:restart!`; `<leader>Cd` for `:detach!`.
- **Media peeks (`image.nvim`)**: Cursor peeks for Markdown/Obsidian `![]()` / `![[]]` embeds (Kitty graphics). PDFs are converted to cached PNG pages (fit-to-width) with `]`/`[` paging. `<leader>Ki` refreshes; `<leader>Kx` clears; `<leader>Ko` opens externally.
- **Website peeks**: On `http(s)` / bare `www` lines, show title and description. Prefer Open Graph images when present; otherwise use a Microlink landscape-mobile screenshot (`844×600`). Esc dismisses; Enter opens the browser. Embed lines use the media peek.
- **Telescope ui-select**: Builtin pickers (`z=`, `:browse oldfiles`, …) go through Telescope.
- **Treesitter**: Ensure `diff` parser; document core visual `]N` / `[N` sibling selection.
- **Yank**: `vim.hl.hl_op` replaces deprecated `vim.hl.on_yank`.
- **Plugin status**: Surfaces pending `rev → rev_to` updates from richer `vim.pack.get()`.
- **Statusline (lualine)**: Dropped LSP status. Conditional right-side indicators: macro recording (`REC @a`), visual selection size with units and word count (`3 lines - 42 words`), search match count (`2/17 matches`), and spell-language flags (🇬🇧 / 🇫🇷). Native `showmode`, `showcmd`, and `shortmess` `S` keep those counts in the bar rather than echoing below it.
- **File formatting**: `BufWritePre` now enforces two empty lines at EOF on save.

---

## [Previous] - Forge kanban workflow refresh

### Forge (keymaps, commands, dashboard)
- **Forge positioning**: Reframed Forge as a **kanban/projects** workflow (Finder tags) rather than a GTD task manager.
- **Keymaps** (`<leader>F*`):
  - `<leader>Fs` now shows **Forge status** (replaces the old “next actions” emphasis).
  - Added **project operations**: move current project to a column (`<leader>Fm`), add/remove tags (`<leader>Fa` / `<leader>Fr`).
  - Added **read-only views**: calendar (`<leader>Ft`), tags for current project (`<leader>Fp`).
  - Telescope helpers: find Forge files (`<leader>Ff`), grep Forge files (`<leader>Fg`).
- **Commands**: Added `:ForgeStatus` and kept `:ForgeNext` as a backwards-compatible alias; added project/tag commands (`:ForgeMove`, `:ForgeProjectTags`, `:ForgeProjectTagAdd`, `:ForgeProjectTagRemove`) and `:ForgeCalendar`.
- **Dashboard**: Updated the mini.nvim dashboard Forge shortcuts to match the new command set.

### Theme/UI
- **Progress / plugin-update popup**: `core.progress-popup` buffers are flagged so global opacity autocmds still apply the shared which-key float chrome (`winblend` 0, `winhl` parity). Previously the update window could look blended next to Mason or which-key because `WinEnter` reapplied editor transparency.
- **Cursor line highlight**: Disabled `cursorline` by default for a calmer editing surface.
- **nvim-tree transparency**: Forced `NvimTree*` background groups to use `bg=none`, and reapply on `ColorScheme` so the file explorer matches the rest of the transparent UI.
- **VimTeX TOC help keys**: Restyled single-letter hints (e.g. `L` in `vimtex#toc#open()`) to use muted red text on a transparent background, avoiding theme-provided background blocks.
- **Flexoki defaults**: Switched theme defaults to `flexoki-dark` / `flexoki-light`, and now rely on the forked [`SimonAB/flexoki-neovim`](https://github.com/SimonAB/flexoki-neovim) for built-in transparency options. The plugin `light_variant` is set to `light` so it matches the fork’s palette keys.
- **macOS system theme / auto-dark-mode**: `ThemeManager.detect_system_theme()` treats empty `defaults read` output as **light** (avoids sticking on dark after a dark→light switch). **auto-dark-mode.nvim** passes `appearance` into `ThemeManager.load_immediate()` so the colourscheme follows the plugin callback without racing `defaults read`.

### Obsidian (callouts)
- **Keymaps** (`<leader>O!*`): insert a callout below the current line (normal mode) or wrap the visual line range (same leader sequence). Types include note, abstract, info, todo, tip, success, question, warning, failure, danger, bug, example, and quote.
- **Command**: `:ObsidianCalloutWrap <type>` with an explicit range when needed.
- **which-key**: `<leader>O!` grouped as “Callout”.

### Pack lock
- **nvim-pack-lock.json**: Refreshed revisions for blink.cmp, blink.lib, codecompanion.nvim, gitsigns.nvim, mini.nvim, nvim-lspconfig, and nvim-tree.lua.

### Julia REPL (code blocks)
- **`<C-c>` / `yic`**: VS Code–style `# %%` cell markers (`# %%`, `#%%`, optional spaces/title) for send and yank; detection order is fenced Quarto chunks, then `# %%` cells (when any marker exists in the buffer), then `##` sections for send only.

### Plugin updates and cache hygiene
- **`core.plugin-reload`**: Clears `package.loaded` prefixes after vim.pack updates; advises restart for plugins that cannot hot-reload cleanly (e.g. gitsigns, blink.cmp).
- **gitsigns**: `reload_gitsigns_if_stale()` for in-session recovery; `PackChanged` hook clears caches when the pack changes.
- **`plugins.lua`**: Single `PackChanged` autocmd runs build hooks and module-cache hygiene together.
- **`:PluginPruneLegacy`**: Removes duplicate trees under `pack/plugins/start/` when the same plugin exists under `site/pack/core/opt/`.

### AI (CodeCompanion)
- **Keymaps** (`<leader>A*`): chat, toggle, debug, and Ollama adapter shortcuts; which-key group “AI”.

### Documentation
- **Forge / Obsidian / Julia / AI**: **docs/reference/keymaps.md**, **AGENTS.md**, **docs/quickstart.md**, **docs/index.md** aligned with current maps.
- **Typst / vault / plugins**: monorepo `--root` notes, **Troubleshooting** vault daily-commit script, **`:PluginPruneLegacy`** in keymaps reference; **scripts/README.md** indexes utility scripts; removed tracked `*.backup` artefact.

---

## [Previous] - Documentation aligned with keymaps

### Documentation
- **README**, **docs/reference/keymaps.md**, **docs/index.md**: Frecency under `<leader>R*`; Forge under `<leader>F*`; Typst `<localleader>t*` (preview, sync, `typst c`, `typst w`); removed references to unbound “send to terminal” keys.
- **AGENTS.md**: Keymap group table updated (Forge, Frecency, Typst).
- **Troubleshooting**: `<leader>Ys` described as spell toggle (not theme/auto-dark).
- **scripts/generate-docs.lua**: Leader group summary brought in line with current which-key groups.

### Configuration
- **toggleterm.nvim**: Set `open_mapping` to `<C-t>` so behaviour matches documented quick toggle.
- **Popup UI parity**: Made update/progress popups, Mason UI, and other floats (diagnostics/LSP previews, gitsigns preview, plugin status) match the which-key popup border/highlight style for a more consistent look.

---

## [Previous] - Markdown List Formatting Fix

### 🐛 Bug Fixes
- **Markdown List Formatting**: Fixed issue where empty lines were incorrectly inserted between math blocks (`$$...$$`) and list items
  - Enhanced list block detection to recognise math blocks as part of list item content
  - Added support for continuation lines (indented content within list items)
  - Improved handling of display math blocks (`$$`) within markdown lists
  - Formatter now correctly preserves math blocks without adding unwanted empty lines

### 📝 Technical Details
- Updated `BufWritePre` autocmd in `lua/config.lua` to track math block state
- Added `has_math_delimiters()` function to detect lines containing `$$`
- Added `update_math_block_state()` function to track math block boundaries
- Enhanced list continuation detection to handle indented content properly

---

## [Previous] - Table Operations and Documentation Updates

### 📊 Markdown Table Operations
- **Table-nvim Integration**: Added comprehensive table editing keymaps under `<leader>Kt`
  - `<leader>Ktf` - Format/realign table
  - `<leader>Ktn/Ktp` - Navigate table cells
  - `<leader>Kto/KtO` - Insert row below/above
  - `<leader>KtJ/KtK` - Move row down/up
  - `<leader>Kti/KtI` - Insert column right/left
  - `<leader>KtL/KtH` - Move column right/left
  - `<leader>Ktdc` - Delete column
  - `<leader>Ktt/KtT` - Insert table (with/without outline)
- **Filetype Support**: Works in markdown, quarto, pandoc, and text files
- **Quarto Support**: Extended table-nvim functionality to `.qmd` files
- **Which-Key Integration**: Table operations registered under `<leader>Kt` group

### 🧘 Zen Mode for Markdown
- **Distraction-Free Writing**: Added `folke/zen-mode.nvim` with sensible defaults
- **Automatic Activation**: Zen Mode opens by default for all markdown buffers (Obsidian notes, research notes, etc.)
- **Keybinding**: `<leader>Yz` toggles Zen Mode on and off (documented in Quickstart and Keymaps Reference)
- **Cursor Behaviour**: Fixed cursor placement when Zen Mode auto-opens so the cursor appears correctly in the Zen window

### 📚 Documentation Updates
- **Keymaps Reference**: Added comprehensive table operations section
- **Quickstart Guide**: Added table operation examples and Zen Mode toggle keymap
- **Note**: Table operations live under `<leader>Kt…`. Markdown preview is `<leader>Kp` (start), `<leader>Ks` (stop), `<leader>Kv` (toggle).

---

## [Previous] - Which-Key Convention Enforcement

### 🔧 Keymap Refactoring
- **Convention Enforcement**: Strict adherence to lowercase/uppercase leader key pattern
  - Lowercase keys (e.g., `<leader>f`, `<leader>g`) execute immediately without delay
  - Uppercase keys (e.g., `<leader>F`, `<leader>G`) show which-key menus with sub-commands
- **Eliminated Delays**: Removed which-key wait time for frequently used commands
  - `<leader>f` (find files) now executes immediately
  - `<leader>g` (grep in project) now executes immediately

### ⌨️ Keymap Reorganisation
- **Frecency Commands**: Moved from `<leader>f*` to `<leader>F*` group
  - `<leader>Ff` → Find files (frecency)
  - `<leader>Fr` → Refresh frecency database
  - `<leader>Fd` → Show database location
  - `<leader>Fb` → Rebuild database
- **Search Commands**: Moved grep location variants from `<leader>g*` to `<leader>S*`
  - `<leader>Sp` → Search in project
  - `<leader>Sw` → Search in working directory
  - `<leader>Sh` → Search in home directory
  - `<leader>Sc` → Search in config
  - `<leader>Sf` → Search in current file directory
- **Conflict Resolution**: Disabled OneDark's `<leader>ts` toggle (use `<leader>Yc` instead)

### 🧹 Configuration Cleanup
- **Which-Key Groups**: Removed incorrect group definitions for direct commands
- **Unused Groups**: Removed empty groups (`<leader>P`)
- **Documentation**: Added convention comments to which-key configuration

### 📚 Documentation Updates
- **Keymap Reference**: Updated `docs/reference/keymaps.md` with correct keybindings
- **Convention Clarity**: Documented the lowercase/uppercase convention

---

## [Previous] - Enhanced Theme Management System

### 🎨 New Features
- **Theme Picker**: Enhanced Telescope interface with nvim-tree style filtering
  - Visual theme categories (dark 🌙, light ☀️, special 🎨)
  - **Telescope Previewer**: Custom preview panel shows theme info and applies theme
  - **Nvim-tree Style Filtering**: Live filtering as you type with immediate updates
  - **Smart Input Modes**: Insert mode for filtering, normal mode for navigation
  - **Enhanced Navigation**: All Telescope navigation (j/k, arrows, gg/G) with preview
  - Quick apply without closing with `<C-y>`
  - Current theme indicator with ● symbol
  - **Responsive Preview**: Theme updates on all selection changes (search, navigation)
  - **Debounced Filtering**: Smooth 150ms debounced filter updates
  - **Clean Integration**: Follows Telescope's standard patterns and behavior
  - **Professional UX**: Consistent with other Telescope pickers

### 🔧 Enhanced Theme Management
- **Modular Architecture**: New `core/theme-picker.lua` module
- **Integration**: Seamless integration with existing theme manager
- **Performance**: Optimized theme loading and switching
- **Feedback**: Enhanced notifications and status updates
- **Robust Loading**: Handles Telescope loading issues gracefully
- **Fallback Support**: Works with vim.ui.select when Telescope unavailable

### ⌨️ New Keybindings
- **`<Space>YTp`**: Open theme picker (floating window)
- **`<Space>YTs`**: Show current theme
- **`<Space>Yc`**: Cycle through themes (enhanced with better fallback)

### 🏗️ Architecture Improvements
- **Theme Picker Module**: Dedicated theme selection system
- **Lazy Loading**: Efficient loading of theme picker functionality
- **Fallback Support**: Graceful degradation when components unavailable
- **Integration**: Clean integration with existing theme management

### 📚 Documentation Updates
- **Quickstart Guide**: Added theme management section
- **Keymap Documentation**: Updated with new theme commands
- **User Experience**: Clear instructions for theme picker usage

---

## [Previous] - Documentation Updates and Consistency Review

### Documentation Improvements
- **README.md**: Updated to reflect current keymap structure with uppercase group keys
- **Plugin Architecture**: Updated plugin list to include mini-nvim subdirectory structure
- **Keymap Documentation**: All key mappings now accurately reflect current configuration
- **British Spelling**: Verified and maintained throughout all documentation
- **Installation Guide**: Current and accurate installation instructions

### Configuration Review
- **Review Report**: Updated to reflect current state with uppercase group keys
- **Consistency Check**: All documentation now matches actual configuration
- **Plugin List**: Accurate representation of current plugin structure
- **Keymap Structure**: Documentation reflects professional uppercase group organisation

### Benefits
- **Accurate Documentation**: All guides now match the actual configuration
- **Professional Appearance**: Consistent uppercase group keys throughout
- **Easy Maintenance**: Clear documentation structure for future updates
- **User Experience**: Reliable installation and usage instructions

## [Previous] - Uppercase Group Key Standardisation

### Major Keymap Reorganisation
- **Uppercase Group Keys**: Standardised all which-key group prefixes to use **uppercase letters** for consistency and improved visual clarity
- **Enhanced Descriptions**: Updated all command descriptions to use proper capitalisation and clear, explicit language
- **Professional Appearance**: Which-key popups now display clean, consistent uppercase group keys that match their descriptive names

### Group Key Changes
- `<leader>B` → **Buffer** operations (was `<leader>b`)
- `<leader>C` → **Configuration** management (was `<leader>c`)
- `<leader>G` → **Git** operations (was `<leader>g`)
- `<leader>J` → **Julia** development (was `<leader>j`)
- `<leader>L` → **LSP** operations (was `<leader>l`)
- `<leader>O` → **Otter** multi-language support (was `<leader>o`)
- `<leader>P` → **Plugin** management (was `<leader>p`)
- `<leader>Q` → **Quarto** operations (already uppercase)
- `<leader>S` → **Search** operations (was `<leader>s`)
- `<leader>T` → **Terminal** operations (already uppercase)
- `<leader>W` → **Window** operations (was `<leader>w`)
- `<leader>X` → **Trouble** diagnostics (was `<leader>x`)
- `<leader>Y` → **Toggle** options (already uppercase)

### Individual Command Updates
**All individual commands updated to match their uppercase group keys:**
- Configuration: `<leader>Cs`, `<leader>Cd`, `<leader>Cg`
- Buffer management: `<leader>Bf`, `<leader>Bc`, `<leader>Bb`, `<leader>Bn`, `<leader>Bj`
- Search operations: `<leader>Sf`, `<leader>St`, `<leader>Sr`, `<leader>Sb`, etc.
- LSP operations: `<leader>Ll`, `<leader>Lr`, `<leader>Lf`, `<leader>LR`, `<leader>Ld`, etc.
- Git operations: `<leader>Gs`, `<leader>Gp`, `<leader>Gg`
- Julia operations: `<leader>Jp`, `<leader>Ji`, `<leader>Ju`, `<leader>Jt`, `<leader>Jd`
- Julia REPL: `<leader>Jrh`, `<leader>Jrv`, `<leader>Jrf`
- Trouble diagnostics: `<leader>Xw`, `<leader>Xd`, `<leader>Xl`, `<leader>Xq`, `<leader>Xx`
- Plugin management: `<leader>Pi`, `<leader>Pu`, `<leader>Pc`, `<leader>Ps`
- Otter operations: `<leader>Oa`, `<leader>Od`

### Preserved Individual Commands
- `<leader>q` - Close buffer (quick access)
- `<leader>e` - Toggle file explorer
- `<leader>f` - Find files
- `<leader>x` - Toggle checkbox (Obsidian)

### Benefits
- **Visual Consistency**: Group keys now match their descriptive names (e.g., `B` for "Buffer")
- **Professional Appearance**: Clean, consistent uppercase letters in which-key popups
- **Better Organisation**: Clear distinction between group prefixes and individual commands
- **Enhanced Workflow**: More intuitive key combinations that align with group names
- **Improved Discoverability**: Easier to remember and navigate keymap structure

## [Earlier] - Keymap Reorganisation

### Group Letter Remapping
- **Toggle Group**: Remapped from `<leader>T*` to `<leader>Y*` to resolve collision with Terminal group
  - `<leader>Yw` - Toggle line wrapping
  - `<leader>Yn` - Toggle line numbers
  - `<leader>Yc` - Cycle through colourschemes

### Addition of Split Group
- **New Split Group**: Added `<leader>|*` prefix for split window commands
  - `<leader>|v` - Split window vertically
  - `<leader>|h` - Split window horizontally

### Key Collision Resolution
- **Terminal Group**: Retained `<leader>T*` for all terminal-related functions
  - `<leader>Th` - Horizontal terminal
  - `<leader>Tv` - Vertical terminal
  - `<leader>Tf` - Float terminal
  - `<leader>Tt` - Toggle terminal (smart vertical default)
  - `<leader>Tk` - Clear terminal
  - `<leader>Td` - Delete terminal
- **Search Group**: Retained `<leader>S*` for search operations (managed by plugins)
- **Toggle Group**: Moved to `<leader>Y*` to avoid "T" collision
- **Split Group**: Uses `<leader>|*` to avoid "S" collision

### Rationale
These changes ensure logical grouping of related commands whilst preventing key conflicts:
- Terminal operations remain under the intuitive "T" prefix
- Toggle operations use "Y" (phonetically similar to "toggle")
- Split operations use "|" symbol (visually represents splitting)
- Search operations maintain "S" prefix for consistency with plugin conventions

All changes maintain backwards compatibility where possible whilst improving the logical organisation of keybindings.
