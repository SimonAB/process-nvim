---Cross-platform path and toolchain helpers (macOS vs Linux/Omarchy).

local M = {}

local uname = (vim.loop.os_uname() or {}).sysname or ""

---@return boolean
function M.is_macos()
	return uname == "Darwin"
end

---@return boolean
function M.is_linux()
	return uname == "Linux"
end

---Preferred login shell for plugin build hooks and terminals.
---@return string
function M.shell()
	if M.is_macos() then
		for _, candidate in ipairs({ "/opt/homebrew/bin/zsh", "/usr/local/bin/zsh" }) do
			if vim.fn.executable(candidate) == 1 then
				return candidate
			end
		end
	end
	if vim.fn.executable("zsh") == 1 then
		return vim.fn.exepath("zsh")
	end
	return vim.env.SHELL or "/bin/bash"
end

---Detect system light/dark appearance (macOS `defaults`, Linux `gsettings`).
---@return "dark"|"light"
function M.detect_system_theme()
	if M.is_macos() then
		local ok, result = pcall(vim.fn.system, { "defaults", "read", "-g", "AppleInterfaceStyle" })
		if ok and type(result) == "string" then
			local trimmed = vim.trim(result)
			-- Light appearance: the global key is absent, so `defaults read` often yields empty stdout.
			if trimmed == "" or not trimmed:match("Dark") then
				return "light"
			end
			return "dark"
		end
		return "dark"
	end

	if M.is_linux() and vim.fn.executable("gsettings") == 1 then
		local ok, result = pcall(vim.fn.system, {
			"gsettings",
			"get",
			"org.gnome.desktop.interface",
			"color-scheme",
		})
		if ok and type(result) == "string" then
			local trimmed = vim.trim(result):lower()
			if trimmed:match("dark") then
				return "dark"
			end
			if trimmed:match("light") then
				return "light"
			end
		end

		ok, result = pcall(vim.fn.system, {
			"gsettings",
			"get",
			"org.gnome.desktop.interface",
			"gtk-theme",
		})
		if ok and type(result) == "string" then
			local trimmed = vim.trim(result):lower()
			if trimmed:match("dark") then
				return "dark"
			end
			return "light"
		end
	end

	return "dark"
end

---Shell command that writes a clipboard image to `dest_path`, or nil if unsupported.
---@param dest_path string
---@return string|nil
function M.clipboard_image_paste_cmd(dest_path)
	local escaped = vim.fn.shellescape(dest_path)
	if M.is_macos() and vim.fn.executable("pngpaste") == 1 then
		return string.format("pngpaste %s", escaped)
	end
	if M.is_linux() then
		if vim.fn.executable("wl-paste") == 1 and (vim.env.WAYLAND_DISPLAY or "") ~= "" then
			return string.format("wl-paste --type image/png > %s", escaped)
		end
		if vim.fn.executable("xclip") == 1 then
			return string.format("xclip -selection clipboard -target image/png -o > %s", escaped)
		end
	end
	return nil
end

---First existing directory from a list of candidate paths.
---@param candidates string[]
---@return string|nil
local function first_existing_dir(candidates)
	for _, path in ipairs(candidates) do
		local expanded = vim.fn.expand(path)
		if expanded ~= "" and vim.fn.isdirectory(expanded) == 1 then
			return expanded
		end
	end
	return nil
end

---Resolve the Obsidian vault path for this machine.
---Prefers `OBSIDIAN_VAULT_PATH`, then known macOS iCloud and Linux locations.
---@return string
function M.obsidian_vault_path()
	local env_path = vim.env.OBSIDIAN_VAULT_PATH
	if env_path and env_path ~= "" then
		return vim.fn.expand(env_path)
	end

	local candidates = {}
	if M.is_macos() then
		candidates = {
			"~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notebook",
		}
	else
		candidates = {
			"~/Documents/Obsidian/Notebook",
			"~/Documents/Notebook",
			"~/Obsidian/Notebook",
			"~/.local/share/obsidian/Notebook",
			-- Optional iCloud mount (e.g. rclone) on Linux
			"~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notebook",
		}
	end

	local found = first_existing_dir(candidates)
	if found then
		return found
	end

	return vim.fn.expand(candidates[1])
end

---Forge task directory (`FORGE_DIR` override supported).
---@return string
function M.forge_dir()
	local env_path = vim.env.FORGE_DIR
	if env_path and env_path ~= "" then
		return vim.fn.expand(env_path)
	end
	return vim.fn.expand("~/Documents/Forge")
end

---Build command for telescope-fzf-native.nvim (toolchain differs by OS).
---@return string
function M.telescope_fzf_native_build()
	if M.is_macos() then
		return 'make clean && env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin" make CC=/usr/bin/clang CFLAGS="-Wall -fpic -std=gnu99"'
	end
	return 'make clean && env -i PATH="/usr/bin:/bin" make CC=gcc CFLAGS="-Wall -fpic -std=gnu99"'
end

---@param path string
---@return boolean
local function is_pdf_path(path)
	local ext = path:match("%.([%w]+)$")
	return ext ~= nil and ext:lower() == "pdf"
end

---Open a PDF with the platform viewer when available.
---@param path string
---@return boolean opened
function M.open_pdf(path)
	if not is_pdf_path(path) then
		return false
	end

	if M.is_macos() and vim.fn.executable("open") == 1 then
		if vim.fn.isdirectory("/Applications/Skim.app") == 1 then
			vim.fn.jobstart({ "open", "-a", "Skim", path }, { detach = true })
			return true
		end
		vim.fn.jobstart({ "open", path }, { detach = true })
		return true
	end

	if M.is_linux() and vim.fn.executable("zathura") == 1 then
		vim.fn.jobstart({ "zathura", path }, { detach = true })
		return true
	end

	return false
end

return M
