-- Active-buffer emphasis smoke test (specs/012-line-number-buffer-highlights,
-- quickstart §6). Asserts the highlight contract in
-- specs/012-line-number-buffer-highlights/contracts/highlight-contract.md by
-- reading real values back from a running editor.
--
-- Why this is a separate file from the other suites: it is the only one that
-- needs the real configuration loaded, because the values under test are
-- defined by the `tokyonight` `on_highlights` hook in nvim/plugin/editor.lua.
-- Under `nvim --headless -u NORC` there is no colorscheme and no buffer-row
-- plugin, so every group it reads would be nil and the suite would pass for the
-- wrong reason — the same failure mode the self-check below guards against.
--
-- Contrast is measured with the WCAG 2.x relative-luminance formula, matching
-- quickstart §6 and research.md R-0001. Floors are named constants rather than
-- repeated literals so SC-002/SC-005 and SC-003/SC-004 have exactly one
-- definition each (data-model.md Entity 4).
--
-- Exits with code 1 via :cquit on any assertion failure.

-- This repository adds its plugin pack to the runtimepath lazily, and opening a
-- buffer is what triggers it. Without this the highlight groups are absent and
-- the measurement below silently reads nil.
local scratch = vim.fn.tempname()
vim.fn.writefile({ '' }, scratch)
vim.cmd('edit ' .. vim.fn.fnameescape(scratch))

--- Linearise one sRGB channel.
local function lin(c)
    c = c / 255
    if c <= 0.03928 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

--- Relative luminance of a 0xRRGGBB integer.
local function lum(rgb)
    return 0.2126 * lin(math.floor(rgb / 65536) % 256)
        + 0.7152 * lin(math.floor(rgb / 256) % 256)
        + 0.0722 * lin(rgb % 256)
end

--- WCAG contrast ratio between two 0xRRGGBB integers. Order-independent.
local function cr(a, b)
    local la, lb = lum(a), lum(b)
    if la < lb then
        la, lb = lb, la
    end
    return (la + 0.05) / (lb + 0.05)
end

--- Format a 0xRRGGBB integer for display.
local function hex(c)
    return c and string.format('#%06x', c) or 'nil'
end

--- Read a highlight group as defined, without following links.
local function g(n)
    return vim.api.nvim_get_hl(0, { name = n, link = false })
end

--- The yardstick. PRIMARY is the text floor (SC-002, SC-005); SECONDARY is the
--- non-primary floor (SC-003, SC-004). See data-model.md Entity 4.
local PRIMARY, SECONDARY = 4.5, 3.0

--- Background every number-column case measures against.
local function normal_bg()
    return g('Normal').bg
end

