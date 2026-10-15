# Dashboard and file search

Press `<Space>H` (Space, then Shift+H) in normal mode to open the Home dashboard. The command `:MiniStarter` also opens it. Lowercase `<Space>h` clears search highlighting.

## Dashboard layout

The working-directory path appears above the following sections:

| Section | Contents | Shortcuts |
| --- | --- | --- |
| Current directory | Up to five newest-modified text files throughout the working directory tree | `a`–`e` |
| Recent projects | Recently visited directories | `1`–`4` |
| Recent files elsewhere | Previously opened files outside the current directory tree | Navigate and press Enter |
| Actions | Find files, Grep, Quit, plugin updates and available Forge actions | Navigate and press Enter; Forge also has labelled uppercase shortcuts |

Use `j`/`k` or the arrow keys to select an item, Enter to open it, and `q` to quit Neovim. Nested files use relative paths. File labels and the directory-path line shorten to approximately 70% of the window width, preserving filename endings; they adjust when the window is resized. Opening a file always uses its full path.

## Discovery and freshness

The dashboard uses `rg --files --null` directly, without loading Telescope. Ripgrep walks subdirectories and respects ignore rules; hidden files are omitted. Files are sorted by modification time, then leading candidates are checked for readability and NUL bytes in their first 8 KiB. This is a lightweight text-file heuristic, rather than complete file-format detection.

Discovery and metadata/content reads run in the background. On a cold visit, file entries appear when discovery finishes; during refresh, previous results remain visible. Results are cached for ten seconds per directory. Saving or renaming files in Neovim invalidates affected caches. Changes made externally are picked up on the next dashboard opening or content refresh after the cache expires. Window resizing adjusts labels without rescanning.

## File picker

Press `<Space>f` to search recursively with Telescope:

- An empty query lists files newest-modified first.
- Typing uses the configured native FZF matcher.
- Clearing the query restores modification-date ordering.

The picker retains its existing file exclusions and preview. It checks modification dates once per candidate per picker session. Reopen it to refresh those dates. Its exclusions differ from the dashboard's text-file check; for example, the picker explicitly excludes common media and archive extensions.

`<Space>R` or `<Space>Rf` opens the separate frecency picker, which ranks files by opening frequency and recency rather than filesystem modification time.

The dashboard's Find files action and other ordinary `Telescope find_files` calls keep their standard sorting; modification-date ordering is attached specifically to `<Space>f`.
