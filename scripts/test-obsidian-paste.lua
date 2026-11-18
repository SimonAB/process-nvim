-- Check image-paste success and failure without touching the system clipboard or vault.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.g.mapleader = " "

local messages = {}
vim.notify = function(message)
	table.insert(messages, tostring(message))
end
dofile("lua/keymaps-plugins.lua")
local paste = vim.fn.maparg("<leader>Op", "n", false, true).callback
assert(type(paste) == "function", "Image paste remains discoverable through its keymap")

---Reset the buffer and replace the plugin command with a controlled outcome.
---@param callback function
local function reset_command(callback)
	pcall(vim.api.nvim_del_user_command, "ObsidianPasteImg")
	vim.api.nvim_create_user_command("ObsidianPasteImg", callback, {})
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Original text" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	messages = {}
end

-- Obsidian reports empty clipboards without raising a Lua exception.
reset_command(function()
	vim.notify("There is no image data in the clipboard")
end)
paste()
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "Original text" }),
	"A declined paste must not add blank lines")
assert(messages[1] == "There is no image data in the clipboard")

reset_command(function()
	error("clipboard export failed")
end)
paste()
assert(vim.api.nvim_buf_line_count(0) == 1, "A failed paste must leave the buffer alone")
assert(table.concat(messages, "\n"):find("clipboard export failed", 1, true),
	"The original command error must be visible")

reset_command(function()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "![image](<../attachments/image.png>)" })
end)
paste()
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
	"![image](<../attachments/image.png>)", "", "",
}), "A successful image paste adds exactly two blank lines")
print("Obsidian paste: empty clipboard, command error and successful insertion passed")
