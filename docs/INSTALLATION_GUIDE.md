# Installation Guide

Installation instructions for process-nvim on macOS and Arch Linux.

## System Requirements

- **Operating System**: 
  - macOS 10.15+ (tested on macOS 13+)
  - Arch Linux (tested on latest stable)
- **Neovim**: 0.12 or later (required for vim.pack plugin management)
- **Terminal**: 
  - **macOS**: [Ghostty](https://github.com/ghostty-org/ghostty), [iTerm2](https://iterm2.com/), or [Warp](https://www.warp.dev/) (256-colour support)
  - **Arch Linux**: Alacritty, Kitty, or any terminal with 256-colour support
- **Internet Connection**: Required for plugin installation

## Prerequisites

### macOS: Homebrew Package Manager

Install dependencies via Homebrew. If Homebrew is not installed:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Verify installation
brew --version
```

Homebrew: https://brew.sh/

Add Homebrew to PATH per installation instructions.

### Arch Linux: Pacman Package Manager

Arch Linux uses `pacman` as its package manager. Ensure your system is up to date:

```bash
# Update system packages
sudo pacman -Syu

# Verify pacman is working
pacman --version
```

For AUR packages, you'll need an AUR helper. Recommended options:

- **yay** (recommended): `sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si`
- **paru**: `sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si`

## Core Dependencies

### 1. Neovim 0.12+

#### macOS

**Note**: Neovim 0.12 is not yet released in stable Homebrew. Install from HEAD to get 0.12:

```bash
# Install Neovim 0.12 from HEAD (development version)
brew install neovim --HEAD

# Verify version
nvim --version  # Must show 0.12.0 or later

# If you need to update later
brew upgrade neovim --HEAD

# Build from source (alternative)
git clone https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=Release
sudo make install
```

#### Arch Linux

**Note**: Neovim 0.12 is not yet in the official Arch repositories. Install from AUR:

```bash
# Install Neovim 0.12 from AUR (requires yay or paru)
yay -S neovim-nightly-bin
# or
paru -S neovim-nightly-bin

# Verify version
nvim --version  # Must show 0.12.0 or later

# Build from source (alternative, if needed)
git clone https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=Release
sudo make install
```

### 2. Essential Command-Line Tools

#### macOS

```bash
# Ripgrep (for Telescope live grep)
brew install ripgrep

# fd (for Telescope file finding)
brew install fd

# Git (for plugin management)
brew install git

# LazyGit (for Git interface)
brew install lazygit

# Cargo (for blink.cmp native fuzzy matcher; optional but recommended)
brew install rust
```

#### Arch Linux

```bash
# Ripgrep (for Telescope live grep)
sudo pacman -S ripgrep

# fd (for Telescope file finding)
sudo pacman -S fd

# Git (for plugin management)
sudo pacman -S git

# LazyGit (for Git interface)
# Available in AUR
yay -S lazygit
# or
paru -S lazygit

# Cargo (for blink.cmp native fuzzy matcher; optional but recommended)
sudo pacman -S rust
```

Verify installation:
```bash
rg --version     # ripgrep 14.0.0+
fd --version     # fd 9.0.0+
git --version    # git 2.40.0+
cargo --version  # cargo 1.70.0+
```

## Configuration Installation

### Clone Repository

```bash
# Backup existing configuration (if any)
mv ~/.config/nvim ~/.config/nvim.backup

# Clone this configuration
git clone https://github.com/SimonAB/process-nvim.git ~/.config/nvim
cd ~/.config/nvim
```

### First Launch

```bash
# Launch Neovim - plugins install automatically
nvim

# Expected behaviour:
# 1. vim.pack clones plugins from GitHub (~2-3 minutes)
# 2. blink.lib installs (small companion plugin required by current blink.cmp)
# 3. blink.cmp compiles its native fuzzy matcher (~30 seconds, needs Cargo)
# 4. Dashboard appears
```

Notes:
- `vim.pack` manages plugins and writes a lockfile to `~/.config/nvim/nvim-pack-lock.json`.
- Current upstream `blink.cmp` expects [`blink.lib`](https://github.com/Saghen/blink.lib) on the
  runtime path; this configuration declares both in `lua/plugins.lua` and loads `blink.lib` before
  `blink.cmp` in `lua/core/plugin-loader.lua`.
- If a native build fails (for example `telescope-fzf-native.nvim`), restart Neovim after fixing
  your toolchain and run a plugin update again.

## Document Processing Tools

### LaTeX Workflow

#### macOS

```bash
# Full TeX distribution (3.5 GB)
brew install --cask mactex

# BasicTeX (100 MB, manual package installation required)
brew install --cask basictex

# PDF viewer with SyncTeX support
brew install --cask skim

# LaTeX language server (optional, can install via Mason)
brew install texlab
```

#### Arch Linux

```bash
# Full TeX distribution
sudo pacman -S texlive-most texlive-lang

# Or minimal installation
sudo pacman -S texlive-core texlive-bin texlive-latex

# PDF viewer with SyncTeX support (Zathura recommended)
sudo pacman -S zathura zathura-pdf-mupdf
# Alternative: Okular
# sudo pacman -S okular

# LaTeX language server (optional, can install via Mason)
sudo pacman -S texlab
```

Verify LaTeX installation:
```bash
pdflatex --version
latexmk --version
```

#### Configure PDF Viewer for SyncTeX

##### macOS: Configure Skim

Run:

```bash
~/.config/nvim/scripts/configure-skim-synctex.sh
```

Or configure manually in Skim → **Preferences** → **Sync** → **PDF-TeX Sync**:

- **Preset**: Custom
- **Command**: `/opt/homebrew/bin/nvim` (use `which nvim`; full path required)
- **Arguments**: `--headless -c "VimtexInverseSearch %line '%file'"`

In Skim:
- Cmd+Shift+Click for inverse search (PDF → Neovim)

##### Arch Linux: Configure Zathura

VimTeX automatically configures Zathura for inverse search when using `vim.g.vimtex_view_method = "zathura"`. However, you may need to configure Zathura manually if automatic setup doesn't work.

Use VimTeX's built-in function directly in `~/.config/zathura/zathurarc`:

```
set synctex true
set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""
```

**Note**: VimTeX automatically starts Zathura with the `-x` argument for inverse search, so manual configuration may not be necessary. Test first without configuring `synctex-editor-command`.

In Zathura:
- Ctrl+Click for inverse search (PDF → Neovim)

Test SyncTeX:
```bash
cd ~/Documents/latex-test
nvim test.tex
```

In Neovim:
- `\ll` to compile
- `\lv` for forward search (Neovim → PDF)

### Markdown Workflow

#### macOS

```bash
# Node.js (for markdown-preview plugin)
brew install node

# Optional: Pandoc for advanced Markdown conversion
brew install pandoc
```

#### Arch Linux

```bash
# Node.js (for markdown-preview plugin)
sudo pacman -S nodejs npm

# Optional: Pandoc for advanced Markdown conversion
sudo pacman -S pandoc
```

Test Markdown preview:
```bash
nvim test.md
```

In Neovim: `<Space>Kp` to start preview

### Typst Workflow

#### macOS

```bash
# Typst compiler
brew install typst

# Verify installation
typst --version
```

#### Arch Linux

```bash
# Typst compiler (available in AUR)
yay -S typst
# or
paru -S typst

# Verify installation
typst --version
```

Test Typst:
```bash
nvim test.typ
```

In Neovim: `\tp` to toggle preview, `\tc` to compile, `\tw` to watch.

**Monorepo / shared packages**: compile, watch, and preview pass `--root` from `core.typst-project`. Set `TYPST_ROOT` to force a root, or place `typst.toml` (or a `shared/typst/` directory) at the project root so nested `.typ` files resolve imports correctly.

### Quarto Workflow

#### macOS

```bash
# Quarto publishing system
brew install --cask quarto

# Verify installation
quarto check
```

#### Arch Linux

```bash
# Quarto publishing system (available in AUR)
yay -S quarto-bin
# or
paru -S quarto-bin

# Verify installation
quarto check
```

## Language Support

### Julia

#### macOS

```bash
# Install Julia
brew install julia

# Verify installation
julia --version  # 1.9.0+ recommended
```

#### Arch Linux

```bash
# Install Julia (available in AUR)
yay -S julia-bin
# or
paru -S julia-bin

# Verify installation
julia --version  # 1.9.0+ recommended
```

Configure Julia environment:
```julia
# Launch Julia
julia

# Install language server
using Pkg
Pkg.add("LanguageServer")
Pkg.add("SymbolServer")

# Optional: Quarto Jupyter engine kernels
Pkg.add("IJulia")
```

Install Julia LSP via Mason (in Neovim):
```vim
:Mason
" Search for 'julials' and install
```

### Python

#### macOS

```bash
# Python 3 (usually pre-installed on macOS)
python3 --version  # 3.8+ required

# pip for package management
python3 -m ensurepip --upgrade
```

#### Arch Linux

```bash
# Python 3
sudo pacman -S python python-pip

# Verify installation
python --version  # 3.8+ required
```

Install Python LSP via Mason:
```vim
:Mason
" Install: pyright, ruff-lsp
```

### R

#### macOS

```bash
# R programming language
brew install r

# Verify installation
R --version
```

#### Arch Linux

```bash
# R programming language (available in AUR)
yay -S r
# or
paru -S r

# Verify installation
R --version
```

Install R language server:
```r
# Launch R
R

# Install languageserver
install.packages("languageserver")
```

Install R LSP via Mason:
```vim
:Mason
" Search for 'r_language_server' and install
```

## Language Server Installation

### Via Mason (Recommended)

Mason provides a unified interface for installing language servers.

```vim
# Open Mason
:Mason

# Or use leader keymaps
<Space>MA            " Install academic LSP servers (automated)
<Space>MR            " Install all recommended servers
<Space>MU            " Update all packages
```

### Recommended Language Servers

#### Academic Writing
- **texlab**: LaTeX language server
- **marksman**: Markdown language server
- **ltex-ls**: Grammar/spell checking (LanguageTool)

#### Programming
- **lua-language-server**: Lua/Neovim configuration
- **pyright**: Python type checking
- **ruff-lsp**: Python linting
- **julials**: Julia language server
- **r-languageserver**: R language server

#### Data/Configuration
- **yaml-language-server**: YAML
- **json-lsp**: JSON
- **taplo**: TOML

### Manual LSP Installation

If Mason installation fails, install manually:

#### macOS

```bash
# Lua LSP
brew install lua-language-server

# Python LSP
npm install -g pyright

# LaTeX LSP
brew install texlab
```

#### Arch Linux

```bash
# Lua LSP
sudo pacman -S lua-language-server

# Python LSP
sudo npm install -g pyright

# LaTeX LSP
sudo pacman -S texlab
```

## Optional Tools

### Obsidian Integration

#### macOS

```bash
# Install Obsidian
brew install --cask obsidian
```

#### Arch Linux

```bash
# Install Obsidian (available in AUR)
yay -S obsidian
# or
paru -S obsidian
```

Configure the Obsidian workspace path in `lua/plugins/obsidian-nvim.lua`:
```lua
obsidian.setup({
  workspaces = {
    {
      name = "notebook",
      path = "/path/to/your/vault",
    },
  },
})
```

### Database Tools

#### macOS

```bash
# SQLite (for Telescope frecency)
brew install sqlite3
```

#### Arch Linux

```bash
# SQLite (for Telescope frecency)
sudo pacman -S sqlite
```

### Additional Utilities

#### macOS

```bash
# Tree-sitter CLI (for parser updates)
npm install -g tree-sitter-cli

# Neovim remote (for advanced workflows)
pip3 install neovim-remote

# GitHub CLI (for gh integration)
brew install gh
```

#### Arch Linux

```bash
# Tree-sitter CLI (for parser updates)
sudo npm install -g tree-sitter-cli

# Neovim remote (for advanced workflows)
pip install neovim-remote

# GitHub CLI (for gh integration)
sudo pacman -S github-cli
```

## Verification

### Check Neovim Health

```vim
:checkhealth
```

Review each section for warnings or errors.

### Verify Plugin Installation

```vim
:lua print(vim.inspect(vim.fn.glob('~/.local/share/nvim/site/pack/core/opt/*', 0, 1)))
```

Expected: List of installed plugins

### Test LSP Functionality

```vim
# Open a Python file
:e test.py

# Check LSP status
:LspInfo

# Verify LSP is attached
<Space>Ll          " List active LSP servers
```

## Troubleshooting

### Plugins Not Installing

**Symptom**: Blank Neovim or plugin errors

**Solution**:
```bash
# Check plugin directory
ls ~/.local/share/nvim/site/pack/core/opt/

# Manual installation
nvim -c "lua require('core.plugin-manager').install_all_plugins()" -c "q"

# Check for errors
nvim -c "messages" -c "q"
```

### blink.cmp or blink.lib startup / build issues

**Symptom**: Errors on startup mentioning `blink.lib`, `loop or previous error loading module 'blink.cmp'`,
or completion not working after an update.

**Cause**: Recent `blink.cmp` releases depend on the separate `blink.lib` plugin. If `blink.lib` is
missing or not on the runtime path before `blink.cmp`, Neovim can fail while loading completion.

**Solution**:
```bash
# Ensure both plugins are present (paths match vim.pack opt layout)
ls ~/.local/share/nvim/site/pack/core/opt/blink.lib
ls ~/.local/share/nvim/site/pack/core/opt/blink.cmp

# Pull latest plugins (from Neovim)
# :lua vim.pack.update(nil, { force = true })

# Ensure Cargo is installed if you build the native fuzzy matcher from source
cargo --version

# Manually compile blink.cmp native library
cd ~/.local/share/nvim/site/pack/core/opt/blink.cmp
cargo build --release

# Alternative: disable blink.cmp in lua/plugins.lua if you must work offline without Rust
```

### LSP Not Starting

**Symptom**: No code intelligence, diagnostics, or completion

**Solution**:
```vim
# Check Mason installation
:Mason

# Verify language server is installed
:LspInfo

# Check log file
:lua print(vim.lsp.get_log_path())

# Manual server installation
<Space>MA          " Install academic servers
```

### LaTeX SyncTeX Issues

**Symptom**: Forward/inverse search not working

**Solution**:
```bash
# Re-apply Skim SyncTeX settings
~/.config/nvim/scripts/configure-skim-synctex.sh

# Test inverse search manually
nvim --headless -c "VimtexInverseSearch 10 '/absolute/path/to/test.tex'"
```

### Terminal Emulator Issues

**Symptom**: Colours wrong, icons not displaying, keymaps not working

**Solution**:
```bash
# Verify terminal supports 256 colours
echo $TERM  # Should be xterm-256color or similar

# Test colours
curl -s https://gist.githubusercontent.com/lifepillar/09a44b8cf0f9397465614e622979107f/raw/24-bit-color.sh | bash

# Install a Nerd Font for icons
```

#### macOS

```bash
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```

#### Arch Linux

```bash
# Install Nerd Fonts (available in AUR)
yay -S nerd-fonts-hack
# or
paru -S nerd-fonts-hack
```

**Recommended terminals**:

**macOS**:
- [Ghostty](https://github.com/ghostty-org/ghostty) - Fast, native macOS terminal
- [iTerm2](https://iterm2.com/) - Feature-rich terminal with extensive customisation
- [Warp](https://www.warp.dev/) - Modern terminal with AI features

**Arch Linux**:
- [Alacritty](https://github.com/alacritty/alacritty) - Fast, GPU-accelerated terminal (`sudo pacman -S alacritty`)
- [Kitty](https://sw.kovidgoyal.net/kitty/) - Feature-rich terminal (`sudo pacman -S kitty`)
- [WezTerm](https://wezfurlong.org/wezterm/) - Cross-platform terminal (`sudo pacman -S wezterm`)

**Terminal.app** (macOS): Built-in terminal has 256-colour support but requires configuration:
1. Terminal → Preferences → Profiles
2. Select or create a profile
3. Advanced tab → Set "Declare terminal as:" to `xterm-256color`
4. Text tab → Install a Nerd Font for proper icon display

## Updating

### Update Configuration

```bash
cd ~/.config/nvim
git pull origin main
```

### Update Plugins

```vim
<Space>CUa         " Update all plugins
:lua require('core.plugin-manager').update_all_plugins()
```

### Update Language Servers

```vim
<Space>MU          " Update all Mason packages
:MasonUpdate
```

## Uninstallation

### Complete Removal

```bash
# Remove configuration
rm -rf ~/.config/nvim

# Remove data (plugins, LSP servers, etc.)
rm -rf ~/.local/share/nvim

# Remove state (logs, swap files)
rm -rf ~/.local/state/nvim

# Remove cache
rm -rf ~/.cache/nvim
```

### Restore Backup

```bash
mv ~/.config/nvim.backup ~/.config/nvim
```

## Platform-Specific Notes

### macOS Apple Silicon (M1/M2/M3)

All tools install natively on Apple Silicon. No Rosetta required.

### macOS Intel

Standard installation. Ensure Homebrew is installed for x86_64 architecture.

### Arch Linux

This configuration is fully supported on Arch Linux. Key differences from macOS:

- **PDF Viewer**: Use Zathura or Okular instead of Skim for LaTeX SyncTeX
- **Package Manager**: Use `pacman` for official packages and `yay`/`paru` for AUR packages
- **Zathura Configuration**: VimTeX may configure inverse search automatically. If manual configuration is needed, use VimTeX's built-in function (see Zathura configuration section above)
- **Font Installation**: Install Nerd Fonts via AUR instead of Homebrew casks

### Other Linux Distributions

This configuration should work on other Linux distributions with modifications:
- Replace package manager commands (`pacman` → `apt`/`dnf`/`zypper`)
- Use appropriate PDF viewer (Zathura, Okular, or Evince)
- Adjust paths in shell scripts for your distribution
- Install AUR packages from source or use distribution-specific alternatives

## Next Steps

After installation:

1. Configure language servers: `<Space>MA`
2. Select theme: `<Space>YTp`
3. Test LaTeX workflow: Compile test document
4. Customise keymaps: Add mappings to `lua/keymaps.lua`
5. Review documentation: Keymaps reference, troubleshooting guide

---

See [Quick Start Guide](quickstart.md) and [Keymaps Reference](reference/keymaps.md).
