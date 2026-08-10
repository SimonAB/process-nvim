-- Configuration for Neovim's built-in directory browser (dir.lua)
-- Used when `:edit`ing a directory; nvim-tree remains the sidebar explorer.

local augroup = vim.api.nvim_create_augroup("NvimDirBrowser", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "directory",
	desc = "Tune built-in dir.lua buffers (hybrid with nvim-tree)",
	callback = function(args)
		local bufnr = args.buf
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		-- Drop directory listings once left so they do not clutter the buffer list.
		vim.bo[bufnr].bufhidden = "delete"
		vim.opt_local.cursorline = false
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
	end,
})
