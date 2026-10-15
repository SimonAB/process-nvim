-- Verify filename-derived image labels without changing code or authored text.
vim.opt.rtp:prepend(vim.fn.getcwd())
local alt = require("core.markdown-image-alt")
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.bo.filetype = "markdown"
local lines = {
	"---", 'example: "![](frontmatter.png)"', "---", "",
	"![](<../attachments/Pasted image 20260930141915.png>)",
	"![Existing description](keep.png)",
	'![](figures/immune_response%20day-7.png "Original title")',
	"`![](inline.png)`", "", "```markdown", "![](fenced.png)", "```", "",
	"    ![](indented.png)", "",
	"<!-- ![](comment.png) -->", "",
	"![]()", "![](https://example.org/fig%5B1%5D.svg?download=true#part)",
}
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
assert(alt.apply(buf) == 3, "Fill only three unlabelled prose images")
local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
assert(result[5] == "![Pasted image 20260930141915](<../attachments/Pasted image 20260930141915.png>)")
assert(result[6] == lines[6], "Preserve authored descriptions")
assert(result[7] == '![immune\\_response day-7](figures/immune_response%20day-7.png "Original title")')
for _, i in ipairs({2, 8, 11, 14, 16, 18}) do
	assert(result[i] == lines[i], "Preserve non-prose or empty target at line " .. i)
end
assert(result[19] == "![fig\\[1\\]](https://example.org/fig%5B1%5D.svg?download=true#part)")
assert(alt.apply(buf) == 0, "Repeat saves must be idempotent")
-- Reverse-position edits must handle several links on one line safely.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"![](one.png) and ![   ](two.png)"})
assert(alt.apply(buf) == 2)
assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "![one](one.png) and ![two](two.png)")
vim.bo[buf].modifiable = false
assert(alt.apply(buf) == 0, "Skip unmodifiable buffers")
vim.bo[buf].modifiable = true
-- Exercise the save event on a disposable file.
alt.setup()
local path = vim.fn.tempname() .. ".md"
vim.cmd.edit(path)
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"![](save.png)"})
vim.cmd.write()
assert(vim.fn.readfile(path)[1] == "![save](save.png)", "Save hook fills missing alt text")
vim.fn.delete(path)
print("Markdown image labels, code exclusions and save hook passed")
vim.cmd("qa!")
