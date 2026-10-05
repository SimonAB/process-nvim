# LSP Setup Guide

Language Server Protocol configuration for academic workflows.

## Overview

Mason manages LSP servers. Settings configured for research and document preparation workflows.

## Automatic Setup

### Installation Commands

```vim
:lua require("plugins.mason-enhanced").install_academic_servers()
" or use the keymap
<Space>MA
```

This installs the core academic servers:
- **Python**: pyright (recommended)
- **LaTeX**: texlab
- **Typst**: tinymist
- **Lua**: lua_ls
- **Bash**: bashls
- **Markdown**: marksman
- **JSON/YAML**: jsonls, yamlls

### Full Install

```vim
:lua require("plugins.mason-enhanced").install_all_recommended()
" or use the keymap
<Space>MR
```

## Server-Specific Configuration

### Python (pyright)

**Configuration:**
```lua
settings = {
  python = {
    analysis = {
      typeCheckingMode = "basic",
      autoSearchPaths = true,
      useLibraryCodeForTypes = true,
      diagnosticMode = "workspace",
    },
  },
}
```

**Features:**
- Basic type checking
- Auto path discovery
- Library code type hints
- Workspace diagnostics

### LaTeX (texlab)

**Configuration:**
```lua
settings = {
  texlab = {
    auxDirectory = ".",
    bibtexFormatter = "texlab",
    build = {
      executable = "latexmk",
      args = {
        "-lualatex", "-interaction=nonstopmode",
        "-synctex=1", "-file-line-error", "%f"
      },
      onSave = false,
      forwardSearchAfter = false,
    },
    chktex = { onOpenAndSave = false, onEdit = false },
    diagnosticsDelay = 300,
    formatterLineLength = 80,
    latexFormatter = "latexindent",
  },
}
```

**Features:**
- LuaLaTeX compilation
- Bibliography formatting
- Syntax checking (disabled by default)
- Forward search support

### Lua (lua_ls)

**Configuration:**
```lua
settings = {
  Lua = {
    runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
    diagnostics = { globals = { "vim" } },
    workspace = {
      library = {
        [vim.fn.expand("$VIMRUNTIME/lua")] = true,
        [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
      },
    },
  },
}
```

**Features:**
- Neovim API completion
- LuaJIT runtime support
- Vim global detection

## Manual Server Installation

### Using Mason Interface

```vim
:Mason                    " Open Mason interface
:MasonInstall <server>    " Install specific server
```

### Available Academic Servers

| Language | Server | Description |
|----------|--------|-------------|
| Python | pyright | Microsoft's Python LSP |
| Python | pylsp | Python LSP Server |
| LaTeX | texlab | LaTeX LSP |
| Typst | tinymist | Typst LSP |
| Julia | julials | Julia LSP |
| R | r_language_server | R LSP |
| Lua | lua_ls | Lua LSP |
| Bash | bashls | Bash LSP |
| Markdown | marksman | Markdown LSP |
| JSON | jsonls | JSON LSP |
| YAML | yamlls | YAML LSP |
| HTML | html | HTML LSP |
| CSS | cssls | CSS LSP |

## LSP Keybindings

### Navigation (Built-in Neovim LSP)
```vim
gd          " Go to definition
gD          " Go to declaration
K           " Show hover documentation
```

### Custom LSP Actions
```vim
<Space>Lf   " Format document
<Space>LR   " Show references
<Space>Lr   " Restart LSP
<Space>Ll   " List active LSP servers
<Space>Lm   " Open Mason
```

**Note**: Additional LSP keymaps (code actions, rename, signature help, etc.) are available through Neovim's built-in LSP functionality. Use `:help lsp` for complete LSP keymap reference.

## Troubleshooting

### Server Not Starting

1. **Check Mason Status:**
   ```vim
   :Mason
   :lua require("plugins.mason-enhanced").check_status()
   ```

2. **Restart LSP:**
   ```vim
   :LspRestart
   ```

3. **Check Logs:**
   ```vim
   :LspLog
   ```

### Manual Configuration

Add custom configuration to `lua/plugins/nvim-lspconfig.lua`, which the plugin loader loads. A separate `lua/user-lsp.lua` file must be explicitly loaded with `require("user-lsp")` from that module:

```lua
-- Custom LSP server setup
-- Use the new vim.lsp.config API (Neovim 0.11+)
vim.lsp.config('myserver', {
  cmd = { "my-server", "--stdio" },
  filetypes = { "myfiletype" },
  settings = {
    -- Server-specific settings
  },
})
vim.lsp.enable('myserver')
```

## Advanced Features

### Multi-Server Support

Configure and enable each server using Neovim's native API. Install both server executables first, for example through Mason:

```lua
vim.lsp.config("pyright", {
	settings = {
		python = { analysis = { typeCheckingMode = "basic" } },
	},
})
vim.lsp.enable({ "pyright", "pylsp" })
```

Both servers can attach to Python buffers. Configure their features to avoid duplicate diagnostics or formatting.

### Custom Root Detection

Use root markers to find the project containing the buffer's file:

```lua
vim.lsp.config("pyright", {
	root_markers = { { "pyproject.toml", ".git" } },
})
vim.lsp.enable("pyright")
```

The nested list gives both markers equal priority, selecting the nearest matching ancestor directory.

### Conditional Loading

For per-buffer control, `root_dir` receives a buffer number and an `on_dir` callback. Call the callback only when the server should attach:

```lua
vim.lsp.config("pyright", {
	root_dir = function(bufnr, on_dir)
		local filename = vim.api.nvim_buf_get_name(bufnr)
		local root = vim.fs.root(filename, { "pyproject.toml", ".git" })
		local allowed = vim.fs.normalize(vim.fn.expand("~/myproject"))
		if root and (root == allowed or root:sub(1, #allowed + 1) == allowed .. "/") then
			on_dir(root)
		end
	end,
})
vim.lsp.enable("pyright")
```

Change `~/myproject` to your project directory. This checks the buffer's project rather than Neovim's working directory.

See the [Neovim LSP configuration reference](https://neovim.io/doc/user/lsp#lsp-config) for root detection and activation rules.

## Integration with Other Tools

### With Treesitter
LSP works seamlessly with Treesitter for enhanced syntax highlighting and navigation.

### With Completion
Blink.cmp provides intelligent completion using LSP capabilities.

### With Diagnostics
Trouble.nvim provides enhanced diagnostic display and navigation.
