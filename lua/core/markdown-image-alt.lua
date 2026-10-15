-- =============================================================================
-- MARKDOWN IMAGE ALT TEXT
-- PURPOSE: Fill empty image descriptions from filenames during Markdown saves
-- =============================================================================

local MarkdownImageAlt = {}
local image_query
local has_warned = false

---Derive a Markdown-safe filename stem while leaving the destination untouched.
---@param destination string Markdown link destination, possibly angle-delimited
---@return string|nil label
local function filename_label(destination)
	local path = destination:gsub("^<", ""):gsub(">$", ""):gsub("[?#].*$", "")
	local name = path:match("([^/]+)$")
	if not name then
		return nil
	end
	name = name:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
	name = name:gsub("%.[^%.]+$", ""):gsub("%s+", " ")
	if name == "" then
		return nil
	end
	return (name:gsub("([\\%[%]`*_])", "\\%1"))
end

---Fill missing inline image descriptions using the incremental Markdown parser.
---Treesitter excludes frontmatter, code blocks, inline code and HTML comments.
---@param bufnr integer Buffer to update
---@return integer count Number of descriptions inserted
function MarkdownImageAlt.apply(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].modifiable
		or vim.bo[bufnr].readonly or vim.bo[bufnr].buftype ~= "" then
		return 0
	end
	local ok, edits = pcall(function()
		local parser = vim.treesitter.get_parser(bufnr, "markdown")
		image_query = image_query or vim.treesitter.query.parse("markdown_inline", "(image) @image")
		parser:parse(true)
		local changes = {}
		parser:for_each_tree(function(tree, language)
			if language:lang() ~= "markdown_inline" or language:parent() ~= parser then
				return
			end
			for _, node in image_query:iter_captures(tree:root(), bufnr) do
				local destination, description, closing
				for child in node:iter_children() do
					if child:type() == "link_destination" then
						destination = vim.treesitter.get_node_text(child, bufnr)
					elseif child:type() == "image_description" then
						description = vim.treesitter.get_node_text(child, bufnr)
					elseif child:type() == "]" then
						closing = { child:range() }
					end
				end
				if destination and closing and (not description or description:match("^%s*$")) then
					local label = filename_label(destination)
					if label then
						local row, col = node:range()
						table.insert(changes, {
							row = row, col = col + 2, end_row = closing[1],
							end_col = closing[2], label = label,
						})
					end
				end
			end
		end)
		return changes
	end)
	if not ok then
		if not has_warned then
			vim.notify("Markdown image labels require the Markdown Treesitter parsers: "
				.. tostring(edits), vim.log.levels.WARN)
			has_warned = true
		end
		return 0
	end
	table.sort(edits, function(a, b)
		return a.row > b.row or (a.row == b.row and a.col > b.col)
	end)
	if #edits > 0 then
		vim.api.nvim_buf_call(bufnr, function()
			local view = vim.fn.winsaveview()
			for _, edit in ipairs(edits) do
				pcall(vim.cmd, "undojoin")
				vim.api.nvim_buf_set_text(bufnr, edit.row, edit.col,
					edit.end_row, edit.end_col, { edit.label })
			end
			vim.fn.winrestview(view)
		end)
	end
	return #edits
end

---Install lightweight save-time cleanup for Markdown and related documents.
function MarkdownImageAlt.setup()
	local group = vim.api.nvim_create_augroup("MarkdownImageAlt", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		pattern = { "*.md", "*.markdown", "*.Rmd", "*.qmd" },
		desc = "Fill empty image descriptions from filenames",
		callback = function(args)
			MarkdownImageAlt.apply(args.buf)
		end,
	})
end

return MarkdownImageAlt
