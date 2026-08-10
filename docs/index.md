---
layout: home

hero:
  name: process-nvim
  text: A Neovim configuration for research
  tagline: Document preparation, scientific computing, and editing in one setup.

features:
  - title: Document workflows
    details: LaTeX (VimTeX, SyncTeX), Markdown, Obsidian, Quarto, and Typst — preview and compile from Neovim.
  - title: Media and link peeks
    details: Cursor peeks for images, PDFs, and HTTP(S) links in Markdown. Esc dismisses; Enter opens externally.
  - title: Scientific computing
    details: Julia REPL integration with code send, plus Python and R support.
  - title: Language servers
    details: Mason-managed LSP, diagnostics, formatting, and completion with blink.cmp.
  - title: Keymaps
    details: Which-key groups with consistent leader prefixes for search, docs, terminal, and LSP.
  - title: Configuration layout
    details: Modular Lua, vim.pack, and deferred plugin loading.
---

## Getting started

process-nvim is a Neovim configuration for academic writing and scientific computing. Installation is straightforward if you already use Homebrew (macOS) or pacman/AUR (Arch). The configuration targets Neovim **0.13-dev** (Homebrew HEAD recommended) and requires **0.12+** for `vim.pack`.

If you are setting this up for the first time, start here:

1. [Installation Guide](/INSTALLATION_GUIDE) — dependencies and first launch
2. [Quick Start](/quickstart) — essential keymaps and checks
3. [Media and link peeks](/guide/media-peeks) — images, PDFs, and website previews

Further reading:

- [Keymaps Reference](/reference/keymaps)
- [Troubleshooting](/TROUBLESHOOTING_GUIDE)
- [Utility scripts](https://github.com/SimonAB/process-nvim/blob/main/scripts/README.md)

## What is included

### Writing and publishing

| Tool | Typical entry points |
| --- | --- |
| LaTeX | `\ll` compile, `\lv` forward search |
| Markdown | `<Leader>Kp` preview; `<Leader>Kt…` tables |
| Media peeks | Cursor on `![](…)` / `![[…]]` or an HTTP(S) URL |
| Quarto | `<Leader>Qp` preview; `<Leader>QR*` render |
| Typst | `<localleader>tp` preview; `tc` / `tw` compile and watch |

### Scientific coding

- Julia REPL layouts: `<Leader>Jrh`, `<Leader>Jrv`, `<Leader>Jrf`
- Send code: `<C-i>` (line), `<C-c>` (block), `<C-s>` (selection); `yic` yanks fenced or `# %%` chunks
- LSP: `gd`, `K`, `<Leader>Lf`, `<Leader>Ll`, `<Leader>Lr`

### Terminal

- `<C-t>` toggles the default terminal
- `<Leader>Tt` / `Th` / `Tv` / `Tf` open managed layouts

## Essential keymaps

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

" Writing
\ll                 " Compile LaTeX
\lv                 " Forward search in PDF
<Space>Kp           " Markdown preview
<Space>Qp           " Quarto preview
<localleader>tp     " Typst preview
```

## Documentation map

- [Installation Guide](/INSTALLATION_GUIDE)
- [Quick Start](/quickstart)
- [Media and link peeks](/guide/media-peeks)
- [Keymaps Reference](/reference/keymaps)
- [LSP Setup](/advanced/lsp-setup)
- [Performance Optimisations](/PERFORMANCE_OPTIMISATIONS)
- [Troubleshooting](/TROUBLESHOOTING_GUIDE)
- [Changelog](/CHANGELOG)
