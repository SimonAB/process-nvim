# Shared application themes

The experimental shared-theme adapter coordinates Neovim, Ghostty and a selected
Rex pane. It uses the existing native Neovim colourschemes and shared float
styling. Opacity and terminal blur settings remain independent.

From the dotfiles repository, preview a selection:

```sh
python3 config/theme/switch.py catppuccin --appearance dark
```

Add `--apply` to write it, and `--rex` to update the Rex pane identified by the
current terminal's `REX_SESSION` and `REX_BLOCK`. Reload Ghostty with its reload
configuration action (Cmd+Shift+, on macOS).

Restart Neovim once after installing the adapter. Subsequent shared selections
are read within one second. The selection file lives beside the real Neovim
configuration at `../theme/selection.json`; `SHARED_THEME_FILE` can override it.
Missing or malformed selections fall back to the existing local theme defaults.

The families are `flexoki` and `catppuccin`. Choose `--appearance light`, `dark`,
or `auto`. An explicit appearance takes precedence over the OS appearance
watcher. `auto` retains OS switching for Neovim and Ghostty. Rex receives a
one-off update to the current appearance; this prototype does not change global
Rex preferences or newly created panes.

To return to the starting family:

```sh
python3 config/theme/switch.py flexoki --appearance auto --apply --rex
```

Reload Ghostty afterwards. To return Neovim to independent local selection, move
`selection.json` aside. The adapter then uses the existing local theme defaults.

The parent dotfiles `config/theme/README.md` documents scope, installation paths
and further integration work. Omarchy integration and continuous Rex appearance
updates are not yet implemented.
