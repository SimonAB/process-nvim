-- Configuration for vimtex
-- LaTeX editing support with enhanced features

-- Proofreading todo categories (from AGENTS.md) for VimTeX TOC (<localleader>lt).
-- VimTeX looks up with toupper(type), so keys must be UPPERCASE (see todo_comments.vim).
vim.g.vimtex_toc_todo_labels = {
	TODO = "TODO: ",
	FIXME = "FIXME: ",
	TIGHTEN = "Tighten: ",
	EDIT = "Edit: ",
	ADD = "Add: ",
	CLARIFY = "Clarify: ",
	REF = "Ref: ",
	VERIFY = "Verify: ",
	DELETE = "Delete: ",
}

-- Custom TOC matchers for proofreading commands (todonotes-style macros).
-- Must be defined in Vimscript so each matcher has get_entry() returning type 'todo',
-- so entries appear in the TOC todo layer instead of mixed with content/headings.
-- Brace pattern allows one nesting level (e.g. \emph{...} inside the note).
vim.cmd([[
let s:proof_brace = '\{%([^{}]|\{[^{}]*\})*\}'
function! VimtexProofTocGetEntry(context) abort dict
  let content = matchstr(a:context.line,
    \ '\v\\' . self.cmd . '\s*\{\zs%([^{}]|\{[^{}]*\})*\ze\}')
  let title = content !=# '' ? self.title . ': ' . content : self.title
  return {
    \ 'title': title,
    \ 'number': '',
    \ 'file': a:context.file,
    \ 'line': a:context.lnum,
    \ 'level': a:context.max_level - a:context.level.current,
    \ 'rank': a:context.lnum_total,
    \ 'type': 'todo',
    \}
endfunction
let g:vimtex_toc_custom_matchers = [
  \ {'name': 'proof_tighten', 'title': 'Tighten', 'cmd': 'tighten', 'prefilter_cmds': ['tighten'], 're': '\v\\tighten\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \ {'name': 'proof_edit', 'title': 'Edit', 'cmd': 'edit', 'prefilter_cmds': ['edit'], 're': '\v\\edit\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \ {'name': 'proof_add', 'title': 'Add', 'cmd': 'add', 'prefilter_cmds': ['add'], 're': '\v\\add\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \ {'name': 'proof_clarify', 'title': 'Clarify', 'cmd': 'clarify', 'prefilter_cmds': ['clarify'], 're': '\v\\clarify\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \ {'name': 'proof_ref', 'title': 'Ref', 'cmd': 'checkref', 'prefilter_cmds': ['checkref'], 're': '\v\\checkref\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \ {'name': 'proof_verify', 'title': 'Verify', 'cmd': 'verify', 'prefilter_cmds': ['verify'], 're': '\v\\verify\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \ {'name': 'proof_delete', 'title': 'Delete', 'cmd': 'delete', 'prefilter_cmds': ['delete'], 're': '\v\\delete\s*' . s:proof_brace, 'in_content': 1, 'get_entry': function('VimtexProofTocGetEntry')},
  \]
]])

-- TOC syntax: VimTeX only highlights todo prefixes that match uppercase keys (TODO:, ADD:).
-- Our proofreading entries display as "Add:", "Tighten:", etc. Add a rule so they get the same green.
local vimtex_toc_hl_group = vim.api.nvim_create_augroup("VimtexTocProofHighlight", { clear = true })

---Make VimTeX TOC “help key” hints (single-letter shortcuts) readable without a background block.
---Some themes give these keys a solid background; we prefer bold red text on transparency.
local function apply_vimtex_toc_help_key_highlights()
	for _, group in ipairs({
		-- Common VimTeX groups (vary by VimTeX version)
		"VimtexTocHelpKey",
		"VimtexTocHelpKeys",
		"VimtexTocHelpKeyName",
		"VimtexTocHelp",
	}) do
		pcall(vim.api.nvim_set_hl, 0, group, { fg = "#c74a4a", bg = "none", bold = false })
	end
end

vim.api.nvim_create_autocmd("User", {
	group = vimtex_toc_hl_group,
	pattern = "VimtexEventTocCreated",
	desc = "Highlight proofreading todo prefixes in TOC like standard TODOs",
	callback = function()
		vim.cmd([[
      syntax match VimtexTocProofTodo "\v\zs%(Tighten|Edit|Add|Clarify|Ref|Verify|Delete):\ze " contained
      syntax cluster VimtexTocTitleStuff add=VimtexTocProofTodo
      highlight link VimtexTocProofTodo VimtexTocTodo
    ]])

		apply_vimtex_toc_help_key_highlights()
	end,
})

-- Re-apply after theme changes so colourschemes can’t reintroduce key backgrounds.
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vimtex_toc_hl_group,
	desc = "Reapply VimTeX TOC help key highlight after theme changes",
	callback = function()
		vim.defer_fn(apply_vimtex_toc_help_key_highlights, 50)
	end,
})

-- Detect platform and set appropriate PDF viewer
local is_macos = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1
local is_linux = vim.fn.has("unix") == 1 and vim.fn.has("macunix") == 0

-- VimTeX configuration (vim variables)
if is_macos then
	-- macOS: Use Skim for PDF viewing (inverse search via scripts/configure-skim-synctex.sh).
	vim.g.vimtex_view_method = "skim"
	-- Keep the terminal/Neovim window focused after forward search (\lv).
	vim.g.vimtex_view_skim_activate = 0
	vim.g.vimtex_view_skim_reading_bar = 1
elseif is_linux then
	-- Linux/Wayland: zathura_simple avoids xdotool (X11-only). VimTeX still
	-- passes -x VimtexInverseSearch when starting Zathura; zathurarc is a fallback.
	vim.g.vimtex_view_method = "zathura_simple"
else
	-- Fallback: generic viewer
	vim.g.vimtex_view_method = "general"
	vim.g.vimtex_view_general_viewer = "zathura"
	vim.g.vimtex_view_general_options = "--synctex-forward %line:0:%tex %pdf"
end

-- LuaTeX logs this longtable split diagnostic as ignored; keep it out of VimTeX quickfix.
vim.g.vimtex_quickfix_ignore_filters = vim.list_extend(
	vim.g.vimtex_quickfix_ignore_filters or {},
	{ "Infinite glue shrinkage found in box being split" }
)

vim.g.vimtex_compiler_method = "latexmk" -- Use latexmk for compilation
-- Compile beside the .tex (matches most manuscripts and texlab auxDirectory = ".").
-- latexmk runs biber/bibtex automatically when the bibliography backend requires it.
vim.g.vimtex_compiler_latexmk = {
	options = {
		"-lualatex",
		"-interaction=nonstopmode",
		"-synctex=1",
		"-file-line-error",
	},
}
vim.g.vimtex_compiler_latexmk_engines = {
	_ = "-lualatex",
}

-- Disable spell checking in citation arguments; style soul/ul commands.
-- Proofreading macros are registered here too so VimTeX owns brace nesting
-- (avoids hand-rolled regions that fight texCmd/texArg and thrash redraw).
-- This must be set before VimTeX initialises to take effect.
local proofreading_cmds = {
	{ cmd = "tighten", fg = "#4a3f2a", bg = "#ffcc80" },
	{ cmd = "edit", fg = "#4a2e2e", bg = "#ef9a9a" },
	{ cmd = "add", fg = "#3a4230", bg = "#c5e1a5" },
	{ cmd = "clarify", fg = "#2e3d48", bg = "#81d4fa" },
	{ cmd = "checkref", fg = "#2e4242", bg = "#80cbc4" },
	{ cmd = "verify", fg = "#3d2e42", bg = "#e1bee7" },
	{ cmd = "delete", fg = "#3a3a3a", bg = "#e0e0e0" },
	{ cmd = "sabhl", fg = "#2e3a48", bg = "#bbdefb" },
}

local author_todos = {
	{ cmd = "icgu", fg = "#4a452e", bg = "#fff59d" },
	{ cmd = "mpb", fg = "#404040", bg = "#eeeeee" },
	{ cmd = "fo", fg = "#3d422e", bg = "#e6ee9c" },
	{ cmd = "sab", fg = "#2e4248", bg = "#b2ebf2" },
	{ cmd = "fb", fg = "#2e4230", bg = "#c8e6c9" },
}

---VimTeX group names for a custom command (`add` → texCmdCAdd / texCAddArg).
---@param cmd string
---@return string cmd_group, string arg_group
local function vimtex_custom_cmd_groups(cmd)
	local name = "C" .. cmd:sub(1, 1):upper() .. cmd:sub(2)
	return "texCmd" .. name, "tex" .. name .. "Arg"
end

local vimtex_custom_cmds = {
	{ name = "cite", argspell = false },
	{ name = "supercite", argspell = false },
	{ name = "citep", argspell = false },
	{ name = "citet", argspell = false },
	{ name = "citealp", argspell = false },
	{ name = "citealt", argspell = false },
	{ name = "citeauthor", argspell = false },
	{ name = "citeyear", argspell = false },
	{ name = "parencite", argspell = false },
	{ name = "footcite", argspell = false },
	{ name = "textcite", argspell = false },
	{ name = "autocite", argspell = false },
	{ name = "ul", argstyle = "under" },
	{ name = "uline", argstyle = "under" },
}

for _, item in ipairs(proofreading_cmds) do
	local cmd_group = vimtex_custom_cmd_groups(item.cmd)
	table.insert(vimtex_custom_cmds, {
		name = item.cmd,
		opt = false,
		argspell = false,
		hlgroup = cmd_group,
	})
end
for _, item in ipairs(author_todos) do
	local cmd_group = vimtex_custom_cmd_groups(item.cmd)
	table.insert(vimtex_custom_cmds, {
		name = item.cmd,
		opt = false,
		argspell = false,
		hlgroup = cmd_group,
	})
end

vim.g.vimtex_syntax_custom_cmds = vimtex_custom_cmds


-- Function to apply citation spell exclusion rules
local function apply_citation_nospell_rules()
	-- Only apply if we're in a tex file
	if vim.bo.filetype ~= "tex" then
		return
	end

	-- Clear any existing citation syntax rules first
	pcall(vim.cmd, "syntax clear texCiteArg")
	pcall(vim.cmd, "syntax clear texCiteNoSpell")

	-- Use higher priority syntax rules with @NoSpell cluster
	-- The 'contained' keyword prevents conflicts with existing VimTeX syntax
	pcall(vim.cmd, [[syntax cluster NoSpell add=texCiteNoSpell]])

	-- Define comprehensive syntax matches with high priority
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\cite{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\supercite{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\citep{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\citet{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\citealp{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\citealt{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\citeauthor{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\citeyear{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\parencite{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\footcite{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\textcite{[^}]*}" contains=@NoSpell contained containedin=ALL]])
	pcall(vim.cmd, [[syntax match texCiteNoSpell "\\autocite{[^}]*}" contains=@NoSpell contained containedin=ALL]])
end

-- Complete spell exclusion using @NoSpell syntax groups
-- This prevents both highlighting AND navigation (]s/[s) from detecting citation arguments
local citation_spell_group = vim.api.nvim_create_augroup("VimTeXCitationSpell", { clear = true })

-- Avoid Syntax + sync-fromstart: that combination forces full reparse and causes
-- wrap/redraw artefacts on long thesis paragraphs.
vim.api.nvim_create_autocmd({ "FileType", "BufReadPost" }, {
	group = citation_spell_group,
	pattern = "tex",
	desc = "Configure LaTeX citation spell exclusion",
	callback = function()
		apply_citation_nospell_rules()
		vim.defer_fn(apply_citation_nospell_rules, 150)
	end,
})

-- Create manual command to reapply citation spell rules
vim.api.nvim_create_user_command("VimTexFixCitationSpell", apply_citation_nospell_rules, {
	desc = "Manually apply citation spell exclusion rules",
})

-- Auto-apply when VimTeX state changes
vim.api.nvim_create_autocmd("User", {
  group = citation_spell_group,
  pattern = "VimtexEventInitPost",
  desc = "Apply citation spell rules after VimTeX initialization",
  callback = function()
    vim.defer_fn(apply_citation_nospell_rules, 50)
  end,
})

-- lua-ul [soul]: \st (strikethrough) and \hl (highlight) — no built-in argstyle, so add syntax
-- so their content gets texStyleStrike / texStyleHl; theme-manager sets gui (OpenType-friendly)
local function add_tex_style_syntax()
  if vim.bo.filetype ~= "tex" then return end
  pcall(vim.cmd, "syntax clear texStyleHl")
  pcall(vim.cmd, [[syntax region texStyleStrike matchgroup=texDelim start="\\st\s*{" skip="\%#=1\\\\[{}]" end="}" contains=TOP,@NoSpell]])
  pcall(vim.cmd, [[syntax region texStyleStrike matchgroup=texDelim start="\\sout\s*{" skip="\%#=1\\\\[{}]" end="}" contains=TOP,@NoSpell]])
  pcall(vim.cmd, [[syntax region texStyleHl matchgroup=texStyleHlDelim start="\\hl\s*{" skip="\%#=1\\\\[{}]" end="}" contains=TOP,@NoSpell]])
  pcall(function()
    require("core.theme-manager").apply_tex_style_highlights()
  end)
end
local vimtex_style_group = vim.api.nvim_create_augroup("VimtexStyleSyntax", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = vimtex_style_group,
  pattern = "tex",
  desc = "Add syntax for \\st and \\hl (lua-ul [soul]) so content gets styled",
  callback = add_tex_style_syntax,
})
vim.api.nvim_create_autocmd("User", {
  group = vimtex_style_group,
  pattern = "VimtexEventInitPost",
  desc = "Re-apply \\st/\\hl syntax after VimTeX init",
  callback = function()
    vim.defer_fn(add_tex_style_syntax, 10)
  end,
})

-- Proofreading macro colours: registered via g:vimtex_syntax_custom_cmds above.
-- VimTeX only calls init_custom() when a syntax *package* loads, so we invoke it
-- ourselves after init, then paint texCmdC*/texC*Arg and restyle braces.
local function apply_proofreading_highlights()
	local function set_hl(name, fg, bg)
		-- Keep default combine behaviour so Visual can paint over these backgrounds.
		-- Opaque todo fills + forced statusline redraws were leaving ghost selection cells.
		pcall(vim.api.nvim_set_hl, 0, name, { fg = fg, bg = bg, bold = false })
	end
	for _, item in ipairs(proofreading_cmds) do
		local cmd_group, arg_group = vimtex_custom_cmd_groups(item.cmd)
		set_hl(cmd_group, item.fg, item.bg)
		set_hl(arg_group, item.fg, item.bg)
	end
	for _, item in ipairs(author_todos) do
		local cmd_group, arg_group = vimtex_custom_cmd_groups(item.cmd)
		set_hl(cmd_group, item.fg, item.bg)
		set_hl(arg_group, item.fg, item.bg)
	end
end

---Restyle VimTeX arg regions so `{` / `}` use the same highlight as the body.
local function polish_proofreading_arg_delims()
	if vim.bo.filetype ~= "tex" then
		return
	end
	-- Skip while selecting: syntax clear/redefine mid-visual corrupts the screen.
	local mode = vim.fn.mode(true)
	if mode == "v" or mode == "V" or mode:match("\22") then
		return
	end
	-- %% in format string → literal %# for Vim's NFA engine flag
	local arg_tpl =
		[[syntax region %s matchgroup=%s start="{" skip="%%#=1\\[\\\}]" end="}" contained contains=TOP,@NoSpell]]
	for _, item in ipairs(proofreading_cmds) do
		local cmd_group, arg_group = vimtex_custom_cmd_groups(item.cmd)
		pcall(vim.cmd, "syntax clear " .. arg_group)
		pcall(vim.cmd, string.format(arg_tpl, arg_group, cmd_group))
	end
	for _, item in ipairs(author_todos) do
		local cmd_group, arg_group = vimtex_custom_cmd_groups(item.cmd)
		pcall(vim.cmd, "syntax clear " .. arg_group)
		pcall(vim.cmd, string.format(arg_tpl, arg_group, cmd_group))
	end
end

local function add_proofreading_syntax()
	if vim.bo.filetype ~= "tex" then
		return
	end
	local mode = vim.fn.mode(true)
	if mode == "v" or mode == "V" or mode:match("\22") then
		return
	end
	-- Ensure custom cmds exist even when no syntax package addon loaded.
	-- Do not call init_custom if groups already exist (it appends duplicate matches).
	local listing = vim.fn.execute("silent! syntax list texCmdCVerify")
	if not listing:find("xxx", 1, true) then
		pcall(vim.fn["vimtex#syntax#core#init_custom"])
	end
	apply_proofreading_highlights()
	polish_proofreading_arg_delims()
end

local vimtex_proof_group = vim.api.nvim_create_augroup("VimtexProofreadingSyntax", { clear = true })

vim.api.nvim_create_autocmd("User", {
	group = vimtex_proof_group,
	pattern = "VimtexEventInitPost",
	desc = "Colourise proofreading todo macros after VimTeX syntax init",
	callback = function()
		vim.defer_fn(add_proofreading_syntax, 20)
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	group = vimtex_proof_group,
	pattern = "tex",
	desc = "Colourise proofreading todos once VimTeX state is ready",
	callback = function()
		-- Deferred pack load: this config may register after the first InitPost.
		vim.defer_fn(add_proofreading_syntax, 50)
		vim.defer_fn(add_proofreading_syntax, 250)
	end,
})
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vimtex_proof_group,
	desc = "Re-apply proofreading todo colours after theme change",
	callback = function()
		vim.defer_fn(apply_proofreading_highlights, 50)
	end,
})

-- After leaving visual mode, clear residual selection paint over todo backgrounds
-- on long wrapped paragraphs (terminal cells can lag behind Visual).
vim.api.nvim_create_autocmd("ModeChanged", {
	group = vimtex_proof_group,
	pattern = "[vV\x16]:n",
	desc = "Redraw TeX window after visual selection to clear ghost highlights",
	callback = function()
		if vim.bo.filetype ~= "tex" then
			return
		end
		vim.schedule(function()
			pcall(vim.cmd, "redraw")
		end)
	end,
})
vim.api.nvim_create_user_command("VimTexProofreadingSyntax", add_proofreading_syntax, {
	desc = "Re-apply proofreading todo syntax highlighting",
})

-- Catch tex buffers already open when this deferred plugin config loads.
vim.defer_fn(function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "tex" then
			vim.api.nvim_buf_call(buf, add_proofreading_syntax)
		end
	end
end, 300)

-- Raise the terminal after inverse search so the cursor jump is visible behind the PDF.
-- macOS: Rex (Skim activate=0 keeps forward search in the terminal).
-- Linux: the Hyprland Ghostty window, after Zathura has taken focus.
do
	local vimtex_focus_group = vim.api.nvim_create_augroup("VimtexSyncTeXFocus", { clear = true })
	local REX_BUNDLE_ID = "com.superlogical.rex"

	---Bring the Rex app to the foreground.
	---The bundle id stays valid while the display name is "Rex Beta".
	local function activate_rex()
		local ok = pcall(vim.system, {
			"osascript",
			"-e",
			string.format('tell application id "%s" to activate', REX_BUNDLE_ID),
		}, { detach = true })
		if not ok then
			vim.notify("Failed to focus Rex after SyncTeX", vim.log.levels.DEBUG)
		end
	end

	---Pick the Rex app that is showing this Neovim's session.
	---@param clients table[]
	---@param session string
	---@return string|nil
	local function rex_app_client_id(clients, session)
		local fallback = nil
		local app_count = 0
		for _, client in ipairs(clients) do
			local info = client.info or {}
			if info.kind == "app" and client.client_id then
				app_count = app_count + 1
				fallback = fallback or client.client_id
				for _, id in ipairs(client.session_ids or {}) do
					if id == session then
						return client.client_id
					end
				end
			end
		end
		if app_count == 1 then
			return fallback
		end
		return nil
	end

	---Show this Neovim's Rex session and pane, then raise Rex.
	---Skim's headless nvim only RPCs the live editor, so REX_SESSION and
	---REX_BLOCK here belong to that editor, not to Skim.
	local function focus_rex()
		local session = vim.env.REX_SESSION
		local block = vim.env.REX_BLOCK
		if not session or session == "" or vim.fn.executable("rex") ~= 1 then
			activate_rex()
			return
		end

		local function select_session(window_id, client_id)
			local args = { "rex" }
			if client_id and client_id ~= "" then
				table.insert(args, "-C")
				table.insert(args, client_id)
			end
			table.insert(args, "do")
			table.insert(args, "session.select")
			table.insert(args, "session_id=" .. session)
			if window_id and window_id ~= "" then
				table.insert(args, "window_id=" .. window_id)
			end
			vim.system(args, {}, function()
				vim.schedule(activate_rex)
			end)
		end

		local function focus_block_then_select(window_id, client_id)
			if not block or block == "" then
				select_session(window_id, client_id)
				return
			end
			vim.system({ "rex", "focus", "-s", session, block }, {}, function()
				vim.schedule(function()
					select_session(window_id, client_id)
				end)
			end)
		end

		vim.system({ "rex", "client", "ls", "-s", session, "--json" }, { text = true }, function(clients_result)
			vim.schedule(function()
				local client_id = nil
				if clients_result.code == 0 and clients_result.stdout and clients_result.stdout ~= "" then
					local ok, decoded = pcall(vim.json.decode, clients_result.stdout)
					if ok and type(decoded) == "table" then
						client_id = rex_app_client_id(decoded.clients or {}, session)
					end
				end

				if not block or block == "" then
					focus_block_then_select(nil, client_id)
					return
				end

				vim.system({ "rex", "block", "inspect", block, "--json" }, { text = true }, function(block_result)
					vim.schedule(function()
						local window_id = nil
						if block_result.code == 0 and block_result.stdout and block_result.stdout ~= "" then
							local ok, decoded = pcall(vim.json.decode, block_result.stdout)
							if ok and type(decoded) == "table" and type(decoded.block) == "table" then
								window_id = decoded.block.window_id
							end
						end
						focus_block_then_select(window_id, client_id)
					end)
				end)
			end)
		end)
	end

	---Bring Ghostty forward on Linux after Zathura takes the focus.
	local function focus_linux_terminal()
		if not (is_linux and vim.fn.executable("hyprctl") == 1) then
			return
		end
		local ok = pcall(vim.system, {
			"hyprctl",
			"dispatch",
			"focuswindow",
			"class:com.mitchellh.ghostty",
		}, { detach = true })
		if not ok then
			vim.notify("Failed to focus Ghostty after SyncTeX", vim.log.levels.DEBUG)
		end
	end

	local function focus_after_synctex()
		vim.schedule(function()
			if is_macos then
				focus_rex()
			else
				focus_linux_terminal()
			end
		end)
	end

	-- Inverse search (PDF → Neovim): raise the terminal so the jump is visible.
	vim.api.nvim_create_autocmd("User", {
		group = vimtex_focus_group,
		pattern = "VimtexEventViewReverse",
		desc = is_macos and "Raise Rex after PDF inverse search"
			or "Raise the terminal after PDF inverse search",
		callback = focus_after_synctex,
	})

	-- Forward search (Neovim → PDF): on Linux, reclaim focus after Zathura maps/activates.
	-- macOS uses vimtex_view_skim_activate = 0 instead.
	if is_linux then
		vim.api.nvim_create_autocmd("User", {
			group = vimtex_focus_group,
			pattern = "VimtexEventView",
			desc = "Keep the terminal focused after Zathura forward search",
			callback = focus_after_synctex,
		})
	end
end
