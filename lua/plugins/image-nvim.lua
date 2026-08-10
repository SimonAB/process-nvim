-- Configuration for image.nvim
-- Cursor-peek Markdown/Obsidian image (and PDF-page) previews via Kitty graphics.

local ok, image = pcall(require, "image")
if not ok then
	vim.notify("image.nvim not found", vim.log.levels.WARN)
	return
end

-- Raster + PDF previews are drawn by our themed cursor peek below. Keep image.nvim
-- loaded for the Kitty backend / from_file API, but do not use its stock popup
-- (single-border, unthemed) or inline virt-line rendering.
image.setup({
	backend = "kitty",
	processor = "magick_cli",
	integrations = {
		markdown = { enabled = false },
		html = { enabled = false },
		css = { enabled = false },
	},
	max_width = nil,
	max_height = nil,
	max_width_window_percentage = 80,
	max_height_window_percentage = 50,
	scale_factor = 1.0,
	window_overlap_clear_enabled = true,
	editor_only_render_when_focused = true,
	hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
})

local embed_popup = {
	win = nil,
	buf = nil,
	image = nil,
	path = nil,
	---Preview path dismissed with Esc; skip reopen until the cursor leaves this embed.
	dismissed_path = nil,
	esc_bufnr = nil,
}

local function popup_is_open()
	return embed_popup.win ~= nil and vim.api.nvim_win_is_valid(embed_popup.win)
end

local function unmap_esc_dismiss()
	local bufnr = embed_popup.esc_bufnr
	embed_popup.esc_bufnr = nil
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	pcall(vim.keymap.del, "n", "<Esc>", { buffer = bufnr })
end

local function clear_embed_popup()
	unmap_esc_dismiss()
	if embed_popup.image then
		pcall(function()
			embed_popup.image:clear()
		end)
		embed_popup.image = nil
	end
	if embed_popup.win and vim.api.nvim_win_is_valid(embed_popup.win) then
		pcall(vim.api.nvim_win_close, embed_popup.win, true)
	end
	if embed_popup.buf and vim.api.nvim_buf_is_valid(embed_popup.buf) then
		pcall(vim.api.nvim_buf_delete, embed_popup.buf, { force = true })
	end
	embed_popup.win = nil
	embed_popup.buf = nil
	embed_popup.path = nil
end

---Close the peek and remember it so CursorMoved does not reopen the same embed.
local function dismiss_embed_popup()
	if not popup_is_open() then
		return
	end
	embed_popup.dismissed_path = embed_popup.path
	clear_embed_popup()
end

local function map_esc_dismiss()
	local bufnr = vim.api.nvim_get_current_buf()
	if embed_popup.esc_bufnr == bufnr then
		return
	end
	unmap_esc_dismiss()
	vim.keymap.set("n", "<Esc>", function()
		dismiss_embed_popup()
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Dismiss media peek",
	})
	embed_popup.esc_bufnr = bufnr
end

---@class EmbedPopupLayout
---@field frame_w integer
---@field frame_h integer
---@field x integer
---@field y integer
---@field render_w integer
---@field render_h integer

---Compute frame size and centred render geometry inside the peek.
---Frame height always follows the rendered image (capped so it stays on screen).
---@param image_width integer
---@param image_height integer
---@param opts { fit_width?: boolean }|nil
---@return EmbedPopupLayout
local function compute_popup_layout(image_width, image_height, opts)
	opts = opts or {}
	local fit_width = opts.fit_width == true
	local win_width = vim.api.nvim_win_get_width(0)
	local max_w = math.max(24, math.floor(win_width * 0.7))
	local max_h = math.max(8, math.floor(vim.o.lines * (fit_width and 0.65 or 0.45)))

	local aspect = (image_width > 0 and image_height > 0) and (image_width / image_height) or (16 / 9)
	local term_size = nil
	local ok_utils, utils = pcall(require, "image.utils")
	if ok_utils and utils.term then
		term_size = utils.term.get_size()
	end

	---@param width integer
	---@param height integer
	---@return integer, integer
	local function adjust(width, height)
		if term_size and utils.math and image_width > 0 and image_height > 0 then
			return utils.math.adjust_to_aspect_ratio(
				term_size,
				image_width,
				image_height,
				width,
				height
			)
		end
		-- Fallback ≈2:1 cell aspect when terminal metrics are missing.
		if height == 0 and width ~= 0 then
			return width, math.max(1, math.floor(width * 0.5 / aspect))
		end
		if width == 0 and height ~= 0 then
			return math.max(1, math.floor(height * aspect / 0.5)), height
		end
		local rw, rh = width, height
		local box_aspect = (width * 0.5) / math.max(height, 1)
		if box_aspect > aspect then
			rw = math.max(1, math.floor(height * aspect / 0.5))
		else
			rh = math.max(1, math.floor(width * 0.5 / aspect))
		end
		return rw, rh
	end

	local render_w, render_h
	if fit_width then
		-- Zoom to page width; height follows the page aspect ratio.
		render_w, render_h = adjust(max_w, 0)
		render_w = max_w
		if render_h > max_h then
			-- Page too tall for the screen: contain within the max box.
			render_w, render_h = adjust(max_w, max_h)
		end
	else
		render_w, render_h = adjust(max_w, max_h)
	end

	render_w = math.max(20, render_w)
	render_h = math.max(6, render_h)

	-- Peek chrome matches the image — no letterboxed empty band.
	return {
		frame_w = render_w,
		frame_h = render_h,
		x = 0,
		y = 0,
		render_w = render_w,
		render_h = render_h,
	}
