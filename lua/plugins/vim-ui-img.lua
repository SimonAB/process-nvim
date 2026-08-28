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
	-- Some editors wrap destinations in quotes: ![]('/abs/path.pdf')
	path = path:gsub("^[\"']+", ""):gsub("[\"']+$", "")
	path = percent_decode(path)
	-- Expand leading ~ after quote stripping.
	if path:sub(1, 1) == "~" then
		path = vim.fn.expand(path)
	end

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
	return require("core.platform").obsidian_vault_path()
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

-- Peek raster profile: PNG keeps slide text crisp; 144 DPI + 1600px suits a ~70% peek.
local PDF_RENDER_PROFILE = "fitw-png-1600-aav"
local PDF_DPI = "144"
local PDF_SCALE_X = "1600"
local PDF_EXT = ".png"

---Discard cached page rasters older than this (also when the source PDF is newer).
local CACHE_TTL_SEC = 24 * 60 * 60
---At most one directory prune per hour of Neovim uptime.
local PRUNE_INTERVAL_SEC = 60 * 60

---In-memory PDF page-count cache (path → pages).
local pdf_page_count_cache = {}
local last_cache_prune_at = 0

---@return string
local function pdf_cache_dir()
	return vim.fn.stdpath("cache") .. "/vim-ui-img"
end

---@param path string
---@param page integer
---@return string
local function pdf_cache_path(path, page)
	return string.format(
		"%s/%s-p%s%s",
		pdf_cache_dir(),
		vim.fn.sha256(path .. ":" .. PDF_RENDER_PROFILE):sub(1, 16),
		tostring(page),
		PDF_EXT
	)
end

---Return true when a cache file is usable (exists, within TTL, not older than source).
---@param out_path string
---@param src_path string|nil
---@return boolean
local function cache_entry_is_fresh(out_path, src_path)
	if vim.fn.filereadable(out_path) ~= 1 then
		return false
	end
	local out_mtime = vim.fn.getftime(out_path)
	if out_mtime <= 0 then
		return false
	end
	if (os.time() - out_mtime) > CACHE_TTL_SEC then
		return false
	end
	if type(src_path) == "string" and src_path ~= "" then
		local src_mtime = vim.fn.getftime(src_path)
		if src_mtime > 0 and out_mtime < src_mtime then
			return false
		end
	end
	return true
end

---Delete cache files older than the TTL (throttled).
local function prune_expired_cache()
	local now = os.time()
	if (now - last_cache_prune_at) < PRUNE_INTERVAL_SEC then
		return
	end
	last_cache_prune_at = now

	local dir = pdf_cache_dir()
	if vim.fn.isdirectory(dir) ~= 1 then
		return
	end

	for name, ftype in vim.fs.dir(dir) do
		if ftype == "file" then
			local path = dir .. "/" .. name
			local mtime = vim.fn.getftime(path)
			if mtime > 0 and (now - mtime) > CACHE_TTL_SEC then
				pcall(vim.fn.delete, path)
			end
		end
	end
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

	vim.fn.mkdir(pdf_cache_dir(), "p")
	prune_expired_cache()
	local out = pdf_cache_path(path, page)

	if cache_entry_is_fresh(out, path) then
		return out, nil
	end
	-- Drop a stale entry so we never serve an expired file if conversion fails mid-way.
	if vim.fn.filereadable(out) == 1 then
		pcall(vim.fn.delete, out)
	end

	if vim.fn.executable("pdftoppm") == 1 then
		local prefix = out:gsub("%.png$", "")
		vim.fn.system({
			"pdftoppm",
			"-png",
			"-aaVector",
			"yes",
			"-singlefile",
			"-f",
			tostring(page),
			"-l",
			tostring(page),
			"-r",
			PDF_DPI,
			"-scale-to-x",
			PDF_SCALE_X,
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
			PDF_DPI,
			string.format("%s[%d]", path, page - 1),
			"-resize",
			PDF_SCALE_X .. "x>",
			out,
		})
		if vim.v.shell_error == 0 and vim.fn.filereadable(out) == 1 then
			return out, nil
		end
	end

	return nil, "need pdftoppm (poppler) or ImageMagick to preview PDF"
end

---Return the number of pages in a PDF, or nil when unknown.
---@param path string
---@return integer|nil
function M.pdf_page_count(path)
	if not is_pdf_path(path) then
		return nil
	end
	local cached = pdf_page_count_cache[path]
	if cached then
		return cached
	end
	if vim.fn.executable("pdfinfo") == 1 then
		local out = vim.fn.system({ "pdfinfo", path })
		if vim.v.shell_error == 0 then
			local n = tonumber(out:match("[Pp]ages:%s*(%d+)"))
			if n and n > 0 then
				pdf_page_count_cache[path] = n
				return n
			end
		end
	end
	return nil
end

