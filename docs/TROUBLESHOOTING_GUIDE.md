# Troubleshooting Guide

Common issues and solutions.

### LaTeX Inverse Search Issues

#### No response on inverse search

**macOS (Skim)**:
- **Skim Sync settings**: Preferences → Sync → Command should point to `skim_inverse_search.sh`, Arguments: `%line "%file"`
- **Neovim path**: Verify `which nvim` points to your Neovim 0.12 install
- **Synctex**: Ensure your build includes `-synctex=1` (configured via VimTeX latexmk options)

**Arch Linux (Zathura)**:
- **Zathura configuration**: If needed, add to `~/.config/zathura/zathurarc`: `set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""`
- **Neovim path**: Verify `which nvim` points to your Neovim 0.12 install
- **Synctex**: Ensure your build includes `-synctex=1` (configured via VimTeX latexmk options)
- **Note**: VimTeX may configure this automatically. Test first without manual configuration.

#### Path Configuration Problems

**macOS**:
- **Verify Script Path**: In Skim preferences, use the full canonical absolute path to the script; do not use tilde (~) and do not use symlinks. Use exactly: `/Users/<username>/.config/nvim/scripts/skim_inverse_search.sh`
- **Test Script Manually**: Run `/Users/<username>/.config/nvim/scripts/skim_inverse_search.sh 10 "/absolute/path/to/test.tex"` to validate the script directly
- **Check nvr Installation**: Verify nvr is installed with `which nvr` (typically `/opt/homebrew/bin/nvr` on Apple Silicon or `/usr/local/bin/nvr` on Intel)

**Arch Linux**:
- **Simplest solution**: Use VimTeX's built-in function directly in `~/.config/zathura/zathurarc`: `set synctex-editor-command "nvim --headless -c \"VimtexInverseSearch %{line} '%{input}'\""`
- **Alternative with nvr**: If using nvr: `set synctex-editor-command "nvr --servername /tmp/nvim_server --remote-silent +%{line} '%{input}'"`
- **Note**: VimTeX may configure this automatically. Test first without manual configuration.
- **Check nvr Installation** (if using nvr): Verify nvr is installed with `which nvr` (typically `/usr/bin/nvr` on Arch Linux)

#### Files not found with relative paths in LaTeX projects
- VimTeX's built-in `VimtexInverseSearch` handles path resolution automatically
- For custom project layouts, ensure your LaTeX project structure is standard
- If using the optional script, check debug log: `tail -f /tmp/inverse_search.log`
- Verify your project structure matches supported patterns

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
- **Inverse Search**: `/tmp/inverse_search.log`
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
