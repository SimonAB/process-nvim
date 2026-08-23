-- Configuration for Forge — local kanban project manager (Finder tags)
-- Provides keymaps, Telescope pickers, and terminal integration

local Platform = require("core.platform")

local M = {}

local FORGE_DIR = Platform.forge_dir()
local SETUP_SCRIPT = FORGE_DIR .. "/setup.sh"

--- Project root: git root from current buffer/cwd, or directory of current file, or cwd.
---@return string
local function project_root()
	local start = ""
	local buf = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(buf)
	if path and path ~= "" then
		start = vim.fn.fnamemodify(path, ":p:h")
	else
		start = vim.fn.getcwd()
	end
	local root = vim.fn.trim(vim.fn.system("git -C " .. vim.fn.shellescape(start) .. " rev-parse --show-toplevel 2>/dev/null"))
	if root and root ~= "" and vim.fn.isdirectory(root) == 1 then
		return root
	end
	return start
end

--- Check whether the forge CLI is available on PATH.
---@return boolean
function M.is_available()
	return vim.fn.executable("forge") == 1
end

--- Check whether Forge.app is installed (macOS only).
---@return boolean
function M.is_app_installed()
	return Platform.is_macos() and vim.fn.isdirectory("/Applications/Forge.app") == 1
end

--- Check whether setup.sh exists in the Forge directory.
---@return boolean
function M.has_setup_script()
	return vim.fn.filereadable(SETUP_SCRIPT) == 1
end

--- Run a forge CLI command in a horizontal terminal (read-only output).
---@param cmd string shell command to execute
---@param opts? table toggleterm overrides
local function forge_terminal(cmd, opts)
	local ok, Terminal = pcall(function()
		return require("toggleterm.terminal").Terminal
	end)
	if not ok then
		vim.notify("toggleterm not available", vim.log.levels.WARN)
		return
	end

	local default_opts = {
		cmd = cmd,
		hidden = true,
		direction = "horizontal",
		size = 18,
		close_on_exit = false,
		on_open = function(term)
			vim.cmd("stopinsert")
			local buf_opts = { buffer = term.bufnr, noremap = true, silent = true }
			vim.keymap.set("n", "q", "<cmd>close<CR>", buf_opts)
		end,
	}

	local term = Terminal:new(vim.tbl_extend("force", default_opts, opts or {}))
	term:toggle()
end

--- Run an interactive forge command in a vertical terminal.
---@param cmd string shell command to execute
local function forge_interactive(cmd)
	forge_terminal(cmd, {
		direction = "vertical",
		size = math.floor(vim.o.columns * 0.4),
		on_open = function(term)
			vim.cmd("startinsert!")
		end,
	})
end

--- Open a Forge area file by name.
---@param filename string e.g. "inbox.md"
local function open_forge_file(filename)
	local path = FORGE_DIR .. "/" .. filename
	if vim.fn.filereadable(path) == 1 then
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	else
		vim.notify("File not found: " .. path, vim.log.levels.WARN)
	end
end

--- Telescope picker scoped to the Forge directory.
---@param picker string telescope builtin name
---@param prompt string prompt title
local function forge_telescope(picker, prompt)
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		vim.notify("telescope not available", vim.log.levels.WARN)
		return
	end
	builtin[picker]({ cwd = FORGE_DIR, prompt_title = prompt })
end

-- ===========================================================================
-- KEYMAPS
-- ===========================================================================

--- Prompt for a string; returns nil if cancelled/empty.
---@param prompt string
---@return string|nil
local function prompt_string(prompt)
	local ok, input = pcall(vim.fn.input, prompt)
	if not ok then return nil end
	if not input or vim.trim(input) == "" then return nil end
	return vim.trim(input)
end

--- Move the current project (git root or cwd) to a column.
local function move_current_project()
	local root = project_root()
	local column = prompt_string("Move project to column: ")
	if not column then return end
	forge_terminal("forge move " .. vim.fn.shellescape(root) .. " " .. vim.fn.shellescape(column))
end

--- Apply or remove a tag from the current project (git root or cwd).
---@param action "add"|"remove"
local function tag_current_project(action)
	local root = project_root()
	local tag = prompt_string(("Tag to %s: "):format(action))
	if not tag then return end
	forge_terminal("forge project-tag " .. action .. " " .. vim.fn.shellescape(root) .. " " .. vim.fn.shellescape(tag))
end

