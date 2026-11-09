-- No-formatter reporting smoke test (specs/009-trim-trailing-whitespace,
-- quickstart §5.3, FR-008). Needs the real configuration, because the claim is
-- about what a real save reports.
--
-- The failure this exercises is not simulated. `sh` maps to the `shfmt`
-- formatter, and `shfmt` is not one of the binaries this configuration
-- installs, so a shell buffer genuinely resolves to an empty formatter list
-- here. That matters: an earlier version of the quickstart tried to produce
-- this state by shortening PATH, which cannot work on this machine, because the
-- configuration itself puts the formatter directory back on PATH during
-- startup. A check that cannot fail is not a check.
--
-- Exits with code 1 via :cquit on any assertion failure.

-- Same lazy runtimepath as the other real-configuration check: opening a buffer
-- is what adds the plugin pack.
local boot = vim.fn.tempname() .. '.sh'
vim.fn.writefile({ 'echo hi' }, boot)
vim.cmd('edit ' .. vim.fn.fnameescape(boot))

local ok, conform = pcall(require, 'conform')
if not ok then
    vim.print 'SKIP no_formatter_warning_smoke: the formatting toolchain is not loadable here'
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

-- Observe the public notification path once per save. There is no parallel
-- repository-local history or self-healing vim.notify wrapper anymore.
local original_notify = vim.notify
local function capture_next_write()
    local raw = {}
    vim.notify = function(msg)
        raw[#raw + 1] = tostring(msg)
    end
    return raw
end

local WARNING_PREFIX = 'No formatter available for '

-- Our own wording inside a raw capture, which also catches a warning that
-- bypassed the notification module. Unrelated messages are ignored: other
-- components announce themselves through the same channel, and a save that
-- formats cleanly can still coincide with a language server attaching.
local function our_warnings_in(raw, ft)
    return vim.tbl_filter(function(message)
        return message:sub(1, #WARNING_PREFIX + #ft) == WARNING_PREFIX .. ft
    end, raw)
end

-- The toolchain's own wording, matched as a substring so a failure prints the
-- real text instead of a guess at it.
local function toolchain_notices(raw)
    return vim.tbl_filter(function(message)
        return message:lower():find('formatters unavailable', 1, true) ~= nil
    end, raw)
end

--- the buffer under test ---------------------------------------------------

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, 'p')
local path = dir .. '/probe.sh'
vim.fn.writefile({ 'echo one   ', 'echo two' }, path)
vim.cmd('edit ' .. vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = 'sh'

-- Confirm the premise before asserting on it: if this machine ever grows an
-- shfmt binary, the check has to say so instead of quietly passing.
local list = conform.list_formatters_to_run(buf)
fail(#list == 0, 'the shell file type really resolves to no formatter here', #list, 0)

--- repeated failing saves keep reporting (SC-003, FR-008) -------------------

local raw_first = capture_next_write()
vim.cmd 'write'
local raw_second = capture_next_write()
vim.cmd 'write'
local raw_third = capture_next_write()
vim.cmd 'write'

for index, raw in ipairs { raw_first, raw_second, raw_third } do
    local warnings = our_warnings_in(raw, 'sh')
    fail(#warnings == 1, 'failing save ' .. index .. ' reports exactly once (SC-003, FR-008)', warnings, 1)
    fail(
        #toolchain_notices(raw) == 0,
        "the toolchain's own notice does not duplicate ours (contract §3 rule 1)",
        toolchain_notices(raw),
        0
    )
    fail(
        not warnings[1]:find('/', 1, true),
        'the warning names the file type, not the file path',
        warnings[1],
        'file type only'
    )
end

--- a save that would have been formatted stays silent (contract §4 rule 3) ---

vim.cmd('edit ' .. vim.fn.fnameescape(boot))
local md = vim.api.nvim_get_current_buf()
vim.bo[md].filetype = 'markdown'
local md_list = conform.list_formatters_to_run(md)
local raw_markdown = capture_next_write()
vim.cmd 'write'
fail(
    #md_list > 0 and #our_warnings_in(raw_markdown, 'markdown') == 0,
    'a save with an available formatter reports nothing',
    { list = #md_list, raw_warnings = #our_warnings_in(raw_markdown, 'markdown') },
    { list = '> 0', raw_warnings = 0 }
)

--- a save the user excluded stays silent (contract §3 rule 3) ---------------

vim.cmd('edit ' .. vim.fn.fnameescape(path))
local skipped = vim.api.nvim_get_current_buf()
vim.bo[skipped].filetype = 'sh'
vim.g.skip_formatting = true
local raw_skipped = capture_next_write()
vim.cmd 'write'
fail(
    #our_warnings_in(raw_skipped, 'sh') == 0,
    'a save excluded by the skip guard reports nothing',
    { raw_warnings = #our_warnings_in(raw_skipped, 'sh') },
    { raw_warnings = 0 }
)
fail(
    vim.g.skip_formatting == false,
    'the skip guard was consumed exactly once, so the formatter still saw it',
    vim.g.skip_formatting,
    false
)

vim.notify = original_notify
vim.fn.delete(boot)
vim.fn.delete(dir, 'rf')

vim.print 'All no-formatter reporting smoke assertions passed'
