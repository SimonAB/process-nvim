# Quick Start Guide

process-nvim is a Neovim configuration for research workflows.

## Prerequisites

### macOS: Homebrew Package Manager

If you don't have Homebrew installed:

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

See https://brew.sh/ for more information.

### Arch Linux: Pacman and AUR Helper

Ensure your system is up to date:

```bash
# Update system
sudo pacman -Syu

# Install AUR helper (yay recommended)
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si
```

### Essential Tools

#### macOS

```bash
# Neovim 0.13-dev (Homebrew HEAD; stable is still 0.12.x)
brew install neovim --HEAD

# Fuzzy finding utilities
brew install ripgrep fd

# Git interface
brew install lazygit

# Node.js (language servers, markdown preview)
brew install node
```

#### Arch Linux

```bash
# Neovim 0.13-dev nightly (prefer over older stable for this config)
yay -S neovim-nightly-bin
# or
paru -S neovim-nightly-bin

# Fuzzy finding utilities
sudo pacman -S ripgrep fd

# Git interface (AUR)
yay -S lazygit

# Node.js (language servers, markdown preview)
sudo pacman -S nodejs npm
```

### Academic Workflow Tools

#### macOS

```bash
# LaTeX support
brew install --cask mactex-no-gui   # or mactex for full installation

# PDF viewer for LaTeX sync
brew install --cask skim

# Typst typesetting
brew install typst

# Julia programming (optional)
brew install julia

# R programming (optional)
brew install r
```

#### Arch Linux

```bash
# LaTeX support
sudo pacman -S texlive-most texlive-lang

# PDF viewer for LaTeX sync
sudo pacman -S zathura zathura-pdf-mupdf

# Typst typesetting (AUR)
yay -S typst

# Julia programming (optional, AUR)
yay -S julia-bin

# R programming (optional, AUR)
yay -S r
```

## Installation

### Clone Configuration

```bash
git clone https://github.com/SimonAB/process-nvim.git ~/.config/nvim
cd ~/.config/nvim
```

### First Launch

```bash
# Launch Neovim - plugins install automatically
nvim
```

**First launch sequence:**

1. vim.pack installs plugins (~2 minutes), including `blink.lib` then `blink.cmp`
2. `blink.cmp` may compile its native fuzzy matcher (needs Cargo; ~30 seconds)
3. System theme detected and applied
4. Mason prompts for language server installation
5. Dashboard displays recent files

## Essential Keymaps

### Navigation (`<Space>` is leader)

```vim
<Space>              " Show all available commands (Which-Key)
<Space>f             " Find files (Telescope)
<Space>g             " Live grep in project
<Space>e             " Toggle file explorer
<Ctrl-h/j/k/l>       " Navigate between windows
<Shift-h/l>          " Navigate between buffers
```

### Terminal Integration

```vim
<Ctrl-t>             " Toggle terminal
<Space>Tt            " Terminal toggle (vertical)
<Space>Th            " Horizontal terminal
<Space>Tv            " Vertical terminal
<Space>Tf            " Floating terminal
<Ctrl-i>             " Send line to Julia REPL
<Ctrl-c>             " Send code block to Julia REPL (fences, # %%, or ## section)
<Ctrl-s>             " Send visual selection to Julia REPL (visual mode)
yic                  " Yank fenced or # %% code chunk
```

### LSP Operations

```vim
gd                   " Go to definition
K                    " Show documentation
<Space>Lf            " Format document
<Space>Lr            " Restart LSP
<Space>LR            " Show references
<Space>Ll            " List active LSP servers
```

### Document Processing

```vim
" LaTeX (localleader is \)
\lv                  " Forward search (LaTeX → PDF)
\ll                  " Compile document
\lc                  " Clean auxiliary files

" Markdown
<Space>Kp            " Start preview
<Space>Kv            " Toggle preview
<Space>Ki            " Refresh media peek
<Space>Kx            " Clear media peek
<Space>Ko            " Open attachment externally
<Space>Ktf           " Format table
<Space>Ktn/Ktp       " Navigate table cells
<Space>Kto/KtO      " Insert row below/above
<Space>Kti/KtI      " Insert column right/left

" Quarto
<Space>Qp            " Preview document
<Space>QRh/QRp/QRw   " Render to HTML/PDF/Word

" Typst
\tp                  " Toggle preview
\tc                  " Compile PDF
```

