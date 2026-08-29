-- Configuration for obsidian.nvim
-- A Neovim plugin for writing and navigating Obsidian vaults

local ok, obsidian = pcall(require, "obsidian")
if not ok then
    vim.notify("obsidian.nvim not found", vim.log.levels.WARN)
    return
end

-- Returns today's date in YAML-tagged format (e.g. !2025-08-19)
local function get_current_yaml_date()
    return os.date("!%Y-%m-%d")
end

-- Builds the YAML frontmatter block for a note
-- id_value: filename without extension
-- date_value: date string from get_current_yaml_date()
local function build_yaml_frontmatter(id_value, date_value)
    return string.format([[
---
id: %s
tags: []
date_created: %s
date_modified: %s
---

]], id_value, date_value, date_value)
end

---Resolve the Obsidian vault path.
---@return string
local function get_obsidian_vault_path()
	return require("core.platform").obsidian_vault_path()
end

obsidian.setup({
    -- Your Obsidian vault path
    workspaces = {
        {
            name = "notebook",
            -- Use the local Notebook vault so paths like ../attachments/… resolve correctly
            path = get_obsidian_vault_path(),
        },
    },

    -- Note settings
    notes_subdir = "notes",
    new_notes_location = "notes",
    note_id_func = function(title)
        -- Create note IDs with timestamp prefix
        local suffix = ""
        if title ~= nil then
            -- If title is given, transform it into valid file name.
            suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
        else
            -- If title is nil, just add timestamp
            suffix = tostring(os.time())
        end
        return suffix
    end,

    -- Image settings
    attachments = {
        img_folder = "attachments",
        confirm_img_paste = false, -- Don't ask for confirmation
        img_name_func = function()
            -- Generate date-time filename
            return os.date("%Y%m%d-%H%M%S")
        end,
        img_text_func = function(client, path)
            -- Use markdown image syntax compatible with external tools
            -- (matches the behaviour expected by wikilinks_converter.py)
            -- The link is rendered relative to a note in the "notes" folder,
            -- so we need a ../ prefix to reach the vault root.
            path = client:vault_relative_path(path) or path
            return string.format("![%s](<../%s>)", path.name, path)
        end,
    },

    -- Templates
    templates = {
        folder = "Templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
        -- Custom substitutions
        substitutions = {
            yesterday = function()
                return os.date("%Y-%m-%d", os.time() - 86400)
            end,
            tomorrow = function()
                return os.date("%Y-%m-%d", os.time() + 86400)
            end,
        },
    },

    -- Completion and navigation
    completion = {
        nvim_cmp = false, -- Disable nvim-cmp since we're using blink.cmp
        min_chars = 2,
    },

    -- Wiki link function (replaces deprecated completion options)
    wiki_link_func = function(opts)
        if opts.id then
            return string.format("[[%s]]", opts.id)
        elseif opts.path then
            return string.format("[[%s]]", opts.path)
        else
            return string.format("[[%s]]", opts.alias)
        end
    end,

    -- Key mappings
    mappings = {
        -- Override the 'gf' mapping to work within the vault
        ["gf"] = {
            action = function()
                return require("obsidian").util.gf_passthrough()
            end,
            opts = { noremap = false, expr = true, buffer = true },
        },
        -- Create new note
        ["<leader>On"] = {
            action = function()
                return require("obsidian").util.new_note()
            end,
            opts = { desc = "New Obsidian note" },
        },
        -- Insert link
        ["<leader>Ol"] = {
            action = function()
                vim.cmd("ObsidianLink")
            end,
            opts = { desc = "Insert Obsidian link" },
        },
        -- Follow link
        ["<leader>Of"] = {
            action = function()
                vim.cmd("ObsidianFollowLink")
            end,
            opts = { desc = "Follow Obsidian link" },
        },
        -- Toggle checkbox
        ["<leader>Oc"] = {
            action = function()
                return require("obsidian").util.toggle_checkbox()
            end,
            opts = { desc = "Toggle Obsidian checkbox" },
        },
        -- Show backlinks
        ["<leader>Ob"] = {
            action = function()
                return require("obsidian").util.show_backlinks()
            end,
            opts = { desc = "Show Obsidian backlinks" },
        },
        -- Show outgoing links
        ["<leader>Oo"] = {
            action = function()
                return require("obsidian").util.show_outgoing_links()
            end,
            opts = { desc = "Show Obsidian outgoing links" },
        },
    },



    -- Search settings
    search = {
        max_results = 20,
        max_search_results = 50,
    },

    -- UI settings
    ui = {
        enable = true,
        update_debounce = 200,
        checkboxes = {
            [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
            ["x"] = { char = "󰄲", hl_group = "ObsidianDone" },
            [">"] = { char = "󰐕", hl_group = "ObsidianRightArrow" },
            ["~"] = { char = "󰘸", hl_group = "ObsidianTilde" },
        },
        bullets = { char = "•", hl_group = "ObsidianBullet" },
        external_link_icon = { char = "󰉹", hl_group = "ObsidianExtLinkIcon" },
        reference_text = { hl_group = "ObsidianRefText" },
        highlight_text = { hl_group = "ObsidianHighlightText" },
        tags = { hl_group = "ObsidianTag" },
        block_ids = { hl_group = "ObsidianBlockID" },
        hl_groups = {
            ObsidianTodo = { bold = true, fg = "#ff6b6b" },
            ObsidianDone = { bold = true, fg = "#51cf66" },
            ObsidianRightArrow = { bold = true, fg = "#5c7cfa" },
            ObsidianTilde = { bold = true, fg = "#ffd43b" },
            ObsidianBullet = { bold = true, fg = "#339af0" },
            ObsidianRefText = { underline = true, fg = "#9c88ff" },
            ObsidianExtLinkIcon = { fg = "#339af0" },
            ObsidianTag = { italic = true, fg = "#e599f7" },
            ObsidianBlockID = { italic = true, fg = "#7a7a7a" },
            ObsidianHighlightText = { bg = "#756bb1", fg = "#ffffff" },
        },
    },

        -- Callbacks
    callbacks = {
        post_setup = function(client)
            -- Called after obsidian.nvim is set up
            vim.notify("Obsidian.nvim configured for your vault", vim.log.levels.INFO)

                        -- Simple autocommand to update date_modified on save
            vim.api.nvim_create_autocmd("BufWritePre", {
                pattern = "*.md",
                callback = function()
                    local bufnr = vim.api.nvim_get_current_buf()
                    
                    -- Skip if buffer is not modifiable
                    if not vim.bo[bufnr].modifiable then
                        return
                    end
                    
                    -- Skip README.md and AGENTS.md files (e.g., GitHub profile READMEs, configuration docs)
                    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
                    local lower_filename = filename:lower()
                    if lower_filename == "readme.md" or lower_filename == "agents.md" then
                        return
                    end

                    -- Preserve current view so updating frontmatter does not scroll the buffer.
                    local view = vim.fn.winsaveview()
                    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                    local content = table.concat(lines, "\n")
                    local current_date = get_current_yaml_date()

                    if content:match("^---") then
                        -- File has YAML header, update date_modified
                        if content:match("date_modified:") then
                            local new_content = content:gsub("date_modified:[^\n]*", "date_modified: " .. current_date)
                            if new_content ~= content then
                                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(new_content, "\n"))
                            end
                        else
                            local new_content = content:gsub("(---\n)", "%1date_modified: " .. current_date .. "\n", 1)
                            if new_content ~= content then
                                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(new_content, "\n"))
                            end
                        end
                    else
                        -- No YAML header, add complete frontmatter
                        local file_id = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t:r")
                        local frontmatter = build_yaml_frontmatter(file_id, current_date)

                        local new_content = frontmatter .. content
                        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(new_content, "\n"))
                    end

                    -- Restore original view after modifying the buffer.
                    vim.fn.winrestview(view)
                end,
            })
        end,
        new_note = function(note)
            -- Add frontmatter to new notes
            local content = note.content or ""
            local current_date = get_current_yaml_date()

            -- Get filename without extension for the id
            local filename = note.id or ""
            if filename == "" and note.path then
                filename = vim.fn.fnamemodify(note.path, ":t:r")  -- Get filename without extension
            end

            local frontmatter = build_yaml_frontmatter(filename, current_date)
            note.content = frontmatter .. content
        end,
    },

    -- Performance settings
    daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        alias_format = "%B %-d, %Y",
        template = nil,
    },

    -- Advanced settings
    disable_frontmatter = true,
    note_path_func = function(spec)
        -- Custom note path function
        if spec.id and spec.id ~= "" then
            return spec.id
        end
        if spec.title then
            return spec.title:gsub(" ", "-"):lower()
        end
        return tostring(os.time())
    end,
})
