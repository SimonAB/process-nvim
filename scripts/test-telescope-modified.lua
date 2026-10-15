-- Checks for modification-date ordering without changing fuzzy-search behaviour.
vim.opt.rtp:prepend(vim.fn.getcwd())
local picker = require("core.modified-file-picker")
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ "old" }, root .. "/old file.jl")
vim.fn.writefile({ "new" }, root .. "/new.jl")
vim.uv.fs_utime(root .. "/old file.jl", 10, 10)
vim.uv.fs_utime(root .. "/new.jl", 20, 20)
local calls = 0
local base = { scoring_function = function(_, prompt, line)
	calls = calls + 1
	return prompt == "new" and line == "new.jl" and 0.1 or -1
end }
local sorter = picker.with_modification_order(base, root)
local old_score = sorter:scoring_function("", "old file.jl")
local new_score = sorter:scoring_function("", "new.jl")
assert(new_score < old_score, "Newest file must rank first")
assert(sorter:scoring_function("", "missing.jl") > old_score, "Missing files rank last")
assert(calls == 0, "Empty prompts must not use fuzzy scoring")
assert(sorter:scoring_function("new", "new.jl") == 0.1, "Preserve fuzzy ranking")
assert(sorter:scoring_function("new", "old file.jl") == -1, "Preserve fuzzy exclusion")
assert(sorter:scoring_function("", "new.jl") == new_score, "Clearing query restores date order")
vim.fn.delete(root, "rf")
print("Modification ordering and fuzzy-search checks passed")
vim.cmd("qa!")
