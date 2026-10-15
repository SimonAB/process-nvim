-- =============================================================================
-- DASHBOARD WIDTH
-- PURPOSE: Fit dashboard labels to the window without changing file actions
-- =============================================================================

local DashboardWidth = {}

---Shorten from the left, preserving the filename and whole Unicode characters.
---@param text string Full display label
---@param limit integer Available display cells
---@return string label
function DashboardWidth.shorten(text, limit)
	limit = math.max(1, limit)
	if vim.fn.strdisplaywidth(text) <= limit then
		return text
	end
	local chars = vim.fn.strchars(text)
	local first = chars
	local suffix = ""
	while first > 0 do
		local candidate = vim.fn.strcharpart(text, first - 1)
		if vim.fn.strdisplaywidth("…" .. candidate) > limit then
			break
		end
		first = first - 1
		suffix = candidate
	end
	return "…" .. suffix
end

---Fit item labels before alignment, using about 70% of the window width.
---@param content table mini.starter content units
---@param bufnr integer Dashboard buffer
---@return table content
function DashboardWidth.fit_content(content, bufnr)
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 or not vim.api.nvim_win_is_valid(win) then
		return content
	end
	local limit = math.max(5, math.floor(vim.api.nvim_win_get_width(win) * 0.7) - 2)
	for _, line in ipairs(content) do
		for _, unit in ipairs(line) do
			if unit.type == "item" then
				local prefix = unit.string:match("^[%w]%.  ") or ""
				local label = unit.string:sub(#prefix + 1)
				unit.string = prefix .. DashboardWidth.shorten(label, limit - #prefix)
			end
		end
	end
	return content
end

return DashboardWidth