---Return true when a cleaned fragment looks like a PDF path.
---@param fragment string
---@return boolean
function M.is_pdf_fragment(fragment)
	local ext = path_ext(fragment or "")
	return ext ~= nil and ext:lower() == "pdf"
end

---Resolve a document-relative image/PDF fragment to a previewable PNG/image path.
---@param document_path string
---@param image_path string
---@param page_override integer|nil Force a PDF page (ignores `#page=` in the fragment).
---@return string|nil preview_path, string|nil source_path, integer|nil page
function M.resolve_preview_path(document_path, image_path, page_override)
	local fragment, page = M.clean_path_fragment(image_path)
	if page_override ~= nil then
		page = math.max(1, page_override)
	end
	local resolved = M.resolve_existing_path(fragment, document_path, nil)
	if not resolved then
		return nil, nil, nil
	end

	if is_pdf_path(resolved) then
		local png, err = M.ensure_pdf_png(resolved, page)
		if not png then
			vim.notify("PDF preview failed: " .. tostring(err), vim.log.levels.WARN)
			return nil, resolved, page
		end
		return png, resolved, page
	end

	return resolved, resolved, nil
end

---Warm the PNG cache for a PDF page without blocking the UI.
---@param path string
---@param page integer
function M.prefetch_pdf_page(path, page)
	if not is_pdf_path(path) or page < 1 then
		return
	end

	local out = pdf_cache_path(path, page)
	if cache_entry_is_fresh(out, path) then
		return
	end

	if vim.fn.executable("pdftoppm") ~= 1 then
		vim.schedule(function()
			M.ensure_pdf_png(path, page)
		end)
		return
	end

	vim.fn.mkdir(pdf_cache_dir(), "p")
	local prefix = out:gsub("%.png$", "")
	vim.system({
		"pdftoppm",
		"-png",
		"-aaVector",
		"yes",
		"-singlefile",
		"-f",
		tostring(page),
		"-l",
		tostring(page),
		"-r",
		PDF_DPI,
		"-scale-to-x",
		PDF_SCALE_X,
		"-scale-to-y",
		"-1",
		path,
		prefix,
	}, { text = true }, function() end)
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

	if is_pdf_path(resolved) then
		if require("core.platform").open_pdf(resolved) then
			vim.notify("Opened: " .. vim.fn.fnamemodify(resolved, ":t"), vim.log.levels.INFO)
			return
		end
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
	if arg == nil or arg == "" then
		arg = nil
	end
	M.open_external(arg)
end, { nargs = "?", complete = "file", desc = "Open image/PDF attachment in system viewer" })

---Derive alt/descriptor text from a markdown link destination.
---Skips remote URLs; uses the basename (matches obsidian.nvim paste + vault style).
---@param dest string
---@return string|nil
local function descriptor_from_dest(dest)
	dest = M.clean_path_fragment(dest)
	if dest:match("^%a+://") then
		return nil
	end
	local basename = vim.fn.fnamemodify(dest, ":t")
	if basename == "" or basename == "." then
		return nil
	end
	return basename
end

---Fill empty image alt text, e.g. `![](<../attachments/foo.png>)` → `![foo.png](<../attachments/foo.png>)`.
---Skips fenced code blocks. Returns updated text and the number of replacements.
---@param text string
---@return string new_text, integer changes
function M.fill_empty_attachment_descriptors(text)
	local in_fence = false
	local out_lines = {}
	local changes = 0

	for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
		if line:match("^```") then
			in_fence = not in_fence
			out_lines[#out_lines + 1] = line
		elseif in_fence then
			out_lines[#out_lines + 1] = line
		else
			local new_line = line:gsub("!%[%]%(([^)]*)%)", function(raw_dest)
				local dest = vim.trim(raw_dest)
				local angle_inner = dest:match("^<(.*)>$")
				if angle_inner then
					dest = angle_inner
				end
				local descriptor = descriptor_from_dest(dest)
				if not descriptor then
					return "![](" .. raw_dest .. ")"
				end
				changes = changes + 1
				if angle_inner or raw_dest:match("^%s*<") then
					return "![" .. descriptor .. "](<" .. dest .. ">)"
				end
				return "![" .. descriptor .. "](" .. raw_dest .. ")"
			end)
			out_lines[#out_lines + 1] = new_line
		end
	end

	return table.concat(out_lines, "\n"), changes
end

local attachment_descriptor_augroup = vim.api.nvim_create_augroup("MarkdownAttachmentDescriptors", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
	group = attachment_descriptor_augroup,
	pattern = "*.md",
	desc = "Fill empty attachment image alt text on save",
	callback = function(args)
		local bufnr = args.buf
		if not vim.bo[bufnr].modifiable then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local content = table.concat(lines, "\n")
		local new_content, changes = M.fill_empty_attachment_descriptors(content)
		if changes == 0 or new_content == content then
			return
		end

		local view = vim.fn.winsaveview()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(new_content, "\n", { plain = true }))
		vim.fn.winrestview(view)
	end,
})

return M