### Julia Development

```vim
<Space>Jrh           " Horizontal Julia REPL
<Space>Jrv           " Vertical Julia REPL
<Space>Jrf           " Floating Julia REPL
<Space>Jp            " Project status
<Space>Ji            " Instantiate project
<Space>Jt            " Run tests
```

Julia REPLs: `--threads=auto`

## Configuration

### Theme Management

```vim
<Space>YTp           " Open theme picker (Telescope)
<Space>Yc            " Cycle through themes
<Space>YTs           " Show current theme
<Space>Yz            " Toggle Zen Mode (markdown writing mode)
```

Themes: Catppuccin, OneDark, Tokyo Night, Nord, GitHub Dark/Light.

### Language Server Installation

```vim
<Space>MA            " Install academic LSP servers (LaTeX, Python, R, Julia)
<Space>MR            " Install all recommended servers
<Space>MU            " Update all packages
<Space>MS            " Show Mason status
:Mason               " Open Mason interface
```

Academic workflow servers:
- **LaTeX**: texlab
- **Python**: pyright, ruff-lsp
- **R**: r-languageserver
- **Julia**: julials
- **Lua**: lua-language-server
- **Markdown**: marksman

### Spell Checking

```vim
<Space>Ys            " Toggle spell check
<Space>Yse           " Set spell language to English (British)
<Space>Ysf           " Set spell language to French
```

## LaTeX Workflow Setup

### macOS: Configure Skim for SyncTeX

Run the helper (writes Skim preferences from `which nvim`):

```bash
~/.config/nvim/scripts/configure-skim-synctex.sh
```

Or set manually in Skim → Preferences → Sync:

1. **Preset**: Custom
2. **Command**: `/opt/homebrew/bin/nvim` (full path from `which nvim`)
3. **Arguments**: `--headless -c "VimtexInverseSearch %line '%file'"`

In Skim:
- Cmd+Shift+Click on PDF to jump to corresponding line in Neovim (Ghostty is raised automatically)

### Arch Linux: Configure Zathura for SyncTeX

VimTeX automatically configures Zathura for inverse search. If needed, create or edit `~/.config/zathura/zathurarc`:

```
set synctex true
set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""
```

**Note**: VimTeX may handle this automatically. Test first without manual configuration.

In Zathura:
- Ctrl+Click on PDF to jump to corresponding line in Neovim

### Test LaTeX Integration

```bash
cd ~/Documents/your-latex-project
nvim main.tex
```

In Neovim:
```vim
\ll                  " Compile document
\lv                  " Open PDF and jump to cursor position
```

### Underline, strikethrough, highlight (lua-ul)

This config expects **lua-ul** with soul-compatible command names (LuaLaTeX/OpenType-friendly). In your preamble use (order matters: **luacolor before lua-ul**):

```latex
\usepackage{luacolor}          % required for \hl (highlight); must be before lua-ul
\usepackage[soul]{lua-ul}      % provides \ul, \uline, \st, \sout, \hl (same names as soul)
```

Do **not** load `soul` or `ulem`; lua-ul with the `[soul]` option gives you the same `\ul`, `\st`, `\hl` (and `\uline`, `\sout`) with better kerning and OpenType support. The editor will style these commands in the buffer and TOC.

## Obsidian Integration

Configure Obsidian vault path in `lua/keymaps-plugins.lua`:

```lua
local obsidian_path = "/Users/<username>/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notebook"
```

### Obsidian Keymaps

```vim
<Space>Oo            " Find files in Obsidian vault
<Space>On            " New note
<Space>Oc            " Toggle checkbox
<Space>Op            " Paste image
<Space>Ol            " Insert link
<Space>Ob            " Show backlinks
```

Callouts: `<Space>O!` plus a key (e.g. `<Space>O!w` for warning)—normal mode inserts a block under the cursor line; in visual mode the same sequence wraps the selection. See **docs/reference/keymaps.md** for the full key list.

### Media and link peeks

