# Quickstart: Line Number and Active Buffer Emphasis

**Feature**: [`012-line-number-buffer-highlights`](spec.md) · **Date**: 2026-10-01 · **Issue**:
[#95](https://github.com/aogallo/dotfiles/issues/95)

A validation runbook. It does not contain implementation code — the overrides belong in
`nvim/plugin/editor.lua` and are specified in
[contracts/highlight-contract.md](contracts/highlight-contract.md); the tasks belong in `tasks.md`.

**Prerequisites**: macOS, Neovim 0.12.1 (`nvim --version`), this repository checked out, and the
plugin pack installed. Run everything from the repository root.

**Contents**:

- [§1 — what this change should look like](#1--what-this-change-should-look-like) — the expected visual result
- [§2 — automated validation](#2--automated-validation) — the commands that gate completion
- [§3 — what the numbers should be, before and after](#3--what-the-numbers-should-be-before-and-after)
- [§4 — quick reference: measuring one group](#4--quick-reference-measuring-one-group)
- [§5 — interactive walkthrough](#5--interactive-walkthrough) — the six criteria a headless run cannot assert
- [§6 — the contrast probe](#6--the-contrast-probe) — the measurement script, re-runnable
- [§7 — the smoke test](#7--the-smoke-test) — what it asserts and how to run it
- [§8 — full validation suite](#8--full-validation-suite) — every command, in order
- [§9 — rollback](#9--rollback)

---

## 1. What this change should look like

**The number column.** Relative line numbers change from near-invisible to clearly readable. Today
they measure 1.56:1 against the background — measurably closer to the background than to any
legibility threshold. After the change they measure 3.67:1. The cursor's own line number stays
orange and stays the strongest number in the column.

**The buffer row.** The active buffer's name stays bright, and its **tab now has a visible
background**. This is the substantive part: today the active tab's background differs from an
inactive tab's by 1.05:1 — visually the same dark grey — so the tab region carries no signal and the
name works alone. After the change the background separates by 1.70:1, so the tab reads as selected
through two independent channels (name tone *and* region), which is what makes it scannable across a
row of tabs. See [research.md](research.md) R-0002 for why this, and why brightening the name
further would have changed nothing visible.

**A buffer displayed in a non-focused window** gets its own intermediate treatment, so it is neither
an inactive tab nor a focus replica. Today its name is *pixel-identical* to an inactive tab's.

**Nothing else moves.** No syntax colors, no tab names, no tab order, no column widths.

---

## 2. Automated validation

The commands that gate completion, in order. Every one must pass with exit 0.

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'
```

Then the pre-existing suite — **all** of it must still be green, because the change touches a file
every plugin is configured from (§8 lists the full set).

`stylua --check` matters here specifically: the hook is a formatted Lua table inside a Lua file, and
stylua is the repository's formatter.

---

## 3. What the numbers should be, before and after

Measured, not predicted ([research.md](research.md) R-0003). "Before" was read from the unmodified
configuration; "after" was read back after applying the change.

### Number column

| Group | Before | After | Floor |
|---|---|---|---|
| `LineNr` (relative) | **1.56:1** | **3.67:1** | 3.0 |
| `LineNrAbove` | **1.56:1** | **3.67:1** | 3.0 |
| `LineNrBelow` | **1.56:1** | **3.67:1** | 3.0 |
| `CursorLineNr` | 7.16:1 | 7.16:1 *(unchanged)* | 4.5 |

Ordinal check: the cursor's number (7.16) must stay stronger than the relative ones (3.67). It does.

### Buffer row

| Measure | Before | After | Floor |
|---|---|---|---|
| active name vs its own background | 13.99:1 | 8.28:1 | 4.5 |
| active name as a multiple of inactive | 1.98× | 3.30× | 1.5× |
| **active background vs inactive background** | **1.05** | **1.38** | 1.3 |
| inactive name vs its own background | 3.47:1 | 3.47:1 | 3.0 |
| non-focused name vs inactive name | **1.00** | **1.48** | 1.25 |
| non-focused background vs active background | **1.02** | 1.38 | 1.3 |

Note the two "before" values in bold. Those are the defects. The active name's own contrast and the
1.98× multiplier were **already passing** — that is why the original design changed the background
rather than the name ([research.md](research.md) R-0002). Both are now explicit tokyonight tokens
(`c.fg` on `c.bg_highlight`), tuned down at the developer's request ([research.md](research.md) R-0009).

### Diagnostic overlays on the active tab

| Group | After | Floor |
|---|---|---|
| `BufferLineErrorSelected` | 4.76:1 | 4.5 |
| `BufferLineWarningSelected` | 5.78:1 | 4.5 |
| `BufferLineInfoSelected` | 5.25:1 | 4.5 |
| `BufferLineHintSelected` | 8.14:1 | 4.5 |
| `BufferLineModifiedSelected` | 8.96:1 | 4.5 |
| `BufferLineCloseButtonSelected` | 8.28:1 | 4.5 |

### The one to watch

`BufferLineBuffer` (inactive name) sits at **3.47:1 against a 3.0 floor**. It is unaffected by this
change, but it is the invariant that **tightens** if anyone later raises the active background
further. Re-check it on any such change — see the change protocol in
[contracts/highlight-contract.md](contracts/highlight-contract.md).

---

## 4. Quick reference: measuring one group

To read any highlight group directly, with the repository's configuration loaded:

```sh
nvim --headless -u nvim/init.lua \
  -c 'lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "LineNr" })))' \
  -c 'qa!'
```

`-u nvim/init.lua` is required. Under `-u NORC` the groups report default-colorscheme values and the
measurement is meaningless — the same reason `markdown_whitespace_smoke.lua` documents at lines
6-11.

---

## 5. Interactive walkthrough

Six criteria cannot be asserted headlessly, because they are properties of a rendered UI and of a
redraw sequence rather than of a color value
([research.md](research.md) R-0007). Follow the precedent of `specs/011` §5 and `nvim/README.md:241`:
this walkthrough is handed to the developer's own session.

**§5.1–§5.3, §5.6 and §5.7 are manual-only.** §5.4 (reduced-color) and §5.5 (colorscheme
survival) are *also* automated — T030 and T025 in [tasks.md](tasks.md) assert them headlessly — so
those two are the manual confirmation of an already-passing check, not additional gates.

### 5.1 — SC-001: first-glance identification (20 trials)

1. Start Neovim from this repository.
2. Open 8 or more buffers with visibly different names (`:badd`-free: just `:edit` eight distinct
   files, or open eight existing files in the repository).
3. **Without reading the names**, look at the buffer row and name the active buffer.
4. Move to another buffer (`:bnext` or `<S-h>`) and repeat.
5. Repeat to 20 trials.

**Pass**: 20 of 20 correct on first glance. **Fail**: any trial needing a second look to tell which
tab is active.

### 5.2 — SC-006: the emphasis moves with the cursor, in one frame

1. With several buffers open, move the cursor between buffers rapidly.
2. Watch the buffer row while moving.

**Pass**: at no point are two tabs carrying the full emphasis, and at no point are none. The
emphasis tracks the content in the same update.

**Why this is manual**: it is a redraw-timing property. A headless run has no frame to inspect.

### 5.3 — SC-008 / SC-009: nothing else changed

1. Before applying the change, record the rendered buffer row for a fixed set of buffers: which tabs
   exist, their order, their names, and their change/problem indicators.
2. Apply the change, restart, reproduce the same buffer set.
3. Compare.

**Pass**: identical tab set, order, names and markers. **Also confirm** `Normal`, a comment, a
string, a warning and the status line look exactly as before — FR-015.

### 5.4 — FR-022: a reduced-color terminal

```sh
nvim --headless -u nvim/init.lua --cmd 'set notermguicolors' '+quitall'
```

**Pass**: exits 0, no error. Colors fall back to whatever the terminal supports
([research.md](research.md) R-006). No `cterm` value is set by this change and none is needed.

### 5.5 — FR-017: survival across a colorscheme change

```sh
nvim -u nvim/init.lua
```

then at the prompt:

```vim
:colorscheme habamax
:colorscheme tokyonight
:lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "LineNr" })))
:lua print(vim.inspect(vim.api.nvim_get_hl(0, { name = "BufferLineBufferSelected" })))
```

**Pass**: after switching away and back, both groups hold the configured values
(`#737aa2`, and `#c8d3f5` on `#2f334d`) — not a default colorscheme's values. This is FR-017 and is
the check most likely to catch a mechanism mistake, because a startup-only override passes §3 and
fails here ([research.md](research.md) R-0005).

### 5.6 — SC-007 / FR-006: the emphasis follows the focused window

1. Open two or more windows: `:split` twice, then open a **different** buffer in each.
2. Move focus between windows with `<C-w>w`, ten times.
3. At each stop, look at both buffer rows.

**Pass**: the strongest tab always belongs to the window that has focus — 10 of 10. And a buffer
that is selected in the *other* window is still visibly different from an ordinary inactive tab —
10 of 10, by name tone and by background.

**Why this is separate from §5.2**: §5.2 tests that the emphasis moves when the *cursor* moves
between buffers. This tests that it moves when *window focus* moves, which is a different state
transition, and that the three tab states stay mutually distinguishable — the property FR-006
requires and the one `BufferLineBufferVisible` exists to satisfy.

### 5.7 — FR-012: the column is legible in every mode

1. Open a file of a few hundred lines so the column is full.
2. Walk the modes in order: `Esc` (normal), `i` (insert), `v` (visual), `:` (command-line), `Esc`.
3. At each stop, read the numbers without adjusting anything.

**Pass**: every number is legible in all four modes, and the cursor's line is the same
distinguishable one in each — it does not fade, invert or lose meaning when the mode changes.

**Why this needs its own step**: `CursorLineNr` is the one group whose rendering can differ by
mode, and FR-012 forbids the cursor's number from changing meaning between modes. A headless
assertion (T049 in [tasks.md](tasks.md)) proves the *color* is stable; only the rendered check
proves the *reading* is.

---

## 6. The contrast probe

The measurement script used to produce every number in this feature
([research.md](research.md) R-0001 through R-0004). Re-runnable as-is.

Save as `/tmp/h95-contrast-probe.lua`, then:

```sh
nvim --headless -u nvim/init.lua -c 'luafile /tmp/h95-contrast-probe.lua' -c 'qa!'
```

```lua
-- /tmp/h95-contrast-probe.lua
-- Reads highlight groups from the running editor and prints contrast ratios.
-- Read-only: sets no highlight group, writes nothing.
local function lin(c)
    c = c / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function lum(rgb)
    return 0.2126 * lin(math.floor(rgb / 65536) % 256)
        + 0.7152 * lin(math.floor(rgb / 256) % 256)
        + 0.0722 * lin(rgb % 256)
end

local function cr(a, b)
    local la, lb = lum(a), lum(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

local function hex(c) return c and string.format('#%06x', c) or 'nil' end
local function g(n) return vim.api.nvim_get_hl(0, { name = n, link = false }) end

-- Sanity-check the ratio implementation against two known WCAG pairs before trusting it.
print(string.format('sanity: #000000 on #ffffff = %.2f (expect 21.00)', cr(0x000000, 0xffffff)))
print(string.format('sanity: #777777 on #ffffff = %.2f (expect 4.48)', cr(0x777777, 0xffffff)))

local N = g('Normal').bg
local sel, vis, ina = g('BufferLineBufferSelected'), g('BufferLineBufferVisible'), g('BufferLineBuffer')

print('\n-- number column (floors: relative 3.0, cursor 4.5) --')
for _, n in ipairs({ 'LineNr', 'LineNrAbove', 'LineNrBelow', 'CursorLineNr' }) do
    local h = g(n)
    print(string.format('  %-14s %s on %s = %6.2f  bold=%s', n, hex(h.fg), hex(N), cr(h.fg, N), tostring(h.bold)))
end
print(string.format('  ordinal: cursor %.2f > relative %.2f -> %s',
    cr(g('CursorLineNr').fg, N), cr(g('LineNr').fg, N),
    cr(g('CursorLineNr').fg, N) > cr(g('LineNr').fg, N) and 'PASS' or 'FAIL'))

print('\n-- buffer row (floors: active 4.5, inactive 3.0, region 1.3, non-focused 1.25) --')
print(string.format('  active    %s on %s = %6.2f  (>= 4.5)', hex(sel.fg), hex(sel.bg), cr(sel.fg, sel.bg)))
print(string.format('  inactive  %s on %s = %6.2f  (>= 3.0)', hex(ina.fg), hex(ina.bg), cr(ina.fg, ina.bg)))
print(string.format('  multiplier              %6.2fx (>= 1.5x)', cr(sel.fg, sel.bg) / cr(ina.fg, ina.bg)))
print(string.format('  region  active bg vs inactive bg = %5.2f  (>= 1.3)', cr(sel.bg, ina.bg)))
print(string.format('  non-focus name vs inactive name  = %5.2f  (>= 1.25)', cr(vis.fg, ina.fg)))
print(string.format('  non-focus bg vs active bg        = %5.2f  (>= 1.3)', cr(vis.bg, sel.bg)))

print('\n-- diagnostics on the active tab (floor 4.5; bold marks severity only) --')
for _, d in ipairs({ 'Error', 'Warning', 'Info', 'Hint', 'Modified' }) do
    local h = g('BufferLine' .. d .. 'Selected')
    print(string.format('  %-9s %s on %s = %6.2f  bold=%-5s %s',
        d, hex(h.fg), hex(h.bg), cr(h.fg, h.bg), tostring(h.bold),
        cr(h.fg, h.bg) >= 4.5 and 'PASS' or 'FAIL'))
end

print('\n-- active-tab furniture resolved in T004 --')
-- These two are unset until this feature lands, so every read must survive a nil. A measurement
-- tool that crashes is worse than one that reports FAIL: it hides the value it was built to expose.
-- The two are checked independently: bufferline never sets a background on the indicator, and
-- gating the separator on that would misreport it as failing.
local sep, ind = g('BufferLineSeparatorSelected'), g('BufferLineIndicatorSelected')
if sep.fg and sep.bg then
    local s = cr(sep.fg, sep.bg)
    print(string.format('  separator  %s on %s = %6.2f  bold=%-5s %s', hex(sep.fg), hex(sep.bg),
        s, tostring(sep.bold),
        (sep.fg == sep.bg and s == 1.0) and 'PASS (vanishes)' or 'FAIL'))
else
    print(string.format('  separator  fg=%s bg=%s   FAIL (expected fg == bg == selected bg)', hex(sep.fg), hex(sep.bg)))
end
if ind.fg then
    -- The indicator inherits its background from the selected tab, so measure it there.
    local iv, nv = cr(ind.fg, sel.bg), cr(sel.fg, sel.bg)
    print(string.format('  indicator  %s on %s = %6.2f  (>= 3.0, and < name %.2f)  %s',
        hex(ind.fg), hex(sel.bg), iv, nv,
        (iv >= 3.0 and iv < nv) and 'PASS' or 'FAIL'))
else
    print(string.format('  indicator  fg=%s   FAIL (expected fg #82aaff)', hex(ind.fg)))
end

print('\n-- frozen by FR-015: these must be untouched --')
for _, n in ipairs({ 'Normal', 'Comment', 'String', 'StatusLine', 'WinSeparator', 'BufferLineFill' }) do
    local h = g(n)
    print(string.format('  %-16s fg=%s bg=%s', n, hex(h.fg), hex(h.bg)))
end
```

**Expected output after the change** matches §3 exactly. If a number disagrees with §3, stop and
re-read [research.md](research.md) R-0002 and R-0003 before proceeding.

---

## 7. The smoke test

One new file: `nvim/lua/tests/highlight_emphasis_smoke.lua`.

**What it asserts** (FR-027) — everything measurable headlessly:

- `LineNr`, `LineNrAbove`, `LineNrBelow` ≥ 3.0 against `Normal`'s background;
- `CursorLineNr` ≥ 4.5, and strictly greater than `LineNr`;
- `BufferLineBufferSelected` ≥ 4.5 against its own background;
- that value ≥ 1.5 × `BufferLineBuffer`'s own contrast;
- `BufferLineBufferSelected`'s background vs `BufferLineBuffer`'s ≥ 1.3;
- `BufferLineBuffer` ≥ 3.0;
- `BufferLineBufferVisible` name vs inactive name ≥ 1.25, and its background vs the selected
  background ≥ 1.3;
- each of the five diagnostic overlays ≥ 4.5 against the selected background;
- `Normal`, `Comment`, `String` unchanged from what the unmodified colorscheme produces — the FR-015
  guard;
- the overrides **survive** `:colorscheme` away and back — the FR-017 guard, which is the check a
  startup-only implementation would fail.

It **fails** (exit 1 via `:cquit`) on any violation, so a later change that removes the emphasis
breaks the build rather than degrading silently.

**How to run**:

```sh
nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'
```

`-u nvim/init.lua` is mandatory, for the reason in §4. Following the pattern at
`markdown_whitespace_smoke.lua:15-18`, the test opens a buffer first so the plugin pack is on the
runtimepath before it reads any highlight group.

**What it deliberately does not assert**: SC-001, SC-006, SC-007, SC-008, SC-009 and FR-012 — the six
criteria in §5.1, §5.2, §5.3, §5.6 and §5.7. They need a rendered UI.

---

## 8. Full validation suite

Every command, in order. All must exit 0.

```sh
# formatting and a clean start
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'

# this feature
nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'

# pre-existing suite — must remain green
nvim --headless -u NORC -c 'lua require("tests.buffer_visibility_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.formatter_chains_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'

# interactive, per §5
```

The `-u NORC` versus `-u nvim/init.lua` split is the repository's existing convention and is
documented per test in `nvim/README.md`; do not normalize it.

---

## 9. Rollback

An ordinary repository revert ([research.md](research.md) R-0010):

```sh
git revert <commit>
```

Then restart Neovim. The change adds color literals to one Lua file — it creates, moves, overwrites
and backs up nothing, so there is no backup to restore, no link to remove and no interrupted-install
path to recover from.

**Related reading**: [research.md](research.md) R-0008 records a *separate* load-order defect found
while measuring this feature (the buffer-row plugin derives its palette before the colorscheme is
applied). It is deliberately **not** fixed here and needs its own issue.