---
layout: home

hero:
  name: process-nvim
  text: Neovim for research and scientific workflows
  tagline: LaTeX, Markdown, Quarto, Typst, Julia, and LSP in one maintainable setup.

features:
  - icon: 🚀
    title: Fast Setup
    details: Neovim 0.12+, vim.pack plugin management, and clear install paths for macOS and Arch Linux.
  - icon: 📄
    title: Writing and Publishing
    details: VimTeX with SyncTeX, Markdown preview, Quarto rendering, and Typst preview/compile workflows.
  - icon: 🧪
    title: Scientific Computing
    details: Julia REPL integration, Python and R support, and terminal-first code execution.
  - icon: 🔧
    title: Language Tooling
    details: 15+ LSP servers through Mason, diagnostics, formatting, and completion via blink.cmp.
  - icon: 🧭
    title: Discoverable Keymaps
    details: Which-key guided leader mappings with consistent groups for editing, docs, terminal, and LSP.
  - icon: ⚙️
    title: Maintainable Design
    details: Modular Lua architecture with deferred loading and practical defaults for daily use.
---

## Start Here

process-nvim is built for Neovim 0.12+ and uses the native `vim.pack` package manager rather than
third-party plugin managers. It combines fast startup, modular Lua configuration, and practical
research tooling in one setup: writing workflows (LaTeX, Markdown, Quarto, Typst), terminal-first
execution, and strong LSP support for day-to-day scientific and technical work.

- [Installation Guide](/INSTALLATION_GUIDE) - platform dependencies and first launch
- [Quick Start](/quickstart) - essential keymaps and first workflow checks
- [Keymaps Reference](/reference/keymaps) - complete leader/localleader map catalogue
- [Troubleshooting](/TROUBLESHOOTING_GUIDE) - fixes for plugin, LSP, terminal, and SyncTeX issues

## Core Workflows

### Writing and publishing
- **LaTeX**: `\ll` compile, `\lv` forward search, Skim/Zathura inverse search
- **Markdown**: `<Leader>Kp` preview, plus table editing mappings under `<Leader>Kt`
- **Quarto**: `<Leader>Qp` preview and `<Leader>QR*` rendering shortcuts
- **Typst**: `<localleader>tp` preview, `<localleader>tc` / `<localleader>tw` compile and watch (monorepo-aware `--root`)

### Scientific coding
- **Julia REPL**: `<Leader>Jrh`, `<Leader>Jrv`, `<Leader>Jrf` launch layouts
- **Code send**: `<C-i>`, `<C-c>`, `<C-s>` for line, block, and selection; blocks include Quarto fences, `# %%` cells, and `##` sections; `yic` yanks fenced or `# %%` chunks
- **LSP controls**: `gd`, `K`, `<Leader>Lf`, `<Leader>Ll`, `<Leader>Lr`

### Terminal-first workflow
- `<C-t>` toggles the default terminal instance
- `<Leader>Tt`, `<Leader>Th`, `<Leader>Tv`, `<Leader>Tf` provide managed terminal layouts
- ToggleTerm and REPL mappings are designed to keep editing and execution in one view

## Essential Keymaps

```vim
" Navigation and search
<Space>f            " Find files
<Space>g            " Grep in project
<Space>e            " Toggle file tree

" LSP
gd                  " Go to definition
K                   " Hover documentation
<Space>Lf           " Format document

" Terminal
<C-t>               " Toggle terminal
<Space>Tt           " Smart vertical terminal

" Writing workflows
\ll                 " Compile LaTeX
\lv                 " Forward search in PDF
<Space>Kp           " Markdown preview
<Space>Qp           " Quarto preview
<localleader>tp     " Typst preview
```

## Documentation Map

- [Installation Guide](/INSTALLATION_GUIDE)
- [Quick Start](/quickstart)
- [Keymaps Reference](/reference/keymaps)
- [LSP Setup](/advanced/lsp-setup)
- [Performance Optimisations](/PERFORMANCE_OPTIMISATIONS)
- [Troubleshooting](/TROUBLESHOOTING_GUIDE)
- [Changelog](/CHANGELOG)
