-- Verify shared selections, live refresh and fallback without changing user settings.
vim.opt.rtp:prepend(vim.fn.getcwd())
local path = vim.fn.tempname()
vim.env.SHARED_THEME_FILE = path
local ok, shared = pcall(require, 'core.shared-theme')
assert(ok, 'Shared theme module loads')
assert(shared.read() == nil, 'Missing selection preserves existing defaults')
vim.fn.writefile({ vim.json.encode({ theme = 'catppuccin', appearance = 'light',
	nvim = { light = 'catppuccin', dark = 'catppuccin' } }) }, path)
local selection = assert(shared.read())
assert(selection.appearance == 'light')
local settings = require('core.theme-settings')
assert(settings.get_default_theme('dark') == 'catppuccin')
local manager = require('core.theme-manager')
manager.get_active_theme({ appearance = 'dark' })
assert(vim.o.background == 'light', 'Explicit selection overrides OS callbacks')
assert(vim.env.JULIA_REPL_THEME == 'light', 'Julia appearance follows effective selection')
local loaded
package.loaded['core.theme-manager'] = { load_immediate = function() loaded = true end }
shared.setup()
vim.fn.writefile({ vim.json.encode({ theme = 'flexoki', appearance = 'dark',
	nvim = { light = 'flexoki-light', dark = 'flexoki-dark' } }) }, path)
assert(vim.wait(2500, function() return loaded end), 'Running editor refreshes')
assert(settings.get_default_theme('light') == 'flexoki-light')
vim.fn.writefile({ '{broken' }, path)
assert(shared.read() == nil, 'Malformed selection falls back safely')
vim.fn.delete(path)
print('Shared theme selection, live refresh and fallback passed')
vim.cmd('qa!')
