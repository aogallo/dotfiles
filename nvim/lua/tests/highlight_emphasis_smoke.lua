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
-- Returns nil when either colour is absent, so a missing override degrades to a
-- named failure below instead of a Lua arithmetic error. The mutation test
-- (T050) removes overrides on purpose and expects a clean failure, not a crash.
local function cr(a, b)
    if not (a and b) then
        return nil
    end
    local la, lb = lum(a), lum(b)
    if la < lb then
        la, lb = lb, la
    end
    return (la + 0.05) / (lb + 0.05)
end

--- A measured ratio reaches a floor. A nil ratio never does: an absent colour
--- is an absent measurement, not a passing one.
local function meets(value, floor)
    return type(value) == 'number' and value >= floor
end

--- Format any value for a failure message, without erroring on nil.
local function show(value)
    return tostring(value)
end

--- A value sits within 0.01 of a reference, and exists at all.
local function close(value, want)
    return type(value) == 'number' and math.abs(value - want) < 0.01
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
check(close(cr(0x000000, 0xffffff), 21.00), 'ratio math: black on white is 21.00', cr(0x000000, 0xffffff), 21.00)
check(close(cr(0x777777, 0xffffff), 4.48), 'ratio math: #777777 on white is 4.48', cr(0x777777, 0xffffff), 4.48)

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

check(meets(sel_own, PRIMARY), 'US1 active name clears PRIMARY against its own bg', sel_own, PRIMARY)
check(
    meets(sel_own, 1.5 * ina_own),
    'US1 active name is at least 1.5x the inactive name',
    show(sel_own) .. ' / ' .. show(ina_own),
    '1.5x'
)
check(
    meets(cr(sel.bg, ina.bg), 1.3),
    'US1 active background separates from the inactive background',
    cr(sel.bg, ina.bg),
    1.3
)
check(meets(ina_own, SECONDARY), 'US1 inactive name clears SECONDARY against its own bg', ina_own, SECONDARY)
check(
    meets(cr(vis.fg, ina.fg), 1.25),
    'US1 non-focused window name is distinguishable from the inactive name',
    cr(vis.fg, ina.fg),
    1.25
)
check(meets(cr(vis.bg, sel.bg), 1.3), 'US1 non-focused window background does not mimic focus', cr(vis.bg, sel.bg), 1.3)
check(
    type(ina_own) == 'number' and type(sel_own) == 'number' and ina_own < sel_own,
    'US1 no inactive name reaches the active name contrast',
    ina_own,
    'below ' .. show(sel_own)
)

-- Invariants added by T004. They are contract clauses now, so they are asserted
-- here rather than living only in the read-only probe.
check(
    sep.fg == sep.bg and cr(sep.fg, sep.bg) == 1.0,
    'US1 separator vanishes on the active tab (fg equals bg)',
    { fg = hex(sep.fg), bg = hex(sep.bg) },
    'fg equals bg'
)
check(
    meets(cr(ind.fg, sel.bg), SECONDARY) and cr(ind.fg, sel.bg) < sel_own,
    'US1 indicator is visible but does not outrank the active name',
    cr(ind.fg, sel.bg),
    '>= ' .. SECONDARY .. ' and < ' .. show(sel_own)
)

-- ---------------------------------------------------------------------------
-- User Story 1, contract section C: diagnostic overlays on the active tab
-- ---------------------------------------------------------------------------

-- bold marks a severity, not a row state: only the four diagnostic overlays
-- carry it. Modified and CloseButton are state markers (contract section C).
local OVERLAYS = {
    { name = 'Error', fg = '#ff757f', bold = true },
    { name = 'Warning', fg = '#ff966c', bold = true },
    { name = 'Info', fg = '#0db9d7', bold = true },
    { name = 'Hint', fg = '#89ddff', bold = true },
    { name = 'Modified', fg = '#c3e88d', bold = false },
    { name = 'CloseButton', fg = '#c8d3f5', bold = false },
}