In Markdown or Obsidian buffers, place the cursor on an image/PDF embed or a web URL to open a popup (Kitty graphics). Esc dismisses; Enter opens a link in the browser. See [Media and link peeks](/guide/media-peeks).

## Julia Setup

### Install Julia Language Server

```julia
using Pkg
Pkg.add("LanguageServer")
```

### Julia REPL Workflow

1. Open Julia file: `nvim script.jl`
2. Launch REPL: `<Space>Jrv` (vertical split)
3. Send code:
   - Current line: `<Ctrl-i>`
   - Code block: `<Ctrl-c>` — Quarto `` ```{julia} `` fences, VS Code `# %%` cells, or `##` sections (see **docs/reference/keymaps.md**)
   - Selection: `<Ctrl-s>` (visual mode)
   - Yank chunk: `yic` (fenced or `# %%` only)

### Project Management

```vim
<Space>Jp            " Check project status
<Space>Ji            " Instantiate dependencies
<Space>Ju            " Update packages
<Space>Jt            " Run tests
```

## Troubleshooting

### Plugins Not Loading

```vim
:checkhealth         " Diagnose issues
:Mason               " Verify language servers
:messages            " Check error messages
```

### LSP Not Working

```vim
<Space>Ll            " List active LSP servers
<Space>Lr            " Restart LSP
:LspInfo             " Check LSP client status
```

### Terminal Issues

```bash
# Verify toggleterm installation
nvim -c "lua print(pcall(require, 'toggleterm'))"

# Test terminal mapping
<Space>Th            " Try horizontal terminal
```

### LaTeX SyncTeX Not Working

#### macOS (Skim)

```bash
# Re-apply Skim preferences from this config
~/.config/nvim/scripts/configure-skim-synctex.sh

# Test inverse search command manually
nvim --headless -c "VimtexInverseSearch 10 '/absolute/path/to/test.tex'"
```

#### Arch Linux (Zathura)

```bash
# Verify Zathura configuration
cat ~/.config/zathura/zathurarc

# Test inverse search command manually (if configured)
nvim --headless -c "VimtexInverseSearch 10 '/absolute/path/to/test.tex'"
```

## Feature Discovery

### Which-Key Integration

Press `<Space>` (500ms delay) to view commands grouped by functionality:

- **A**: AI (CodeCompanion)
- **B**: Buffer operations
- **C**: Configuration management
- **CU**: Plugin updates (vim.pack)
- **F**: Forge (kanban / projects)
- **R**: Frecency (recent files)
- **G**: Git operations
- **J**: Julia development
- **K**: Markdown preview
- **L**: LSP operations
- **M**: Mason package management
- **O**: Obsidian operations (`O!` = callouts)
- **Q**: Quarto operations
- **S**: Search operations
- **T**: Terminal operations
- **W**: Window operations
- **X**: Diagnostics (Trouble)
- **Y**: Toggle options

### Search Keymaps

```vim
:WhichKey            " Show all keymaps
:WhichKey <Space>    " Show leader keymaps
```

## Next Steps

1. Install language servers: `<Space>MA`
2. Configure theme: `<Space>YTp`
3. Set up LaTeX: Configure Skim for bidirectional sync
4. Customise: Add core keymaps to `lua/keymaps-core.lua` (plugin-free) and plugin keymaps to `lua/keymaps-plugins.lua`
5. Explore: Press `<Space>` to view command groups

## Advanced Usage

### Custom Keymaps

Add to `lua/keymaps-core.lua` (plugin-independent) or `lua/keymaps-plugins.lua` (plugin-dependent):

```lua
vim.keymap.set("n", "<leader>custom", function()
    -- Your custom functionality
end, { desc = "Custom command" })
```

### Adding Plugins

Edit `lua/plugins.lua`:

```lua
local plugins = {
	{ src = "https://github.com/user/plugin", name = "plugin" },
}
```

## Resources

- [Keymaps Reference](reference/keymaps.md)
- [Installation Guide](INSTALLATION_GUIDE.md)
- [Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)
- [Utility scripts](https://github.com/SimonAB/process-nvim/blob/main/scripts/README.md) — SyncTeX helpers, vault daily commit, config tests, doc generator

---

Press `<Space>` to view available commands.
