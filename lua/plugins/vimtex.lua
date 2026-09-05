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
	-- macOS: Use Skim for PDF viewing
	vim.g.vimtex_view_method = "skim"
	-- Keep the terminal/Neovim window focused after forward search (\lv).
	vim.g.vimtex_view_skim_activate = 0
	vim.g.vimtex_view_skim_reading_bar = 1
elseif is_linux then
	-- Linux: Use Zathura for PDF viewing
	vim.g.vimtex_view_method = "zathura"
	vim.g.vimtex_view_general_viewer = "zathura"
	vim.g.vimtex_view_general_options = "--synctex-forward %line:0:%tex %pdf"
else
	-- Fallback: generic viewer
	vim.g.vimtex_view_method = "general"
	vim.g.vimtex_view_general_viewer = "zathura"
	vim.g.vimtex_view_general_options = "--synctex-forward %line:0:%tex %pdf"
end

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

-- Disable spell checking in citation arguments
-- This must be set before VimTeX initialises to take effect
-- lua-ul [soul]: \ul and \uline get underline; \st and \hl get custom syntax below (same command names)
vim.g.vimtex_syntax_custom_cmds = {
  { name = 'cite', argspell = false },
  { name = 'supercite', argspell = false },
  { name = 'citep', argspell = false },
  { name = 'citet', argspell = false },
  { name = 'citealp', argspell = false },
  { name = 'citealt', argspell = false },
  { name = 'citeauthor', argspell = false },
  { name = 'citeyear', argspell = false },
  { name = 'parencite', argspell = false },
  { name = 'footcite', argspell = false },
  { name = 'textcite', argspell = false },
  { name = 'autocite', argspell = false },
  { name = 'ul', argstyle = 'under' },
  { name = 'uline', argstyle = 'under' },
}