end

---Short window title from the embed fragment (not the hashed cache PNG name).
---@param fragment string
---@param is_pdf boolean
---@param page integer|nil
---@return string
local function popup_title(fragment, is_pdf, page)
	local name = vim.fn.fnamemodify(fragment, ":t")
	name = name:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
	if #name > 42 then
		name = name:sub(1, 39) .. "…"
	end
	if is_pdf then
		return string.format(" %s · p%s ", name, tostring(page or 1))
	end
	return " " .. name .. " "
end

---Place the peek below the cursor, or above when near the bottom of the screen.
---@param height integer
---@return integer row
local function popup_row_for_height(height)
	local screen_row = vim.fn.screenrow()
	local below = vim.o.lines - screen_row - 2
	if below < height + 2 and screen_row > height + 2 then
		return -(height + 1)
	end
	return 1
end

---@param preview_path string
---@param title string
---@param opts { fit_width?: boolean }|nil
local function show_embed_popup(preview_path, title, opts)
	opts = opts or {}
	if embed_popup.path == preview_path and embed_popup.win and vim.api.nvim_win_is_valid(embed_popup.win) then
		return
	end
	clear_embed_popup()

	local img_ok, img = pcall(image.from_file, preview_path, {
		with_virtual_padding = false,
	})
	if not img_ok or not img then
		return
	end

	local layout = compute_popup_layout(img.image_width or 0, img.image_height or 0, opts)
	local width, height = layout.frame_w, layout.frame_h
	local row = popup_row_for_height(height)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "image_nvim_popup"
	vim.bo[buf].modifiable = true
	-- Blank lines reduce terminal glyph bleed under transparent float backgrounds.
	local blanks = {}
	for _ = 1, height do
		blanks[#blanks + 1] = string.rep(" ", width)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, blanks)
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = row,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "left",
		zindex = 50,
		focusable = false,
		noautocmd = true,
	})

	local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")
	if ok_ts and ThemeSettings and ThemeSettings.style_float_like_which_key then
		ThemeSettings.style_float_like_which_key(win)
	end

	img.window = win
	img.buffer = buf
	img.ignore_global_max_size = true

	embed_popup.win = win
	embed_popup.buf = buf
	embed_popup.image = img
	embed_popup.path = preview_path
	embed_popup.dismissed_path = nil
	map_esc_dismiss()

	-- Defer until the float has a real screen position (same pattern as image.nvim).
	vim.defer_fn(function()
		if not embed_popup.image or embed_popup.image ~= img then
			return
		end
		if not vim.api.nvim_win_is_valid(win) then
			return
		end
		local win_info = vim.fn.getwininfo(win)[1]
		if not win_info or win_info.wincol <= 0 then
			return
		end
		pcall(function()
			img:render({
				x = layout.x,
				y = layout.y,
				width = layout.render_w,
				height = layout.render_h,
			})
		end)
	end, 10)
end

---Extract wiki or markdown image embed target from a line.
---@param line string
---@return string|nil
local function embed_target_on_line(line)
	local wiki = line:match("%!%[%[([^%]]+)%]%]")
	local md = line:match("%!%[[^%]]*%]%((.-)%)")
	return md or wiki
end

local embed_augroup = vim.api.nvim_create_augroup("ImageNvimWikiPopup", { clear = true })

vim.api.nvim_create_autocmd("CursorMoved", {
	group = embed_augroup,
	desc = "Themed cursor peek for Markdown/wiki image and PDF embeds",
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft ~= "markdown" and ft ~= "quarto" and ft ~= "pandoc" then
			return
		end
		local line = vim.api.nvim_get_current_line()
		local fragment = embed_target_on_line(line)
		if not fragment then
			embed_popup.dismissed_path = nil
			clear_embed_popup()
			return
		end

		local media = require("plugins.vim-ui-img")
		local cleaned, page = media.clean_path_fragment(fragment)
		local preview = media.resolve_preview_path(vim.api.nvim_buf_get_name(args.buf), fragment)
		if not preview then
			clear_embed_popup()
			return
		end

		-- Esc dismissed this embed; stay closed until the cursor leaves it.
		if embed_popup.dismissed_path == preview then
			return
		end

		local is_pdf = media.is_pdf_fragment(cleaned)
		local title = popup_title(cleaned, is_pdf, page)
		show_embed_popup(preview, title, { fit_width = is_pdf })
	end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "InsertEnter" }, {
	group = embed_augroup,
	callback = function()
		embed_popup.dismissed_path = nil
		clear_embed_popup()
	end,
})
