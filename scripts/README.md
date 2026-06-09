# Scripts

Utility scripts for this Neovim configuration. Paths are relative to the repo root (`~/.config/nvim` when installed).

| Script | Purpose |
|--------|---------|
| `daily-vault-commit.sh` | Commit (and optionally push) the Obsidian vault on a schedule; `install` / `uninstall` for macOS launchd |
| `skim_inverse_search.sh` | macOS Skim ↔ Neovim inverse search (SyncTeX) |
| `zathura_inverse_search.sh` | Linux Zathura ↔ Neovim inverse search |
| `start_nvim_server.sh` | Start a headless Neovim server for remote control |
| `test-config.sh` | Headless checks (e.g. CodeCompanion commands after plugin load) |
| `test-markdown-preview.lua` | Markdown preview plugin smoke test |
| `performance_test.lua` | Startup / load timing helper |
| `generate-docs.lua` | Generate plugin and keymap reference snippets (`:luafile` from Neovim) |

Do not commit `*.backup` copies of scripts; they are ignored via `.gitignore`.
