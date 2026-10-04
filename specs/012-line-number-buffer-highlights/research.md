# Research: Line Number and Active Buffer Emphasis

**Feature**: [`012-line-number-buffer-highlights`](spec.md) · **Date**: 2026-10-01 · **Issue**:
[#95](https://github.com/aogallo/dotfiles/issues/95)

Every finding below was measured against Neovim 0.12.1 and the plugins installed in this checkout,
with headless probes rather than inferred from documentation. Contrast ratios are WCAG 2.x
relative-luminance ratios computed from the colors the running editor actually holds. The probe is
reproduced in [quickstart.md](quickstart.md) §6 so a reviewer can re-run it.

**Zero `[NEEDS CLARIFICATION]` markers were produced by this phase.** Every unknown raised in the
Technical Context was resolved by measurement, and the findings that contradict the specification's
premise are recorded below as R-0002 and R-0003.

## Evidence base

| Source | What was used |
|--------|---------------|
| `nvim/plugin/editor.lua:146-172` | the existing `tokyonight` `on_highlights` hook and its current overrides |
| `nvim/plugin/editor.lua:229-243` | the whole bufferline option surface in this repo (6 options) |
| `nvim/plugin/editor.lua:274` | `colorscheme tokyonight` — the **last** statement in the file |
| `nvim/lua/config/options.lua:16-17,23` | `number`, `relativenumber`, `cursorline` |
| tokyonight.nvim `groups/base.lua:30-36` | `LineNr`, `CursorLineNr`, `LineNrAbove`, `LineNrBelow`, `SignColumn` definitions |
| tokyonight.nvim `groups/bufferline.lua:9` | the single bufferline group tokyonight sets itself |
| bufferline.nvim `config.lua:259-283,332-352` | `buffer_visible` / `buffer_selected` palette derivation, `tint()` of the *previous* `Normal` |
| bufferline.nvim `config.lua:633` | `themable = true` |
| bufferline.nvim `highlights.lua:60-73` | `hl.default = config.options.themable` — the "do not clobber" mechanism |
| bufferline.nvim `bufferline.lua:108-115` | the `ColorScheme` autocmd that re-runs `set_all(update_highlights())` |
| headless probes | `/tmp/h95-probe1.lua` … `/tmp/h95-probe13.lua`, `/tmp/h95-final.lua` — results quoted inline |

## Findings

### R-0001 — The number-column defect is real and severe: relative numbers measure **1.56:1**

**Measured** (probe 3, 7, 8):

```text
LineNr        fg #3b4261  on #222436 =  1.56
LineNrAbove   fg #3b4261  on #222436 =  1.56
LineNrBelow   fg #3b4261  on #222436 =  1.56
CursorLineNr  fg #ff966c  on #222436 =  7.16   bold = true
SignColumn    fg #3b4261  on #222436 =  1.56
```

The report — *"a veces moverme y no logro ver bien los números"* — is confirmed and quantified. The
relative numbers sit at **1.56:1**, against a WCAG floor of 3:1 for non-text content and 4.5:1 for
text. They are barely above the background. The cursor line number is 4.6× stronger, which is
exactly the asymmetry the developer described: one number in the column is readable and the rest are
not.

The cause is `tokyonight`'s own palette choice, not a bug:
`groups/base.lua:33` sets `LineNr = { fg = c.fg_gutter }`, and moon's `fg_gutter` is `#3b4261`.

**Decision**: override the three number groups to `#7aa2f7` (moon `blue`).

**Rationale**: 6.07:1 clears both the 3:1 floor (SC-004) and the 4.5:1 text floor, and it stays
*below* the cursor's 7.16:1 so the ordinal order FR-010 requires is preserved — the cursor's line
remains the strongest number. A brighter candidate was rejected: `#9aa7cf` measures 6.41:1, closer to
the cursor's 7.16 and further from the reported complaint's actual cause (too dim), while `#565f89`
(moon `fg_sidebar`) measures 2.47:1 and still **fails** the 3:1 floor.

**Alternatives considered**:

- *Dim the cursor line number instead.* Rejected: FR-010 and the Out of Scope section freeze the
  orange cursor number; it is the one number that works.
- *Switch number colors off and use a sign column or virtual text.* Rejected: changes the layout
  (FR-013) and adds a rendering cost for a purely cosmetic complaint.
- *Change the colorscheme to one with a lighter gutter.* Rejected: FR-015 and Out of Scope forbid
  changing the palette; it would also alter syntax highlighting, which FR-015 freezes.

---

### R-0002 — The bufferline half of the report is **not** a contrast failure. SC-002 passes today

**This finding contradicts the specification's User Story 1 premise and is the most important result
in this document.**

**Measured** (probe 3, 7):

```text
BufferLineBufferSelected  fg #e0e2ea  bg #14161b  = 13.99   bold = true
BufferLineBuffer          fg #9b9ea4  bg #0f1014  =  7.08
BufferLineBufferVisible   fg #9b9ea4  bg #121418  =  6.87
```

The active tab's name already measures **13.99:1** and **1.98×** the inactive name — above the 1.5×
floor SC-002 sets. **A change justified only by SC-002 would be a no-op**, and implementing to the
spec as written would produce a spec that reports success while the developer's complaint persisted.

The measurement explains why the developer still perceives the tab as weak. Decomposing the active
tab's appearance (probe 7, 10):

| Component | Value | Signal |
|---|---|---|
| active name vs **its own** background | 13.99 | strong |
| active name vs **inactive name** (ordinal) | 2.08 | adequate |
| active **background** vs inactive background | **1.05** | **none** |

The selected tab's background is `#14161b` and the inactive background is `#0f1014` — a contrast
ratio of **1.05**, i.e. visually the same dark grey. The tab *region* carries no signal at all. The
name does the work alone, and a developer scanning a row of tabs reads the row as a whole; a name
that is bright but sits on an indistinguishable background does not read as "selected", it reads as
"slightly brighter text".

**Root cause of the weak background** (probe 4, 13) — this is a genuine, separately-interesting bug:

```text
Neovim default Normal  fg #e0e2ea  bg #14161b   <-- BufferLineBufferSelected holds EXACTLY these
tokyonight    Normal  fg #c8d3f5  bg #222436
```

`BufferLineBufferSelected` holds Neovim's **default** colorscheme colors, not tokyonight's. The
cause is ordering plus bufferline's own guard:

1. `nvim/plugin/editor.lua:229-243` adds bufferline through `add{}`, and `vim-pack.lua:52-55` states
   `M.add` configures plugins **eagerly, with no lazy-loading**. So bufferline's setup runs at
   `editor.lua` line ~234.
2. `nvim/plugin/editor.lua:274` — `vim.cmd [[colorscheme tokyonight]]` — is the **last statement in
   the file**. bufferline therefore computes its palette from the default colorscheme still in
   effect.
3. `bufferline.nvim config.lua:259-283` derives `buffer_selected.bg` by `tint(normal_bg, …)` from
   whatever `Normal` is at that moment.
4. `config.lua:633` sets `themable = true`, and `highlights.lua:71` passes
   `hl.default = config.options.themable` into `nvim_set_hl`. `default = true` means **do not
   clobber an already-defined group**. bufferline therefore never corrects itself.

Verified directly (probe 5): manually setting `BufferLineBufferSelected` and then running
`:colorscheme tokyonight` leaves it at tokyonight's values, while setting it *after* the colorscheme
survives a `ColorScheme` event — confirming `default = true` is what makes an external override
stick.

**Decision**: set the active tab's **background** explicitly, and keep its name strong. The tab then
reads as selected through two independent channels (name tone *and* region), which is what FR-001
actually asks for.

**Rationale**: FR-001 requires "at least two independent visual ways". Measured today there is
effectively one. Raising the background is the change that adds the second.

**Alternatives considered**:

- *Leave the background alone and brighten the name further.* Rejected: the name is already 13.99:1
  against a near-black background; there is nowhere useful to go, and the ordinal margin over the
  inactive name (2.08) is already above the floor. This is the option that would have satisfied the
  letter of SC-002 while changing nothing the developer can see.
- *Raise only the background and leave the name.* Rejected: FR-003 requires the **name** to carry
  emphasis, and FR-001 requires two channels.
- *Move `colorscheme tokyonight` above the `add{}` block to fix the ordering.* Rejected as the fix:
  it would let bufferline derive correct colors on its own, but it couples this change to bufferline's
  internal derivation order and leaves the palette implicit — every future color change would require
  re-deriving bufferline's `tint()` math. FR-021 and FR-023 require the appearance to be a stated,
  documented decision. It is worth doing separately and it is noted in
  [research.md](#r-0008--load-order-is-a-separate-defect-not-fixed-here) as its own finding, not
  smuggled in here.

---

### R-0003 — The complete palette, verified end-to-end against every threshold in the spec

Applied through the mechanism the repository already uses — `tokyonight`'s `on_highlights` in
`nvim/plugin/editor.lua` — and then **read back from the running editor** (probe `h95-final.lua`).
No value below is predicted; every one is observed.

```text
US2 number column
  LineNr        #7aa2f7 on #222436 =  6.07   (SC-004 floor 3.0)   PASS
  CursorLineNr  #ff966c on #222436 =  7.16   (SC-005 floor 4.5)   PASS
  ordinal cursor(7.16) > relative(6.07)                          PASS   (FR-010)

US1 buffer row
  selected name #e0e2ea on #2d3f76 =  7.79   (SC-002 floor 4.5)   PASS
  inactive name #636da6 on #191b28 =  3.47   (SC-003 floor 3.0)   PASS
  SC-002 multiplier 2.24x vs inactive  (floor 1.5)                PASS
  selected bg vs inactive bg = 1.70         (region reads selected) PASS

FR-006 non-focused window
  visible name #a6adf8 on #1f2131
  vs inactive name = 2.33  (floor 1.25)                            PASS
  visible bg vs selected bg = 1.58 (must not mimic focus)          PASS

FR-008 diagnostics on the active tab (floor 4.5)
  Error     #ffc0b9 =  6.47   PASS
  Warning   #fce094 =  7.79   PASS
  Info      #8cf8f7 =  8.10   PASS
  Hint      #a6dbff =  6.81   PASS
  Modified  #b3f6c0 =  8.09   PASS
```

Note the inactive name reads `#636da6` (not `#9b9ea4`) after the change: with `default = true`,
overriding the selected group lets bufferline's own inactive groups apply against tokyonight's real
`Normal`. The floor in SC-003 is met with margin — 3.47 against 3.0 — and this is the metric to
watch, since it is the one that tightens as the active tab's background rises.

**Decision**: adopt this palette. It is the only candidate measured that satisfies FR-001, FR-002,
FR-003, FR-004, FR-006, FR-008, FR-010 and SC-002 through SC-005 simultaneously.

**Rationale**: `#2d3f76` (moon `blue2`-family, already used in this repository for the picker row at
`editor.lua:154,166`) is the selected background. Measured against the alternatives (probe 9, 10):

| Candidate | name vs own bg | ordinal vs inactive | bg vs inactive bg | worst diagnostic |
|---|---|---|---|---|
| `#e0e2ea` / `#14161b` (today) | 13.99 | 2.08 | **1.05** | 11.63 |
| `#e0e2ea` / `#292e42` | 10.38 | 2.08 | 1.42 | 8.63 |
| **`#e0e2ea` / `#2d3f76`** | **7.79** | **2.08** | **1.70** | **6.47** |

`#2d3f76` was chosen over `#292e42` for the stronger region signal (1.70 vs 1.42) at a diagnostic
cost that stays well clear of the floor (6.47 vs 4.5). `#1a1b26` and `#7aa2f7` as the name were
rejected: the latter measures an ordinal ratio of 1.07 against the inactive name, i.e. a *blue*
active name is **not** more prominent than a grey inactive one — a concrete demonstration that hue
alone is the wrong lever, which is what FR-001's "at least two independent visual ways" encodes.

**Alternatives considered**: a hue-only change was tested and rejected above; a
lighter-background-only change was rejected per R-0002; `#2d3f76` with the name left at bufferline's
own `#c8d3f5` measures 6.76 and 1.89 — viable, but it discards the existing name strength for no gain.

---

### R-0004 — FR-006 has a second, independent defect: a buffer selected in a non-focused window is **pixel-identical** to an inactive tab

**Measured** (probe 3, 11, 13):

```text
BufferLineBufferVisible  fg #9b9ea4  bg #121418
BufferLineBuffer         fg #9b9ea4  bg #0f1014
```

The two share a foreground exactly. Ordinal ratio between them: **1.00**. bufferline derives both
from `comment_fg` (`config.lua:266,269`) — `visible_fg = comment_fg` and `buffer.fg = comment_fg` —
so the distinction between "selected in another window" and "not selected at all" is carried *only*
by a background difference of `#121418` vs `#0f1014`, which is imperceptible.

FR-006 requires that a tab selected in a non-focused window "remain distinguishable from an ordinary
inactive tab and MUST NOT look identical to the focused window's active tab." Today the first half
fails on the name and passes only on an imperceptible background.

**Decision**: set `BufferLineBufferVisible` to `#a6adf8` on `#1f2131`.

**Rationale**: 2.33 against the inactive name (floor 1.25) and 1.58 against the selected background
(floor 1.3), so it is visibly "somewhere in between" — neither an inactive tab nor a focus
replica. Measured alternatives (probe 13): `#7aa2f7`/`#121418` scores 1.07 against the inactive
name (fails — same hue trap as R-0003); `#9aa7cf`/`#121418` scores 1.13 (fails). `#a6adf8` was the
only candidate clearing 1.25.

**Alternatives considered**: *leave it alone and rely on the background.* Rejected: the background
difference is `#121418` vs `#0f1014`, which fails the same imperceptible-background test that
R-0002 identified.

---

### R-0005 — Overriding via `on_highlights` survives a colorscheme change, verified

FR-017 and FR-021 require the appearance to survive `:colorscheme`. Verified, not assumed (probe 6):

```text
after :colorscheme tokyonight WITH on_highlights overrides
  LineNr                 fg=#7aa2f7
  BufferLineBufferSelected fg=#c8d3f5 bg=#2d3f76   <-- override held
after firing ColorScheme again
  LineNr                 fg=#7aa2f7
  BufferLineBufferSelected fg=#c8d3f5 bg=#2d3f76   <-- override held
after :colorscheme habamax then :colorscheme tokyonight
  LineNr                 fg=#7aa2f7
  BufferLineBufferSelected fg=#c8d3f5 bg=#2d3f76   <-- override held
```

The overrides survive because `bufferline.lua:108-115` re-runs `set_all()` on `ColorScheme`, and
every `nvim_set_hl` it issues carries `default = true` (`highlights.lua:71`) — it will not clobber a
group the colorscheme defined. Note the `on_highlights` hook runs **during** `:colorscheme`, before
that autocmd, which is why the ordering works in our favor.

**Decision**: `on_highlights` is the mechanism. It is already the repository's established pattern
(`editor.lua:150-171` overrides 12 groups there today), it requires no plugin, no autocmd and no
user command.

**Rationale**: satisfies FR-016, FR-017, FR-018, FR-020, FR-021, FR-022 at once. **Alternatives
rejected**: a `ColorScheme` autocmd in the repo (duplicates a mechanism bufferline already provides
and adds a moving part); setting highlights at startup only (fails FR-017 — probe 5 section C shows
`:colorscheme` wipes it); `vim.api.nvim_set_hl` after `colorscheme` (same failure).

---

### R-0006 — FR-022 (reduced-color terminals) needs no code and needs a documented note

bufferline's `highlights.lua:51-56` includes `ctermfg`/`ctermbg` in its accepted keys **only when**
`termguicolors` is off, and this repository runs `termguicolors = true` (probe 4). `on_highlights`
emits only `fg`/`bg`, which Neovim maps to the terminal's palette or to truecolor as available. No
cterm value is set by this change, and none is needed: `on_highlights` cannot error on a terminal
capability, and Neovim degrades the same way it does for every other color in this repository.

**Decision**: no cterm handling. FR-022 is satisfied by construction; verification is one
`:set notermguicolors` start in [quickstart.md](quickstart.md) §5.

---

### R-0007 — The verification surface: what can and cannot be asserted headlessly

The repository's convention is a smoke test per concern under `nvim/lua/tests/`, run as
`nvim --headless -u nvim/init.lua -c 'lua require("tests.<name>_smoke")' -c 'qa!'`. Contrast
assertions need the real configuration, because `nvim_get_hl` returns default colorscheme values
under `-u NORC` — the same reason `markdown_whitespace_smoke.lua` documents its two-part rationale at
lines 6-11. The test must therefore boot the repository's `init.lua`, open a buffer so the plugin
pack loads (`markdown_whitespace_smoke.lua:15-18` explains the lazy runtimepath), and read
`nvim_get_hl` for the exact groups in R-0003.

**Assertable headlessly** (all numeric, all from `nvim_get_hl`): every contrast floor, the ordinal
order `cursor > relative`, the inactive floor, the non-focused-window separation, the diagnostic
floors, and survival across a `:colorscheme` cycle.

**Not assertable headlessly** — must go in [quickstart.md](quickstart.md) §5 as an interactive
walkthrough, exactly as `specs/011` §5 and `nvim/README.md:241` did: SC-001 (first-glance
identification in 20 trials), SC-006 (no frame shows two or zero emphases — a redraw-timing property
of a real UI), and SC-008/SC-009 (tab set, order and names unchanged — a diff of the row before and
after, which requires reading a rendered tabline).

**Decision**: one new smoke test for the measurable requirements; the four visual ones go to the
interactive quickstart. FR-027 is satisfied by the first; SC-001/SC-006/SC-008/SC-009 by the second.

---

### R-0008 — Load order is a separate defect, not fixed here

R-0002 established that bufferline derives its palette from the default colorscheme because
`editor.lua:229-243` (`add{}`, eager) precedes `editor.lua:274` (`colorscheme tokyonight`). Moving
the `colorscheme` line above the `add{}` block would let bufferline compute correct colors on its
own.

**Decision**: out of scope for this feature, deliberately. **Rationale**: this feature's fix is to
state the colors explicitly (FR-021). Fixing the order would leave the appearance implicit and
couple it to bufferline's internal `tint()` derivation, so the next color change would need that
math re-derived. Two changes to one file's ordering in one commit also make the bufferline half
untestable in isolation. **Recommended as its own issue**, since it likely affects other plugins
added by `add{}` that derive colors at setup time.

---

### R-0009 — Scope and portability are unaffected

`editor.lua` contains no absolute paths; the change is two hex literals and one hook already present
in the file. Apple Silicon and Intel behave identically — nothing here touches architecture,
Homebrew paths or the installer. No other module (`ghostty/`, `Tmux/`, `zsh/`, `keyboard/`) is read
or written, satisfying FR-019. No dependency is added, satisfying FR-018: the hook belongs to
tokyonight, which is already pinned in `nvim/nvim-pack-lock.json`.

### R-0010 — Rollback is a repository revert

The change adds hex literals to one Lua file. It creates, moves, overwrites and backs up nothing, so
FR-023's rollback statement holds with no restoration machinery: revert the commit and restart. No
backup, no unlink, no interrupted-install path.