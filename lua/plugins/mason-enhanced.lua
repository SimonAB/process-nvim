-- =============================================================================
-- MASON ENHANCED UI
-- PURPOSE: Enhanced Mason package management with progress tracking and batch operations
-- =============================================================================

local MasonUI = {}

---When true, per-package install notifications are suppressed (batch update).
local quiet_install_notifications = false

local progress_handle = nil
local update_popup = nil
local updated_packages = {}

---Handlers registered on `mason-registry` (cleared and re-registered in `setup_event_handlers`).
local registry_handlers = {}

-- Progress notification system
local function create_progress_notification(title, message)
	if progress_handle then
		progress_handle:finish()
	end

	local ok, fidget = pcall(require, "fidget")
	if ok then
		progress_handle = fidget.progress.handle.create({
			title = title,
			message = message,
			percentage = 0,
		})
	else
		-- Fallback to basic notification
		vim.notify(message, vim.log.levels.INFO, {
			title = title,
			timeout = 5000,
		})
	end
	return progress_handle
end

---Open (or replace) a floating popup for Mason updates.
---@param title string
---@param message string
local function open_update_popup(title, message)
	local ok, ProgressPopup = pcall(require, "core.progress-popup")
	if not ok then
		return
	end

	if update_popup and update_popup.winid and vim.api.nvim_win_is_valid(update_popup.winid) then
		ProgressPopup.close(update_popup)
	end

	update_popup = ProgressPopup.create(title, { width = 78, height = 18 })
	ProgressPopup.set_lines(update_popup, {
		"",
		message,
		"",
		"Updated packages:",
	})
end

