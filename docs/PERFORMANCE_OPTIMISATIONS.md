# Neovim Performance Optimisations

## Overview

This page records current file-discovery behaviour alongside earlier startup measurements. The historical startup benchmark reported a **17 ms improvement** (from 105 ms to 88 ms); those figures have not been remeasured for the current plugin set.

## Historical startup results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Startup Time | 105ms | 88ms | -17ms (-16%) |
| Plugin Loading | 79ms | 63ms | -16ms (-20%) |
| Core Config | 26ms | 2ms | -24ms (-92%) |

## Key Optimisations Implemented

### 1. Deferred Initialisation

**Problem**: Heavy operations were blocking startup
**Solution**: Use `vim.defer_fn()` to defer non-critical initialisations

```lua
-- Before: Immediate loading
local ThemeManager = require("core.theme-manager")
ThemeManager.init()

-- After: Deferred loading
vim.defer_fn(function()
    local ThemeManager = require("core.theme-manager")
    ThemeManager.init()
end, 50)
```

**Impact**: Reduced core config loading from 26ms to 2ms

### 2. Lazy Plugin Loading

**Problem**: All plugins loaded synchronously during startup
**Solution**: Implement staged plugin loading with deferred configurations

```lua
-- Critical plugins loaded immediately
vim.cmd("packadd nvim-lspconfig")
vim.cmd("packadd mason.nvim")

-- Other plugins loaded asynchronously
vim.defer_fn(function()
    local plugin_configs = {
        "plugins.blink-cmp",
        "plugins.nvim-treesitter",
        -- ... other plugins
    }

    for _, config in ipairs(plugin_configs) do
        pcall(require, config)
    end
end, 100)
```

**Impact**: Reduced plugin loading overhead by 20%

### 3. Background dashboard discovery and caching

Recursive recent files are discovered by `core.dashboard-files` using `rg --files --null`. Discovery runs asynchronously, followed by a pool of at most 16 outstanding metadata requests. Leading candidates are checked for readable text until five files are found. No synchronous per-file walk runs on the editor thread.

Results are cached for ten seconds per directory. Concurrent requests share a scan, and previous results remain available during refresh. Saves and renames invalidate caches; generation checks prevent an invalidated scan from publishing stale results. Old completed entries are pruned with a target of eight cached directories; in-flight work may temporarily exceed that count. File labels are resized independently of discovery.

A local synthetic benchmark with 3,000 text files measured:

| Operation | Time |
| --- | --- |
| Previous blocking dashboard scan | 38.55 ms |
| New cold request returning to the caller | 0.89 ms |
| Background results available after the request | 31.46 ms |
| Cached request | 0.17 ms |

These are filesystem-cache-dependent local measurements, not whole-editor startup timings or performance guarantees. Exact modification ordering still requires metadata for every discovered candidate, and sorting remains on the main thread after asynchronous collection. The main benefit is keeping discovery and file I/O off the interactive path.

### 4. File search and Markdown cleanup

`<leader>f` keeps Telescope's standard discovery and exclusions. The picker-session sorter caches modification-date scores per candidate, avoiding repeated metadata reads when the query is cleared. Non-empty queries delegate directly to the configured native FZF sorter. Initial metadata reads in this picker remain synchronous; very large or slow directory trees can still cost time.

Markdown image-label cleanup uses Neovim's incremental Markdown parser and edits only missing descriptions. It starts no Python process, invokes no language model and makes no network request. It runs on save; large documents still incur parser work.

For recent project history, the existing dashboard helper checks at most ten oldfile entries and uses a two-minute in-memory cache. This is separate from the ten-second recursive file cache.

### 5. Consolidated Autocommands

**Problem**: Multiple autocmd registrations during startup
**Solution**: Single autocmd for multiple filetypes

```lua
-- Before: Multiple autocmds
vim.api.nvim_create_autocmd("FileType", { pattern = "tex", ... })
vim.api.nvim_create_autocmd("FileType", { pattern = "julia", ... })

-- After: Single autocmd
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "tex", "julia", "python", "r", "qmd" },
    callback = function(args)
        local ft = args.match
        if ft == "tex" then
            vim.g.vimtex_enabled = 1
        end
    end,
})
```

**Impact**: Reduced autocmd registration overhead

### 6. Deferred Theme Management

**Problem**: Theme manager initialisation blocking startup
**Solution**: Defer theme operations until after startup

```lua
-- OPTIMISED: Defer heavy initialisations
vim.defer_fn(function()
    local ThemeManager = require("core.theme-manager")
    ThemeManager.init()
end, 50)
```

**Impact**: Non-blocking theme initialisation

## Performance Monitoring

### Performance Test Script

A comprehensive performance test script is available at `scripts/performance_test.lua`:

```lua
-- Run performance analysis
local perf = require("scripts.performance_test")
perf.generate_report()
```

### Startup Time Measurement

Use Neovim's built-in startup time measurement:

```bash
nvim --headless --startuptime /tmp/startup.log -c "quit"
```

### Key Metrics to Monitor

1. **Total startup time**: Target < 100ms
2. **Plugin loading time**: Target < 70ms
3. **Core config loading**: Target < 5ms
4. **Module loading times**: Identify slow modules (>10ms)
5. **Plugin loading times**: Identify slow plugins (>5ms)

## Best Practices

### 1. Use Deferred Loading

```lua
-- For non-critical operations
vim.defer_fn(function()
    -- Heavy operation here
end, delay_ms)
```

### 2. Implement Caching

```lua
-- Cache expensive operations
local cache = {}
local cache_ttl = 300000 -- 5 minutes

function expensive_operation()
    local now = vim.loop.now()
    if cache.data and (now - cache.timestamp) < cache_ttl then
        return cache.data
    end
    -- ... perform operation and cache result
end
```

### 3. Limit File System Operations

```lua
-- Limit the scope of file operations
local max_files = math.min(#files, 100)
for i = 1, max_files do
    -- Process file
end
```

### 4. Use pcall for Error Handling

```lua
-- Graceful error handling
local ok, result = pcall(require, "plugin")
if not ok then
    vim.notify("Plugin not available", vim.log.levels.WARN)
end
```

### 5. Consolidate Autocommands

```lua
-- Single autocmd for multiple patterns
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "pattern1", "pattern2", "pattern3" },
    callback = function(args)
        local ft = args.match
        -- Handle different filetypes
    end,
})
```

## Future Optimisations

### 1. Plugin Lazy Loading

Consider implementing true lazy loading for plugins that are only used in specific contexts:

```lua
-- Example: Load LSP only for supported filetypes
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "lua", "python", "javascript" },
    callback = function()
        vim.lsp.enable('lua_ls')
    end,
})
```

### 2. Conditional Plugin Loading

Load plugins based on project type or file presence:

```lua
-- Load Julia-specific plugins only in Julia projects
if vim.fn.filereadable("Project.toml") == 1 then
    require("julia-vim")
end
```

### 3. Profile-Guided Optimisation

Use profiling tools to identify remaining bottlenecks:

```lua
-- Enable profiling
vim.cmd("profile start profile.log")
vim.cmd("profile func *")
vim.cmd("profile file *")
```

## Conclusion

The implemented optimisations provide a significant improvement in startup time while maintaining full functionality. The key principles are:

1. **Defer non-critical operations**
2. **Cache expensive computations**
3. **Limit file system operations**
4. **Consolidate similar operations**
5. **Use graceful error handling**

These optimisations ensure a fast, responsive Neovim experience while preserving all features and functionality.
