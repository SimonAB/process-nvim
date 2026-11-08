-- =============================================================================
-- REX FOLLOW
-- PURPOSE: Inside a Rex pane, ask the terminal for its default background and
-- foreground (OSC 11 / 10) plus ANSI red and blue (OSC 4), recognise which Rex
-- theme they belong to, and load the matching generated `rex-*` colourscheme.
-- Red and blue exist because some themes share a background and foreground.
-- Does nothing outside Rex. Disable with `vim.g.rex_follow = false`.
-- =============================================================================

local RexFollow = {}

-- Per colour, summed |ΔR|+|ΔG|+|ΔB|. Keep below the closest distinct Rex pair
-- (ember-hollow vs sonoran-dusk score 48 across four colours), so 10×4 = 40.
local TOLERANCE = 10

---Colours we ask for and the OSC reply that carries each.
local FIELDS = { "background", "foreground", "red", "blue" }

---@type table<string, string>
local state = {}
local group

---Parse an OSC 4/10/11 reply such as `rgb:0d0d/1111/1717`.
---@param sequence string
---@return string|nil field one of FIELDS
---@return string|nil hex "#rrggbb"
local function parse(sequence)
	local field, r, g, b
	local kind
	kind, r, g, b = sequence:match("\27%]1([01]);rgb:(%x+)/(%x+)/(%x+)")
	if kind then
		field = kind == "1" and "background" or "foreground"
	else
		local slot
		slot, r, g, b = sequence:match("\27%]4;(%d+);rgb:(%x+)/(%x+)/(%x+)")
		field = ({ ["1"] = "red", ["4"] = "blue" })[slot or ""]
	end
	if not field then
		return nil, nil
	end
	local function channel(hex)
		-- Components carry 1-4 hex digits; scale each to 0-255.
		return math.floor(tonumber(hex, 16) / (16 ^ #hex - 1) * 255 + 0.5)
	end
	return field, string.format("#%02x%02x%02x", channel(r), channel(g), channel(b))
end

---Summed absolute RGB difference between two "#rrggbb" colours.
---@param a string
---@param b string
---@return integer
local function distance(a, b)
	local total = 0
	for i = 2, 6, 2 do
		total = total + math.abs(tonumber(a:sub(i, i + 1), 16) - tonumber(b:sub(i, i + 1), 16))
	end
	return total
end

---Find the closest Rex theme for the observed colours, within tolerance.
---Only colours actually observed take part; the background is mandatory.
---@param observed table<string, string>
---@return string|nil name
function RexFollow.match(observed)
	local ok, index = pcall(require, "core.rex-index")
	if not ok or not observed.background then
		return nil
	end
	local best, best_score
	for _, entry in ipairs(index) do
		local score, count = 0, 0
		for _, field in ipairs(FIELDS) do
			if observed[field] then
				score = score + distance(observed[field], entry[field])
				count = count + 1
			end
		end
		if score <= TOLERANCE * count and (not best_score or score < best_score) then
			best, best_score = entry.name, score
		end
	end
	return best
end

---Load the matched scheme when it differs from the current one.
local function sync()
	local name = RexFollow.match(state)
	state.matched = name
	if name and vim.g.colors_name ~= name then
		pcall(vim.cmd.colorscheme, name)
	end
end

---Ask the terminal for its colours; replies arrive as `TermResponse`.
function RexFollow.query()
	local st = "\27\\"
	pcall(vim.api.nvim_chan_send, vim.v.stderr,
		"\27]11;?" .. st .. "\27]10;?" .. st .. "\27]4;1;?" .. st .. "\27]4;4;?" .. st)
end

---The Rex scheme the terminal currently matches, for `ThemeManager` to prefer.
---@return string|nil
function RexFollow.current()
	if vim.g.rex_follow == false or not vim.env.REX_SESSION then
		return nil
	end
	return state.matched
end

---Start following the terminal. No-op outside Rex.
function RexFollow.setup()
	if vim.g.rex_follow == false or not vim.env.REX_SESSION then
		return
	end
	group = vim.api.nvim_create_augroup("RexFollow", { clear = true })
	vim.api.nvim_create_autocmd("TermResponse", {
		group = group,
		desc = "Track Rex theme from OSC 4/10/11 replies",
		callback = function(event)
			local sequence = event.data and event.data.sequence
			local field, hex = parse(type(sequence) == "string" and sequence or "")
			if not field then
				return
			end
			state[field] = hex
			vim.schedule(sync)
		end,
	})
	-- Theme changes in the Rex app need not notify Neovim, so re-ask on focus.
	vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
		group = group,
		desc = "Re-query Rex terminal colours",
		callback = RexFollow.query,
	})
	vim.api.nvim_create_user_command("RexFollow", function()
		vim.notify(vim.inspect(state), vim.log.levels.INFO, { title = "Rex follow" })
	end, { desc = "Show observed terminal colours and matched Rex theme" })
	RexFollow.query()
end

-- Exposed for tests.
RexFollow._parse = parse
RexFollow._TOLERANCE = TOLERANCE

return RexFollow
