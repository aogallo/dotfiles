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

-- Two channels, because the failure this guards against is a message arriving
-- from somewhere other than our own path:
--   * the notification module's history counts OUR warnings, and
--   * a vim.notify capture, armed for exactly one write at a time, catches
--     anything at all — including a notice the toolchain emits on its own.
--
-- The capture is not a permanent stub on purpose. This configuration re-wraps
-- vim.notify shortly after startup (nvim/plugin/editor.lua) and discards
-- whatever a check installed, and nesting one capture inside another multiplies
-- every message. Armed once per measurement point, it is exact.
--
-- The capture does NOT call through to the notify it replaced, and that is load
-- bearing rather than lazy: the wrapper re-points its own base at whatever has
-- replaced it, so a call-through capture parked in that slot is a function whose
-- sink is the wrapper itself, and the next notification recurses until the stack
-- runs out. The message is already recorded either way, which is all this check
-- measures.
local notifications = require 'notifications'
local history_length = #notifications.history()

local function capture_next_write()
    local raw = {}
    vim.notify = function(msg)
        raw[#raw + 1] = tostring(msg)
    end
    return raw
end

local WARNING_PREFIX = 'No formatter available for '

-- Filtered by our own wording on purpose. The history is shared, and other
-- components announce themselves into it while this check runs (a language
-- server attaching, for one), so an unfiltered count would measure the timing
-- of the check rather than the behavior under test.
local function our_warnings(ft)
    local out = {}
    for i = history_length + 1, #notifications.history() do
        local entry = notifications.history()[i]
        if entry.summary:sub(1, #WARNING_PREFIX + #ft) == WARNING_PREFIX .. ft then
            out[#out + 1] = entry
        end
    end
    return out
end

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
local after_first = our_warnings 'sh'

raw_first = capture_next_write()
vim.cmd 'write'
local after_second = our_warnings 'sh'

fail(#after_first == 1, 'the first failing save reports exactly one message', #after_first, 1)

-- Two saves in quick succession are shown by the notification module as one
-- entry with a repeat count, which is the user-visible "it happened again".
-- What FR-008 rules out is that count staying at 1 for the rest of the session,
-- which is exactly what the toolchain's once-per-filetype notice did.
fail(
    after_second[1] and after_second[1].count == 2,
    'the second failing save is reported, not swallowed (SC-003)',
    after_second[1] and { count = after_second[1].count },
    { count = 2 }
)

-- Past the module's aggregation window it is a separate entry, so the failure
-- is not one quiet line for the whole session either.
vim.wait(1600)
capture_next_write()
vim.cmd 'write'
local after_third = our_warnings 'sh'
fail(#after_third == 2, 'a later failing save is its own message again (FR-008)', #after_third, 2)

fail(
    #toolchain_notices(raw_first) == 0,
    "the toolchain's own notice does not duplicate ours (contract §3 rule 1)",
    toolchain_notices(raw_first),
    0
)

fail(
    vim.iter(after_third):all(function(entry)
        return entry.summary:find('sh', 1, true) ~= nil
    end),
    'every message names the file type',
    vim.tbl_map(function(e)
        return e.summary
    end, after_third),
    'each mentions sh'
)
fail(
    vim.iter(after_third):all(function(entry)
        return not entry.summary:find('/', 1, true)
    end),
    'no message says anything about the file',
    vim.tbl_map(function(e)
        return e.summary
    end, after_third),
    'no path'
)

--- a save that would have been formatted stays silent (contract §4 rule 3) ---

vim.cmd('edit ' .. vim.fn.fnameescape(boot))
local md = vim.api.nvim_get_current_buf()
vim.bo[md].filetype = 'markdown'
local md_list = conform.list_formatters_to_run(md)
local raw_markdown = capture_next_write()
vim.cmd 'write'
fail(
    #md_list > 0 and #our_warnings 'markdown' == 0 and #our_warnings_in(raw_markdown, 'markdown') == 0,
    'a save with an available formatter reports nothing',
    { list = #md_list, warnings = #our_warnings 'markdown', raw_warnings = #our_warnings_in(raw_markdown, 'markdown') },
    { list = '> 0', warnings = 0, raw_warnings = 0 }
)

--- a save the user excluded stays silent (contract §3 rule 3) ---------------

vim.cmd('edit ' .. vim.fn.fnameescape(path))
local skipped = vim.api.nvim_get_current_buf()
vim.bo[skipped].filetype = 'sh'
local warnings_before_skip = #our_warnings 'sh'
vim.g.skip_formatting = true
local raw_skipped = capture_next_write()
vim.cmd 'write'
fail(
    #our_warnings_in(raw_skipped, 'sh') == 0 and #our_warnings 'sh' == warnings_before_skip,
    'a save excluded by the skip guard reports nothing',
    { raw_warnings = #our_warnings_in(raw_skipped, 'sh'), warnings = #our_warnings 'sh' - warnings_before_skip },
    { raw_warnings = 0, warnings = 0 }
)
fail(
    vim.g.skip_formatting == false,
    'the skip guard was consumed exactly once, so the formatter still saw it',
    vim.g.skip_formatting,
    false
)

vim.print 'All no-formatter reporting smoke assertions passed'
