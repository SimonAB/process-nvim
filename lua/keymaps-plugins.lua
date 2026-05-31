-- Plugin Key Mappings
-- Purpose: All plugin-dependent mappings and helper functions (loaded after plugins)

-- This module intentionally contains everything that may require plugins.
-- Core, plugin-independent mappings live in `keymaps-core.lua`.
--
-- Maintenance notes:
-- - Prefer `pcall(require, ...)` for optional plugins to avoid hard startup failures.
-- - If a mapping can be expressed without plugins, put it in `keymaps-core.lua`.
-- - If you want even tighter lazy-loading, split this file further into per-plugin keymap
--   modules and load them in the same phase as their plugin.

local map = vim.keymap.set

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function safe_cmd(cmd)
	return function()
		local success, err = pcall(vim.cmd, cmd)
		if not success then
			vim.notify("Command failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
		end
	end
end

---Return the Obsidian vault path from obsidian.nvim config if available.
---@return string|nil
local function get_obsidian_vault_path()
	local ok, obsidian = pcall(require, "obsidian")
	if not ok then
		return nil
	end
	if not obsidian.config then
		return nil
	end
	local workspaces = obsidian.config.workspaces
	if type(workspaces) ~= "table" then
		return nil
	end
	local workspace = workspaces[1]
	if type(workspace) ~= "table" then
		return nil
	end
	if type(workspace.path) ~= "string" then
		return nil
	end
	return workspace.path
end

local function create_terminal(cmd, opts)
	local Terminal = require("toggleterm.terminal").Terminal
	local default_opts = {
		hidden = true,
		direction = "horizontal",
		close_on_exit = false,
		on_open = function(_)
			vim.cmd("startinsert!")
		end,
	}
	local terminal = Terminal:new(vim.tbl_extend("force", default_opts, opts or {}))
	terminal.cmd = cmd
	return terminal
end

-- VimTeX: custom LuaLaTeX compilation with biber
-- Executes: latexmk → biber → latexmk × 2
-- Reuses a single terminal instance for subsequent compilations.
local latex_compile_terminal = nil

---Return true if a .tex file appears to use biblatex (and therefore biber).
---@param tex_path string
---@return boolean
local function tex_uses_biblatex(tex_path)
	-- Heuristic (intentionally simple): biblatex projects typically contain one or more of:
	-- - \usepackage{biblatex} (with or without options)
	-- - \addbibresource{...}
	-- - \printbibliography
	local ok, lines = pcall(vim.fn.readfile, tex_path)
	if not ok or type(lines) ~= "table" then
		return false
	end
	local text = table.concat(lines, "\n")
	return text:match("\\usepackage%s*(%b%[%])?%s*%{biblatex%}") ~= nil
		or text:match("\\addbibresource%s*%b{}") ~= nil
		or text:match("\\printbibliography") ~= nil
end

---Compile the current .tex file using LuaLaTeX and the correct bibliography tool.
---- biblatex: latexmk → biber → latexmk × 2
---- BibTeX:  lualatex → bibtex → lualatex × 2 (avoids latexmk non-stabilising loops)
local function compile_lualatex_auto_bibtool()
	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("No file is currently open", vim.log.levels.ERROR)
		return
	end

	if vim.fn.fnamemodify(current_file, ":e") ~= "tex" then
		vim.notify("Current file is not a LaTeX file (.tex)", vim.log.levels.ERROR)
		return
	end

	local file_dir = vim.fn.fnamemodify(current_file, ":h")
	local file_base = vim.fn.fnamemodify(current_file, ":t:r")

	local uses_biber = tex_uses_biblatex(current_file)
	local cmd
	if uses_biber then
		cmd = string.format(
			'cd "%s"'
				.. ' && latexmk -pdf -pdflatex=lualatex -synctex=1 -interaction=nonstopmode -file-line-error "%s.tex"'
				.. ' && biber "%s"'
				.. ' && latexmk -pdf -pdflatex=lualatex -synctex=1 -interaction=nonstopmode -file-line-error "%s.tex"'
				.. ' && latexmk -pdf -pdflatex=lualatex -synctex=1 -interaction=nonstopmode -file-line-error "%s.tex"',
			file_dir,
			file_base,
			file_base,
			file_base,
			file_base
		)
		vim.notify("Starting LuaLaTeX compilation: latexmk → biber → latexmk × 2", vim.log.levels.INFO)
	else
		cmd = string.format(
			'cd "%s"'
				.. ' && lualatex -synctex=1 -interaction=nonstopmode -file-line-error "%s.tex"'
				.. ' && bibtex "%s"'
				.. ' && lualatex -synctex=1 -interaction=nonstopmode -file-line-error "%s.tex"'
				.. ' && lualatex -synctex=1 -interaction=nonstopmode -file-line-error "%s.tex"',
			file_dir,
			file_base,
			file_base,
			file_base,
			file_base
		)
		vim.notify("Starting LuaLaTeX compilation: lualatex → bibtex → lualatex × 2", vim.log.levels.INFO)
	end

	if latex_compile_terminal == nil then
		local Terminal = require("toggleterm.terminal").Terminal
		latex_compile_terminal = Terminal:new({
			hidden = true,
			direction = "horizontal",
			size = 15,
			close_on_exit = false,
			on_open = function(term)
				vim.cmd("stopinsert")
				local opts = { buffer = term.bufnr, noremap = true, silent = true }
				vim.keymap.set("n", "q", "<cmd>close<CR>", opts)
				vim.keymap.set("n", "<C-h>", "<C-w>h", opts)
				vim.keymap.set("n", "<C-j>", "<C-w>j", opts)
				vim.keymap.set("n", "<C-k>", "<C-w>k", opts)
				vim.keymap.set("n", "<C-l>", "<C-w>l", opts)
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					vim.notify("✓ LuaLaTeX compilation complete", vim.log.levels.INFO)
				else
					vim.notify("✗ LuaLaTeX compilation failed (exit " .. exit_code .. ")", vim.log.levels.ERROR)
				end
			end,
		})
	end

	if not latex_compile_terminal:is_open() then
		latex_compile_terminal:open()
	end

	latex_compile_terminal:send(cmd)
end

---Return a best-effort Git root, falling back to the current working directory.
---@return string
local function get_project_root()
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if not git_root or git_root == "" or git_root:match("fatal:") then
		return vim.loop.cwd() or vim.fn.getcwd()
	end
	return git_root
end

local function buffer_operation(bufferline_cmd, fallback_cmd)
	return function()
		local success = pcall(vim.cmd, bufferline_cmd)
		if not success then
			vim.cmd(fallback_cmd)
		end
	end
end

local function toggle_zen_mode()
	local ok, zen_mode = pcall(require, "zen-mode")
	if not ok then
		vim.notify("zen-mode.nvim not available", vim.log.levels.WARN)
		return
	end
	zen_mode.toggle()
end

---Safely call an obsidian.nvim util operation if available.
---@param operation_name string
---@return fun()
local function obsidian_operation(operation_name)
	return function()
		local ok, obsidian = pcall(require, "obsidian")
		if ok and obsidian.util and obsidian.util[operation_name] then
			obsidian.util[operation_name]()
			return
		end
		vim.notify("Obsidian operation '" .. operation_name .. "' not available", vim.log.levels.WARN)
	end
end

---Paste an image into the Obsidian vault and insert a link, then add two blank lines.
---Prefers obsidian.nvim's own paste command/utilities; falls back to pngpaste on macOS.
local function paste_obsidian_image()
	local used_obsidian = false

	if vim.fn.exists(":ObsidianPasteImg") == 2 then
		local ok = pcall(vim.cmd, "ObsidianPasteImg")
		if ok then
			used_obsidian = true
		end
	else
		local ok, obsidian = pcall(require, "obsidian")
		if ok then
			if obsidian.util and type(obsidian.util) == "table" then
				if type(obsidian.util.paste_img_and_link) == "function" then
					pcall(obsidian.util.paste_img_and_link)
					used_obsidian = true
				elseif type(obsidian.util.paste_img) == "function" then
					pcall(obsidian.util.paste_img)
					used_obsidian = true
				end
			end
			if (not used_obsidian) and obsidian.commands and type(obsidian.commands) == "table" then
				if type(obsidian.commands.paste_img) == "function" then
					pcall(obsidian.commands.paste_img)
					used_obsidian = true
				end
			end
		end
	end

	if used_obsidian then
		vim.cmd("put =''")
		vim.cmd("put =''")
		return
	end

	local vault_path = get_obsidian_vault_path()
	if not vault_path then
		vim.notify("Obsidian vault path not available", vim.log.levels.ERROR)
		return
	end

	local attachments_dir = vault_path .. "/attachments"
	vim.fn.mkdir(attachments_dir, "p")

	local filename = os.date("%Y%m%d-%H%M%S") .. ".png"
	local fullpath = attachments_dir .. "/" .. filename

	local cmd = string.format('pngpaste "%s"', fullpath)
	vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify(
			"Failed to paste image: pngpaste not available or clipboard is not an image",
			vim.log.levels.ERROR
		)
		return
	end

	local link_line = string.format("![%s](<../attachments/%s>)", filename, filename)
	vim.api.nvim_put({ link_line, "", "" }, "l", true, true)
end

---Safely call a quarto-nvim operation if available.
---@param operation_name string
---@return fun()
local function quarto_operation(operation_name)
	return function()
		local ok, quarto = pcall(require, "quarto")
		if ok and quarto[operation_name] then
			quarto[operation_name]()
			return
		end
		vim.notify("Quarto operation '" .. operation_name .. "' not available", vim.log.levels.WARN)
	end
end

---Build jobstart options for non-interactive Quarto renders.
---@param format_name string
---@return table
local function build_quarto_job_opts(format_name)
	return {
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				vim.notify("✓ " .. format_name .. " render complete", vim.log.levels.INFO)
			else
				vim.notify("✗ " .. format_name .. " render failed (exit " .. exit_code .. ")", vim.log.levels.ERROR)
			end
		end,
		on_stderr = function(_, data)
			if not data or #data == 0 then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					print(line)
				end
			end
		end,
		env = {
			TERM = "dumb",
			NONINTERACTIVE = "1",
			PAGER = "cat",
			MANPAGER = "cat",
			LESS = "-R",
			MORE = "-R",
		},
	}
end

---Render the current Quarto document to a specific format.
---@param format string
---@param format_name string
---@return fun()
local function quarto_render_to_format(format, format_name)
	return function()
		local file = vim.fn.expand("%:p")
		if file == "" then
			vim.notify("No file to render", vim.log.levels.WARN)
			return
		end

		local cmd = { "quarto", "render", file, "--to", format }
		if format == "pdf" then
			table.insert(cmd, "--pdf-engine-opt=-interaction=nonstopmode")
		end

		vim.notify("Rendering to " .. format_name .. "...", vim.log.levels.INFO)
		vim.fn.jobstart(cmd, build_quarto_job_opts(format_name))
	end
end

---Render all Quarto documents in the current project.
local function quarto_render_all()
	vim.notify("Rendering all files in project...", vim.log.levels.INFO)
	vim.fn.jobstart({ "quarto", "render" }, build_quarto_job_opts("Project"))
end

---Toggle a vertical terminal: hide if visible, otherwise show/create.
local function toggle_terminal_vertical_smart()
	if vim.fn.mode() == "t" then
		vim.cmd("stopinsert")
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
			pcall(vim.api.nvim_win_close, win, true)
			return
		end
	end

	local existing_terminal_buf = nil
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
				existing_terminal_buf = buf
				break
			end
		end
	end

	if existing_terminal_buf then
		vim.cmd("vsplit")
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, existing_terminal_buf)
		vim.cmd("startinsert")
		return
	end

	local size = math.floor(vim.o.columns * 0.3)
	vim.cmd("ToggleTerm direction=vertical size=" .. size)
