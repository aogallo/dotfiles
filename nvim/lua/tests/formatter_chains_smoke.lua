-- Formatter chain selection smoke test (specs/009-trim-trailing-whitespace,
-- quickstart automated check). Asserts the selection that
-- nvim/plugin/conform.lua hands to the formatting toolchain, loadable with
-- `nvim --headless -u NORC` because the selection lives in a plain module
-- instead of inside the plugin file (FR-010, contract §1):
--   - both branches end with the whitespace-only steps
--   - both branches stop after the first available formatter, so a missing
--     main formatter degrades to trimming instead of to nothing
--   - the main formatter is still first in both branches
--   - the branch is chosen by a marker file in the buffer's directory, and a
--     second call for the same buffer returns an equal chain
-- No live UI is touched. Exits with code 1 via :cquit on any assertion failure.

local function fail(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

--- chain shape -------------------------------------------------------------

local chains = require 'config.formatter_chains'

-- Real directories: the marker list holds file names, so a directory merely
-- NAMED .prettierrc would not match and the check would silently exercise the
-- wrong branch.
local tmp = vim.fn.tempname()
local function dir_with_marker(marker)
    local dir = tmp .. '/' .. (marker or 'bare'):gsub('[^%w]', '_')
    vim.fn.mkdir(dir, 'p')
    if marker then
        vim.fn.writefile({ '{}' }, dir .. '/' .. marker)
    end
    return dir
end

local function buffer_in(path)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, path)
    return buf
end

-- Buffer in a temp directory with no formatter configuration above it: the
-- toolchain's own markdown formatter branch.
local plain = buffer_in(dir_with_marker(nil) .. '/notes.md')
local plain_chain = chains.markdown(plain)

-- Buffer under a directory that does carry a prettier configuration: the
-- project branch.
local project = buffer_in(dir_with_marker '.prettierrc' .. '/notes.md')
local project_chain = chains.markdown(project)

fail(
    plain_chain[1] == 'markdown_prettier',
    'plain markdown buffer selects the bundled markdown formatter first',
    plain_chain[1],
    'markdown_prettier'
)
fail(
    project_chain[1] == 'prettier',
    'project-signal buffer selects the project prettier formatter first',
    project_chain[1],
    'prettier'
)

-- The bug this guards: a project-signal chain that listed only the main
-- formatter left the file completely unformatted when prettier was missing.
-- Both branches must carry the trims, and must stop after the first available
-- formatter so the trims never run alongside prettier (which would flatten
-- two-space hard breaks, FR-004).
for name, chain in pairs { ['plain branch'] = plain_chain, ['project branch'] = project_chain } do
    local seen_whitespace, seen_newlines = false, false
    for _, formatter in ipairs(chain) do
        if formatter == 'trim_whitespace' then
            seen_whitespace = true
        elseif formatter == 'trim_newlines' then
            seen_newlines = true
        end
    end
    fail(seen_whitespace, name .. ' chain keeps the trailing-whitespace trim', chain, 'trim_whitespace present')
    fail(seen_newlines, name .. ' chain keeps the trailing-newline trim', chain, 'trim_newlines present')
    fail(
        chain.stop_after_first == true,
        name .. ' chain stops after the first available formatter',
        chain.stop_after_first,
        true
    )
    fail(chain.timeout_ms == 500, name .. ' chain keeps the 500ms timeout', chain.timeout_ms, 500)
end

fail(
    project_chain.lsp_format == 'fallback',
    'project branch keeps the LSP fallback for prettier',
    project_chain.lsp_format,
    'fallback'
)
fail(
    plain_chain.lsp_format == nil,
    'plain branch does not gain an LSP fallback it never had',
    plain_chain.lsp_format,
    nil
)

-- Determinism: the table is rebuilt per call, so a formatter that mutated it
-- could not leak into the next buffer.
fail(
    vim.deep_equal(chains.markdown(plain), plain_chain),
    'repeated selection for the same buffer returns an equal chain',
    chains.markdown(plain),
    plain_chain
)

--- branch choice -----------------------------------------------------------

fail(
    chains.markdown_project_markers[1] == '.prettierrc',
    'marker list is exported',
    chains.markdown_project_markers,
    '.prettierrc first'
)
for _, marker in ipairs { 'package.json', 'prettier.config.js', '.prettierrc.json' } do
    fail(
        vim.tbl_contains(chains.markdown_project_markers, marker),
        'marker list includes ' .. marker,
        marker,
        'present'
    )
end

-- The marker search walks upward, so a file nested below the configured
-- directory still gets the project branch.
local nested = buffer_in(dir_with_marker '.prettierrc' .. '/docs/deep/notes.md')
fail(
    chains.markdown(nested)[1] == 'prettier',
    'a buffer nested below the marker directory keeps the project branch',
    chains.markdown(nested)[1],
    'prettier'
)

-- Every exported marker name selects the project branch, so adding a name to
-- the list cannot come with a typo that never matches.
for _, marker in ipairs { '.prettierrc.json', 'package.json', 'prettier.config.js' } do
    local buf = buffer_in(dir_with_marker(marker) .. '/notes.md')
    fail(
        chains.markdown(buf)[1] == 'prettier',
        'a directory containing ' .. marker .. ' takes the project branch',
        chains.markdown(buf)[1],
        'prettier'
    )
end

-- An unnamed buffer resolves against the cwd. Run it from a temp directory
-- with no marker so the result does not depend on where the check was invoked.
local bare = buffer_in(dir_with_marker(nil) .. '/.gitkeep')
vim.fn.chdir(dir_with_marker(nil))
local unnamed = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(unnamed, '')
fail(
    chains.markdown(unnamed)[1] == 'markdown_prettier',
    'an unnamed buffer in a directory with no marker takes the plain branch',
    chains.markdown(unnamed)[1],
    'markdown_prettier'
)

--- the no-formatter warning -------------------------------------------------

local message = chains.no_formatter_message 'markdown'
fail(
    type(message) == 'string' and message:find('markdown', 1, true) ~= nil,
    'the warning names the file type',
    message,
    'contains the filetype'
)
fail(chains.no_formatter_message '' == nil, 'no file type means no warning', 'nil', 'nil')
fail(chains.no_formatter_message() == nil, 'a missing file type means no warning', 'nil', 'nil')

-- The warning must not leak the file it is about, so assert it stays generic
-- across two different files of the same type.
local other = chains.no_formatter_message 'sql'
fail(other:gsub('sql', 'markdown') == message, 'the warning text does not depend on the file', other, message)

-- Contract §3 rule 2: nothing about content or path. The text is the same
-- whatever the file is called, and mentions no path separator.
fail(not message:find('/', 1, true), 'the warning carries no path', message, 'no "/"')

vim.print 'All formatter chain smoke assertions passed'
