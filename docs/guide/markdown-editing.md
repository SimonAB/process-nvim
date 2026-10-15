# Markdown save-time cleanup

Saving a `.md`, `.markdown`, `.Rmd` or `.qmd` file fills empty inline image descriptions with the image filename stem. This also applies to Obsidian notes.

Before saving:

```markdown
![](<../attachments/Pasted image 20260930141915.png>)
```

After saving:

```markdown
![Pasted image 20260930141915](<../attachments/Pasted image 20260930141915.png>)
```

## What changes

The helper removes the filename extension, decodes URL-encoded characters and escapes Markdown punctuation in the inserted label. A destination such as `figures/response%20day-7.png` receives the label `response day-7`. Existing descriptions, link destinations and optional titles are preserved. Whitespace-only descriptions are treated as empty. Repeated saves do not add text again.

Neovim's incremental Markdown Treesitter parser identifies image links, so examples in fenced or indented code, inline code, frontmatter and HTML comments are left alone. The helper skips read-only and unmodifiable buffers and preserves the current view.

This operates on inline Markdown images, `![](destination)`. It does not rewrite Obsidian wikilink embeds (`![[image.png]]`), reference-style image links, or HTML image tags. It does not inspect the image or generate content-based accessibility descriptions. You can replace the filename label with a more useful description at any time; subsequent saves preserve it.

## Requirements and checks

The `markdown` and `markdown_inline` Treesitter parsers must be available. Missing parsers produce a warning in `:messages`; the document is saved without this cleanup. There are no external script, network or model calls.

Restart Neovim after updating the configuration. To check the save hook, use `:autocmd MarkdownImageAlt`. To apply the helper to the current buffer without writing it:

```vim
:lua require('core.markdown-image-alt').apply(vim.api.nvim_get_current_buf())
```

Other existing save-time rules in `lua/config.lua` still handle whitespace and list spacing. See [Media and link peeks](/guide/media-peeks) for previewing images and PDFs.
