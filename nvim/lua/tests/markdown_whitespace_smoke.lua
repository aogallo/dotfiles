-- Markdown whitespace behavior smoke test (specs/009-trim-trailing-whitespace,
-- quickstart §5). The one check that needs the real configuration, because the
-- steps that actually move the whitespace belong to the formatting toolchain.
--
-- Two reasons it cannot run with `nvim --headless -u NORC`, which is why it is
-- a separate file instead of more assertions in formatter_chains_smoke:
--   1. the formatting toolchain is only on the runtimepath after this
--      repository's own plugin boot;
--   2. the interesting input is a real file on disk, because the claim is
--      about what a save leaves behind.
--
-- Skips with exit 0 when the toolchain cannot be loaded, so the offline suite
-- stays green on a machine without it. Exits with code 1 via :cquit on any
-- assertion failure.

-- This repository adds its plugin pack to the runtimepath lazily, and opening a
-- buffer is what triggers it: before that, `require 'conform'` fails even
-- though nothing is wrong. Open a scratch file so the check exercises the real
-- configuration rather than skipping on a healthy machine.
local boot = vim.fn.tempname() .. '.md'
vim.fn.writefile({ '' }, boot)
vim.cmd('edit ' .. vim.fn.fnameescape(boot))

local ok, conform = pcall(require, 'conform')
if not ok then
    vim.print 'SKIP markdown_whitespace_smoke: the formatting toolchain is not loadable here'
    vim.cmd 'quitall'
    return
end

local function fail(ok_, name, got, want)
    if ok_ then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

local function cat(bufnr)
    return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

-- No marker file above the temp directory, so the chain under test is the one
-- the toolchain uses for Markdown anywhere in this repository.
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')

--- formatter reachable: the main formatter's own rules ---------------------

