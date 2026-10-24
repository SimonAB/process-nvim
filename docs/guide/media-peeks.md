# Media and link peeks

In Markdown and Obsidian buffers, process-nvim can show a popup next to the cursor for media embeds and web links. Place the cursor on the relevant line; the peek appears after a short debounce. The image itself is drawn with the Kitty graphics protocol.

## Images and PDFs

Move the cursor onto an embed:

```markdown
![caption](../attachments/figure.png)
![[paper.pdf]]
![]( '/Users/me/Papers/example.pdf' )
```

The popup shows the image, or a PNG of the current PDF page (fit to width).

PDF keys:

| Key | Action |
| --- | --- |
| `]` / `<C-f>` | Next page |
| `[` / `<C-b>` | Previous page |
| Esc | Dismiss (does not reopen until the cursor leaves the embed) |

Leader keys:

| Key | Action |
| --- | --- |
| `<Leader>Ki` | Refresh the peek |
| `<Leader>Kx` | Clear overlays |
| `<Leader>Ko` | Open the file externally |

PDF pages are cached under `~/.cache/nvim/vim-ui-img/` (about 24 hours). Startup also prunes old undo history and oversized logs.

Saving Markdown documents fills empty `![](...)` image descriptions from filename stems. Existing descriptions and code examples are preserved; see [Markdown save-time cleanup](/guide/markdown-editing).

## Website links

Move the cursor onto a line that contains an `http(s)` URL (Markdown link, bare URL, or `www.…`). The peek shows the page title and description when they can be parsed from the HTML.

Preview image selection:

1. Open Graph / Twitter card image, if present (for example on neovim.io).
2. Otherwise a landscape mobile screenshot from Microlink (`844×600`, `isMobile` and `isLandscape`).
3. Image-embed lines (`![…]`) are handled by the media peek, not the website peek.

| Key | Action |
| --- | --- |
| Esc | Dismiss |
| Enter | Open the URL in the default browser |

`o` and `<C-o>` are not remapped, so normal Vim behaviour is preserved.

## Requirements

- A terminal that implements Kitty graphics, for the image or PDF page. The popup can still open when the host does not draw that protocol. On macOS this configuration runs in [Rex](https://www.superlogical.com/rex).
- `pdftoppm` from Poppler, for PDF peeks (`brew install poppler` on macOS)
- Network access, for website peeks and the screenshot fallback

If peeks do not appear, see [Troubleshooting](/TROUBLESHOOTING_GUIDE#media-and-link-peeks).
