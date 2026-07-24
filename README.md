# process-nvim

[Documentation](https://simonab.github.io/process-nvim/)

Neovim configuration optimised for academic research and scientific computing. Document processing: LaTeX (VimTeX, SyncTeX), Markdown (preview, Obsidian), Quarto (R/Python/Julia execution), Typst (preview). Scientific computing: Julia REPL (multi-threaded), Python LSP (pyright), R execution. Development: LSP (15+ languages via Mason), completion ([blink.cmp](https://github.com/Saghen/blink.cmp) with [blink.lib](https://github.com/Saghen/blink.lib)), terminal integration, Git integration. Modular architecture. vim.pack plugin management. Neovim 0.12+ required.

## Features

### Document Processing

- LaTeX: VimTeX, bidirectional SyncTeX (Skim)
- Markdown: Live preview, Obsidian integration
- Quarto: Code execution (R, Python, Julia)
- Typst: Preview (typst-preview), CLI compile/watch (`typst c` / `typst w`)

### Scientific Computing

- Julia: REPL integration, multi-threaded execution
- Python: LSP (pyright)
- R: Code execution, project management

### Development Environment

- LSP: 15+ languages (Mason)
- Completion: blink.cmp (with blink.lib dependency)
- Terminal: Code block detection
- Git: GitSigns, LazyGit

## Requirements

### Essential

- **Package Manager**:
  - **macOS**: Homebrew ([install here](https://brew.sh/))
  - **Arch Linux**: pacman (built-in) and yay/paru for AUR packages
- Neovim 0.12+ (required for vim.pack plugin management)
- Git
- Cargo (recommended: builds blink.cmp native fuzzy matcher from source)
- ripgrep, fd (for Telescope fuzzy finding)

### Document Processing

- **LaTeX**: 
  - **macOS**: MacTeX or BasicTeX, Skim PDF viewer
  - **Arch Linux**: texlive-most, Zathura PDF viewer
- **Typst**: 
  - **macOS**: `brew install typst`
  - **Arch Linux**: `yay -S typst` (AUR)
- **Markdown**: Node.js (for preview plugin)

### Language Support

- **Julia**: Julia 1.9+ with LanguageServer.jl
- **Python**: Python 3.8+ with pyright LSP
- **R**: R 4.0+ with languageserver package

See [Installation Guide](docs/INSTALLATION_GUIDE.md).

## Installation

```bash
# Clone configuration
git clone https://github.com/SimonAB/process-nvim.git ~/.config/nvim
cd ~/.config/nvim

# First launch (plugins auto-install)
nvim

# Verify installation
nvim
```

Plugins install automatically on first launch (vim.pack). Mason prompts for language server installation.

## Quick Reference

### Leader: `<Space>`


| Key                        | Action                 |
| -------------------------- | ---------------------- |
| `<leader>f`                | Find files (Telescope) |
| `<leader>g`                | Live grep in project   |
| `<leader>R` / `<leader>Rf` | Find files (frecency)  |
| `<leader>e`                | Toggle file explorer   |
| `<leader>w`                | Save file              |


### Terminal Integration


| Key                | Action                                      |
| ------------------ | ------------------------------------------- |
| `<C-t>`            | Toggle terminal (ToggleTerm `open_mapping`) |
| `<leader>Tt`       | Terminal toggle (vertical, smart)           |
| `<leader>Th/Tv/Tf` | Horizontal/Vertical/Float terminal          |


### Document Workflows


| Key                                 | Action                                       |
| ----------------------------------- | -------------------------------------------- |
| `<localleader>lv`                   | LaTeX forward search (VimTeX)                |
| `<localleader>ll`                   | Compile LaTeX (VimTeX)                       |
| `<localleader>lb`                   | Compile (alias of `<localleader>ll`; latexmk runs biber when needed) |
| `<localleader>tp`–`<localleader>tw` | Typst preview / sync / `typst c` / `typst w` |
| `<leader>Kp`                        | Markdown preview                             |
| `<leader>Qp`                        | Quarto preview                               |


### Julia Development


| Key               | Action                                 |
| ----------------- | -------------------------------------- |
| `<leader>Jrh/v/f` | Julia REPL (horizontal/vertical/float) |
| `<leader>Jp`      | Project status                         |
| `<leader>Ji`      | Instantiate project                    |
| `<C-i>` / `<C-c>` / `<C-s>` | Send line, block, or selection to REPL |
| `yic`             | Yank fenced or `# %%` code chunk       |


Julia REPLs launch with `--threads=auto` for parallel computing. `<C-c>` recognises Quarto `` ```{...} `` fences, `# %%` cells, and `##` sections.

### Theme Management


| Key           | Action                   |
| ------------- | ------------------------ |
| `<leader>Yc`  | Cycle themes             |
| `<leader>YTp` | Theme picker (Telescope) |
| `<leader>YTs` | Show current theme       |

This configuration uses Flexoki from the fork [`SimonAB/flexoki-neovim`](https://github.com/SimonAB/flexoki-neovim)
for transparent UI surfaces (`flexoki-dark` / `flexoki-light`).

### AI (CodeCompanion)

| Key | Action |
| --- | --- |
| `<leader>Ac` | Chat (default adapter) |
| `<leader>At` | Toggle chat |
| `<leader>Ad` | Chat debug |
| `<leader>Ao` | Chat (Ollama) |


See [Keymaps Reference](docs/reference/keymaps.md).

## Configuration Structure

```
~/.config/nvim/
├── init.lua                 # Entry point
├── lua/
│   ├── config.lua           # Editor settings
│   ├── keymaps.lua          # Loads keymaps-core + keymaps-plugins
│   ├── keymaps-core.lua     # Core keymaps (plugin-independent)
│   ├── keymaps-plugins.lua  # Plugin keymaps (deferred)
│   ├── plugins.lua          # vim.pack plugin list and hooks
│   ├── core/
│   │   ├── plugin-loader.lua
│   │   ├── plugin-manager.lua
│   │   ├── plugin-reload.lua
│   │   ├── theme-manager.lua
│   │   ├── theme-picker.lua
│   │   └── typst-project.lua
│   └── plugins/             # Per-plugin setup
├── docs/                    # VitePress site
└── scripts/                 # SyncTeX, vault commit, config tests (see scripts/README.md)
```

## Customisation

### Adding Plugins

Edit `lua/plugins.lua`:

```lua
local plugins = {
	{ src = "https://github.com/user/plugin", name = "plugin" },
}
```

### Custom Keymaps

Add plugin-independent mappings to `lua/keymaps-core.lua`, and plugin-dependent mappings to
`lua/keymaps-plugins.lua`:

```lua
vim.keymap.set("n", "<leader>custom", ":CustomCommand<CR>", 
    { desc = "Custom command" })
```

### LSP Configuration

Install language servers via Mason:

```vim
:Mason                    " Open Mason interface
<leader>MA               " Install academic LSP servers
<leader>MR               " Install all recommended servers
```

## Documentation

- [Installation Guide](docs/INSTALLATION_GUIDE.md)
- [Quick Start](docs/quickstart.md)
- [Keymaps Reference](docs/reference/keymaps.md)
- [Troubleshooting](docs/TROUBLESHOOTING_GUIDE.md)

## Troubleshooting

### LSP Issues

```vim
:checkhealth          " Diagnose Neovim health
:Mason                " Check installed language servers
<leader>Ll            " List active LSP servers
<leader>Lr            " Restart LSP
```

### LaTeX SyncTeX

**macOS (Skim)**:

- Run `~/.config/nvim/scripts/configure-skim-synctex.sh` or set Skim → Sync → Custom with `nvim --headless -c "VimtexInverseSearch %line '%file'"`
- Forward search: `\lv` in a `.tex` buffer (Skim scrolls to the cursor; Neovim keeps focus)

**Arch Linux (Zathura)**:

- VimTeX may configure this automatically
- If needed, configure in `~/.config/zathura/zathurarc`: `set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""`
- See Installation Guide for detailed setup

## Recent Changes

- Terminal mappings: `<leader>T[1,2,3]` → `<leader>T[h,v,f]` (consistency with Julia REPL)
- Julia REPL: `--threads=auto` enabled
- File formatting: Single newline at end of file on save
- Obsidian: `<leader>Op` pastes image, adds two newlines

See [CHANGELOG](docs/CHANGELOG.md) for complete version history.

## Design Principles

1. Discoverability: Which-key integration
2. Consistency: British spelling, logical keymap organisation
3. Research workflows: Academic document preparation, scientific computing
4. Maintainability: Modular architecture, documented code

## License

Provided as-is for educational and personal use.

**Note**: Requires Neovim 0.12+ (vim.pack). Older versions: use lazy.nvim or packer.nvim.