end

---Clear the first visible terminal buffer (or current one if already in terminal).
local function clear_terminal()
	local current_win = vim.api.nvim_get_current_win()
	local terminal_win = nil
	local terminal_buf = nil

	if vim.bo.buftype == "terminal" then
		terminal_win = current_win
		terminal_buf = vim.api.nvim_get_current_buf()
	else
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
				terminal_win = win
				terminal_buf = buf
				break
			end
		end
	end

	if not (terminal_win and terminal_buf) then
		print("No terminal window found - open a terminal first")
		return
	end

	local original_win = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(terminal_win)
	vim.cmd("startinsert")
	vim.api.nvim_feedkeys("clear", "t", false)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "t", false)

	if original_win ~= terminal_win then
		vim.schedule(function()
			pcall(vim.api.nvim_set_current_win, original_win)
		end)
	end
	print("Terminal cleared")
end

---Kill the first visible terminal buffer (or current one if already in terminal).
local function kill_terminal()
	local terminal_buf = nil

	if vim.bo.buftype == "terminal" then
		terminal_buf = vim.api.nvim_get_current_buf()
	else
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_get_option(buf, "buftype") == "terminal" then
				terminal_buf = buf
				break
			end
		end
	end

	if not terminal_buf then
		print("No terminal window found")
		return
	end

	vim.api.nvim_buf_delete(terminal_buf, { force = true })
	print("Terminal killed")
