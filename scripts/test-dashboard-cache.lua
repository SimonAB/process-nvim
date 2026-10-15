-- Verify background discovery, cache reuse and invalidation with real files.
vim.opt.rtp:prepend(vim.fn.getcwd())
local files = require("core.dashboard-files")
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/nested", "p")
vim.fn.mkdir(root .. "/other", "p")
vim.fn.writefile({"old"}, root .. "/old.jl")
vim.fn.writefile({"new"}, root .. "/nested/new.jl")
vim.uv.fs_utime(root .. "/old.jl", 10, 10)
vim.uv.fs_utime(root .. "/nested/new.jl", 20, 20)
local updates = 0
local function updated(cwd)
	assert(cwd == vim.uv.fs_realpath(root))
	updates = updates + 1
end
local first = files.get(root, updated)
assert(#first == 0 and updates == 0, "Cold request must return before background scan")
files.get(root, updated)
assert(vim.wait(3000, function() return updates == 1 end), "Coalesce pending requests")
local cached = files.get(root, updated)
assert(cached[1].name == "nested/new.jl", "Newest nested file first")
vim.wait(30)
assert(updates == 1, "Fresh cache must avoid repeat scans")
vim.fn.writefile({"newest"}, root .. "/latest.jl")
files.invalidate(root .. "/latest.jl")
assert(files.get(root, updated) == cached, "Keep stale results during refresh")
assert(vim.wait(3000, function() return updates == 2 end))
assert(files.get(root)[1].name == "latest.jl", "Save invalidation refreshes results")
local other_done = false
files.get(root .. "/other", function() other_done = true end)
assert(vim.wait(3000, function() return other_done end), "Empty directory completes")
assert(#files.get(root .. "/other") == 0, "Directory caches are separate")
-- Invalidating a pending scan must prevent stale data from becoming fresh.
files.invalidate(root .. "/latest.jl")
files.get(root, updated)
vim.fn.delete(root .. "/latest.jl")
files.invalidate(root .. "/latest.jl")
assert(vim.wait(3000, function() return updates == 3 end), "Invalidated pending scan restarts")
assert(files.get(root)[1].name == "nested/new.jl", "Deleted file is removed")
-- Advance the cache clock without a ten-second blocking test.
local now = vim.uv.now
vim.uv.now = function() return now() + 10001 end
files.get(root, updated)
vim.uv.now = now
assert(vim.wait(3000, function() return updates == 4 end), "Expired cache refreshes")
vim.fn.delete(root, "rf")
print("Background discovery, coalescing, directory caches and invalidation passed")
vim.cmd("qa!")
