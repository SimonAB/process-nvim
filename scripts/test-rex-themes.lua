-- Verify generated Rex colourschemes and terminal-theme following without
-- touching user settings. Run from `config/nvim`:
--   nvim --headless -u NONE -l scripts/test-rex-themes.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.env.REX_SESSION = "test"

local follow = require("core.rex-follow")
local index = require("core.rex-index")

-- Every generated scheme loads, names itself and sets a background.
local files = vim.fn.glob("colors/rex-*.lua", true, true)
assert(#files == #index, "colours/ and rex-index.lua list the same themes")
for _, file in ipairs(files) do
	local name = vim.fn.fnamemodify(file, ":t:r")
	assert(pcall(vim.cmd.colorscheme, name), "loads " .. name)
	assert(vim.g.colors_name == name, "names itself " .. name)
	assert(vim.api.nvim_get_hl(0, { name = "Normal" }).bg, "sets Normal background " .. name)
end

-- OSC replies parse at 8 and 16 bits; unrelated palette slots are ignored.
assert(select(2, follow._parse("\27]11;rgb:0d0d/1111/1717\27\\")) == "#0d1117")
assert(select(2, follow._parse("\27]10;rgb:e6/ed/f3\27\\")) == "#e6edf3")
local field, hex = follow._parse("\27]4;4;rgb:0909/6969/dada\27\\")
assert(field == "blue" and hex == "#0969da")
assert(follow._parse("\27]4;9;rgb:00/00/00\27\\") == nil)

-- Every theme is recognised from its own colours; unknown colours match nothing.
for _, entry in ipairs(index) do
	assert(follow.match(entry) == entry.name, "recognises " .. entry.name)
end
assert(follow.match({ background = "#123456", foreground = "#abcdef" }) == nil)

-- Replies drive the colourscheme, and a later theme replaces an earlier one.
follow.setup()
local function osc(slot, colour)
	local r, g, b = colour:match("#(%x%x)(%x%x)(%x%x)")
	return ("\27]%s;rgb:%s%s/%s%s/%s%s\27\\"):format(slot, r, r, g, g, b, b)
end
local function show(name)
	local entry = vim.iter(index):find(function(item) return item.name == name end)
	for key, slot in pairs({ background = "11", foreground = "10", red = "4;1", blue = "4;4" }) do
		vim.api.nvim_exec_autocmds("TermResponse", { data = { sequence = osc(slot, entry[key]) } })
	end
	vim.wait(200, function() return vim.g.colors_name == name end)
	assert(vim.g.colors_name == name, "follows " .. name)
	assert(follow.current() == name)
end
show("rex-merino-light")
show("rex-whitby-bay")

-- Outside Rex the follower stays inert.
vim.env.REX_SESSION = nil
assert(follow.current() == nil, "inert outside Rex")

print("rex themes ok: " .. #files .. " schemes")