end

local julia_repl_terminal = nil

---Open a Julia REPL in a ToggleTerm window.
---@param direction "horizontal"|"vertical"|"float"
local function open_julia_repl(direction)
	local project_path = vim.fn.shellescape(vim.fn.getcwd())
	local julia_repl = create_terminal("julia --project=" .. project_path .. " --threads=auto", {
		direction = direction,
	})
	julia_repl_terminal = julia_repl
	julia_repl:toggle()
end

---Run a Julia command in a terminal using the current project.
---@param command string
---@return fun()
local function julia_command(command)
	return function()
		local project_path = vim.fn.shellescape(vim.fn.getcwd())
		local julia_cmd = "julia --project=" .. project_path .. " --threads=auto -e '" .. command .. "'"
		local terminal = create_terminal(julia_cmd, { direction = "horizontal", close_on_exit = false })
		terminal:toggle()
	end
end

local typst_project = require("core.typst-project")

---Compile the current Typst file to PDF using the CLI (`typst compile --root …`).
local function typst_compile_current()
	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("No file is currently open", vim.log.levels.ERROR)
		return
	end

	if vim.fn.fnamemodify(current_file, ":e") ~= "typ" then
		vim.notify("Current file is not a Typst file (.typ)", vim.log.levels.ERROR)
		return
	end

	local root, rel_input = typst_project.root_and_input(current_file)
	local cmd = string.format('typst compile --root "%s" "%s"', root, rel_input)

	vim.fn.jobstart(cmd, {
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				vim.notify("PDF compiled successfully", vim.log.levels.INFO)
			else
				vim.notify("Failed to compile PDF", vim.log.levels.ERROR)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				vim.notify("Typst compilation error: " .. table.concat(data, " "), vim.log.levels.ERROR)
			end
		end,
	})
end

---Open ToggleTerm with `typst w` for the current Typst file.
local function typst_watch_current()
	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("No file is currently open", vim.log.levels.ERROR)
		return
	end

	if vim.fn.fnamemodify(current_file, ":e") ~= "typ" then
		vim.notify("Current file is not a Typst file (.typ)", vim.log.levels.ERROR)
		return
	end

	local root, rel_input = typst_project.root_and_input(current_file)
	local cmd = string.format('typst watch --root "%s" "%s"', root, rel_input)

	local Terminal = require("toggleterm.terminal").Terminal
	local typst_watch = Terminal:new({
		cmd = cmd,
		dir = root,
		hidden = true,
		direction = "horizontal",
		close_on_exit = false,
		on_open = function(_)
			vim.cmd("startinsert!")
		end,
	})
	typst_watch:toggle()
end

-- ============================================================================
-- PLUGIN-DEPENDENT KEYMAPS
-- ============================================================================

local filetype_keymaps_group = vim.api.nvim_create_augroup("FiletypeKeymaps", { clear = true })

-- Buffer Operations (<leader>B)
map("n", "<leader>Bf", "<cmd>Telescope buffers<CR>", { desc = "Find buffers (Telescope)" })
map("n", "<leader>Bp", "<cmd>BufferLinePick<CR>", { desc = "Pick buffer" })
map("n", "<leader>Bb", buffer_operation("BufferLineCyclePrev", "bprevious"), { desc = "Previous buffer" })
map("n", "<leader>Bn", buffer_operation("BufferLineCycleNext", "bnext"), { desc = "Next buffer" })
map("n", "<leader>Bq", buffer_operation("BufferLineClose", "bdelete"), { desc = "Close buffer" })
map("n", "<leader>Bl", "<cmd>ls!<CR>", { desc = "List all buffers (including unlisted)" })

-- Toggle Zen Mode
map("n", "<leader>Yz", toggle_zen_mode, { desc = "Toggle Zen Mode" })

-- Theme management (deferred)
local function show_theme_picker()
	vim.defer_fn(function()
		local ok, ThemeManager = pcall(require, "core.theme-manager")
		if ok and ThemeManager.show_theme_picker then
			ThemeManager.show_theme_picker()
		else
			vim.notify("Theme Picker not available", vim.log.levels.WARN)
		end
	end, 50)
end

local function cycle_colorscheme()
	vim.defer_fn(function()
		local ok, ThemeManager = pcall(require, "core.theme-manager")
		if ok and ThemeManager.cycle_theme then
			ThemeManager.cycle_theme()
		else
			local colorschemes = { "catppuccin", "onedark", "tokyonight", "nord", "github_dark" }
			local current = vim.g.colors_name or "default"
			local current_index = 1
			for i, scheme in ipairs(colorschemes) do
				if scheme == current then
					current_index = i
					break
				end
			end
			local next_index = current_index % #colorschemes + 1
			local next_scheme = colorschemes[next_index]
			local success = pcall(vim.cmd.colorscheme, next_scheme)
			if success then
				vim.notify("Switched to " .. next_scheme .. " theme", vim.log.levels.INFO)
			else
				vim.notify("Failed to switch to " .. next_scheme .. " theme", vim.log.levels.WARN)
			end
		end
	end, 50)
end

map("n", "<leader>Yc", cycle_colorscheme, { desc = "Cycle themes" })
map("n", "<leader>YTp", show_theme_picker, { desc = "Theme picker" })
map("n", "<leader>YTs", function()
	local current = vim.g.colors_name or "default"
	vim.notify("Current theme: " .. current, vim.log.levels.INFO)
end, { desc = "Show current theme" })

-- CodeCompanion / AI (<leader>A)
map("n", "<leader>Ac", safe_cmd("CodeCompanionChat"), { desc = "AI: Chat (default adapter)" })
map("n", "<leader>At", safe_cmd("CodeCompanionChat Toggle"), { desc = "AI: Toggle chat" })
map("n", "<leader>Ad", safe_cmd("CodeCompanionChat Debug"), { desc = "AI: Chat debug" })
map("n", "<leader>Ao", safe_cmd("CodeCompanionChat adapter=ollama"), { desc = "AI: Chat (Ollama)" })

