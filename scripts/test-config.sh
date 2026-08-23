#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")/.."

ZSH_BIN="${ZSH_BIN:-$(command -v zsh)}"

echo "==> Headless startup"
"${ZSH_BIN}" -lc 'nvim --headless -c "qa"'

echo "==> Load phased plugins"
"${ZSH_BIN}" -lc 'nvim --headless -c "lua require(\"core.plugin-loader\").load_all(); vim.wait(800)" -c "qa"'

echo "==> Assert CodeCompanion commands exist"
"${ZSH_BIN}" -lc 'nvim --headless -c "lua require(\"core.plugin-loader\").load_all(); vim.wait(800); local function must(cond, msg) if not cond then vim.api.nvim_err_writeln(msg); vim.cmd(\"cq\") end end; must(vim.fn.exists(\":CodeCompanionChat\") == 2, \"CodeCompanionChat missing\"); must(vim.fn.exists(\":CodeCompanion\") == 2, \"CodeCompanion missing\")" -c "qa"'

echo "==> Assert blink provider wiring is present"
"${ZSH_BIN}" -lc 'nvim --headless -c "lua require(\"core.plugin-loader\").load_all(); vim.wait(800); local function must(cond, msg) if not cond then vim.api.nvim_err_writeln(msg); vim.cmd(\"cq\") end end; local ok, cfg = pcall(require, \"blink.cmp.config\"); must(ok, \"blink.cmp.config not loadable\"); local providers = cfg.sources.providers or {}; must(providers.codecompanion ~= nil, \"blink codecompanion provider missing\"); local found = false; for _, v in ipairs(cfg.sources.default or {}) do if v == \"codecompanion\" then found = true end end; must(found, \"blink sources.default missing codecompanion\")" -c "qa"'

echo "All local checks passed."
