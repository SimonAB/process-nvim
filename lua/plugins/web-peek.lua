-- Configuration for Markdown website link peeks
-- Cursor float with page title/description and optional Open Graph image.

local M = {}

local CACHE_TTL_SEC = 24 * 60 * 60
local FETCH_TIMEOUT_SEC = 6
local DEBOUNCE_MS = 280
local USER_AGENT = "Mozilla/5.0 (compatible; NeovimWebPeek/1.0)"

local peek = {
	win = nil,
	buf = nil,
	image = nil,
	url = nil,
	dismissed_url = nil,
	key_bufnr = nil,
	request_id = 0,
	timer = nil,
}

---@return string
local function cache_dir()
	return vim.fn.stdpath("cache") .. "/vim-ui-img/web"
end

---@param url string
---@return string
local function meta_cache_path(url)
	return cache_dir() .. "/" .. vim.fn.sha256(url):sub(1, 16) .. ".json"
end

---@param url string
---@return string
local function image_cache_path(url)
	-- Strip query/fragment so `photo.jpg?w=800` still yields a usable extension.
	local path_only = (url:match("^([^?#]+)") or url):lower()
	local ext = path_only:match("%.([%w]+)$") or "png"
	if not vim.tbl_contains({ "png", "jpg", "jpeg", "webp", "gif", "avif" }, ext) then
		ext = "png"
	end
	return cache_dir() .. "/" .. vim.fn.sha256(url):sub(1, 16) .. "." .. ext
end

---@param path string
---@return boolean
local function file_is_fresh(path)
	if vim.fn.filereadable(path) ~= 1 then
		return false
	end
	local mtime = vim.fn.getftime(path)
	return mtime > 0 and (os.time() - mtime) <= CACHE_TTL_SEC
end

---@param s string
---@return string
local function decode_entities(s)
	s = s:gsub("&nbsp;", " ")
	s = s:gsub("&amp;", "&")
	s = s:gsub("&lt;", "<")
	s = s:gsub("&gt;", ">")
	s = s:gsub("&quot;", '"')
	s = s:gsub("&#39;", "'")
	s = s:gsub("&#x(%x+);", function(hex)
		return vim.fn.nr2char(tonumber(hex, 16) or 0)
	end)
	s = s:gsub("&#(%d+);", function(dec)
		return vim.fn.nr2char(tonumber(dec) or 0)
	end)
	return s
end

---@param s string|nil
---@return string|nil
local function clean_text(s)
	if type(s) ~= "string" or s == "" then
		return nil
	end
	s = decode_entities(s)
	s = s:gsub("%s+", " ")
	return vim.trim(s)
end

---@param html string
---@param key string
---@return string|nil
local function meta_by_property(html, key)
	local patterns = {
		'[Pp]roperty=["\']' .. key .. '["\'][^>]*[Cc]ontent=["\']([^"\']+)["\']',
		'[Cc]ontent=["\']([^"\']+)["\'][^>]*[Pp]roperty=["\']' .. key .. '["\']',
	}
	for _, pat in ipairs(patterns) do
		local value = html:match(pat)
		if value then
			return clean_text(value)
		end
	end
	return nil
end

---@param html string
---@param key string
---@return string|nil
local function meta_by_name(html, key)
	local patterns = {
		'[Nn]ame=["\']' .. key .. '["\'][^>]*[Cc]ontent=["\']([^"\']+)["\']',
		'[Cc]ontent=["\']([^"\']+)["\'][^>]*[Nn]ame=["\']' .. key .. '["\']',
	}
	for _, pat in ipairs(patterns) do
		local value = html:match(pat)
		if value then
			return clean_text(value)
		end
	end
	return nil
end

---@param page_url string
---@param maybe_relative string|nil
---@return string|nil
local function absolutise_url(page_url, maybe_relative)
	if type(maybe_relative) ~= "string" or maybe_relative == "" then
		return nil
	end
	if maybe_relative:match("^https?://") then
		return maybe_relative
	end
	if maybe_relative:sub(1, 2) == "//" then
		local scheme = page_url:match("^(https?):") or "https"
		return scheme .. ":" .. maybe_relative
	end
	local origin = page_url:match("^(https?://[^/]+)")
	if not origin then
		return nil
	end
	if maybe_relative:sub(1, 1) == "/" then
		return origin .. maybe_relative
	end
	local base = page_url:match("^(https?://.*/)") or (origin .. "/")
	return base .. maybe_relative