-- File tree / Telescope / Search
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<leader>f", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>R", "<cmd>Telescope frecency<CR>", { desc = "Find files (by frequency/recency)" })
map("n", "<leader>Rf", "<cmd>Telescope frecency<CR>", { desc = "Find files (frecency)" })
map("n", "<leader>Rr", function()
	require("telescope").extensions.frecency.frecency()
end, { desc = "Refresh frecency database" })
map("n", "<leader>Rd", function()
	local db_root = vim.fn.stdpath("state")
	print("Frecency DB root: " .. db_root)
	print("  - " .. db_root .. "/file_frecency.bin")
	print("  - " .. db_root .. "/file_frecency_v2.bin")
end, { desc = "Show frecency database location" })
map("n", "<leader>Rb", function()
	local db_root = vim.fn.stdpath("state")
	vim.fn.delete(db_root .. "/file_frecency.bin")
	vim.fn.delete(db_root .. "/file_frecency_v2.bin")
	vim.fn.delete(db_root .. "/file_frecency.bin.lock")
	vim.fn.delete(db_root .. "/file_frecency_v2.bin.lock")
	print("Frecency database deleted. It will rebuild as you use it.")
end, { desc = "Rebuild frecency database" })

-- Git
map("n", "<leader>Gs", safe_cmd("!git status"), { desc = "Git Status" })
map("n", "<leader>Gp", safe_cmd("!git pull"), { desc = "Git Pull" })

map("n", "<leader>Gg", function()
	local lazygit = create_terminal("lazygit", {
		dir = "git_dir",
		direction = "float",
		float_opts = {
			border = "curved",
			width = function()
				return math.floor(vim.o.columns * 0.9)
			end,
			height = function()
				return math.floor(vim.o.lines * 0.9)
			end,
		},
		close_on_exit = true,
		env = {
			TERM = "xterm-256color",
			COLORTERM = "truecolor",
			EDITOR = "nvim --clean",
			GIT_EDITOR = "nvim --clean",
			NVIM = "",
			NVIM_LISTEN_ADDRESS = "",
		},
		on_open = function(term)
			vim.cmd("startinsert!")
			vim.keymap.set("t", "<esc>", "<esc>", { buffer = term.bufnr })
		end,
		on_close = function()
			vim.cmd("stopinsert")
		end,
	})
	lazygit:toggle()
end, { desc = "LazyGit" })

-- Terminal

---Find a running Julia terminal job and return its channel id.
---Prefers terminal buffers whose name includes "julia".
---@return integer|nil
local function get_julia_terminal_job_id()
	if julia_repl_terminal and julia_repl_terminal.bufnr and vim.api.nvim_buf_is_valid(julia_repl_terminal.bufnr) then
		local job_id = vim.b[julia_repl_terminal.bufnr].terminal_job_id
		if type(job_id) == "number" and job_id > 0 then
			return job_id
		end
	end

	local fallback_job_id = nil

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
			local job_id = vim.b[buf].terminal_job_id
			if type(job_id) == "number" and job_id > 0 then
				local name = vim.api.nvim_buf_get_name(buf) or ""
				if name:match("julia") then
					return job_id
				end
				fallback_job_id = fallback_job_id or job_id
			end
		end
	end

	return fallback_job_id
end

---Send text to the Julia REPL as bracketed paste.
---This prevents REPL line-editing features from mutating the payload (e.g. auto-closing `[`).
---@param text string
local function send_to_julia_repl(text)
	local job_id = get_julia_terminal_job_id()
	if not job_id then
		vim.notify("No Julia terminal found (open one with <leader>Jr*)", vim.log.levels.WARN)
		return
	end

	-- Bracketed paste: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html (2004/2005)
	local payload = "\27[200~" .. text .. "\27[201~"
	vim.api.nvim_chan_send(job_id, payload)
end

---True when `line` starts a VS Code–style cell marker (`# %%`, `#%%`, optional spaces).
---@param line string|nil
---@return boolean
local function is_percent_cell_marker_line(line)
	if not line then
		return false
	end
	return line:match("^#%s*%%%%") ~= nil
end

---Bounds of the `# %%` cell containing `current_line` (body only, markers excluded).
---@param lines string[]
---@param current_line integer
---@return integer|nil body_start
---@return integer|nil body_end
---@return integer|nil jump_after_send first line of the next cell body, if any
local function resolve_percent_cell_range(lines, current_line)
	if current_line < 1 or current_line > #lines then
		return nil, nil, nil
	end

	local any_marker = false
	for i = 1, #lines do
		if is_percent_cell_marker_line(lines[i]) then
			any_marker = true
			break
		end
	end
	if not any_marker then
		return nil, nil, nil
	end

	if is_percent_cell_marker_line(lines[current_line]) then
		local body_start = current_line + 1
		local body_end = #lines
		for j = current_line + 1, #lines do
			if is_percent_cell_marker_line(lines[j]) then
				body_end = j - 1
				break
			end
		end
		if body_start > body_end then
			return nil, nil, nil
		end
		local jump_after = nil
		for j = body_end + 1, #lines do
			if is_percent_cell_marker_line(lines[j]) then
				jump_after = j + 1
				break
			end
		end
		if jump_after and jump_after > #lines then
			jump_after = nil
		end
		return body_start, body_end, jump_after
	end

	local prev_marker = nil
	for i = current_line - 1, 1, -1 do
		if is_percent_cell_marker_line(lines[i]) then
			prev_marker = i
			break
		end
	end

	local body_start = prev_marker and (prev_marker + 1) or 1

	local next_marker = nil
	for j = current_line + 1, #lines do
		if is_percent_cell_marker_line(lines[j]) then
			next_marker = j
			break
		end
	end

	local body_end = next_marker and (next_marker - 1) or #lines

	if body_start > body_end or current_line < body_start or current_line > body_end then
		return nil, nil, nil
	end

	local jump_after = nil
	if next_marker then
		jump_after = next_marker + 1
		if jump_after > #lines then
			jump_after = nil
		end
	end

	return body_start, body_end, jump_after
end

