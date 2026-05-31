---Resolve Typst project root for monorepos (e.g. Institut Eléazar Cours).
local M = {}

---@param path_of_main_file string
---@return string
function M.find_root(path_of_main_file)
	local env_root = os.getenv("TYPST_ROOT")
	if env_root and env_root ~= "" then
		return vim.fn.fnamemodify(env_root, ":p")
	end

	local dir = vim.fn.fnamemodify(path_of_main_file, ":p:h")
	while dir and dir ~= "/" do
		if vim.fn.filereadable(dir .. "/typst.toml") == 1 then
			return dir
		end
		if vim.fn.isdirectory(dir .. "/shared/typst") == 1 then
			return dir
		end
		dir = vim.fn.fnamemodify(dir, ":h")
	end

	return vim.fn.fnamemodify(path_of_main_file, ":p:h")
end

---@param current_file string
---@return string root, string input absolute path to main file
function M.root_and_input(current_file)
	local root = M.find_root(current_file)
	return root, vim.fn.fnamemodify(current_file, ":p")
end

return M