-- Function to apply citation spell exclusion rules
local function apply_citation_nospell_rules()
  -- Only apply if we're in a tex file
  if vim.bo.filetype ~= 'tex' then return end

  -- Clear any existing citation syntax rules first
  pcall(vim.cmd, 'syntax clear texCiteArg')
  pcall(vim.cmd, 'syntax clear texCiteNoSpell')

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

  -- Alternative approach: directly modify spell checking regions
  -- This creates regions that are explicitly excluded from spell checking
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\cite{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\supercite{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\citep{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\citet{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\citealp{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\citealt{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\citeauthor{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\citeyear{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\parencite{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\footcite{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\textcite{" end="}" oneline contains=@NoSpell]])
  pcall(vim.cmd, [[syntax region texCiteRegion start="\\autocite{" end="}" oneline contains=@NoSpell]])

  -- Force syntax highlighting refresh with higher priority
  pcall(vim.cmd, 'syntax sync fromstart')
end

-- Complete spell exclusion using @NoSpell syntax groups
-- This prevents both highlighting AND navigation (]s/[s) from detecting citation arguments
local citation_spell_group = vim.api.nvim_create_augroup('VimTeXCitationSpell', { clear = true })

-- Apply rules on multiple events to ensure they're always active
vim.api.nvim_create_autocmd({"FileType", "BufEnter", "BufReadPost", "Syntax"}, {
  group = citation_spell_group,
  pattern = "tex",
  desc = "Configure LaTeX citation spell exclusion",
  callback = function()
    -- Apply rules immediately
    apply_citation_nospell_rules()

    -- Also apply after a delay to handle VimTeX initialization
    vim.defer_fn(apply_citation_nospell_rules, 100)
    vim.defer_fn(apply_citation_nospell_rules, 300)
  end,
})

-- Create manual command to reapply citation spell rules
vim.api.nvim_create_user_command('VimTexFixCitationSpell', apply_citation_nospell_rules, {
  desc = "Manually apply citation spell exclusion rules"
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

-- Proofreading macros (Ivan thesis / AGENTS.md): visible colours in the buffer, not the PDF.
--
-- Two brittleness fixes:
-- 1) Builtin tex.vim's texRefOption omits texSpecialChar, so `\%` inside `\cite[...]`
--    is parsed as a comment, the `]` never closes, and later macros lose highlighting.
-- 2) A single `start={\ end=}` region ends at the first `}`, so nested `\emph{...}` etc.
--    truncate the colour. Use nextgroup + self-nesting brace args instead.
local proof_cmd_skip = [[skip="\%#=1\\\\[{}]"]]

-- Command name match, then balanced-brace argument (self-nesting for nested `{...}`).
-- containedin=ALL so macros still highlight inside a leaked texRefOption/texComment.
local proof_cmd_tpl =
	[[syntax match %s "\\%s\>" containedin=ALL nextgroup=%s skipwhite]]
local proof_arg_tpl =
	[[syntax region %s matchgroup=%s start="{" %s end="}" contains=%s,@NoSpell contained]]

local proofreading_cmds = {
	{ cmd = "tighten", region = "texProofTighten", fg = "#4a3f2a", bg = "#ffcc80" },
	{ cmd = "edit", region = "texProofEdit", fg = "#4a2e2e", bg = "#ef9a9a" },
	{ cmd = "add", region = "texProofAdd", fg = "#3a4230", bg = "#c5e1a5" },
	{ cmd = "clarify", region = "texProofClarify", fg = "#2e3d48", bg = "#81d4fa" },
	{ cmd = "checkref", region = "texProofRef", fg = "#2e4242", bg = "#80cbc4" },
	{ cmd = "verify", region = "texProofVerify", fg = "#3d2e42", bg = "#e1bee7" },
	{ cmd = "delete", region = "texProofDelete", fg = "#3a3a3a", bg = "#e0e0e0" },
	{ cmd = "sabhl", region = "texProofSabhl", fg = "#2e3a48", bg = "#bbdefb" },
}

local author_todos = {
	{ cmd = "icgu", region = "texProofIcgU", fg = "#4a452e", bg = "#fff59d" },
	{ cmd = "mpb", region = "texProofMpb", fg = "#404040", bg = "#eeeeee" },
	{ cmd = "fo", region = "texProofFo", fg = "#3d422e", bg = "#e6ee9c" },
	{ cmd = "sab", region = "texProofSab", fg = "#2e4248", bg = "#b2ebf2" },
	{ cmd = "fb", region = "texProofFb", fg = "#2e4230", bg = "#c8e6c9" },
}

local function apply_proofreading_highlights()
	local function set_hl(name, fg, bg)
		pcall(vim.api.nvim_set_hl, 0, name, { fg = fg, bg = bg, bold = false })
	end
	for _, item in ipairs(proofreading_cmds) do
		-- Command match + matchgroup braces use `region`; body uses `regionArg`.
		set_hl(item.region, item.fg, item.bg)
		set_hl(item.region .. "Arg", item.fg, item.bg)
	end
	for _, item in ipairs(author_todos) do
		set_hl(item.region, item.fg, item.bg)
		set_hl(item.region .. "Arg", item.fg, item.bg)
	end
end

---Allow `\%` (and other `\[$&%#{}_]`) inside `\cite[...]` so `%` does not start a comment.
local function fix_tex_ref_option_specials()
	pcall(vim.cmd, "syntax cluster texRefGroup add=texSpecialChar")
end

---Define syntax for one proofreading / author-todo macro.
---@param item {cmd: string, region: string}
local function define_proof_macro_syntax(item)
	local arg = item.region .. "Arg"
	pcall(vim.cmd, "syntax clear " .. item.region)
	pcall(vim.cmd, "syntax clear " .. arg)
	pcall(vim.cmd, string.format(proof_cmd_tpl, item.region, item.cmd, arg))
	pcall(vim.cmd, string.format(proof_arg_tpl, arg, item.region, proof_cmd_skip, arg))
end

local function add_proofreading_syntax()
	if vim.bo.filetype ~= "tex" then
		return
	end
	fix_tex_ref_option_specials()
	apply_proofreading_highlights()
	for _, item in ipairs(proofreading_cmds) do
		define_proof_macro_syntax(item)
	end
	for _, item in ipairs(author_todos) do
		define_proof_macro_syntax(item)
	end
end

local vimtex_proof_group = vim.api.nvim_create_augroup("VimtexProofreadingSyntax", { clear = true })
vim.api.nvim_create_autocmd({ "FileType", "Syntax" }, {
  group = vimtex_proof_group,
  pattern = "tex",
  desc = "Colourise proofreading todo macros in TeX buffers",
  callback = function()
    add_proofreading_syntax()
    vim.defer_fn(add_proofreading_syntax, 100)
  end,
})
vim.api.nvim_create_autocmd("User", {
  group = vimtex_proof_group,
  pattern = "VimtexEventInitPost",
  desc = "Re-apply proofreading syntax after VimTeX init",
  callback = function()
    vim.defer_fn(add_proofreading_syntax, 10)
  end,
})
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vimtex_proof_group,
  desc = "Re-apply proofreading todo colours after theme change",
  callback = function()
    vim.defer_fn(apply_proofreading_highlights, 50)
  end,
})
vim.api.nvim_create_user_command("VimTexProofreadingSyntax", add_proofreading_syntax, {
  desc = "Re-apply proofreading todo syntax highlighting",
})

-- Raise Ghostty after Skim inverse search so the cursor jump is visible behind Skim.
if is_macos then
	local vimtex_inverse_focus_group = vim.api.nvim_create_augroup("VimtexInverseSearchFocus", { clear = true })

	---Bring Ghostty to the foreground after a successful VimTeX inverse search.
	local function focus_terminal_after_inverse_search()
		vim.schedule(function()
			local ok = pcall(vim.system, { "osascript", "-e", 'tell application "Ghostty" to activate' }, { detach = true })
			if not ok then
				vim.notify("Failed to focus Ghostty after inverse search", vim.log.levels.DEBUG)
			end
		end)
	end

	vim.api.nvim_create_autocmd("User", {
		group = vimtex_inverse_focus_group,
		pattern = "VimtexEventViewReverse",
		desc = "Raise Ghostty after Skim inverse search",
		callback = focus_terminal_after_inverse_search,
	})
end