end

---@param html string
---@param page_url string
---@return string|nil
local function icon_from_html(html, page_url)
	local patterns = {
		'[Rr]el=["\']apple%-touch%-icon[^"\']*["\'][^>]*[Hh]ref=["\']([^"\']+)["\']',
		'[Hh]ref=["\']([^"\']+)["\'][^>]*[Rr]el=["\']apple%-touch%-icon[^"\']*["\']',
		'[Rr]el=["\']shortcut icon["\'][^>]*[Hh]ref=["\']([^"\']+)["\']',
		'[Hh]ref=["\']([^"\']+)["\'][^>]*[Rr]el=["\']shortcut icon["\']',
		'[Rr]el=["\']icon["\'][^>]*[Hh]ref=["\']([^"\']+)["\']',
		'[Hh]ref=["\']([^"\']+)["\'][^>]*[Rr]el=["\']icon["\']',
	}
	for _, pat in ipairs(patterns) do
		local href = html:match(pat)
		local abs = absolutise_url(page_url, href)
		if abs then
			return abs
		end
	end
	return nil
end

---Optional icon / on-page image when Open Graph is absent (not a screenshot).
---@param page_url string
---@param html string|nil
---@return string|nil
local function fallback_image_url(page_url, html)
	if type(html) ~= "string" or html == "" then
		return nil
	end

	local from_html = icon_from_html(html, page_url)
	if from_html then
		return from_html
	end

	-- First on-page raster image (skip scripts/SVGs).
	for src in html:gmatch("[Ss][Rr][Cc]=[\"']([^\"']+)[\"']") do
		local lower = src:lower()
		if lower:match("%.png") or lower:match("%.jpe?g") or lower:match("%.webp") or lower:match("%.gif") then
			local abs = absolutise_url(page_url, src)
			if abs then
				return abs
			end
		end
	end
	return nil
end

---@param page_url string
---@return string
local function screenshot_cache_path(page_url)
	return cache_dir() .. "/" .. vim.fn.sha256(page_url):sub(1, 16) .. "-mobile-land-600.png"
end

---True for legacy / useless preview URLs that should be replaced by a mobile screenshot.
---@param image_url string|nil
---@return boolean
local function is_weak_preview_image(image_url)
	if type(image_url) ~= "string" or image_url == "" then
		return true
	end
	return image_url:match("thum%.io")
		or image_url:match("google%.com/s2/favicons")
		or image_url:match("icons%.duckduckgo%.com")
		or image_url:match("^https://github%.com/[%w%-]+%.png") ~= nil
end

---@param html string
---@param page_url string
---@return { title: string|nil, description: string|nil, image: string|nil, site: string|nil }
local function parse_html_meta(html, page_url)
	local title = meta_by_property(html, "og:title")
		or meta_by_name(html, "twitter:title")
		or clean_text(html:match("<[Tt]itle[^>]*>(.-)</[Tt]itle>"))
	local description = meta_by_property(html, "og:description")
		or meta_by_name(html, "description")
		or meta_by_name(html, "twitter:description")
		or clean_text(html:match("<[Pp][^>]*class=[\"'][^\"']*sub[^\"']*[\"'][^>]*>(.-)</[Pp]>"))
	local image = absolutise_url(
		page_url,
		meta_by_property(html, "og:image") or meta_by_name(html, "twitter:image")
	) or fallback_image_url(page_url, html)
	local site = meta_by_property(html, "og:site_name")
		or page_url:match("^https?://([^/]+)")
	return {
		title = title,
		description = description,
		image = image,
		site = site,
	}
end

---@param url string
---@return { title: string|nil, description: string|nil, image: string|nil, site: string|nil }|nil
local function read_meta_cache(url)
	local path = meta_cache_path(url)
	if not file_is_fresh(path) then
		return nil
	end
	local ok, data = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
	end)
	if ok and type(data) == "table" then
		-- Drop weak legacy preview URLs; mobile screenshot runs at display time.
		if is_weak_preview_image(data.image) then
			data.image = nil
		end
		return data
	end
	return nil
end

---@param url string
---@param meta table
local function write_meta_cache(url, meta)
	vim.fn.mkdir(cache_dir(), "p")
	local path = meta_cache_path(url)
	pcall(function()
		vim.fn.writefile({ vim.json.encode(meta) }, path)
	end)