---Send the current code block to ToggleTerm (best effort).
---Supports Quarto/R Markdown fences (```{...}), VS Code–style cells (`# %%`), and header blocks (## ...).
local function send_current_code_block()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_line = cursor[1]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local start_line = nil
	local end_line = nil
	local block_type = nil -- "fenced" | "percent" | "header"
	local percent_jump = nil

	local fenced_start = nil
	local fenced_end = nil

	for i = current_line, 1, -1 do
		if lines[i] and lines[i]:match("^```{.*}") then
			fenced_start = i
			break
		end
	end

	if fenced_start then
		for i = current_line, #lines do
			if lines[i] and lines[i]:match("^```%s*$") then
				fenced_end = i
				break
			end
		end
	end

	if fenced_start and fenced_end and current_line > fenced_start and current_line < fenced_end then
		start_line = fenced_start
		end_line = fenced_end
		block_type = "fenced"
	else
		local ps, pe, pj = resolve_percent_cell_range(lines, current_line)
		if ps and pe then
			start_line = ps
			end_line = pe
			block_type = "percent"
			percent_jump = pj
		else
			local header_start = nil
			local header_end = nil

			for i = current_line, 1, -1 do
				if lines[i] and lines[i]:match("^##") then
					header_start = i
					break
				end
			end

			if header_start then
				for i = header_start + 1, #lines do
					if lines[i] and lines[i]:match("^##") then
						header_end = i - 1
						break
					end
				end
				if not header_end then
					header_end = #lines
				end
			end

			if header_start and header_end and current_line >= header_start and current_line <= header_end then
				start_line = header_start
				end_line = header_end
				block_type = "header"
			end
		end
	end

	if not (start_line and end_line and start_line <= end_line) then
		vim.notify("No code block found around cursor", vim.log.levels.WARN)
		return
	end

	local selection_start, selection_end
	if block_type == "fenced" then
		selection_start = start_line + 1
		selection_end = end_line - 1
	elseif block_type == "percent" then
		selection_start = start_line
		selection_end = end_line
	else
		selection_start = start_line
		selection_end = end_line
	end

	if selection_start > selection_end then
		vim.notify("Empty code block", vim.log.levels.WARN)
		return
	end

	local code_lines = {}
	for i = selection_start, selection_end do
		code_lines[#code_lines + 1] = lines[i] or ""
	end
	send_to_julia_repl(table.concat(code_lines, "\n") .. "\n")

	local next_block_start = nil
	if block_type == "percent" and percent_jump then
		next_block_start = percent_jump
	else
		local search_start = end_line + 1

		for i = search_start, #lines do
			if lines[i] and lines[i]:match("^```{.*}") then
				next_block_start = i + 1
				break
			end
		end

		if not next_block_start then
			for i = search_start, #lines do
				if lines[i] and is_percent_cell_marker_line(lines[i]) then
					next_block_start = i + 1
					break
				end
			end
		end

		if not next_block_start then
			for i = search_start, #lines do
				if lines[i] and lines[i]:match("^##") then
					next_block_start = i
					break
				end
			end
		end
	end

	if next_block_start then
		vim.api.nvim_win_set_cursor(0, { next_block_start, 0 })
	end
end

---Yank the current code chunk (fenced or `# %%` cell), excluding delimiter lines.
---Supports Quarto (```{lang}), Markdown fences (```lang / ```), and VS Code–style `# %%` cells.
local function yank_code_chunk()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_line = cursor[1]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local fenced_start = nil
	local fenced_end = nil

	local function is_opening_delimiter(line)
		if not line then
			return false
		end
		if line:match("^```{.*}") then
			return true
		end
		return line:match("^```") ~= nil
	end

	local function is_closing_delimiter(line)
		if not line then
			return false
		end
		return line:match("^```%s*$") ~= nil
	end

	local is_on_opening = is_opening_delimiter(lines[current_line])
	local is_on_closing = is_closing_delimiter(lines[current_line])

	if is_on_opening then
		fenced_start = current_line
	elseif is_on_closing then
		for i = current_line - 1, 1, -1 do
			if is_opening_delimiter(lines[i]) then
				fenced_start = i
				break
			end
		end
		if fenced_start then
			fenced_end = current_line
		end
	else
		for i = current_line, 1, -1 do
			if is_opening_delimiter(lines[i]) then
				fenced_start = i
				break
			end
		end
	end

	if fenced_start and not fenced_end then
		for i = fenced_start + 1, #lines do
			if is_closing_delimiter(lines[i]) then
				fenced_end = i
				break
			end
		end
	end

	if fenced_start and fenced_end and fenced_start < fenced_end then
		local code_start = fenced_start + 1
		local code_end = fenced_end - 1
		if code_start > code_end then
			vim.notify("Empty code chunk", vim.log.levels.WARN)
			return
		end

		local code_lines = {}
		for i = code_start, code_end do
			table.insert(code_lines, lines[i])
		end
		local code_content = table.concat(code_lines, "\n") .. "\n"

		vim.fn.setreg('"', code_content)
		vim.fn.setreg("+", code_content)
		vim.fn.setreg("*", code_content)

		vim.notify(
			("Yanked code chunk (%d lines)"):format(code_end - code_start + 1),
			vim.log.levels.INFO
		)
		return
	end

	local ps, pe = resolve_percent_cell_range(lines, current_line)
	if ps and pe then
		local code_lines = {}
		for i = ps, pe do
			table.insert(code_lines, lines[i])
		end
		local code_content = table.concat(code_lines, "\n") .. "\n"

		vim.fn.setreg('"', code_content)
		vim.fn.setreg("+", code_content)
		vim.fn.setreg("*", code_content)

		vim.notify(
			("Yanked code chunk (%d lines)"):format(pe - ps + 1),
			vim.log.levels.INFO
		)
		return
	end

	vim.notify("No code chunk found around cursor", vim.log.levels.WARN)
end

---Open ToggleTerm with a consistent direction/size.
---@param direction "horizontal"|"vertical"|"float"
---@param size integer|nil
local function open_terminal(direction, size)
	if direction == "horizontal" then
		vim.cmd("ToggleTerm direction=horizontal size=" .. tostring(size or 15))
		return
	end

	if direction == "vertical" then
		local width = size or math.floor(vim.o.columns * 0.3)
		vim.cmd("ToggleTerm direction=vertical size=" .. tostring(width))
		return
	end

	vim.cmd("ToggleTerm direction=float")
end

map("n", "<C-t>", "<esc><cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
map("t", "<C-t>", "<C-\\><C-N><cmd>ToggleTerm<CR>", { desc = "Toggle terminal from terminal" })
map("t", "<Esc>", "<C-\\><C-N>", { desc = "Exit terminal mode" })

map("n", "<C-i>", function()
	send_to_julia_repl(vim.api.nvim_get_current_line() .. "\n")
	pcall(vim.cmd, "normal! j")
end, { desc = "Send current line to Julia REPL" })
map("n", "<C-c>", send_current_code_block, { desc = "Send current code block to Julia REPL" })
map("v", "<C-s>", function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line = start_pos[2]
	local end_line = end_pos[2]
	if start_line < 1 or end_line < 1 or end_line < start_line then
		vim.notify("Invalid selection", vim.log.levels.WARN)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local selected = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	send_to_julia_repl(table.concat(selected, "\n") .. "\n")
end, { desc = "Send selection to Julia REPL" })

map("n", "yic", yank_code_chunk, { desc = "Yank code chunk" })

map({ "n", "t" }, "<A-1>", function()
	open_terminal("horizontal", 15)
end, { desc = "Terminal horizontal (15 lines)" })
map({ "n", "t" }, "<A-2>", function()
	open_terminal("vertical")
end, { desc = "Terminal vertical" })
map({ "n", "t" }, "<A-3>", function()
	open_terminal("float")
end, { desc = "Terminal float" })

map({ "n", "t" }, "<M-1>", function()
	open_terminal("horizontal", 15)
end, { desc = "Terminal horizontal (15 lines, Meta)" })
map({ "n", "t" }, "<M-2>", function()
	open_terminal("vertical")
end, { desc = "Terminal vertical (Meta)" })
map({ "n", "t" }, "<M-3>", function()
	open_terminal("float")
end, { desc = "Terminal float (Meta)" })

map({ "n", "t" }, "<leader>Tt", toggle_terminal_vertical_smart, { desc = "Toggle terminal (vertical)" })
map({ "n", "t" }, "<leader>Th", function()
	vim.cmd("ToggleTerm direction=horizontal size=15")
end, { desc = "Terminal horizontal" })
map({ "n", "t" }, "<leader>Tv", function()
	local size = math.floor(vim.o.columns * 0.3)
	vim.cmd("ToggleTerm direction=vertical size=" .. size)
end, { desc = "Terminal vertical" })
map({ "n", "t" }, "<leader>Tf", function()
	vim.cmd("ToggleTerm direction=float")
end, { desc = "Terminal float" })
map("n", "<leader>Tk", clear_terminal, { desc = "Clear terminal" })
map("n", "<leader>Td", kill_terminal, { desc = "Kill terminal" })

-- Search (Telescope)
map("n", "<leader>g", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end
	builtin.live_grep({ cwd = get_project_root() })
end, { desc = "Grep in project" })

map("n", "<leader>Sp", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end
	builtin.live_grep({ cwd = get_project_root() })
end, { desc = "Search in project" })

map("n", "<leader>Sw", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end
	builtin.live_grep({ cwd = vim.loop.cwd() or vim.fn.getcwd() })
end, { desc = "Search in working directory" })

map("n", "<leader>Sh", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end
	local home = vim.loop.os_homedir() or vim.fn.expand("~")
	builtin.live_grep({ search_dirs = { home } })
end, { desc = "Search in home directory" })

map("n", "<leader>Sc", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end
	builtin.live_grep({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search in config" })

map("n", "<leader>Sf", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end

	local current_file = vim.fn.expand("%:p")
	if current_file ~= "" then
		local current_dir = vim.fn.fnamemodify(current_file, ":h")
		builtin.live_grep({ cwd = current_dir })
	else
		builtin.live_grep()
	end
end, { desc = "Search in current file directory" })

-- Config (Telescope)
map("n", "<leader>Cf", function()
	local config_path = vim.fn.stdpath("config")
	vim.cmd("Telescope find_files cwd=" .. config_path)
end, { desc = "Find config files" })

map("n", "<leader>Cg", function()
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end
	builtin.live_grep({ cwd = vim.fn.stdpath("config") })
end, { desc = "Grep config files" })

-- Trouble diagnostics
map("n", "<leader>Xw", ":TroubleToggle workspace_diagnostics<CR>", { desc = "Workspace Diagnostics" })
map("n", "<leader>Xd", ":TroubleToggle document_diagnostics<CR>", { desc = "Document Diagnostics" })
map("n", "<leader>Xl", ":TroubleToggle loclist<CR>", { desc = "Location List" })
map("n", "<leader>Xq", ":TroubleToggle quickfix<CR>", { desc = "Quickfix" })

-- Mason
map("n", "<leader>Mm", "<cmd>Mason<CR>", { desc = "Open Mason" })
map("n", "<leader>Mi", "<cmd>MasonInstall<CR>", { desc = "Install Package" })
map("n", "<leader>Mu", "<cmd>MasonUninstall<CR>", { desc = "Uninstall Package" })
map("n", "<leader>Ml", "<cmd>MasonLog<CR>", { desc = "View Mason Log" })
map("n", "<leader>Mh", "<cmd>MasonHelp<CR>", { desc = "Mason Help" })

map("n", "<leader>Lm", "<cmd>Mason<CR>", { desc = "LSP: Open Mason" })

-- Markdown preview
map("n", "<leader>Kp", "<cmd>MarkdownPreview<CR>", { desc = "Start Markdown Preview" })
map("n", "<leader>Ks", "<cmd>MarkdownPreviewStop<CR>", { desc = "Stop Markdown Preview" })
map("n", "<leader>Kv", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })

-- Quarto
map("n", "<leader>Qp", quarto_operation("quartoPreview"), { desc = "Quarto preview" })
map("n", "<leader>Qc", quarto_operation("quartoClosePreview"), { desc = "Close Quarto preview" })
map("n", "<leader>QRh", quarto_render_to_format("html", "HTML"), { desc = "Render to HTML" })
map("n", "<leader>QRp", quarto_render_to_format("pdf", "PDF"), { desc = "Render to PDF" })
map("n", "<leader>QRw", quarto_render_to_format("docx", "Word"), { desc = "Render to Word" })
map("n", "<leader>QRa", quarto_render_all, { desc = "Render all" })

-- Molten
local molten_commands = {
	["<leader>QMi"] = { cmd = "MoltenImagePopup", desc = "Show image popup" },
	["<leader>QMl"] = { cmd = "MoltenEvaluateLine", desc = "Evaluate line" },
	["<leader>QMe"] = { cmd = "MoltenEvaluateOperator", desc = "Evaluate operator" },
	["<leader>QMn"] = { cmd = "MoltenInit", desc = "Initialise kernel" },
	["<leader>QMk"] = { cmd = "MoltenDeinit", desc = "Stop kernel" },
	["<leader>QMr"] = { cmd = "MoltenRestart", desc = "Restart kernel" },
	["<leader>QMo"] = { cmd = "MoltenEvaluateOperator", desc = "Evaluate operator" },
	["<leader>QM<CR>"] = { cmd = "MoltenEvaluateLine", desc = "Evaluate line" },
	["<leader>QMv"] = { cmd = "MoltenEvaluateVisual", desc = "Evaluate visual selection" },
	["<leader>QMf"] = { cmd = "MoltenReevaluateCell", desc = "Re-evaluate cell" },
	["<leader>QMh"] = { cmd = "MoltenHideOutput", desc = "Hide output" },
	["<leader>QMs"] = { cmd = "MoltenShowOutput", desc = "Show output" },
	["<leader>QMd"] = { cmd = "MoltenDelete", desc = "Delete cell" },
	["<leader>QMb"] = { cmd = "MoltenOpenInBrowser", desc = "Open in browser" },
}

for key, data in pairs(molten_commands) do
	map("n", key, safe_cmd(data.cmd), { desc = data.desc })
end

-- Julia
map("n", "<leader>Jrh", function()
	open_julia_repl("horizontal")
end, { desc = "Julia REPL (horizontal)" })

map("n", "<leader>Jrv", function()
	open_julia_repl("vertical")
end, { desc = "Julia REPL (vertical)" })

map("n", "<leader>Jrf", function()
	open_julia_repl("float")
end, { desc = "Julia REPL (floating)" })

map("n", "<leader>Jp", julia_command("using Pkg; Pkg.status()"), { desc = "Julia: Project status" })
map("n", "<leader>Ji", julia_command("using Pkg; Pkg.instantiate()"), { desc = "Julia: Instantiate project" })
map("n", "<leader>Ju", julia_command("using Pkg; Pkg.update()"), { desc = "Julia: Update project" })
map("n", "<leader>Jt", julia_command("using Pkg; Pkg.test()"), { desc = "Julia: Run tests" })
map("n", "<leader>Jd", julia_command("using Pkg; using Documenter; makedocs()"), { desc = "Julia: Generate docs" })

-- Filetype-specific (localleader) mappings
vim.api.nvim_create_autocmd("FileType", {
	group = filetype_keymaps_group,
	pattern = "tex",
	desc = "VimTeX localleader mappings",
	callback = function(args)
		local bufnr = args.buf
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		-- Ensure VimTeX is loaded before setting <Plug> mappings.
		vim.cmd("silent! packadd vimtex")

		map("n", "<localleader>ll", "<Plug>(vimtex-compile)", { buffer = bufnr, desc = "Compile" })
		map("n", "<localleader>lb", compile_lualatex_auto_bibtool, { buffer = bufnr, desc = "Compile LuaLaTeX (auto BibTeX/biber)" })
		map("n", "<localleader>lv", "<Plug>(vimtex-view)", { buffer = bufnr, desc = "View PDF" })
		map("n", "<localleader>lk", "<Plug>(vimtex-stop)", { buffer = bufnr, desc = "Stop" })
		map("n", "<localleader>lK", "<Plug>(vimtex-stop-all)", { buffer = bufnr, desc = "Stop all" })
		map("n", "<localleader>lc", "<Plug>(vimtex-clean)", { buffer = bufnr, desc = "Clean aux" })
		map("n", "<localleader>lC", "<Plug>(vimtex-clean-full)", { buffer = bufnr, desc = "Clean full" })
		map("n", "<localleader>le", "<Plug>(vimtex-errors)", { buffer = bufnr, desc = "Errors" })
		map("n", "<localleader>lo", "<Plug>(vimtex-compile-output)", { buffer = bufnr, desc = "Output" })
		map("n", "<localleader>lg", "<Plug>(vimtex-status)", { buffer = bufnr, desc = "Status" })
		map("n", "<localleader>lG", "<Plug>(vimtex-status-all)", { buffer = bufnr, desc = "Status all" })
		map("n", "<localleader>lt", "<Plug>(vimtex-toc-open)", { buffer = bufnr, desc = "TOC" })
		map("n", "<localleader>lT", "<Plug>(vimtex-toc-toggle)", { buffer = bufnr, desc = "TOC toggle" })
		map("n", "<localleader>lq", "<Plug>(vimtex-log)", { buffer = bufnr, desc = "Log" })
		map("n", "<localleader>li", "<Plug>(vimtex-info)", { buffer = bufnr, desc = "Info" })
		map("n", "<localleader>lI", "<Plug>(vimtex-info-full)", { buffer = bufnr, desc = "Info full" })
		map("n", "<localleader>lx", "<Plug>(vimtex-reload)", { buffer = bufnr, desc = "Reload" })
		map("n", "<localleader>lX", "<Plug>(vimtex-reload-state)", { buffer = bufnr, desc = "Reload state" })
		map("n", "<localleader>la", "<Plug>(vimtex-context-menu)", { buffer = bufnr, desc = "Context menu" })
		map("n", "<localleader>lm", "<Plug>(vimtex-imaps-list)", { buffer = bufnr, desc = "Insert mode maps" })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = filetype_keymaps_group,
	pattern = { "typst", "typ" },
	desc = "Typst localleader mappings",
	callback = function(args)
		local bufnr = args.buf
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		map("n", "<localleader>tp", function()
			if vim.fn.exists(":TypstPreviewToggle") == 2 then
				pcall(vim.cmd, "TypstPreviewToggle")
				return
			end
			local ok = pcall(require, "typst-preview")
			if not ok then
				vim.notify("typst-preview.nvim not available", vim.log.levels.WARN)
			end
		end, { buffer = bufnr, desc = "Typst preview: Toggle" })

		map("n", "<localleader>ts", function()
			if vim.fn.exists(":TypstPreviewSyncCursor") == 2 then
				pcall(vim.cmd, "TypstPreviewSyncCursor")
				return
			end
			local ok, tp = pcall(require, "typst-preview")
			if ok and tp.sync_with_cursor then
				pcall(tp.sync_with_cursor)
				return
			end
			vim.notify("Typst preview sync not available", vim.log.levels.WARN)
		end, { buffer = bufnr, desc = "Typst preview: Sync cursor" })

		map("n", "<localleader>tc", typst_compile_current, { buffer = bufnr, desc = "Compile PDF (typst c)" })

		map("n", "<localleader>tw", typst_watch_current, { buffer = bufnr, desc = "Watch file (typst w)" })
	end,
})

-- Obsidian
map("n", "<leader>On", obsidian_operation("new_note"), { desc = "New Obsidian note" })
map("n", "<leader>Ol", obsidian_operation("insert_link"), { desc = "Insert Obsidian link" })
map("n", "<leader>Of", obsidian_operation("follow_link"), { desc = "Follow Obsidian link" })
map("n", "<leader>Oc", obsidian_operation("toggle_checkbox"), { desc = "Toggle Obsidian checkbox" })
map("n", "<leader>Ob", obsidian_operation("show_backlinks"), { desc = "Show Obsidian backlinks" })
map("n", "<leader>Og", obsidian_operation("show_outgoing_links"), { desc = "Show Obsidian outgoing links" })

map("n", "<leader>Oo", function()
	local ok, telescope = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope.nvim not available", vim.log.levels.WARN)
		return
	end

	local vault_path = get_obsidian_vault_path()
	if not vault_path then
		vim.notify("Obsidian vault path not available", vim.log.levels.ERROR)
		return
	end

	telescope.find_files({
		cwd = vault_path,
		prompt_title = "Obsidian Vault",
	})
end, { desc = "Find files in Obsidian vault" })

map("n", "<leader>Ot", safe_cmd("ObsidianTemplate"), { desc = "Insert Obsidian template" })
map("n", "<leader>ON", safe_cmd("ObsidianNewFromTemplate"), { desc = "New note from template" })
map("n", "<leader>Op", paste_obsidian_image, { desc = "Paste image and add two lines" })
map("n", "<leader>Ov", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Obsidian preview" })

-- Obsidian callouts
-- Insert Obsidian-style callout blocks (https://help.obsidian.md/callouts).
-- The `!` sub-prefix mirrors the `[!type]` syntax used in callouts.
-- Normal mode: insert an empty callout below the current line and place the
--   cursor inside the body, ready for typing.
-- Visual mode: wrap the selected lines inside a callout block.

---List of Obsidian callout types mapped to a sub-key under `<leader>O!`.
---@type { key: string, type: string, desc: string }[]
local obsidian_callouts = {
	{ key = "n", type = "note",     desc = "Note" },
	{ key = "a", type = "abstract", desc = "Abstract" },
	{ key = "i", type = "info",     desc = "Info" },
	{ key = "o", type = "todo",     desc = "Todo" },
	{ key = "t", type = "tip",      desc = "Tip" },
	{ key = "s", type = "success",  desc = "Success" },
	{ key = "q", type = "question", desc = "Question" },
	{ key = "w", type = "warning",  desc = "Warning" },
	{ key = "f", type = "failure",  desc = "Failure" },
	{ key = "d", type = "danger",   desc = "Danger" },
	{ key = "b", type = "bug",      desc = "Bug" },
	{ key = "e", type = "example",  desc = "Example" },
	{ key = "Q", type = "quote",    desc = "Quote" },
}

---Return whether the given buffer is safe to modify.
---@param bufnr integer
---@return boolean
local function is_buffer_writable(bufnr)
	return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modifiable and not vim.bo[bufnr].readonly
end

---Validate that `callout_type` is one of the registered Obsidian callout types.
---@param callout_type string
---@return boolean
local function is_valid_callout_type(callout_type)
	for _, callout in ipairs(obsidian_callouts) do
		if callout.type == callout_type then
			return true
		end
	end
	return false
end

---Insert an Obsidian-style callout block below the current line and position
---the cursor at the end of the body line in insert mode. The user can edit
---the title by escaping to normal mode and pressing `kA`.
---@param callout_type string Callout type identifier (e.g. "note", "warning").
local function insert_obsidian_callout(callout_type)
	local bufnr = vim.api.nvim_get_current_buf()
	if not is_buffer_writable(bufnr) then
		return
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local header = "> [!" .. callout_type .. "] "
	local body = "> "
	vim.api.nvim_buf_set_lines(bufnr, row, row, false, { header, body })

	vim.api.nvim_win_set_cursor(0, { row + 2, #body })
	vim.cmd("startinsert!")
end

---Wrap a line range inside an Obsidian-style callout block.
---
---Modal-editing notes:
--- - This function is invoked from a user command bound to a `:`-style RHS in
---   visual mode. Pressing `:` in visual mode auto-inserts `'<,'>` as the
---   range, exits visual mode for cmdline, then returns to normal mode after
---   `<CR>`. The range arrives here as `line1` / `line2`, fully resolved by
---   Vim, so we never need to inspect visual marks or call `feedkeys`.
--- - V-line and V-block both reduce to a contiguous line range when consumed
---   as a `:` command range, which is the correct shape for a blockquote
---   callout (whole-line wrap).
---@param callout_type string Callout type identifier (e.g. "note", "warning").
---@param line1 integer 1-indexed first line of the range (inclusive).
---@param line2 integer 1-indexed last line of the range (inclusive).
local function wrap_obsidian_callout_range(callout_type, line1, line2)
	local bufnr = vim.api.nvim_get_current_buf()
	if not is_buffer_writable(bufnr) then
		return
	end
	if not is_valid_callout_type(callout_type) then
		vim.notify("Unknown Obsidian callout type: " .. tostring(callout_type), vim.log.levels.ERROR)
		return
	end
	if line1 < 1 or line2 < line1 then
		vim.notify("Invalid range for Obsidian callout wrap", vim.log.levels.WARN)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
	local header = "> [!" .. callout_type .. "] "
	local wrapped = { header }
	for _, line in ipairs(lines) do
		table.insert(wrapped, "> " .. line)
	end
	vim.api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, wrapped)

	-- Land at the end of the header so the user can append a title with `a`
	-- or `A`, keeping the operation discoverable via normal-mode motions.
	vim.api.nvim_win_set_cursor(0, { line1, #header })
end

vim.api.nvim_create_user_command("ObsidianCalloutWrap", function(opts)
	wrap_obsidian_callout_range(opts.fargs[1], opts.line1, opts.line2)
end, {
	range = true,
	nargs = 1,
	complete = function()
		local names = {}
		for _, callout in ipairs(obsidian_callouts) do
			table.insert(names, callout.type)
		end
		return names
	end,
	desc = "Wrap range inside an Obsidian callout block",
})

for _, callout in ipairs(obsidian_callouts) do
	local lhs = "<leader>O!" .. callout.key
	map("n", lhs, function()
		insert_obsidian_callout(callout.type)
	end, { desc = "Callout: " .. callout.desc })

	-- Use a `:`-style RHS so Vim performs the standard visual→cmdline→normal
	-- modal transition. The `'<,'>` range is auto-inserted by `:` in visual
	-- mode and consumed by `:ObsidianCalloutWrap`, which the user command
	-- declares via `range = true`. This avoids `<Cmd>`/`feedkeys` workarounds.
	map("x", lhs,
		string.format(":ObsidianCalloutWrap %s<CR>", callout.type),
		{ silent = true, desc = "Wrap selection in " .. callout.desc .. " callout" })
end

-- Enhanced plugin manager keybindings
local function call_plugin_manager(func_name)
	local ok, PluginManager = pcall(require, "core.plugin-manager")
	if ok then
		PluginManager[func_name](PluginManager)
	else
		vim.notify("Plugin Manager not available", vim.log.levels.WARN)
	end
end

map("n", "<leader>CUa", function()
	call_plugin_manager("update_all_plugins")
end, { desc = "Update All Plugins" })
map("n", "<leader>CUs", function()
	call_plugin_manager("show_status")
end, { desc = "Plugin Status" })
map("n", "<leader>CUc", function()
	call_plugin_manager("cleanup_orphaned")
end, { desc = "Cleanup Orphaned Plugins" })

return {}

