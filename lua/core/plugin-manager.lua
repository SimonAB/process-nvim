-- =============================================================================
-- ENHANCED PLUGIN MANAGER
-- PURPOSE: Comprehensive plugin update system with progress feedback
-- =============================================================================

local PluginManager = {}
local PluginReload = require("core.plugin-reload")
local progress_handle = nil

---Get vim.pack plugin list (managed plugins).
---@return table[] plugins
local function get_pack_plugins()
	if not vim.pack or type(vim.pack.get) ~= "function" then
		return {}
	end

	return vim.pack.get()
end

-- Progress and notification system (vim.notify only; no fidget dependency)
local function create_progress(title, message)
	local ok, ProgressPopup = pcall(require, "core.progress-popup")
	if not ok then
		vim.notify(message, vim.log.levels.INFO, { title = title, timeout = 5000 })
		return nil
	end

	if progress_handle and progress_handle.winid and vim.api.nvim_win_is_valid(progress_handle.winid) then
		ProgressPopup.close(progress_handle)
	end

	progress_handle = ProgressPopup.create(title, { width = 78, height = 18 })
	ProgressPopup.set_lines(progress_handle, {
		"",
		message,
		"",
	})
	return progress_handle
end

local function notify(message, level, opts)
	local default_opts = {
		title = "Plugin Manager",
		timeout = 3000,
	}
	local final_opts = vim.tbl_extend("force", default_opts, opts or {})
	vim.notify(message, level, final_opts)
end

-- Get list of installed plugins
function PluginManager.get_installed_plugins()
	local plugins = {}
	for _, plug in ipairs(get_pack_plugins()) do
		table.insert(plugins, {
			name = (plug.spec or {}).name or "unknown",
			path = plug.path,
			rev = plug.rev,
			active = plug.active,
		})
	end
	return plugins
end

