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

## Rex themes

Rex ships 41 built-in themes (27 dark, 14 light). They are available in Neovim as
generated colourschemes named `rex-<id>`, for example `rex-merino-dark`,
`rex-whitby-bay` or `rex-sunlit-parchment`. Use `:colorscheme rex-merino-dark` or
the theme picker, which labels them dark or light.

The schemes come from the `themes.json` bundled with Rex. After updating Rex,
regenerate them from the dotfiles repository:

```sh
python3 config/theme/rex-to-nvim.py            # dry run: lists what would be written
python3 config/theme/rex-to-nvim.py --write    # writes colors/rex-*.lua and lua/core/rex-index.lua
python3 config/theme/rex-to-nvim.py --write --only merino-dark merino-light
```

Each generated file in `colors/` holds only a palette (background, foreground,
cursor, selection and sixteen ANSI colours). The mapping to highlight groups lives
in `lua/core/rex-colorscheme.lua`; edit that file, never the generated ones.
Surfaces such as the cursorline, floats and borders are blends of background and
foreground, so one rule serves light and dark schemes. Comments and line numbers
are mixed to at least about 3:1 contrast on every theme.

### Following the Rex theme

Inside a Rex pane, Neovim follows the pane's theme automatically. It asks the
terminal for its default background and foreground (OSC 11 and 10) and for ANSI red
and blue (OSC 4). It matches the replies against `lua/core/rex-index.lua` and loads
the corresponding `rex-*` scheme. Red and blue separate themes that share a
background and foreground, such as `merino-light` and `ivory-gallery`.

* The match overrides the default from `selection.json` and the OS appearance
  watcher, because `ThemeManager.load_immediate` prefers it.
* Replies are re-requested on `FocusGained` and `VimResume`, so a theme changed in
  the Rex app, or by `rex-theme`, `switch.py --rex` or `set_theme`, is picked up when
  you return to the pane.
* It does nothing outside Rex (it requires `REX_SESSION`). Set
  `vim.g.rex_follow = false` to disable it.
* Run `:RexFollow` to show the colours observed and the theme matched.
* Themes not built into Rex, such as imported Ghostty palettes, do not match; Neovim
  then keeps its current scheme.

To check the generated schemes and the follower without changing settings:

```sh
nvim --headless -u NONE -l scripts/test-rex-themes.lua
```

Rex themes are not yet shared families for `switch.py`, because that script resolves
Ghostty palettes. Select them with `:colorscheme` or by running Neovim in Rex.
