-- Configuration for codecompanion.nvim
-- PURPOSE: Use ACP (Cursor CLI) for chat, with optional Ollama HTTP adapter for local models

local ok, codecompanion = pcall(require, "codecompanion")
if not ok then
	vim.notify("codecompanion.nvim not found", vim.log.levels.WARN)
	return {}
end


---Ensure PATH includes directories needed by the Cursor Agent wrapper script.
---The wrapper calls `dirname` / `realpath`; without `/usr/bin` on PATH it fails with
---`dirname: command not found`. Also keep `~/.local/bin` so repaired shims remain visible.
---@param path string|nil
---@return string
local function ensure_cursor_agent_path(path)
	local home = vim.env.HOME or vim.fn.expand("~")
	local extras = {
		"/usr/bin",
		"/bin",
		"/usr/sbin",
		"/sbin",
		"/opt/homebrew/bin",
		"/usr/local/bin",
		home .. "/.local/bin",
	}

	local result = path or ""
	for _, dir in ipairs(extras) do
		local needle = ":" .. dir .. ":"
		local haystack = ":" .. result .. ":"
		if not haystack:find(needle, 1, true) then
			if result == "" then
				result = dir
			else
				result = dir .. ":" .. result
			end
		end
	end

	return result
end


---Build a process environment for Cursor Agent ACP.
---CodeCompanion passes `adapter.env_replaced` to `vim.system` as a full replacement
---(not a merge). An empty table therefore strips PATH and breaks the agent wrapper.
---Forward Neovim's environment and strengthen PATH for GUI / Hermes-touched installs.
---@return table<string, fun(self: table): string>
local function build_cursor_agent_env()
	local env = {}

	for key, value in pairs(vim.fn.environ()) do
		-- Capture by value so `get_env_vars` does not treat the string as an env-var name.
		local captured = value
		env[key] = function()
			return captured
		end
	end

	env.PATH = function()
		return ensure_cursor_agent_path(vim.env.PATH)
	end

	return env
end


---Resolve the Cursor Agent CLI executable.
---Prefer the versioned install under `~/.local/share/cursor-agent` so a broken
---`~/.local/bin` shim (e.g. after Hermes rewrites that directory) still works.
---@return string
local function resolve_cursor_agent()
	local versions_dir = vim.fn.expand("~/.local/share/cursor-agent/versions")
	if vim.fn.isdirectory(versions_dir) == 1 then
		local entries = vim.fn.readdir(versions_dir) or {}
		table.sort(entries)
		for i = #entries, 1, -1 do
			local name = entries[i]
			-- Skip temporary extract directories left by the installer.
			if not vim.startswith(name, ".tmp-") then
				local candidate = versions_dir .. "/" .. name .. "/cursor-agent"
				if vim.fn.executable(candidate) == 1 then
					return candidate
				end
			end
		end
	end

	for _, name in ipairs({ "agent", "cursor-agent" }) do
		if vim.fn.executable(name) == 1 then
			return vim.fn.exepath(name)
		end
	end

	return "agent"
end


codecompanion.setup({
	interactions = {
		-- ACP adapters are chat-only. This makes Cursor CLI the default for :CodeCompanionChat.
		chat = {
			adapter = "cursor_cli",
		},

		-- Keep non-chat interactions conservative; you can switch these later if desired.
		background = {
			adapter = {
				name = "ollama",
				model = "llama3.1:8b",
			},
		},
	},
	adapters = {
		acp = {
			cursor_cli = function()
				local agent_bin = resolve_cursor_agent()
				return require("codecompanion.adapters").extend("cursor_cli", {
					-- Cursor CLI auth is handled by `agent login` in your shell.
					-- Session config options (models/modes/etc.) vary by agent; use the debug window to inspect.
					commands = {
						default = {
							agent_bin,
							"acp",
						},
					},
					env = build_cursor_agent_env(),
					defaults = {
						session_config_options = {},
					},
				})
			end,
		},
		http = {
			ollama = function()
				return require("codecompanion.adapters").extend("ollama", {
					-- For remote Ollama, set OLLAMA_HOST in your environment (preferred),
					-- or configure `env.url` here. Local default is typically http://127.0.0.1:11434.
					schema = {
						model = {
							default = "llama3.1:8b",
						},
					},
				})
			end,
		},
	},
})

return {}