-- check(ok, name, got, want): record one assertion result.
-- Called by: every assertion in this suite
-- SQL: none
-- Args: ok = truthy when the assertion holds, name = what is being asserted,
--   got = the observed value (printed on failure), want = the expected value
-- Returns: nothing
-- Side effects: prints PASS, or prints FAIL plus got/want and quits with 1
local function check(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

-- Self-check before any real assertion depends on the math. A cr() that
-- silently returned a constant would make every later case pass while proving
-- nothing, and the whole suite would be worthless in exactly the way FR-027
-- warns about. Both pairs are standard WCAG reference values.
check(
    math.abs(cr(0x000000, 0xffffff) - 21.00) < 0.01,
    'ratio math: black on white is 21.00',
    cr(0x000000, 0xffffff),
    21.00
)
check(
    math.abs(cr(0x777777, 0xffffff) - 4.48) < 0.01,
    'ratio math: #777777 on white is 4.48',
    cr(0x777777, 0xffffff),
    4.48
)

-- Report what the editor currently defines, so a later reader can tell a
-- not-yet-implemented state from a broken one. Asserts nothing on its own.
vim.print(
    string.format('harness ready: Normal bg=%s, PRIMARY=%.1f, SECONDARY=%.1f', hex(normal_bg()), PRIMARY, SECONDARY)
)

-- ---------------------------------------------------------------------------
-- User Story 1, contract section B: the buffer row
-- ---------------------------------------------------------------------------

local sel = g 'BufferLineBufferSelected'
local vis = g 'BufferLineBufferVisible'
local ina = g 'BufferLineBuffer'
local sep = g 'BufferLineSeparatorSelected'
local ind = g 'BufferLineIndicatorSelected'

-- Each name measured against the background it actually sits on.
local sel_own = cr(sel.fg, sel.bg)
local ina_own = cr(ina.fg, ina.bg)

check(sel_own >= PRIMARY, 'US1 active name clears PRIMARY against its own bg', sel_own, PRIMARY)
check(sel_own >= 1.5 * ina_own, 'US1 active name is at least 1.5x the inactive name', sel_own / ina_own, 1.5)
check(
    cr(sel.bg, ina.bg) >= 1.3,
    'US1 active background separates from the inactive background',
    cr(sel.bg, ina.bg),
    1.3
)
check(ina_own >= SECONDARY, 'US1 inactive name clears SECONDARY against its own bg', ina_own, SECONDARY)
check(
    cr(vis.fg, ina.fg) >= 1.25,
    'US1 non-focused window name is distinguishable from the inactive name',
    cr(vis.fg, ina.fg),
    1.25
)
check(cr(vis.bg, sel.bg) >= 1.3, 'US1 non-focused window background does not mimic focus', cr(vis.bg, sel.bg), 1.3)
check(ina_own < sel_own, 'US1 no inactive name reaches the active name contrast', ina_own < sel_own, true)

-- Invariants added by T004. They are contract clauses now, so they are asserted
-- here rather than living only in the read-only probe.
check(
    sep.fg == sep.bg and cr(sep.fg, sep.bg) == 1.0,
    'US1 separator vanishes on the active tab (fg equals bg)',
    { fg = hex(sep.fg), bg = hex(sep.bg) },
    'fg equals bg'
)
check(
    cr(ind.fg, sel.bg) >= SECONDARY and cr(ind.fg, sel.bg) < sel_own,
    'US1 indicator is visible but does not outrank the active name',
    cr(ind.fg, sel.bg),
    '>= ' .. SECONDARY .. ' and < ' .. sel_own
)

-- ---------------------------------------------------------------------------
-- User Story 1, contract section C: diagnostic overlays on the active tab
-- ---------------------------------------------------------------------------

-- bold marks a severity, not a row state: only the four diagnostic overlays
-- carry it. Modified and CloseButton are state markers (contract section C).
local OVERLAYS = {
    { name = 'Error', fg = '#ffc0b9', bold = true },
    { name = 'Warning', fg = '#fce094', bold = true },
    { name = 'Info', fg = '#8cf8f7', bold = true },
    { name = 'Hint', fg = '#a6dbff', bold = true },
    { name = 'Modified', fg = '#b3f6c0', bold = false },
    { name = 'CloseButton', fg = '#e0e2ea', bold = false },
}

for _, o in ipairs(OVERLAYS) do
    local h = g('BufferLine' .. o.name .. 'Selected')
    local measured = cr(h.fg, h.bg)
    check(
        measured >= PRIMARY,
        'US1 overlay ' .. o.name .. ' clears PRIMARY on the active background',
        measured,
        PRIMARY
    )
    check(
        measured >= ina_own,
        'US1 overlay ' .. o.name .. ' is never weaker than a plain inactive name',
        measured,
        ina_own
    )
    check(
        (h.bold and true or false) == o.bold,
        'US1 overlay ' .. o.name .. ' bold is ' .. tostring(o.bold),
        h.bold and true or false,
        o.bold
    )
end

-- ---------------------------------------------------------------------------
-- User Story 2, contract section A: the number column
-- ---------------------------------------------------------------------------

local bg = normal_bg()
local rel = { g 'LineNr', g 'LineNrAbove', g 'LineNrBelow' }

for i, h in ipairs(rel) do
    local group = ({ 'LineNr', 'LineNrAbove', 'LineNrBelow' })[i]
    check(cr(h.fg, bg) >= SECONDARY, 'US2 ' .. group .. ' clears SECONDARY against Normal', cr(h.fg, bg), SECONDARY)
end

local cursor_nr = g 'CursorLineNr'
check(cr(cursor_nr.fg, bg) >= PRIMARY, 'US2 CursorLineNr clears PRIMARY against Normal', cr(cursor_nr.fg, bg), PRIMARY)
-- Strict: the cursor's number must stay the strongest, never merely equal.
check(
    cr(cursor_nr.fg, bg) > cr(rel[1].fg, bg),
    'US2 CursorLineNr outranks the relative numbers',
    cr(cursor_nr.fg, bg) .. ' vs ' .. cr(rel[1].fg, bg),
    'strictly greater'
)
check(
    rel[1].fg == rel[2].fg and rel[2].fg == rel[3].fg,
    'US2 the three relative groups hold one foreground',
    { hex(rel[1].fg), hex(rel[2].fg), hex(rel[3].fg) },
    'all equal'
)
