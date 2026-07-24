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

Create `~/.config/nvim/lua/user-lsp.lua`:

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

Configure multiple servers for the same language:

```lua
-- In mason-lspconfig handlers
["python"] = function()
  lspconfig.pyright.setup({
    -- Primary server config
  })
end

lspconfig.pylsp.setup({
  -- Secondary server config
})
```

### Custom Root Detection

```lua
root_dir = function(fname)
  return lspconfig.util.root_pattern(".git", "pyproject.toml")(fname) or
         lspconfig.util.path.dirname(fname)
end
```

### Conditional Loading

```lua
-- Only load in specific directories
lspconfig.pyright.setup({
  root_dir = function(fname)
    return vim.fn.getcwd():match("myproject") and
           lspconfig.util.find_git_ancestor(fname)
  end,
})
```

## Integration with Other Tools

### With Treesitter
LSP works seamlessly with Treesitter for enhanced syntax highlighting and navigation.

### With Completion
Blink.cmp provides intelligent completion using LSP capabilities.

### With Diagnostics
Trouble.nvim provides enhanced diagnostic display and navigation.
