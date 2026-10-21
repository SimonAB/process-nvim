# Scripts

Utility scripts for this Neovim configuration. Paths are relative to the repo root (`~/.config/nvim` when installed).

| Script | Purpose |
|--------|---------|
| `configure-skim-synctex.sh` | Write Skim inverse-search preferences for VimTeX (`VimtexInverseSearch`) — macOS |
| `configure-zathura-synctex.sh` | Write Zathura `synctex-editor-command` for VimTeX (`VimtexInverseSearch`) — Linux |
| `daily-vault-commit.sh` | Commit (and optionally push) the Obsidian vault on a schedule; `install` / `uninstall` for macOS launchd |
| `test-dashboard-recursive.lua` | Check nested text-file discovery, ignore rules and file opening |
| `test-dashboard-cache.lua` | Check asynchronous discovery, cache reuse, expiry and invalidation |
| `test-dashboard-async-ui.lua` | Check dashboard refresh, directory isolation and shortcut rebinding |
| `test-telescope-modified.lua` | Check modification-date sorting and fuzzy-search delegation |
| `test-markdown-image-alt.lua` | Check filename-derived image labels, code exclusions and save-time insertion |
| `test-julia-lsp.lua` | Check Julia LSP initialisation, literal project paths and hover |
| `test-config.sh` | Headless checks (e.g. CodeCompanion commands after plugin load) |
| `test-markdown-preview.lua` | Markdown preview plugin smoke test |
| `performance_test.lua` | Startup / load timing helper |
| `generate-docs.lua` | Generate plugin and keymap reference snippets (`:luafile` from Neovim) |

Do not commit `*.backup` copies of scripts; they are ignored via `.gitignore`.

Run the file-search, dashboard and image-label checks above from the repository root with `nvim --headless -u NONE -i NONE -l scripts/<test>.lua`. The dashboard UI check uses the installed mini.nvim plugin.

## Julia language server

After updating Julia, LanguageServer.jl or Neovim, run this integration check from
this repository root with the normal configuration loaded:

```sh
nvim --headless -n -i NONE -c 'luafile scripts/test-julia-lsp.lua'
```

This requires `julia` on `PATH` and LanguageServer.jl in `@nvim-lspconfig`
(`:JuliaLspInstall` installs it). The check allows 60 seconds for initialisation
and 30 seconds for hover, and returns a non-zero exit status on failure. It uses
a temporary project path containing spaces, an apostrophe and `$` to catch
accidental interpolation. It is intended for Linux and macOS.

The launcher follows LanguageServer.jl's documented
[`runserver()` entry point](https://github.com/julia-vscode/LanguageServer.jl/blob/main/src/runserver.jl),
with the project path passed through `ARGS`, rather than constructing a server
with version-dependent positional arguments. Updates remain explicit through
`:JuliaLspUpdate`; `:JuliaLspUpdateDev` deliberately selects unreleased code.