end

---Extract the best http(s) URL from a Markdown line (links preferred over bare URLs).
---@param line string
---@return string|nil
function M.url_on_line(line)
	if type(line) ~= "string" or line == "" then
		return nil
	end
	-- Image embeds are handled by the media peek.
	if line:match("%!%[") then
		return nil
	end

	local from_md = line:match("%[[^%]]*%]%(%s*<?(https?://[^%)%s>]+)>?%s*%)")
	local from_angle = line:match("%<(https?://[^>]+)>")
	local from_bare = line:match("(https?://[%w%-._~:/%?#%[%]@!$&'()*+,;=%%]+)")
	local from_www = line:match("(www%.[%w%-._~:/%?#%[%]@!$&'()*+,;=%%]+)")
	local raw = from_md or from_angle or from_bare or from_www
	if not raw then
		return nil
	end
	raw = raw:gsub("[.,;:!?)]+$", "")
	if raw:match("^www%.") then
		raw = "https://" .. raw
	end
	if raw:match("^https?://") then
		return raw
	end
	return nil
end

local function popup_is_open()
	return peek.win ~= nil and vim.api.nvim_win_is_valid(peek.win)
end

local function unmap_keys()
	local bufnr = peek.key_bufnr
	peek.key_bufnr = nil
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	for _, lhs in ipairs({ "<Esc>", "<CR>" }) do
		pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
	end
end

function M.clear()
	unmap_keys()
	if peek.image then
		pcall(function()
			peek.image:clear()
		end)
		peek.image = nil
	end
	if peek.win and vim.api.nvim_win_is_valid(peek.win) then
		pcall(vim.api.nvim_win_close, peek.win, true)
	end
	if peek.buf and vim.api.nvim_buf_is_valid(peek.buf) then
		pcall(vim.api.nvim_buf_delete, peek.buf, { force = true })
	end
	peek.win = nil
	peek.buf = nil
	peek.url = nil
end

local function dismiss()
	if not popup_is_open() then
		return
	end
	peek.dismissed_url = peek.url
	M.clear()
end

local function open_url()
	local url = peek.url
	if not url then
		return
	end
	if vim.ui and type(vim.ui.open) == "function" then
		pcall(vim.ui.open, url)
		return
	end
	if vim.fn.executable("open") == 1 then
		vim.fn.jobstart({ "open", url }, { detach = true })
	end
end

local function map_keys()
	local bufnr = vim.api.nvim_get_current_buf()
	if peek.key_bufnr == bufnr then
		return
	end
	unmap_keys()
	vim.keymap.set("n", "<Esc>", dismiss, { buffer = bufnr, silent = true, desc = "Dismiss web peek" })
	vim.keymap.set("n", "<CR>", open_url, { buffer = bufnr, silent = true, desc = "Open link in browser" })
	peek.key_bufnr = bufnr
end

