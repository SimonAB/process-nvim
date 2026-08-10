# Keymaps Reference

Complete keymap reference for process-nvim, organised by functionality.

## Leader Keys

- Primary Leader: `<Space>`
- Local Leader: `\` (document-specific commands)

## Navigation

### Window Navigation
```vim
<C-h>           " Move to left window
<C-j>           " Move to bottom window
<C-k>           " Move to top window
<C-l>           " Move to right window
```

### Window Resizing
```vim
<S-Up>          " Decrease window height
<S-Down>        " Increase window height
<S-Left>        " Decrease window width
<S-Right>       " Increase window width

<Leader>Wk      " Decrease window height (universal)
<Leader>Wj      " Increase window height (universal)
<Leader>Wh      " Decrease window width (universal)
<Leader>Wl      " Increase window width (universal)
```

### Buffer Navigation
```vim
<S-h>           " Previous buffer
<S-l>           " Next buffer

<Leader>Bb      " Previous buffer (BufferLine)
<Leader>Bn      " Next buffer (BufferLine)
<Leader>Bp      " Pick buffer (BufferLine)
<Leader>Bf      " Find buffers (Telescope)
<Leader>Bl      " List all buffers (including unlisted)
<Leader>Bq      " Close buffer
```

### File Navigation
```vim
<Leader>f       " Find files (Telescope)
<Leader>R       " Find files by frequency/recency (Telescope frecency)
<Leader>Rf      " Find files (frecency)
<Leader>Rr      " Refresh frecency database
<Leader>Rd      " Show frecency database location
<Leader>Rb      " Rebuild frecency database
<Leader>e       " Toggle file explorer (NvimTree)
```

### Forge (kanban / projects)
Finder-tag kanban workflow (see `lua/plugins/forge-nvim.lua`):

```vim
<Leader>Fs      " Forge status
<Leader>Fb      " Kanban board (list)
<Leader>Fp      " Project tags (current project)
<Leader>Ft      " Calendar (read-only)
<Leader>Fm      " Move current project to column
<Leader>Fa      " Add tag to current project
<Leader>Fr      " Remove tag from current project
<Leader>Fi      " Open inbox.md
<Leader>Ff      " Find Forge files (Telescope)
<Leader>Fg      " Grep Forge files (Telescope)
```

Commands: `:ForgeStatus` (alias `:ForgeNext`), `:ForgeMove`, `:ForgeProjectTags`, `:ForgeProjectTagAdd`, `:ForgeProjectTagRemove`, `:ForgeCalendar`.

## LSP Operations

### Core LSP
```vim
gd              " Go to definition
gD              " Go to declaration
K               " Show hover documentation
<Leader>Lf      " Format document
<Leader>LR      " Show references
<Leader>Lr      " Restart LSP
<Leader>Ll      " List active LSP servers
<Leader>Lm      " Open Mason
```

## Mason Package Management

### Enhanced Mason Operations
```vim
<Leader>MA      " Install academic LSP servers
<Leader>MR      " Install all recommended servers
<Leader>MU      " Update all packages
<Leader>MS      " Show Mason status
<Leader>Mm      " Open Mason interface
<Leader>Mi      " Install package
<Leader>Mu      " Uninstall package
<Leader>Ml      " View Mason log
<Leader>Mh      " Mason help
```

## Document Processing

### LaTeX/VimTeX
VimTeX provides comprehensive default keymaps (see `:help vimtex-default-mappings`):
```vim
\LocalLeader\ll  " Compile LaTeX (latexmk + lualatex; runs biber when needed)
\LocalLeader\lb  " Compile (alias of ll)
\LocalLeader\lv  " View PDF (forward search)
\LocalLeader\lk  " Stop compilation
\LocalLeader\lK  " Stop all compilations
\LocalLeader\lc  " Clean auxiliary files
\LocalLeader\lC  " Clean all files (including PDF)
\LocalLeader\lt  " Open table of contents
\LocalLeader\lT  " Toggle table of contents
\LocalLeader\le  " Show errors
\LocalLeader\lo  " Show compilation output
\LocalLeader\lg  " Show status
\LocalLeader\lG  " Show status (all)
\LocalLeader\lq  " Show log
\LocalLeader\li  " Show info
\LocalLeader\lI  " Show info (full)
\LocalLeader\lx  " Reload VimTeX
\LocalLeader\lX  " Reload VimTeX state
\LocalLeader\la  " Context menu
\LocalLeader\lm  " List insert mode maps
" And many more - see :help vimtex-default-mappings
```

**Note**: Compilation uses VimTeX’s latexmk backend with LuaLaTeX. latexmk runs biber/bibtex when the bibliography backend requires it, so `\lb` is kept only as an alias of `\ll`. Auxiliary files are written beside the `.tex` (same as texlab `auxDirectory = "."`).

### Typst
Buffer-local on `typ` / `typst` files (`<localleader>` is typically `\`):
```vim
<localleader>tp " Toggle Typst preview (typst-preview.nvim when installed)
<localleader>ts " Sync cursor in preview
<localleader>tc " Compile PDF (`typst compile --root …`, CLI)
<localleader>tw " Watch file (`typst watch --root …`, ToggleTerm)
```

Project root is resolved by `core.typst-project`: `TYPST_ROOT` if set, else the nearest ancestor with `typst.toml` or `shared/typst/`, else the file’s directory. Preview and compile/watch use that root so monorepo layouts (shared packages) work without manual `--root` flags.

### Markdown/Quarto
```vim
<Leader>Kp      " Start markdown preview
<Leader>Ks      " Stop markdown preview
<Leader>Kv      " Toggle markdown preview
<Leader>Ki      " Refresh media peek
<Leader>Kx      " Clear media peek
<Leader>Ko      " Open attachment externally

