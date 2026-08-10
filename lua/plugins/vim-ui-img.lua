-- Configuration for Markdown attachment helpers
-- PDF→PNG page cache and system open for Obsidian embeds (used by image.nvim).

local M = {}

local IMAGE_EXTS = {
	png = true,
	jpg = true,
	jpeg = true,
	gif = true,
	webp = true,
	bmp = true,
	tif = true,
	tiff = true,
	avif = true,
}

---@param path string
---@return string|nil
local function path_ext(path)
	return path:match("%.([%w]+)$")
end

---@param path string
---@return boolean
local function is_pdf_path(path)
	local ext = path_ext(path)
	return ext ~= nil and ext:lower() == "pdf"
end

---@param path string
---@return boolean
local function is_image_path(path)
	local ext = path_ext(path)
	return ext ~= nil and IMAGE_EXTS[ext:lower()] == true
end

---@param path string
---@return boolean
local function is_previewable_path(path)
	return is_image_path(path) or is_pdf_path(path)
end

---Percent-decode a path fragment (`%20` → space). Obsidian often encodes spaces.
---@param s string
---@return string
local function percent_decode(s)
	return (s:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

---Clean a Markdown/wiki path fragment and optional PDF page.
---@param raw string
---@return string path, integer page
function M.clean_path_fragment(raw)
	local path = vim.trim(raw or "")
	path = path:gsub("^<%s*", ""):gsub("%s*>$", "")
	path = path:gsub("^%[", ""):gsub("%]$", "")
	path = percent_decode(path)

	local page = 1
	local page_from_hash = path:match("#[Pp]age=(%d+)") or path:match("#p(%d+)") or path:match("#(%d+)$")
	if page_from_hash then
		page = math.max(1, tonumber(page_from_hash) or 1)
	end

	path = path:match("^([^|#]+)") or path
	return vim.trim(path), page
end

---@return string
local function get_obsidian_vault_path()
	local env_path = vim.env.OBSIDIAN_VAULT_PATH
	if env_path and env_path ~= "" then
		return vim.fn.expand(env_path)
	end
	return vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notebook")
end

---Resolve a fragment to an existing image/PDF path.
---@param fragment string
---@param document_path string|nil
---@param bufnr integer|nil
---@return string|nil
function M.resolve_existing_path(fragment, document_path, bufnr)
	fragment = vim.trim(fragment or "")
	if fragment == "" then
		return nil
	end

	local candidates = {}
	local function add(path)
		if type(path) == "string" and path ~= "" then
			candidates[#candidates + 1] = path
		end
	end

	if fragment:sub(1, 1) == "/" or fragment:match("^%a:[/\\]") then
		add(fragment)
	else
		local buf_dir
		if document_path and document_path ~= "" then
			buf_dir = vim.fn.fnamemodify(document_path, ":p:h")
		elseif bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			local buf_name = vim.api.nvim_buf_get_name(bufnr)
			buf_dir = buf_name ~= "" and vim.fn.fnamemodify(buf_name, ":p:h") or vim.fn.getcwd()
		else
			buf_dir = vim.fn.getcwd()
		end

		local cwd = vim.fn.getcwd()
		local vault = get_obsidian_vault_path()

		add(buf_dir .. "/" .. fragment)
		add(cwd .. "/" .. fragment)
		add(vault .. "/" .. fragment)
		add(vault .. "/attachments/" .. fragment)
		add(buf_dir .. "/attachments/" .. fragment)
		if not fragment:find("attachments/", 1, true) then
			add(buf_dir .. "/../attachments/" .. vim.fn.fnamemodify(fragment, ":t"))
			add(vault .. "/attachments/" .. vim.fn.fnamemodify(fragment, ":t"))
		end
	end

	for _, path in ipairs(candidates) do
		local normalised = vim.fn.fnamemodify(path, ":p")
		if vim.fn.filereadable(normalised) == 1 and is_previewable_path(normalised) then
			return normalised
		end
	end

	return nil
end

---Convert a PDF page to a cached PNG (pdftoppm, else ImageMagick).
---@param path string
---@param page integer|nil
---@return string|nil, string|nil
function M.ensure_pdf_png(path, page)
	page = page or 1
	if not is_pdf_path(path) then
		return path, nil
	end

	local cache_dir = vim.fn.stdpath("cache") .. "/vim-ui-img"
	vim.fn.mkdir(cache_dir, "p")
	-- Hash includes render profile so DPI/width bumps invalidate stale cache.
	local out = string.format(
		"%s/%s-p%s.png",
		cache_dir,
		vim.fn.sha256(path .. ":fitw-1600"):sub(1, 16),
		tostring(page)
	)

	if vim.fn.filereadable(out) == 1 then
		local src_mtime = vim.fn.getftime(path)
		local out_mtime = vim.fn.getftime(out)
		if src_mtime > 0 and out_mtime >= src_mtime then
			return out, nil
		end
	end

	-- Wide enough for ~70% window peeks; modest DPI keeps conversion snappy.
	local dpi = "120"

	if vim.fn.executable("pdftoppm") == 1 then
		local prefix = out:gsub("%.png$", "")
		vim.fn.system({
			"pdftoppm",
			"-png",
			"-singlefile",
			"-f",
			tostring(page),
			"-l",
			tostring(page),
			"-r",
			dpi,
			"-scale-to-x",
			"1600",
			"-scale-to-y",
			"-1",
			path,
			prefix,
		})
		if vim.v.shell_error == 0 and vim.fn.filereadable(out) == 1 then
			return out, nil
		end
	end

	if vim.fn.executable("magick") == 1 then
		vim.fn.system({
			"magick",
			"-density",
			dpi,
			string.format("%s[%d]", path, page - 1),
			"-resize",
			"1600x>",
			out,
		})
		if vim.v.shell_error == 0 and vim.fn.filereadable(out) == 1 then
			return out, nil
		end
	end

	return nil, "need pdftoppm (poppler) or ImageMagick to preview PDF"
end

---Return true when a cleaned fragment looks like a PDF path.
---@param fragment string
---@return boolean
function M.is_pdf_fragment(fragment)
	local ext = path_ext(fragment or "")
	return ext ~= nil and ext:lower() == "pdf"
end

---Resolve a document-relative image/PDF fragment to a previewable PNG/image path.
---Used by image.nvim `resolve_image_path` and the cursor PDF popup.
---@param document_path string
---@param image_path string
---@return string|nil
function M.resolve_preview_path(document_path, image_path)
	local fragment, page = M.clean_path_fragment(image_path)
	local resolved = M.resolve_existing_path(fragment, document_path, nil)
	if not resolved then
		return nil
	end

	if is_pdf_path(resolved) then
		local png, err = M.ensure_pdf_png(resolved, page)
		if not png then
			vim.notify("PDF preview failed: " .. tostring(err), vim.log.levels.WARN)
		end
		return png
	end

	return resolved
end

---Resolve attachment under the cursor (image or PDF).
---@return string|nil path, integer|nil page
function M.resolve_path()
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_get_current_line()

	local wiki = line:match("%!%[%[([^%]]+)%]%]")
	local md = line:match("%!%[[^%]]*%]%((.-)%)")
	local raw = wiki or md
	if raw then
		local fragment, page = M.clean_path_fragment(raw)
		local resolved = M.resolve_existing_path(fragment, vim.api.nvim_buf_get_name(bufnr), bufnr)
		if resolved then
			return resolved, page
		end
	end

	local under_cursor = vim.fn.expand("<cfile>")
	if type(under_cursor) == "string" and under_cursor ~= "" then
		local fragment, page = M.clean_path_fragment(under_cursor)
		local resolved = M.resolve_existing_path(fragment, vim.api.nvim_buf_get_name(bufnr), bufnr)
		if resolved then
			return resolved, page
		end
	end

	return nil, nil
end

---Open the attachment under the cursor in the system viewer (Preview/Skim/etc.).
---@param path string|nil
function M.open_external(path)
	local resolved = path
	if not resolved then
		resolved = M.resolve_path()
	else
		resolved = M.resolve_existing_path(
			select(1, M.clean_path_fragment(path)),
			vim.api.nvim_buf_get_name(0),
			vim.api.nvim_get_current_buf()
		)
	end

	if not resolved then
		vim.notify("No image/PDF attachment on this line", vim.log.levels.WARN)
		return
	end

	if is_pdf_path(resolved) and vim.fn.executable("open") == 1 then
		if vim.fn.isdirectory("/Applications/Skim.app") == 1 then
			vim.fn.jobstart({ "open", "-a", "Skim", resolved }, { detach = true })
			vim.notify("Opened in Skim: " .. vim.fn.fnamemodify(resolved, ":t"), vim.log.levels.INFO)
			return
		end
		vim.fn.jobstart({ "open", resolved }, { detach = true })
		vim.notify("Opened: " .. vim.fn.fnamemodify(resolved, ":t"), vim.log.levels.INFO)
		return
	end

	if vim.ui and type(vim.ui.open) == "function" then
		local ok, err = pcall(vim.ui.open, resolved)
		if ok then
			vim.notify("Opened: " .. vim.fn.fnamemodify(resolved, ":t"), vim.log.levels.INFO)
			return
		end
		vim.notify("Open failed: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	if vim.fn.executable("open") == 1 then
		vim.fn.jobstart({ "open", resolved }, { detach = true })
		vim.notify("Opened: " .. vim.fn.fnamemodify(resolved, ":t"), vim.log.levels.INFO)
		return
	end

	vim.notify("No system open handler for " .. resolved, vim.log.levels.WARN)
end

---Clear image.nvim previews (compat for old ImageClear callers).
---@param silent boolean|nil
function M.clear(silent)
	local ok, image = pcall(require, "image")
	if ok and image and type(image.clear) == "function" then
		pcall(image.clear)
	end
	pcall(vim.ui.img.del, math.huge)
	if not silent then
		vim.notify("Cleared media previews", vim.log.levels.INFO)
	end
end

---Force image.nvim to re-evaluate the current buffer (compat for ImageRefresh).
---@param _winid integer|nil
---@param _opts table|nil
function M.refresh(_winid, _opts)
	local ok, image = pcall(require, "image")
	if not ok or not image then
		vim.notify("image.nvim not available", vim.log.levels.WARN)
		return
	end
	pcall(image.clear)
	if type(image.enable) == "function" then
		pcall(image.enable)
	end
	-- Nudge cursor so the cursor-popup integration re-renders.
	local winid = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(winid)
	vim.api.nvim_win_set_cursor(winid, cursor)
	vim.cmd("doautocmd CursorMoved")
end

M.show = M.refresh
M.peek = M.refresh
M.refresh_inline = M.refresh

vim.api.nvim_create_user_command("ImageShow", function()
	M.refresh()
end, { desc = "Refresh image.nvim cursor preview" })

vim.api.nvim_create_user_command("ImageClear", function()
	M.clear(false)
end, { desc = "Clear image.nvim / media previews" })

vim.api.nvim_create_user_command("ImageRefresh", function()
	M.refresh()
end, { desc = "Refresh image.nvim cursor preview" })

vim.api.nvim_create_user_command("AttachmentOpen", function(opts)
	local arg = opts.args
	if arg == "" then
		arg = nil
	end
	M.open_external(arg)
end, { nargs = "?", complete = "file", desc = "Open image/PDF attachment in system viewer" })

return M
