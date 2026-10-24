---Flexoki theme configuration.
---
---This module is loaded by the phased plugin loader (`core/plugin-loader.lua`).
---It configures Flexoki to keep backgrounds transparent so the UI inherits the
---terminal backdrop. The host terminal (Rex on macOS) shows through.
---
---The active colourscheme names are `flexoki-dark` and `flexoki-light`.
---
---@return nil
local function setup()
	local ok, flexoki = pcall(require, "flexoki")
	if not ok then
		return
	end

	flexoki.setup({
		-- Must match a key in `flexoki.palette` variants (`dark` / `light` only in this fork).
		light_variant = "light",
		transparent = {
			editor = true,
			floats = true,
			float_border = true,
			ui = true,
			menus = true,
		},
	})
end

setup()

