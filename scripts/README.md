# Scripts

Utility scripts for this Neovim configuration. Paths are relative to the repo root (`~/.config/nvim` when installed).

| Script | Purpose |
|--------|---------|
| `configure-skim-synctex.sh` | Write Skim inverse-search preferences for VimTeX (`VimtexInverseSearch`) |
| `daily-vault-commit.sh` | Commit (and optionally push) the Obsidian vault on a schedule; `install` / `uninstall` for macOS launchd |
| `repair-cursor-agent.sh` | Diagnose/reinstall Cursor Agent `~/.local/bin` shims (Hermes conflicts, `dirname: command not found`) |
| `test-config.sh` | Headless checks (e.g. CodeCompanion commands after plugin load) |
| `test-markdown-preview.lua` | Markdown preview plugin smoke test |
| `performance_test.lua` | Startup / load timing helper |
| `generate-docs.lua` | Generate plugin and keymap reference snippets (`:luafile` from Neovim) |

Do not commit `*.backup` copies of scripts; they are ignored via `.gitignore`.
