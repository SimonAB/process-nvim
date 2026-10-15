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
| `test-config.sh` | Headless checks (e.g. CodeCompanion commands after plugin load) |
| `test-markdown-preview.lua` | Markdown preview plugin smoke test |
| `performance_test.lua` | Startup / load timing helper |
| `generate-docs.lua` | Generate plugin and keymap reference snippets (`:luafile` from Neovim) |

Do not commit `*.backup` copies of scripts; they are ignored via `.gitignore`.

Run the four file-search and dashboard checks above from the repository root with `nvim --headless -u NONE -i NONE -l scripts/<test>.lua`. The dashboard UI check uses the installed mini.nvim plugin.