<Leader>Kln     " Autolist: Next list style
<Leader>Klp     " Autolist: Previous list style

<Leader>Qp      " Quarto preview
<Leader>Qc      " Close Quarto preview
<Leader>QRh     " Render to HTML
<Leader>QRp     " Render to PDF
<Leader>QRw     " Render to Word
<Leader>QRa     " Render all formats (or project if _quarto.yml)
```

### Markdown Table Operations
Table editing operations for markdown and quarto files (table-nvim):
```vim
<Leader>Ktf     " Format/realign table
<Leader>Ktn     " Next cell
<Leader>Ktp     " Previous cell
<Leader>Kto     " Insert row below
<Leader>KtO     " Insert row above
<Leader>KtJ     " Move row down
<Leader>KtK     " Move row up
<Leader>Kti     " Insert column right
<Leader>KtI     " Insert column left
<Leader>KtL     " Move column right
<Leader>KtH     " Move column left
<Leader>Ktdc    " Delete column
<Leader>Ktt     " Insert table
<Leader>KtT     " Insert table (no outline)
```

**Note**: Table editing uses `<Leader>Kt…`. Markdown preview uses `<Leader>Kp` / `Ks` / `Kv`. Media and URL peeks are documented in [Media and link peeks](/guide/media-peeks).

## Academic Workflow

### Julia Development
```vim
<Leader>Jrh     " Horizontal Julia REPL
<Leader>Jrv     " Vertical Julia REPL
<Leader>Jrf     " Floating Julia REPL
<Leader>Jp      " Project status
<Leader>Ji      " Instantiate project
<Leader>Ju      " Update project
<Leader>Jt      " Run tests
<Leader>Jd      " Generate documentation
```

### Obsidian Integration
```vim
<Leader>On      " New Obsidian note
<Leader>Ol      " Insert Obsidian link
<Leader>Of      " Follow Obsidian link
<Leader>Oc      " Toggle Obsidian checkbox
<Leader>Ob      " Show Obsidian backlinks
<Leader>Og      " Show Obsidian outgoing links
<Leader>Oo      " Find files in Obsidian vault
<Leader>Ot      " Insert Obsidian template
<Leader>ON      " New note from template
<Leader>Op      " Paste image into note
<Leader>Ov      " Toggle Obsidian preview
```

Obsidian [callouts](https://help.obsidian.md/callouts) (`<Leader>O!` then a letter; normal mode inserts below the line, visual mode wraps the range):

```vim
<Leader>O!n     " Note        <Leader>O!a     " Abstract    <Leader>O!i     " Info
<Leader>O!o     " Todo        <Leader>O!t     " Tip         <Leader>O!s     " Success
<Leader>O!q     " Question    <Leader>O!w     " Warning     <Leader>O!f     " Failure
<Leader>O!d     " Danger      <Leader>O!b     " Bug         <Leader>O!e     " Example
<Leader>O!Q     " Quote
```

Command-line wrap (optional): `:ObsidianCalloutWrap <type>` with a line range.

## Terminal Integration

### Terminal Management
ToggleTerm is configured with `open_mapping` `<C-t>` (see `lua/plugins/toggleterm-nvim.lua`). Additional bindings:
```vim
<C-t>           " Toggle terminal (ToggleTerm default instance)
<Leader>Tt      " Toggle terminal (vertical default, smart hide/show)
<Leader>Th      " Horizontal terminal (15 lines)
<Leader>Tv      " Vertical terminal (30% width)
<Leader>Tf      " Floating terminal
<Leader>Tk      " Clear terminal
<Leader>Td      " Kill terminal
```

### Send code to Julia REPL
When a Julia REPL is open (via `<Leader>Jr*`), you can send code directly:

```vim
<C-i>           " Send current line to Julia REPL (normal mode)
<C-c>           " Send current code block to Julia REPL (normal mode)
<C-s>           " Send visual selection to Julia REPL (visual mode)
yic             " Yank current code chunk (fenced or # %%) to registers
```

Note: these use bracketed paste to avoid REPL line-editing features mutating bracket characters.

**`<C-c>` block detection** (first match wins; marker lines are not sent):

| Style | Opening | Closing / end |
|-------|---------|----------------|
| Quarto / R Markdown | `` ```{...} `` (e.g. `` ```{julia} ``) | `` ``` `` (line of three backticks only) |
| VS Code cells | `# %%`, `#%%`, or `#` + spaces + `%%` (optional title after) | Next `# %%` marker or EOF |
| Section (fallback) | `##` header | Line before next `##` header (header line is included) |

**`yic`** uses fenced chunks first (Quarto `` ```{...} `` or plain `` ``` `` … `` ``` ``), then the same `# %%` cell body as `<C-c>` (markers excluded). It does not yank `##` sections.

After `<C-c>`, the cursor jumps to the start of the next detected block when one exists.

## Git Operations

```vim
<Leader>Gs      " Git status
<Leader>Gp      " Git pull
<Leader>Gg      " LazyGit interface
```

## Search Operations

```vim
<Leader>g       " Grep in project (direct command)
<Leader>Sp      " Search in project
<Leader>Sw      " Search in working directory
<Leader>Sh      " Search in home directory
<Leader>Sc      " Search in config
<Leader>Sf      " Search in current file directory
```

## Configuration Management

```vim
<Leader>Cs      " Reload configuration
<Leader>Cr      " Restart Neovim (restore session)
<Leader>CR      " Restart Neovim (no session restore)
<Leader>Cd      " Mark UI detachable (:detach!)
<Leader>Cf      " Find config files
<Leader>Cg      " Grep in config files
```

## Theme & Appearance

### Theme Management
```vim
<Leader>Yc      " Cycle through themes
<Leader>Yw      " Toggle word wrap
<Leader>Yz      " Toggle Zen Mode (markdown writing)
<Leader>Yn      " Toggle line numbers
<Leader>Ys      " Toggle spell check
<Leader>Yse     " Set spell language to English (British)
<Leader>Ysf     " Set spell language to French
```

## Window Management

### Split Operations
```vim
<Leader>|v      " Vertical split
<Leader>|h      " Horizontal split
```

## Diagnostics

```vim
<Leader>Xw      " Workspace diagnostics
<Leader>Xd      " Document diagnostics
<Leader>Xl      " Location list
<Leader>Xq      " Quickfix
```

## AI (CodeCompanion)

```vim
<Leader>Ac      " AI chat (default adapter)
<Leader>At      " Toggle chat
<Leader>Ad      " AI chat debug
<Leader>Ao      " AI chat (Ollama adapter)
```

Requires CodeCompanion and configured adapters (see `lua/plugins/codecompanion-nvim.lua`).

## Plugin Management

```vim
<Leader>CUa     " Update all plugins
<Leader>CUs     " Show plugin status
<Leader>CUc     " Cleanup orphaned plugins
```

Command-line (not leader-mapped): `:PluginPruneLegacy` removes duplicate legacy trees under `pack/plugins/start/` when vim.pack already manages the same plugin under `site/pack/core/opt/`.

## Editor Basics

```vim
<Leader>w       " Write file
<C-s>           " Quick save
<Leader>q       " Close buffer
<Esc>           " Clear search highlights
<Leader>h       " Clear search highlights (alternative)

" Better indenting (visual mode)
<               " Indent left
>               " Indent right

" Move text (visual mode)
J               " Move selection down
K               " Move selection up

" Better paste (visual mode)
p               " Paste without yanking
```

## Search & Replace

```vim
" Clear search highlights
<Esc>           " Clear highlights
<Leader>h       " Clear highlights (alternative)

" Incremental search
/               " Forward search
?               " Backward search
*               " Search word under cursor
#               " Search word under cursor (backward)
n               " Next match
N               " Previous match
```

## Quick Access

```vim
<Leader>q       " Close buffer (quick access)
```

## Special Characters

### Which-Key Triggers
- `<Space>` - Show all leader key groups
- `<LocalLeader>` - Show local leader commands
- `<C-` - Control key combinations
- `<A-` - Alt key combinations
- `<S-` - Shift key combinations

## Customization

### Adding Keymaps
Create `~/.config/nvim/lua/user.lua`:

```lua
-- Add your custom keymaps
vim.keymap.set("n", "<leader>mykey", ":MyCommand<CR>", {
    desc = "My custom command"
})
```

### Remapping Existing Keys
```lua
-- Remap existing keymap
vim.keymap.set("n", "<leader>f", ":MyCustomFinder<CR>", {
    desc = "Custom file finder"
})
```

## Keymap Discovery

### Which-Key Integration
- Press `<Space>` and wait to see all available commands
- Type part of a command to filter results
- Use `<BS>` to go back in the navigation tree

### Help Commands
```vim
:WhichKey        " Show all keymaps
:WhichKey <key>  " Show keymaps for specific key
:help which-key  " Which-Key documentation
```

## Troubleshooting

### Keymap Conflicts
1. Check for conflicting mappings: `:verbose map <key>`
2. Use `:WhichKey` to visualise conflicts
3. Override in `user.lua` if needed

### Slow Keymaps
1. Check for expensive operations in keymap functions
2. Use `vim.defer_fn()` for heavy operations
3. Consider lazy loading heavy plugins

### Missing Keymaps
1. Ensure plugin is loaded: `:lua require("plugins.plugin-name")`
2. Check plugin configuration
3. Verify keymap registration in plugin files

---

Press `<Space>` to view available keymaps via Which-Key.
