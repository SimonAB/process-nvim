-- =============================================================================
-- MINI.NVIM CONFIGURATION
-- PURPOSE: Centralised configuration constants for mini.nvim setup
-- =============================================================================

local M = {}

-- Dashboard configuration
M.DASHBOARD = {
	MAX_PROJECTS = 4,
	MAX_RECENT_FILES = 4,
	MAX_CWD_FILES = 5,
	CWD_FILE_KEYS = { "a", "b", "c", "d", "e" },
	FORGE_KEYS = { "I", "N", "B", "R" },
	HEADER_COLOUR = "#4A6D8C", -- Muted blue-black
	REFRESH_DELAY = 50,
	PLUGIN_UPDATE_DELAY = 100,
}

-- Dashboard header ASCII art
M.HEADER = [[
███╗   ██╗ ███████╗  ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗
████╗  ██║ ██╔════╝ ██╔═══██╗ ██║   ██║ ██║ ████╗ ████║
██╔██╗ ██║ █████╗   ██║   ██║ ██║   ██║ ██║ ██╔████╔██║
██║╚██╗██║ ██╔══╝   ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║
██║ ╚████║ ███████╗ ╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║
╚═╝  ╚═══╝ ╚══════╝  ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝
]]

-- Plugin management configuration
M.PLUGIN_MANAGER = {
	PLUGIN_DIR = vim.fn.stdpath("data") .. "/pack/plugins/start",
	CONFIG_DIR = vim.fn.stdpath("config"),
}

-- Explicit shortcuts must be excluded from mini.starter's generated indexing.
M.INDEXED_SECTIONS = {
	"Current directory",
	"Recent projects",
	"Actions",
	"Sessions",
	"Builtin actions",
}

-- Sections appear in the order their items are generated.
M.SECTIONS = {
	"Current directory",
	"Recent projects",
	"Recent files elsewhere",
	"Actions",
}

return M