---Refresh popup contents from the current updated package list.
local function refresh_update_popup()
	if not update_popup then
		return
	end

	local ok, ProgressPopup = pcall(require, "core.progress-popup")
	if not ok then
		return
	end

	ProgressPopup.set_lines(update_popup, {
		"",
		string.format("Updating packages... (%d updated)", #updated_packages),
		"",
		"Updated packages:",
	})

	for _, name in ipairs(updated_packages) do
		ProgressPopup.append_line(update_popup, "  - " .. name)
	end
end

-- Enhanced notification system
local function notify(message, level, opts)
	local default_opts = {
		title = "Mason Package Manager",
		timeout = 3000,
	}
	local final_opts = vim.tbl_extend("force", default_opts, opts or {})

	vim.notify(message, level, final_opts)
end

-- Batch installation of LSP servers
function MasonUI.install_servers_batch(servers, options)
	options = options or {}
	local title = options.title or "Installing LSP Servers"
	local show_progress = options.show_progress ~= false

	local handle = nil
	if show_progress then
		handle = create_progress_notification(title, "Starting batch installation...")
	end

	local total = #servers
	local completed = 0
	local failed = {}

	-- Install servers sequentially to avoid conflicts
	local function install_next(index)
		if index > total then
			-- All done
			if handle then
				handle.message = string.format("Installation complete! %d/%d successful", completed, total)
				vim.defer_fn(function() handle:finish() end, 1000)
			end

			if #failed > 0 then
				notify(string.format("Batch installation: %d/%d successful, %d failed", completed, total, #failed),
					vim.log.levels.WARN, { timeout = 5000 })
				for _, failure in ipairs(failed) do
					notify("Failed: " .. failure, vim.log.levels.ERROR)
				end
			else
				notify(string.format("All %d LSP servers installed successfully!", total),
					vim.log.levels.INFO)
			end
			return
		end

		local server = servers[index]
		if handle then
			handle.message = string.format("Installing %s (%d/%d)", server, index, total)
			handle.percentage = ((index - 1) / total) * 100
		end

		-- Install the server
		local success = pcall(function()
			vim.cmd("MasonInstall " .. server)
		end)

		if success then
			completed = completed + 1
		else
			table.insert(failed, server)
		end

		-- Schedule next installation
		vim.defer_fn(function()
			install_next(index + 1)
		end, 500) -- Small delay between installations
	end

	-- Start the installation process
	install_next(1)
end

-- Install core academic LSP servers
function MasonUI.install_academic_servers()
	local academic_servers = {
		"pyright",     -- Python
		"texlab",      -- LaTeX
		-- tinymist: system package (brew / pacman), not Mason
		"lua_ls",      -- Lua
		"bashls",      -- Bash
		"marksman",    -- Markdown
		"jsonls",      -- JSON
		"yamlls",      -- YAML
	}

	MasonUI.install_servers_batch(academic_servers, {
		title = "Installing Academic LSP Servers"
	})
end

-- Install all recommended servers
function MasonUI.install_all_recommended()
	local all_servers = {
		-- Core LSP servers (tinymist is system-managed: brew / pacman)
		"pyright", "texlab", "lua_ls", "bashls",
		"marksman", "jsonls", "yamlls", "html", "cssls",
		"ts_ls", "r_language_server"
	}

	MasonUI.install_servers_batch(all_servers, {
		title = "Installing All Recommended Servers"
	})
end

---Refresh Mason registries then reinstall any installed package whose receipt
---version differs from the latest version in the registry.
---Note: `:MasonUpdate` alone only updates registry sources, not installed tools.
function MasonUI.update_all_packages()
	local ok_a, a = pcall(require, "mason-core.async")
	local ok_registry, registry = pcall(require, "mason-registry")
	if not ok_a or not ok_registry then
		notify("Mason registry API not available", vim.log.levels.ERROR)
		return
	end

	local handle = create_progress_notification("Updating Packages", "Updating registries…")
	updated_packages = {}
	quiet_install_notifications = true
	open_update_popup("Mason: Updating Packages", "Updating registries…")

	a.run(function()
		a.wait(function(resolve, reject)
			registry.update(function(success, result)
				if success then
					resolve(result)
				else
					reject(result)
				end
			end)
		end)

		local outdated = {}
		for _, name in ipairs(registry.get_installed_package_names()) do
			local ok_pkg, pkg = pcall(registry.get_package, name)
			if ok_pkg and pkg then
				local current_version = pkg:get_installed_version()
				local ok_lv, latest_version = pcall(function()
					return pkg:get_latest_version()
				end)
				if ok_lv and current_version ~= latest_version then
					table.insert(outdated, pkg)
				end
			end
		end

		if #outdated == 0 then
			return { n_updated = 0, failed = {} }
		end

		local failed = {}
		for _, pkg in ipairs(outdated) do
			local install_ok = a.wait(function(resolve)
				pkg:install({}, function(ok)
					resolve(ok)
				end)
			end)
			a.scheduler()
			if install_ok then
				table.insert(updated_packages, pkg.name)
			else
				table.insert(failed, pkg.name)
			end
		end

		return { n_updated = #updated_packages, failed = failed }
	end, function(run_ok, result)
		quiet_install_notifications = false

		vim.schedule(function()
			if handle then
				if not run_ok then
					handle.message = "Update failed: " .. tostring(result)
				elseif result.n_updated == 0 then
					handle.message = "Registries updated; all packages already current"
				elseif #result.failed == 0 then
					handle.message = string.format("Updated %d package(s)", result.n_updated)
				else
					handle.message = string.format(
						"Updated %d; %d failed",
						result.n_updated,
						#result.failed
					)
				end
				vim.defer_fn(function()
					handle:finish()
				end, 2000)
			end

			if update_popup then
				local ok_pp, ProgressPopup = pcall(require, "core.progress-popup")
				if ok_pp then
					ProgressPopup.set_lines(update_popup, {
						"",
						not run_ok and ("Error: " .. tostring(result)) or "Finished.",
						"",
						"Updated packages:",
					})
					for _, name in ipairs(updated_packages) do
						ProgressPopup.append_line(update_popup, "  - " .. name)
					end
					if run_ok and type(result) == "table" and #result.failed > 0 then
						ProgressPopup.append_line(update_popup, "")
						ProgressPopup.append_line(update_popup, "Failed:")
						for _, name in ipairs(result.failed) do
							ProgressPopup.append_line(update_popup, "  - " .. name)
						end
					end
					vim.defer_fn(function()
						ProgressPopup.close(update_popup)
						update_popup = nil
					end, 10000)
				end
			end

			if not run_ok then
				notify("Mason update failed: " .. tostring(result), vim.log.levels.ERROR)
			elseif result.n_updated == 0 then
				notify("Mason registries refreshed; no package upgrades needed", vim.log.levels.INFO)
			elseif #result.failed == 0 then
				notify(
					string.format("Mason: upgraded %d package(s)", result.n_updated),
					vim.log.levels.INFO
				)
			else
				notify(
					string.format(
						"Mason: upgraded %d package(s), %d failed (see :MasonLog)",
						result.n_updated,
						#result.failed
					),
					vim.log.levels.WARN
				)
			end
		end)
	end)
end

-- Check Mason status and provide summary
function MasonUI.check_status()
	local handle = create_progress_notification("Mason Status", "Checking installation status...")

	vim.defer_fn(function()
		local ok, mason = pcall(require, "mason")
		if not ok then
			notify("Mason not available", vim.log.levels.ERROR)
			if handle then handle:finish() end
			return
		end

		local registry = mason.registry
		local installed = registry.installed_packages or {}
		local total_installed = 0
		local lsp_servers = 0

		for name, pkg in pairs(installed) do
			total_installed = total_installed + 1
			if pkg.spec and pkg.spec.categories then
				for _, category in ipairs(pkg.spec.categories) do
					if category == "LSP" then
						lsp_servers = lsp_servers + 1
						break
					end
				end
			end
		end

		local message = string.format("Mason Status: %d packages installed (%d LSP servers)",
			total_installed, lsp_servers)

		if handle then
			handle.message = message
			vim.defer_fn(function() handle:finish() end, 2000)
		end

		notify(message, vim.log.levels.INFO, { timeout = 5000 })
	end, 100)
end

-- Create user commands for easy access
function MasonUI.setup_commands()
	vim.api.nvim_create_user_command("MasonInstallAcademic", function()
		MasonUI.install_academic_servers()
	end, { desc = "Install academic LSP servers (Python, LaTeX, Typst, etc.)" })

	vim.api.nvim_create_user_command("MasonInstallAll", function()
		MasonUI.install_all_recommended()
	end, { desc = "Install all recommended LSP servers" })

	vim.api.nvim_create_user_command("MasonUpdateAll", function()
		MasonUI.update_all_packages()
	end, { desc = "Update all installed Mason packages" })

	vim.api.nvim_create_user_command("MasonStatus", function()
		MasonUI.check_status()
	end, { desc = "Show Mason installation status" })
end

---Subscribe to Mason registry install events (Mason does not emit `User` autocmds for these).
function MasonUI.setup_event_handlers()
	local ok, registry = pcall(require, "mason-registry")
	if not ok then
		return
	end

	for _, h in ipairs(registry_handlers) do
		registry:off(h.event, h.fn)
	end
	registry_handlers = {}

	local function track_success(pkg)
		if quiet_install_notifications then
			return
		end
		notify("✓ " .. pkg.name .. " installed successfully", vim.log.levels.INFO)
		table.insert(updated_packages, pkg.name)
		refresh_update_popup()
	end

	local on_success = function(pkg)
		vim.schedule(function()
			track_success(pkg)
		end)
	end
	registry:on("package:install:success", on_success)
	table.insert(registry_handlers, { event = "package:install:success", fn = on_success })

	local on_failed = function(pkg, result)
		vim.schedule(function()
			notify(
				"✗ Failed to install " .. pkg.name .. ": " .. tostring(result),
				vim.log.levels.ERROR
			)
		end)
	end
	registry:on("package:install:failed", on_failed)
	table.insert(registry_handlers, { event = "package:install:failed", fn = on_failed })
end

-- Initialize the enhanced Mason UI
function MasonUI.init()
	MasonUI.setup_commands()
	MasonUI.setup_event_handlers()

	vim.notify("Mason Enhanced UI initialized", vim.log.levels.INFO)
end

return MasonUI