-- Four lines, one per verified rule, plus a whitespace-only line and an
-- indented example.
-- Placement matters and is the point: a two- or three-space run only survives
-- when text FOLLOWS it in the same paragraph. On the last line of a paragraph
-- it is removed, so every case below is placed to exercise exactly one rule.
local input = {
    '# heading  ',
    '',
    'prose with a hard break.  ',
    'continued here',
    'prose with 3 spaces...   ',
    'still the same paragraph',
    'last line of the paragraph.  ',
    '',
    '   ',
    '```lua',
    'local x = 1   ',
    '```',
    '',
    '    indented example   ',
}
local path = dir .. '/rules.md'
vim.fn.writefile(input, path)
vim.cmd('edit ' .. vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = 'markdown'
conform.format { bufnr = buf, async = false, lsp_format = 'never' }
local out = cat(buf)

fail(
    out:find('# heading\n', 1, true) ~= nil,
    'trailing spaces after a heading are removed (FR-005)',
    out:match '^# heading.*',
    '# heading'
)
fail(
    out:find('prose with a hard break.  \n', 1, true) ~= nil,
    'a two-space break with following text is preserved (FR-004)',
    out:match 'hard break.*',
    'prose with a hard break.  '
)
fail(
    out:find('prose with 3 spaces...  \n', 1, true) ~= nil,
    'three spaces mid-paragraph become the two of a hard break, not zero (FR-004)',
    out:match '3 spaces.*',
    'prose with 3 spaces...  '
)
fail(
    out:find('last line of the paragraph.\n', 1, true) ~= nil,
    'a two-space break on the last line of a paragraph is removed (FR-005)',
    out:match 'last line.*',
    'last line of the paragraph.'
)
fail(
    out:find('local x = 1\n', 1, true) ~= nil,
    'trailing spaces inside a fenced block are removed (FR-005)',
    out:match 'local x.*',
    'local x = 1'
)
fail(out:find('```\n', 1, true) ~= nil, 'the fenced block is still fenced after formatting', out:match '```.*', '```')
-- The last line, read as a line: `cat()` joins with \n and adds no trailing one,
-- so asserting on a final \n would be asserting on the join, not the content.
local last_line = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
fail(
    last_line == '    indented example',
    'the indented example keeps its indentation and loses its trailing spaces (FR-005, FR-006)',
    last_line,
    '    indented example'
)

-- FR-003 was written as "a whitespace-only line becomes an empty line and is
-- never removed". Running the main formatter falsified the second half: a line
-- of only whitespace sitting between two blank lines is collapsed, because
-- that is what the formatter does to consecutive blank lines. Assert what is
-- actually true — the fallback's guarantee, and the formatter's own behavior
-- recorded here so a reader does not mistake one for the other.
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
fail(not vim.iter(lines):any(function(l)
    return l:match '^%s+$' ~= nil
end), 'no line is left holding only whitespace (FR-001, SC-001)', lines, 'no whitespace-only line')
fail(
    vim.iter(lines):any(function(l)
        return l == ''
    end),
    'the paragraph separation survives as empty lines (FR-003)',
    lines,
    'at least one empty line'
)
fail(
    vim.iter(lines):any(function(l)
        return l == '    indented example'
    end),
    'content inside the line survives byte for byte (FR-006)',
    lines,
    "'    indented example'"
)

--- content invariants -------------------------------------------------------

-- Tabs and leading indentation are the author's, not the cleanup's. Assert it
-- on a file type whose chain is the whitespace-only fallback, because that is
-- the step FR-006 constrains: a real formatter is free to reindent code, and
-- the Lua formatter here does exactly that, which is its job and not a defect.
local tabs_path = dir .. '/tabs.txt'
vim.fn.writefile({ 'run:', '\t\tdeep   ', '\tshallow', '  two spaces   ' }, tabs_path)
vim.cmd('edit ' .. vim.fn.fnameescape(tabs_path))
local tabs = vim.api.nvim_get_current_buf()
vim.bo[tabs].filetype = 'text'
conform.format { bufnr = tabs, async = false, lsp_format = 'never' }
local tabs_out = cat(tabs)
fail(
    tabs_out:find('\t\tdeep\n', 1, true) ~= nil,
    'a tab-indented line keeps its tabs and loses only the trailing spaces (FR-006)',
    tabs_out,
    '\t\tdeep'
)
fail(tabs_out:find('\tshallow\n', 1, true) ~= nil, 'a single-tab line is untouched (FR-006)', tabs_out, '\tshallow')
-- Read as a line, for the same reason as the indented example above: the
-- trailing-newline form of this assertion tests the join, not the content.
fail(
    vim.api.nvim_buf_get_lines(tabs, -2, -1, false)[1] == '  two spaces',
    'leading indentation is not trailing whitespace (FR-001, FR-006)',
    vim.api.nvim_buf_get_lines(tabs, -2, -1, false)[1],
    '  two spaces'
)

-- The Lua chain proves the other half: the trailing whitespace is gone, and the
-- formatter was allowed to reindent while doing it.
local lua_path = dir .. '/reindent.lua'
vim.fn.writefile({ 'local t = {', '\t\t"a",   ', '}' }, lua_path)
vim.cmd('edit ' .. vim.fn.fnameescape(lua_path))
local lua_buf = vim.api.nvim_get_current_buf()
vim.bo[lua_buf].filetype = 'lua'
conform.format { bufnr = lua_buf, async = false, lsp_format = 'never' }
local lua_out = cat(lua_buf)
fail(
    not lua_out:find('   ', 1, true),
    'the source formatter also removes trailing whitespace (FR-001)',
    lua_out,
    'no run of trailing spaces'
)
fail(
    lua_out:find('"a",', 1, true) ~= nil,
    'and it is allowed to reindent the code around it (FR-006, main formatter)',
    lua_out,
    'contains "a",'
)

-- CRLF endings are the file's, not the formatter's.
local crlf_path = dir .. '/crlf.md'
-- Written as raw bytes: vim.fn.writefile cannot express CRLF, and a line with a
-- trailing space in it is exactly the input this check is about.
local crlf_raw = io.open(crlf_path, 'wb')
crlf_raw:write 'alpha  \r\nbeta\r\n'
crlf_raw:close()
vim.cmd('edit ' .. vim.fn.fnameescape(crlf_path))
local crlf = vim.api.nvim_get_current_buf()
vim.bo[crlf].filetype = 'markdown'
fail(vim.bo[crlf].fileformat == 'dos', 'the CRLF file is read as dos (FR-011)', vim.bo[crlf].fileformat, 'dos')
-- The buffer is checked, not the file: a conform run edits the buffer and this
-- check never writes, so nothing is asserted about a path on disk.
conform.format { bufnr = crlf, async = false, lsp_format = 'never' }
local crlf_check = io.open(crlf_path, 'rb')
local crlf_text = crlf_check:read '*a'
crlf_check:close()
fail(
    crlf_text:find('\r\n', 1, true) ~= nil,
    'the CRLF file keeps its endings (FR-011)',
    vim.inspect(crlf_text),
    'contains \\r\\n'
)

-- With auto-formatting off, nothing runs at all: the disabled switch means
-- disabled, not "format with extra steps".
local off_path = dir .. '/off.md'
vim.fn.writefile({ 'gamma  ', 'delta' }, off_path)
vim.cmd('edit ' .. vim.fn.fnameescape(off_path))
local off = vim.api.nvim_get_current_buf()
vim.bo[off].filetype = 'markdown'
local saved_autoformat = vim.g.autoformat
vim.g.autoformat = false
conform.format { bufnr = off, async = false, lsp_format = 'never' }
fail(
    vim.deep_equal(vim.api.nvim_buf_get_lines(off, 0, -1, false), { 'gamma  ', 'delta' }),
    'a save with auto-formatting disabled changes nothing (FR-012)',
    vim.api.nvim_buf_get_lines(off, 0, -1, false),
    "{ 'gamma  ', 'delta' }"
)
vim.g.autoformat = saved_autoformat

vim.print 'All markdown whitespace smoke assertions passed'
