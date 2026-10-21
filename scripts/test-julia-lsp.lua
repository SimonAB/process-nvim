-- Julia LSP integration check using the normal Neovim configuration.
-- Run: nvim --headless -n -i NONE -c 'luafile scripts/test-julia-lsp.lua'

local clients = {}
local test_dir = vim.fn.tempname() .. [[ Julia's $project]]
local function check()
	vim.fn.mkdir(test_dir, 'p')
	vim.fn.writefile({ 'sin(1.0)' }, test_dir .. '/smoke.jl')
	vim.cmd.edit(vim.fn.fnameescape(test_dir .. '/smoke.jl'))
	local ready = vim.wait(60000, function()
		clients = vim.lsp.get_clients({ name = 'julials', bufnr = 0 })
		return clients[1] and clients[1].initialized
	end, 100)
	assert(ready, 'Julia LSP did not initialise; inspect :LspLog')
	assert(#clients == 1, 'Expected exactly one Julia client')
	local client = clients[1]
	assert(vim.uv.fs_realpath(client.config.cmd[#client.config.cmd]) == vim.uv.fs_realpath(test_dir),
		'Incorrect project argument: ' .. vim.inspect(client.config.cmd))
	assert(client.config.cmd[#client.config.cmd - 1]:find('LanguageServer.runserver()', 1, true),
		'Use the documented LanguageServer entry point')
	local response = client:request_sync('textDocument/hover', {
		textDocument = { uri = vim.uri_from_bufnr(0) },
		position = { line = 0, character = 1 },
	}, 30000, 0)
	assert(response and not response.err and response.result,
		'Julia hover failed or timed out')
	local contents = response.result.contents
	assert(contents and vim.inspect(contents):lower():find('sine', 1, true),
		'Expected sin documentation')
	print('Julia LSP: initialisation, project path and hover passed')
end

local ok, err = xpcall(check, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients({ name = 'julials' })) do
	client:stop(true)
end
-- Let Neovim release workspace watchers before removing their directory.
vim.wait(3000, function()
	return #vim.lsp.get_clients({ name = 'julials' }) == 0
end, 50)
vim.fn.delete(test_dir, 'rf')
if not ok then
	vim.api.nvim_err_writeln(err)
	os.exit(1)
else
	vim.cmd('qa!')
end