function M.setup_keymaps()
	local map = vim.keymap.set

	-- View commands (read-only terminal output)
	map("n", "<leader>Fs", function()
		forge_terminal("forge status")
	end, { desc = "Status" })

	map("n", "<leader>Fb", function()
		forge_terminal("forge board --list")
	end, { desc = "Kanban board" })

	map("n", "<leader>Fp", function()
		forge_terminal("forge project-tag list " .. vim.fn.shellescape(project_root()))
	end, { desc = "Project tags (current project)" })

	map("n", "<leader>Ft", function()
		forge_terminal("forge calendar")
	end, { desc = "Calendar (read-only)" })

	-- Project operations (interactive)
	map("n", "<leader>Fm", function()
		move_current_project()
	end, { desc = "Move current project to column" })

	map("n", "<leader>Fa", function()
		tag_current_project("add")
	end, { desc = "Add tag to current project" })

	map("n", "<leader>Fr", function()
		tag_current_project("remove")
	end, { desc = "Remove tag from current project" })

	-- File access
	map("n", "<leader>Fi", function()
		open_forge_file("inbox.md")
	end, { desc = "Open inbox" })

	-- Telescope: browse area files
	map("n", "<leader>Ff", function()
		forge_telescope("find_files", "Forge Files")
	end, { desc = "Find Forge files" })

	-- Telescope: search across all Forge files
	map("n", "<leader>Fg", function()
		forge_telescope("live_grep", "Search Forge")
	end, { desc = "Grep Forge files" })
end

-- ===========================================================================
-- SETUP
-- ===========================================================================

--- Run setup.sh in a full-screen terminal so the user can watch the build.
function M.run_setup()
	if not M.has_setup_script() then
		vim.notify("setup.sh not found at " .. SETUP_SCRIPT, vim.log.levels.ERROR)
		return
	end

	local ok, Terminal = pcall(function()
		return require("toggleterm.terminal").Terminal
	end)
	if not ok then
		vim.notify("toggleterm not available — run manually:\n  zsh " .. SETUP_SCRIPT, vim.log.levels.WARN)
		return
	end

	local term = Terminal:new({
		cmd = Platform.shell() .. " " .. vim.fn.shellescape(SETUP_SCRIPT),
		hidden = true,
		direction = "float",
		close_on_exit = false,
		on_open = function(t)
			vim.cmd("startinsert!")
		end,
		on_exit = function()
			vim.schedule(function()
				if M.is_available() then
					vim.notify("Forge installed successfully", vim.log.levels.INFO)
				end
			end)
		end,
	})
	term:toggle()
end

-- ===========================================================================
-- USER COMMANDS
-- ===========================================================================

function M.setup_commands()
	vim.api.nvim_create_user_command("ForgeStatus", function()
		forge_terminal("forge status")
	end, { desc = "Forge: status" })

	-- Backwards-compatible alias (legacy name from old GTD-era config).
	vim.api.nvim_create_user_command("ForgeNext", function()
		forge_terminal("forge status")
	end, { desc = "Forge: status (alias)" })

	vim.api.nvim_create_user_command("ForgeBoard", function()
		forge_terminal("forge board --list")
	end, { desc = "Forge: kanban board" })

	vim.api.nvim_create_user_command("ForgeMove", function(opts)
		local root = project_root()
		local column = opts.args
		if not column or vim.trim(column) == "" then
			column = prompt_string("Move project to column: ")
		end
		if not column then return end
		forge_terminal("forge move " .. vim.fn.shellescape(root) .. " " .. vim.fn.shellescape(column))
	end, { nargs = "?", desc = "Forge: move current project to a column" })

	vim.api.nvim_create_user_command("ForgeProjectTags", function()
		forge_terminal("forge project-tag list " .. vim.fn.shellescape(project_root()))
	end, { desc = "Forge: list tags for current project" })

	vim.api.nvim_create_user_command("ForgeProjectTagAdd", function(opts)
		local tag = opts.args
		if not tag or vim.trim(tag) == "" then
			tag = prompt_string("Tag to add: ")
		end
		if not tag then return end
		forge_terminal("forge project-tag add " .. vim.fn.shellescape(project_root()) .. " " .. vim.fn.shellescape(tag))
	end, { nargs = "?", desc = "Forge: add tag to current project" })

	vim.api.nvim_create_user_command("ForgeProjectTagRemove", function(opts)
		local tag = opts.args
		if not tag or vim.trim(tag) == "" then
			tag = prompt_string("Tag to remove: ")
		end
		if not tag then return end
		forge_terminal("forge project-tag remove " .. vim.fn.shellescape(project_root()) .. " " .. vim.fn.shellescape(tag))
	end, { nargs = "?", desc = "Forge: remove tag from current project" })

	vim.api.nvim_create_user_command("ForgeCalendar", function()
		forge_terminal("forge calendar")
	end, { desc = "Forge: calendar (read-only)" })

	vim.api.nvim_create_user_command("ForgeSetup", function()
		M.run_setup()
	end, { desc = "Forge: build and install Forge on this machine" })
end

-- ===========================================================================
-- ENTRY POINT — auto-setup on require (matches plugin-loader convention)
-- ===========================================================================

M.setup_commands()

if M.is_available() then
	M.setup_keymaps()
else
	vim.defer_fn(function()
		if M.has_setup_script() then
			vim.notify(
				"Forge CLI not found. Run :ForgeSetup to build and install.",
				vim.log.levels.WARN
			)
		end
	end, 500)
end

return M
