-- Configuration for Typst file navigation
-- Let native gf find code snippets stored alongside a shared lecture theme.

local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:h')
while dir and dir ~= '' do
	local snippets = dir .. '/teaching/lectures/snippets'
	if vim.fn.isdirectory(snippets) == 1 then
		vim.opt_local.path:append(vim.fn.escape(snippets, ' ,\\'))
		break
	end
	local parent = vim.fn.fnamemodify(dir, ':h')
	if parent == dir then
		break
	end
	dir = parent
end