---@param text string
---@param width integer
---@return string[]
local function wrap_text(text, width)
	local lines = {}
	local remaining = text
	while #remaining > 0 do
		if #remaining <= width then
			lines[#lines + 1] = remaining
			break
		end
		local chunk = remaining:sub(1, width)
		local split_at = chunk:match(".*()%s")
		if not split_at or split_at < math.floor(width * 0.5) then
			split_at = width
		end
		lines[#lines + 1] = vim.trim(remaining:sub(1, split_at))
		remaining = vim.trim(remaining:sub(split_at + 1))
	end
	return lines
end

---@param url string
---@param meta table
---@param image_path string|nil
local function show_peek(url, meta, image_path)
	if peek.dismissed_url == url then
		return
	end
	-- Always rebuild: the loading placeholder shares `peek.url` with the final peek.
	M.clear()

	local win_width = vim.api.nvim_win_get_width(0)
	local width = math.max(36, math.min(72, math.floor(win_width * 0.55)))
	local host = meta.site or url:match("^https?://([^/]+)") or "link"
	local lines = {}
	if meta.title and meta.title ~= "" then
		for _, line in ipairs(wrap_text(meta.title, width - 2)) do
			lines[#lines + 1] = line
		end
		lines[#lines + 1] = ""
	end
	if meta.description and meta.description ~= "" then
		local desc = meta.description
		if #desc > 420 then
			desc = desc:sub(1, 417) .. "…"
		end
		for _, line in ipairs(wrap_text(desc, width - 2)) do
			lines[#lines + 1] = line
		end
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = url
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Esc dismiss · Enter open"

	local text_height = #lines
	local image_height = 0
	local img = nil
	if image_path and vim.fn.filereadable(image_path) == 1 then
		local ok_image, image = pcall(require, "image")
		if ok_image then
			local img_ok, loaded = pcall(image.from_file, image_path, { with_virtual_padding = false })
			if img_ok and loaded and loaded.image_width and loaded.image_height and loaded.image_width > 0 then
				img = loaded
				local aspect = loaded.image_width / math.max(loaded.image_height, 1)
				image_height = math.max(6, math.min(16, math.floor(width * 0.5 / aspect)))
			end
		end
	end

	local max_h = math.max(6, math.floor(vim.o.lines * 0.55))
	if image_height > 0 and text_height + image_height > max_h then
		-- Keep the OG image visible; trim description/title lines if needed.
		local keep = math.max(3, max_h - image_height)
		while #lines > keep do
			table.remove(lines)
		end
		text_height = #lines
	end
	local height = math.min(max_h, text_height + image_height)
	height = math.max(6, height)

	local screen_row = vim.fn.screenrow()
	local below = vim.o.lines - screen_row - 2
	local row = 1
	if below < height + 2 and screen_row > height + 2 then
		row = -(height + 1)
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "web_peek"
	vim.bo[buf].modifiable = true
	local display = {}
	for i = 1, height do
		display[i] = lines[i] or string.rep(" ", width)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display)
	vim.bo[buf].modifiable = false

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = row,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " " .. host .. " ",
		title_pos = "left",
		zindex = 50,
		focusable = false,
		noautocmd = true,
	})

	local ok_ts, ThemeSettings = pcall(require, "core.theme-settings")
	if ok_ts and ThemeSettings and ThemeSettings.style_float_like_which_key then
		ThemeSettings.style_float_like_which_key(win)
	end

	peek.win = win
	peek.buf = buf
	peek.url = url
	peek.dismissed_url = nil
	map_keys()

	if img and image_height > 0 then
		img.window = win
		img.buffer = buf
		img.ignore_global_max_size = true
		peek.image = img
		vim.defer_fn(function()
			if peek.image ~= img or not vim.api.nvim_win_is_valid(win) then
				return
			end
			pcall(function()
				img:render({
					x = 0,
					y = text_height,
					width = width,
					height = image_height,
				})
			end)
		end, 10)
	end
end

---@param page_url string
---@param dest string
---@param request_id integer
---@param meta table
local function fetch_mobile_screenshot(page_url, dest, request_id, meta)
	vim.fn.mkdir(cache_dir(), "p")
	-- Microlink: landscape mobile viewport — wider, fits the peek float better than portrait.
	vim.system({
		"curl",
		"-fsSG",
		"--max-time",
		"30",
		"--data-urlencode",
		"url=" .. page_url,
		"--data-urlencode",
		"screenshot=true",
		"--data-urlencode",
		"meta=false",
		"--data",
		"viewport.width=844",
		"--data",
		"viewport.height=600",
		"--data",
		"viewport.deviceScaleFactor=2",
		"--data",
		"viewport.isMobile=true",
		"--data",
		"viewport.hasTouch=true",
		"--data",
		"viewport.isLandscape=true",
		"https://api.microlink.io/",
	}, { text = true }, function(api)
		vim.schedule(function()
			if peek.request_id ~= request_id or peek.dismissed_url == page_url then
				return
			end
			if api.code ~= 0 or type(api.stdout) ~= "string" or api.stdout == "" then
				return
			end
			local ok, payload = pcall(vim.json.decode, api.stdout)
			local shot = ok
				and payload
				and payload.data
				and payload.data.screenshot
				and payload.data.screenshot.url
			if type(shot) ~= "string" or shot == "" then
				return
			end
			vim.system({
				"curl",
				"-fsSL",
				"-L",
				"--max-time",
				"20",
				"-A",
				USER_AGENT,
				"-o",
				dest,
				shot,
			}, {}, function(img)
				vim.schedule(function()
					if peek.request_id ~= request_id or peek.dismissed_url == page_url then
						return
					end
					if img.code == 0 and vim.fn.filereadable(dest) == 1 and vim.fn.getfsize(dest) > 0 then
						show_peek(page_url, meta, dest)
					end
				end)
			end)
		end)
	end)
end

---@param url string
---@param meta table
---@param request_id integer
local function maybe_fetch_og_image(url, meta, request_id)
	-- Show text immediately; attach image when (or if) the download finishes.
	if meta.image and not is_weak_preview_image(meta.image) then
		local dest = image_cache_path(meta.image)
		if file_is_fresh(dest) then
			show_peek(url, meta, dest)
			return
		end

		show_peek(url, meta, nil)
		vim.fn.mkdir(cache_dir(), "p")
		vim.system({
			"curl",
			"-fsSL",
			"-L",
			"--max-time",
			tostring(FETCH_TIMEOUT_SEC),
			"-A",
			USER_AGENT,
			"-o",
			dest,
			meta.image,
		}, {}, function(obj)
			vim.schedule(function()
				if peek.request_id ~= request_id then
					return
				end
				if peek.dismissed_url == url then
					return
				end
				if obj.code == 0 and vim.fn.filereadable(dest) == 1 and vim.fn.getfsize(dest) > 0 then
					show_peek(url, meta, dest)
				else
					-- OG/icon failed: fall back to a real mobile screenshot.
					fetch_mobile_screenshot(url, screenshot_cache_path(url), request_id, meta)
				end
			end)
		end)
		return
	end

	local dest = screenshot_cache_path(url)
	if file_is_fresh(dest) then
		show_peek(url, meta, dest)
		return
	end
	show_peek(url, meta, nil)
	fetch_mobile_screenshot(url, dest, request_id, meta)
end

---@param url string
local function fetch_and_show(url)
	local cached = read_meta_cache(url)
	if cached then
		peek.request_id = peek.request_id + 1
		local request_id = peek.request_id
		maybe_fetch_og_image(url, cached, request_id)
		return
	end

	peek.request_id = peek.request_id + 1
	local request_id = peek.request_id

	-- Lightweight placeholder while fetching.
	show_peek(url, {
		title = "Loading…",
		description = nil,
		site = url:match("^https?://([^/]+)"),
	}, nil)

	vim.system({
		"curl",
		"-fsSL",
		"-L",
		"--max-time",
		tostring(FETCH_TIMEOUT_SEC),
		"-A",
		USER_AGENT,
		url,
	}, { text = true }, function(obj)
		vim.schedule(function()
			if peek.request_id ~= request_id then
				return
			end
			local html = obj.stdout or ""
			local meta
			if obj.code == 0 and html ~= "" then
				meta = parse_html_meta(html, url)
				write_meta_cache(url, meta)
			else
				meta = {
					title = "Could not fetch page",
					description = "Press Enter to open in the browser.",
					site = url:match("^https?://([^/]+)"),
				}
			end
			maybe_fetch_og_image(url, meta, request_id)
		end)
	end)
end

---@param url string
local function schedule_peek(url)
	if peek.timer then
		peek.timer:stop()
		peek.timer:close()
		peek.timer = nil
	end
	peek.timer = vim.uv.new_timer()
	peek.timer:start(DEBOUNCE_MS, 0, function()
		vim.schedule(function()
			if peek.timer then
				peek.timer:stop()
				peek.timer:close()
				peek.timer = nil
			end
			if peek.dismissed_url == url then
				return
			end
			fetch_and_show(url)
		end)
	end)
end

local augroup = vim.api.nvim_create_augroup("WebPeekPopup", { clear = true })

vim.api.nvim_create_autocmd("CursorMoved", {
	group = augroup,
	desc = "Themed cursor peek for Markdown website links",
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft ~= "markdown" and ft ~= "quarto" and ft ~= "pandoc" then
			return
		end
		local line = vim.api.nvim_get_current_line()
		local url = M.url_on_line(line)
		if not url then
			peek.dismissed_url = nil
			M.clear()
			return
		end
		if peek.dismissed_url == url then
			return
		end
		if peek.url == url and popup_is_open() then
			return
		end
		schedule_peek(url)
	end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "InsertEnter" }, {
	group = augroup,
	callback = function()
		peek.dismissed_url = nil
		if peek.timer then
			peek.timer:stop()
			peek.timer:close()
			peek.timer = nil
		end
		M.clear()
	end,
})

return M