for _, o in ipairs(OVERLAYS) do
    local h = g('BufferLine' .. o.name .. 'Selected')
    local measured = cr(h.fg, h.bg)
    -- The contrast floors below would still pass for the wrong hue, so pin the
    -- palette token too. `fg` sat unused in this table until the #101 amendment.
    check(hex(h.fg) == o.fg, 'US1 overlay ' .. o.name .. ' uses its palette token', hex(h.fg), o.fg)
    check(
        meets(measured, PRIMARY),
        'US1 overlay ' .. o.name .. ' clears PRIMARY on the active background',
        measured,
        PRIMARY
    )
    check(
        meets(measured, ina_own),
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
    check(
        meets(cr(h.fg, bg), SECONDARY),
        'US2 ' .. group .. ' clears SECONDARY against Normal',
        cr(h.fg, bg),
        SECONDARY
    )
end

local cursor_nr = g 'CursorLineNr'
check(
    meets(cr(cursor_nr.fg, bg), PRIMARY),
    'US2 CursorLineNr clears PRIMARY against Normal',
    cr(cursor_nr.fg, bg),
    PRIMARY
)
-- Strict: the cursor's number must stay the strongest, never merely equal.
check(
    type(cr(cursor_nr.fg, bg)) == 'number'
        and type(cr(rel[1].fg, bg)) == 'number'
        and cr(cursor_nr.fg, bg) > cr(rel[1].fg, bg),
    'US2 CursorLineNr outranks the relative numbers',
    show(cr(cursor_nr.fg, bg)) .. ' vs ' .. show(cr(rel[1].fg, bg)),
    'strictly greater'
)
check(
    rel[1].fg == rel[2].fg and rel[2].fg == rel[3].fg,
    'US2 the three relative groups hold one foreground',
    { hex(rel[1].fg), hex(rel[2].fg), hex(rel[3].fg) },
    'all equal'
)

-- ---------------------------------------------------------------------------
-- User Story 3: the emphasis holds, and nothing else moved
-- ---------------------------------------------------------------------------

-- FR-017 / SC-011: the case a startup-only implementation fails while every
-- other case still passes. tokyonight's on_highlights runs during :colorscheme,
-- so the values must come back after leaving and returning.
local want_line_nr, want_selected = g 'LineNr', g 'BufferLineBufferSelected'
vim.cmd.colorscheme 'habamax'
check(
    g('LineNr').fg ~= want_line_nr.fg,
    'US3 habamax really does change LineNr (guard on this test)',
    hex(g('LineNr').fg),
    'a value other than ' .. hex(want_line_nr.fg)
)
vim.cmd.colorscheme 'tokyonight'
check(
    g('LineNr').fg == want_line_nr.fg,
    'US3 LineNr survives a colorscheme round trip',
    hex(g('LineNr').fg),
    hex(want_line_nr.fg)
)
check(
    g('BufferLineBufferSelected').fg == want_selected.fg and g('BufferLineBufferSelected').bg == want_selected.bg,
    'US3 BufferLineBufferSelected survives a colorscheme round trip',
    { fg = hex(g('BufferLineBufferSelected').fg), bg = hex(g('BufferLineBufferSelected').bg) },
    { fg = hex(want_selected.fg), bg = hex(want_selected.bg) }
)

-- FR-012: mode-scoped variants must not silently override the configured values.
-- These three are global highlight groups, so the headless claim is that no
-- variant shadows them. Entering insert, visual and command-line mode is not
-- reliably reachable from a headless one-shot (the mode never settles), so the
-- per-mode reading is verified across separate launches by T049's shell check,
-- and quickstart section 5.7 covers it interactively.
local MODE_GROUPS = { 'LineNr', 'CursorLineNr', 'BufferLineBufferSelected' }
for _, n in ipairs(MODE_GROUPS) do
    local base = g(n)
    for _, variant in ipairs { n .. 'Cursor', n .. 'Insert', n .. 'Visual', n .. 'Cmdline' } do
        local v = g(variant)
        check(v.fg == nil or v.fg == base.fg, 'US3 no ' .. variant .. ' variant shadows ' .. n, hex(v.fg), hex(base.fg))
    end
end

-- FR-015 / SC-009: the pre-feature values of the frozen concerns, asserted as
-- literals. A bare tokyonight load is the wrong reference here, because this
-- repository already overrides Comment for its own reasons; the contract froze
-- the values as they stood before this feature.
local FROZEN = {
    Normal = { fg = 0xc8d3f5, bg = 0x222436 },
    Comment = { fg = 0x9aa7cf },
    String = { fg = 0xc3e88d },
    SignColumn = { fg = 0x3b4261, bg = 0x222436 },
    StatusLine = { fg = 0x828bb8, bg = 0x1e2030 },
}
for _, n in ipairs { 'Normal', 'Comment', 'String', 'SignColumn', 'StatusLine' } do
    local h, w = g(n), FROZEN[n]
    check(
        h.fg == w.fg and h.bg == w.bg,
        'US3 frozen group ' .. n .. ' is unchanged',
        { fg = hex(h.fg), bg = hex(h.bg) },
        { fg = hex(w.fg), bg = hex(w.bg) }
    )
end

-- #101: the palette is tokyonight tokens, and every relation above would still
-- pass for the wrong hue. Pin the actual values so a palette regression is
-- caught here rather than by eye. CursorLineNr is frozen by contract section A
-- and is pinned deliberately: it is the one value that must never drift.
local PALETTE = {
    { group = 'LineNr', fg = '#737aa2' },
    { group = 'LineNrAbove', fg = '#737aa2' },
    { group = 'LineNrBelow', fg = '#737aa2' },
    { group = 'CursorLineNr', fg = '#ff966c' },
    { group = 'BufferLineBufferSelected', fg = '#c8d3f5', bg = '#2f334d' },
    { group = 'BufferLineBufferVisible', fg = '#828bb8', bg = '#191b29' },
    { group = 'BufferLineBuffer', fg = '#636da6', bg = '#191b29' },
    { group = 'BufferLineIndicatorSelected', fg = '#82aaff' },
}

for _, p in ipairs(PALETTE) do
    local h = g(p.group)
    check(hex(h.fg) == p.fg, 'palette ' .. p.group .. ' keeps its foreground', hex(h.fg), p.fg)
    if p.bg then
        check(hex(h.bg) == p.bg, 'palette ' .. p.group .. ' keeps its background', hex(h.bg), p.bg)
    end
end

-- The active tab must not share a value with the picker's cursor line any more:
-- they used to both be #2d3f76 and read as one layer.
check(
    g('BufferLineBufferSelected').bg ~= g('SnacksPickerListCursorLine').bg,
    'palette the active tab is decoupled from SnacksPickerListCursorLine',
    hex(g('BufferLineBufferSelected').bg),
    hex(g('SnacksPickerListCursorLine').bg)
)

-- FR-013 / FR-016: layout options must not have moved.
check(vim.o.relativenumber == true, 'US3 relativenumber is still on', vim.o.relativenumber, true)
check(vim.o.cursorline == true, 'US3 cursorline is still on', vim.o.cursorline, true)
check(vim.o.number == true, 'US3 number is still on', vim.o.number, true)

-- FR-014: the emphasis is global, not per-filetype.
local function emphasis_here()
    local h = g 'BufferLineBufferSelected'
    return h.fg == want_selected.fg and h.bg == want_selected.bg
end
check(emphasis_here(), 'US3 emphasis applies to the ordinary file buffer', emphasis_here(), true)

vim.cmd.enew()
vim.bo.buftype = 'nofile'
check(emphasis_here(), 'US3 emphasis applies to a nofile drawer', emphasis_here(), true)

local query = require 'config.db_query_buffer'
local qbuf = query.open('https://example.invalid/x', 'owner', { 'select 1;' }, 'testdb')
check(
    type(qbuf) == 'number' and vim.api.nvim_buf_is_valid(qbuf),
    'US3 opened a query-result buffer',
    qbuf,
    'a valid buffer number'
)
vim.api.nvim_set_current_buf(qbuf)
check(emphasis_here(), 'US3 emphasis applies to a query-result buffer', emphasis_here(), true)