-- Update all plugins with progress feedback
function PluginManager.update_all_plugins()
	local plugins = PluginManager.get_installed_plugins()
	local handle = create_progress("Updating Plugins", "Checking for updates...")

	if #plugins == 0 then
		notify("No plugins found to update", vim.log.levels.WARN)
		if handle then
			local ok, ProgressPopup = pcall(require, "core.progress-popup")
			if ok then
				ProgressPopup.append_line(handle, "No plugins found.")
				vim.defer_fn(function() ProgressPopup.close(handle) end, 1500)
			end
		end
		return
	end

	local before = {}
	for _, plugin in ipairs(plugins) do
		before[plugin.name] = plugin.rev
	end

	if not vim.pack or type(vim.pack.update) ~= "function" then
		notify("vim.pack is not available; cannot update plugins", vim.log.levels.ERROR)
		return
	end

	local update_ok, err = pcall(function()
		vim.pack.update(nil, { force = true })
	end)

	local after_plugins = PluginManager.get_installed_plugins()
	local updated_plugins = {}
	for _, plugin in ipairs(after_plugins) do
		local prev = before[plugin.name]
		if prev and plugin.rev and prev ~= plugin.rev then
			table.insert(updated_plugins, string.format("%s  %s → %s", plugin.name, prev, plugin.rev))
		end
	end

	if handle then
		local ok_popup, ProgressPopup = pcall(require, "core.progress-popup")
		if ok_popup then
			ProgressPopup.append_line(handle, "")
			if update_ok then
				ProgressPopup.append_line(handle, string.format("Done. %d updated.", #updated_plugins))
			else
				ProgressPopup.append_line(handle, "Update failed: " .. tostring(err))
			end
			if #updated_plugins > 0 then
				ProgressPopup.append_line(handle, "")
				ProgressPopup.append_line(handle, "Updated plugins:")
				for _, line in ipairs(updated_plugins) do
					ProgressPopup.append_line(handle, "  - " .. line)
				end
			end
			vim.defer_fn(function() ProgressPopup.close(handle) end, 10000)
		end
	end

	if update_ok then
		local updated_names = {}
		for _, plugin in ipairs(after_plugins) do
			local prev = before[plugin.name]
			if prev and plugin.rev and prev ~= plugin.rev then
				updated_names[#updated_names + 1] = plugin.name
				PluginReload.clear_plugins(plugin.name)
			end
		end
		PluginReload.notify_restart_advice(updated_names)

		local msg = string.format("Plugin updates complete (%d updated)", #updated_plugins)
		if #updated_names > 0 then
			msg = msg .. ". Restart Neovim if anything behaves oddly."
		end
		notify(msg, vim.log.levels.INFO, { timeout = 8000 })
	else
		notify("Plugin update failed: " .. tostring(err), vim.log.levels.ERROR, { timeout = 7000 })
	end
end

-- Update specific plugin
function PluginManager.update_plugin(plugin_name)
	local handle = create_progress("Updating Plugin", "Updating " .. plugin_name .. "...")

	if not vim.pack or type(vim.pack.update) ~= "function" then
		notify("vim.pack is not available; cannot update plugins", vim.log.levels.ERROR)
		return
	end

	local update_ok, err = pcall(function()
		vim.pack.update({ plugin_name }, { force = true })
	end)

	if handle then
		local ok_popup, ProgressPopup = pcall(require, "core.progress-popup")
		if ok_popup then
			ProgressPopup.append_line(handle, "")
			if update_ok then
				ProgressPopup.append_line(handle, plugin_name .. " updated")
			else
				ProgressPopup.append_line(handle, "Update failed: " .. tostring(err))
			end
			vim.defer_fn(function() ProgressPopup.close(handle) end, 4000)
		end
	end

	if update_ok then
		PluginReload.clear_plugins(plugin_name)
		PluginReload.notify_restart_advice({ plugin_name })
		notify("✓ " .. plugin_name .. " updated (restart Neovim if behaviour looks wrong)", vim.log.levels.INFO)
	else
		notify("✗ Failed to update " .. plugin_name .. ": " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- Show plugin status
function PluginManager.show_status()
	local plugins = PluginManager.get_installed_plugins()
	local handle = create_progress("Plugin Status", "Analyzing plugins...")

	vim.defer_fn(function()
		local total_plugins = #plugins
		local git_plugins = 0
		local status_lines = {}

		for _, plugin in ipairs(plugins) do
			git_plugins = git_plugins + 1
			table.insert(status_lines, string.format("✓ %s @%s", plugin.name, plugin.rev or "unknown"))
		end

		local summary = string.format("Plugin Status: %d total, %d git repos", total_plugins, git_plugins)

		if handle then
			handle.message = summary
			vim.defer_fn(function() handle:finish() end, 2000)
		end

		notify(summary, vim.log.levels.INFO, { timeout = 5000 })

		-- Show detailed status in a floating window
		local buf = vim.api.nvim_create_buf(false, true)
		local width = 60
		local height = math.min(20, #status_lines + 2)

		local lines = { "Plugin Status Details:", "" }
		vim.list_extend(lines, status_lines)

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		local win_opts = {
			relative = "editor",
			width = width,
			height = height,
			col = (vim.o.columns - width) / 2,
			row = (vim.o.lines - height) / 2,
			style = "minimal",
			border = "rounded",
		}

		local win = vim.api.nvim_open_win(buf, true, win_opts)

		-- Match which-key float styling (opaque + shared float highlight mapping).
		local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")
		if ok_ts and ThemeSettings and ThemeSettings.style_float_like_which_key then
			ThemeSettings.style_float_like_which_key(win)
		end

		-- Close window on any key
		vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
		vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
		vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":close<CR>", { noremap = true, silent = true })

		-- Auto-close after 10 seconds
		vim.defer_fn(function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, 10000)

	end, 100)
end

-- Clean up orphaned plugins (plugins in pack that aren't in the plugin list)
function PluginManager.cleanup_orphaned()
	local handle = create_progress("Plugin Cleanup", "Checking for inactive plugins...")

	vim.defer_fn(function()
		if not vim.pack or type(vim.pack.get) ~= "function" then
			notify("vim.pack is not available; cannot clean plugins", vim.log.levels.ERROR)
			return
		end

		local orphaned = {}
		for _, plug in ipairs(vim.pack.get()) do
			if not plug.active then
				table.insert(orphaned, { name = (plug.spec or {}).name, path = plug.path })
			end
		end

		if #orphaned == 0 then
			notify("No inactive plugins found", vim.log.levels.INFO)
			return
		end

		local message = "Inactive plugins (managed by vim.pack):\n"
		for _, plugin in ipairs(orphaned) do
			message = message .. "  - " .. plugin.name .. "\n"
		end
		message = message .. "\nUse :PluginCleanupConfirm to remove them"

		vim.notify(message, vim.log.levels.WARN, { timeout = 10000 })
		_G.orphaned_plugins = orphaned
	end, 100)
end

-- Confirm and remove orphaned plugins
function PluginManager.cleanup_confirm()
	if not _G.orphaned_plugins or #_G.orphaned_plugins == 0 then
		notify("No orphaned plugins to clean up", vim.log.levels.INFO)
		return
	end

	local handle = create_progress("Cleaning Plugins", "Removing orphaned plugins...")

	local total = #_G.orphaned_plugins
	local completed = 0
	local failed = {}

	local function cleanup_next(index)
		if index > total then
			if handle then
				local msg = string.format("Cleanup complete! %d/%d removed", completed - #failed, total)
				if #failed > 0 then
					msg = msg .. string.format(" (%d failed)", #failed)
				end
				handle.message = msg
				vim.defer_fn(function() handle:finish() end, 1000)
			end

			if #failed > 0 then
				notify(string.format("Cleanup: %d/%d successful (%d failed)", completed - #failed, total, #failed), vim.log.levels.WARN)
			else
				notify(string.format("Cleanup: %d/%d plugins removed", completed, total), vim.log.levels.INFO)
			end

			_G.orphaned_plugins = nil
			return
		end

		local plugin = _G.orphaned_plugins[index]
		if handle then
			handle.message = string.format("Removing %s (%d/%d)", plugin.name, index, total)
			handle.percentage = ((index - 1) / total) * 100
		end

		if vim.pack and type(vim.pack.del) == "function" then
			local success = pcall(function()
				vim.pack.del({ plugin.name }, { force = true })
			end)
			if success then
				completed = completed + 1
			else
				table.insert(failed, plugin.name)
			end
		else
			table.insert(failed, plugin.name)
		end

		vim.defer_fn(function()
			cleanup_next(index + 1)
		end, 100)
	end

	cleanup_next(1)
end

---Remove legacy pack/plugins/start trees duplicated by vim.pack (site/pack/core/opt).
---@param opts? { dry_run?: boolean }
---@return integer removed
function PluginManager.prune_legacy_pack(opts)
	opts = opts or {}
	local dry_run = opts.dry_run == true
	local legacy_root = vim.fn.stdpath("data") .. "/pack/plugins/start"
	if vim.fn.isdirectory(legacy_root) ~= 1 then
		return 0
	end

	local opt_root = vim.fn.stdpath("data") .. "/site/pack/core/opt"
	local removed = 0

	for name in vim.fs.dir(legacy_root) do
		local legacy_path = legacy_root .. "/" .. name
		if vim.fn.isdirectory(legacy_path) == 1 then
			local managed = opt_root .. "/" .. name
			if vim.fn.isdirectory(managed) == 1 then
				if dry_run then
					vim.notify("Would remove legacy duplicate: " .. legacy_path, vim.log.levels.INFO)
				else
					local ok = vim.fn.delete(legacy_path, "rf") == 0
					if ok then
						removed = removed + 1
					end
				end
			end
		end
	end

	if removed > 0 and not dry_run then
		notify(string.format("Removed %d legacy plugin(s) from pack/plugins/start", removed), vim.log.levels.INFO)
	end

	return removed
end

-- Setup user commands
function PluginManager.setup_commands()
	vim.api.nvim_create_user_command("PluginUpdateAll", function()
		PluginManager.update_all_plugins()
	end, { desc = "Update all Neovim plugins with progress feedback" })

	vim.api.nvim_create_user_command("PluginUpdate", function(opts)
		local plugin_name = opts.args
		if plugin_name == "" then
			notify("Usage: PluginUpdate <plugin-name>", vim.log.levels.ERROR)
			return
		end
		PluginManager.update_plugin(plugin_name)
	end, { nargs = 1, desc = "Update specific plugin" })

	vim.api.nvim_create_user_command("PluginStatus", function()
		PluginManager.show_status()
	end, { desc = "Show plugin status and details" })

	vim.api.nvim_create_user_command("PluginCleanup", function()
		PluginManager.cleanup_orphaned()
	end, { desc = "Check for orphaned plugins" })

	vim.api.nvim_create_user_command("PluginCleanupConfirm", function()
		PluginManager.cleanup_confirm()
	end, { desc = "Confirm and remove orphaned plugins" })

	vim.api.nvim_create_user_command("PluginPruneLegacy", function(opts)
		local dry_run = opts.bang
		local n = PluginManager.prune_legacy_pack({ dry_run = dry_run })
		if dry_run then
			notify("Dry run complete (see messages)", vim.log.levels.INFO)
		elseif n == 0 then
			notify("No legacy duplicates under pack/plugins/start", vim.log.levels.INFO)
		end
	end, { bang = true, desc = "Remove pack/plugins/start copies already in site/pack/core/opt (! = dry run)" })
end

-- Initialize the plugin manager
function PluginManager.init()
	PluginManager.setup_commands()
	vim.notify("Enhanced Plugin Manager initialized", vim.log.levels.INFO)
end

return PluginManager
