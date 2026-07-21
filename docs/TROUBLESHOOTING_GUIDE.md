# Troubleshooting Guide

Common issues and solutions. Utility scripts are listed in [scripts/README.md](https://github.com/SimonAB/process-nvim/blob/main/scripts/README.md).

### LaTeX Inverse Search Issues

#### No response on inverse search

**macOS (Skim)**:
- **Skim Sync settings**: Preferences → Sync → Preset **Custom**; **Command** = absolute path to `nvim` (e.g. `/opt/homebrew/bin/nvim`); **Arguments** = `--headless -c "VimtexInverseSearch %line '%file'"`
- **One-shot setup**: `~/.config/nvim/scripts/configure-skim-synctex.sh` (writes Skim preferences from `which nvim`)
- **Neovim path**: Skim does not always search `$PATH`; use the full path from `which nvim`
- **Synctex**: Ensure your build includes `-synctex=1` (configured via VimTeX latexmk options)
- **Automation**: macOS may prompt for permission the first time Skim runs Neovim

**Arch Linux (Zathura)**:
- **Zathura configuration**: If needed, add to `~/.config/zathura/zathurarc`: `set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""`
- **Neovim path**: Verify `which nvim` points to your Neovim 0.12 install
- **Synctex**: Ensure your build includes `-synctex=1` (configured via VimTeX latexmk options)
- **Note**: VimTeX may configure this automatically. Test first without manual configuration.

#### Path Configuration Problems

**macOS**:
- **Verify Skim settings**: Command must be the full `nvim` binary; Arguments must be exactly `--headless -c "VimtexInverseSearch %line '%file'"`
- **Test manually**: `nvim --headless -c "VimtexInverseSearch 10 '/absolute/path/to/test.tex'"`
- **Multiple Neovims**: VimTeX registers each instance and routes inverse search to the matching project

**Arch Linux**:
- Use VimTeX's built-in function in `~/.config/zathura/zathurarc`: `set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""`
- **Note**: VimTeX may configure this automatically. Test first without manual configuration.

#### Files not found with relative paths in LaTeX projects
- VimTeX's built-in `VimtexInverseSearch` handles path resolution automatically
- For custom project layouts, ensure your LaTeX project structure is standard
- Verify your project structure matches supported patterns

#### After changing SyncTeX configuration
- **Restart Neovim** in every tmux/Herdr pane so each instance registers a fresh RPC socket with VimTeX
- Open a `.tex` buffer once, then check `~/.cache/vimtex/nvim_servernames.log` lists a live socket (not a stale path)
- **Forward search** (`\lv`) is in-process and usually works without RPC; **inverse search** (Skim click) depends on the registry above
- Remove a leftover shared socket from older configs if present: `rm -f /tmp/nvim_server`

### Plugin and Configuration Issues

#### Plugins not loading
- Restart Neovim (auto-installs on first run)
- Clear vim.pack plugins: `rm -rf ~/.local/share/nvim/site/pack/core/opt/`
- If you track the lockfile, keep `~/.config/nvim/nvim-pack-lock.json` (it will reinstall on next start)
- Check individual plugin files for configuration errors
- Check error messages in `:messages` for specific plugin failures

#### Configuration changes not taking effect
- Use `<leader>Cs` to reload all configuration files
- Check for syntax errors in individual plugin files
- Verify plugin dependencies are installed

#### gitsigns: `handle_on_lines` (a nil value) after plugin updates
- Cause: Lua module cache (`package.loaded`) still holds an older `gitsigns.manager` while `attach.lua` expects the newer API.
- Fix: quit and restart Neovim (recommended after `:PluginUpdateAll`).
- In-session: `:lua require('core.plugin-reload').reload_gitsigns_if_stale()` then reopen buffers.
- Prevention: `PackChanged` and the plugin manager clear caches on update; `PluginPruneLegacy` removes duplicate trees under `pack/plugins/start/`.

#### Obsidian vault: slow gitsigns or huge `git status`
- Large vaults with many unstaged notes keep gitsigns busy.
- Optional: `scripts/daily-vault-commit.sh` (commit/push on a schedule; `install` for launchd on macOS). Set `OBSIDIAN_VAULT_PATH` if the vault is not the default iCloud Notebook path.

#### Markdown preview not working
- Ensure the plugin is built: check `~/.local/share/nvim/site/pack/core/opt/markdown-preview.nvim/app/bin/`
- Use `<leader>Kp` to start preview
- Check browser permissions for local file access

### Language Server Issues

#### Julia LSP not starting
- Install LanguageServer.jl: `using Pkg; Pkg.add("LanguageServer")`
- Verify Julia is in PATH
- Check Mason interface: `<leader>Mm` to see available servers

#### Python LSP issues
- Install pyright: `npm install -g pyright`
- Or use Mason: `<leader>Mm` then install `pyright`
- Verify Python is in PATH

#### LaTeX LSP issues

**macOS**:
- Install texlab: `brew install texlab`
- Or use Mason: `<leader>Mm` then install `texlab`
- Verify LaTeX distribution is properly installed

**Arch Linux**:
- Install texlab: `sudo pacman -S texlab`
- Or use Mason: `<leader>Mm` then install `texlab`
- Verify LaTeX distribution is properly installed

### Terminal Integration Issues

#### Terminal not opening
- Check if toggleterm plugin is loaded
- Try `<leader>Th` for horizontal terminal or `<leader>Tv` for vertical
- Verify terminal emulator is properly configured

#### Code block execution not working
- Ensure you're in a supported file type (Julia, Python, R, etc.)
- Check if the appropriate language server is installed
- Verify terminal integration is properly configured

### CodeCompanion / Cursor Agent Issues

#### `~/.local/bin/cursor-agent: line 8: dirname: command not found`
- **Cause**: CodeCompanion starts ACP agents via `vim.system` with a replaced environment. Without an inherited `PATH`, the Cursor Agent wrapper cannot find `dirname` / `realpath`. Separately, Hermes installs into `~/.local/bin` and may leave `agent` / `cursor-agent` as broken shims instead of symlinks into `~/.local/share/cursor-agent/versions/`.
- **Config fix** (already in this repo): `lua/plugins/codecompanion-nvim.lua` forwards Neovim's environment, strengthens `PATH`, and prefers the versioned agent binary.
- **Repair shims** (machine-local; not part of etc sync):
  ```bash
  ~/.config/nvim/scripts/repair-cursor-agent.sh --check
  ~/.config/nvim/scripts/repair-cursor-agent.sh
  ```
- **Dotfiles sync** (`~/Documents/etc`): follow that README’s allowlist. Sync this nvim config (repair script + CodeCompanion setup). Do **not** sync `~/.local/bin`, `~/.local/share/cursor-agent`, `~/.hermes`, or Cursor auth/state. Optional PATH helper: `scripts/snippets/path-local-bin.zsh` (only if the etc README includes shell PATH snippets).
- **Auth**: after a reinstall, run `agent login` in a terminal, then reopen `:CodeCompanionChat`.
- **Note**: Hermes may keep its own `~/.local/bin/node` symlink; that is expected. The versioned Cursor Agent package uses its bundled Node next to the real `cursor-agent` script.

### Theme and Appearance Issues

#### Theme not cycling
- Use `<leader>Yc` to cycle through available themes
- Spell check (unrelated to themes): `<leader>Ys` toggles spell; `<leader>Yse` / `<leader>Ysf` set English/French
- Verify theme plugins are properly installed

#### Icons not displaying
- Ensure nvim-web-devicons is installed
- Check if your terminal supports icons
- Verify font supports the required glyphs

### Debugging Commands

#### General Debugging
```vim
:messages          " View error messages
:checkhealth       " Run Neovim health checks
:lua print(vim.inspect(vim.lsp.get_active_clients()))  " Check LSP clients
:VimtexInfo        " Check VimTeX status
:Mason             " Open Mason interface
```

#### Plugin Debugging
```vim
:WhichKey          " Show all available keymaps
:Telescope keymaps " Search through keymaps
:lua print(vim.inspect(vim.g))  " Check global variables
```

### Log Files

#### Important Log Locations
- **Neovim**: `~/.local/share/nvim/log/`
- **Mason**: `~/.local/share/nvim/mason/`
- **LSP**: Check `:lua print(vim.lsp.get_log_path())`

### Getting Help

#### Built-in Help
- `:help` - General Neovim help
- `:help vimtex` - VimTeX documentation
- `:help telescope` - Telescope documentation
- `:help which-key` - Which-key documentation

#### External Resources
- [Neovim Documentation](https://neovim.io/doc/)
- [VimTeX Documentation](https://github.com/lervag/vimtex)
- [Mason Documentation](https://github.com/mason-org/mason.nvim)
- [Telescope Documentation](https://github.com/nvim-telescope/telescope.nvim)

---

*For additional support, check the configuration files in `lua/plugins/` for detailed comments and usage examples.*
