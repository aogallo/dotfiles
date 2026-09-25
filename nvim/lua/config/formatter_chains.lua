-- Formatter chain selection for save-time formatting (specs/009-trim-trailing-whitespace).
--
-- Which formatter chain a buffer gets. Lives here, outside the plugin file,
-- for one reason: the chain must be verifiable without the formatting
-- toolchain being installed. Inside nvim/plugin/conform.lua these were locals,
-- and that file is only on the runtimepath after the repository's own plugin
-- boot, so no offline check could reach them (spec FR-010, research D8).
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function below carries a header with Purpose / Called by / SQL /
--   Args / Returns / Side effects. Required for new functions too.

local M = {}

-- Files that mean "this directory has its own formatter rules" (FR-007).
-- A markdown file under any of these gets the project's formatter, and the
-- whitespace fallback is chained behind it so a missing formatter still
-- cleans the file.
M.markdown_project_markers = {
    '.prettierrc',
    '.prettierrc.cjs',
    '.prettierrc.js',
    '.prettierrc.json',
    '.prettierrc.json5',
    '.prettierrc.mjs',
    '.prettierrc.toml',
    '.prettierrc.yaml',
    '.prettierrc.yml',
    'package.json',
    'prettier.config.cjs',
    'prettier.config.js',
    'prettier.config.mjs',
    'prettier.config.ts',
}

-- has_signal(bufnr): does a formatter configuration govern this buffer?
-- Called by: M.markdown()
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: boolean — true when one of the marker files exists in the buffer's
--   directory or any ancestor
-- Side effects: none
local function has_signal(bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local start = bufname ~= '' and vim.fs.dirname(bufname) or vim.fn.getcwd()

    if not start or start == '' then
        return false
    end

    return #vim.fs.find(M.markdown_project_markers, { path = start, upward = true, type = 'file' }) > 0
end

-- M.markdown(bufnr): the formatter chain for a markdown buffer.
-- Called by: nvim/plugin/conform.lua (formatters_by_ft.markdown), and by
--   nvim/lua/tests/formatter_chains_smoke.lua
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: table of formatter names plus options, in the shape the formatting
--   plugin expects. Both branches end with the whitespace-only steps and both
--   set stop_after_first, so a missing main formatter degrades to trimming
--   instead of to nothing, and the trims never run alongside the main
--   formatter (which would flatten two-space hard breaks).
-- Side effects: none
function M.markdown(bufnr)
    if has_signal(bufnr) then
        return {
            'prettier',
            'trim_whitespace',
            'trim_newlines',
            timeout_ms = 500,
            lsp_format = 'fallback',
            stop_after_first = true,
        }
    end

    return { 'markdown_prettier', 'trim_whitespace', 'trim_newlines', timeout_ms = 500, stop_after_first = true }
end

-- M.no_formatter_message(ft): the warning for a save that had no formatter.
-- Called by: nvim/plugin/conform.lua (the BufWritePre availability check),
--   and by nvim/lua/tests/formatter_chains_smoke.lua
-- SQL: none
-- Args: ft = filetype that had no formatter, or nil/'' when the buffer has none
-- Returns: the warning text naming the file type, or nil when there is
--   nothing to report
-- Side effects: none
--
-- The text names the file type and says nothing about the file's content or
-- path (contract §3 rule 2), and both ways out are named, because a warning
-- with no remedy is just noise the user learns to ignore.
function M.no_formatter_message(ft)
    if not ft or ft == '' then
        return nil
    end
    return string.format(
        'No formatter available for %s: this save did not clean the file. Install one, or set vim.g.autoformat = false to stop this warning.',
        ft
    )
end

return M
