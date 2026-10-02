# Contract: Highlight Group Contract

**Feature**: [`012-line-number-buffer-highlights`](spec.md) · **Date**: 2026-10-01
**Type**: editor highlight-group contract
**Owner**: `nvim/plugin/editor.lua`

This is the interface between this repository and the two plugins that draw the editor chrome
involved: the colorscheme and the buffer-row plugin. It states the exact highlight groups this
feature owns, the values each must hold, the mechanism that applies them, and the invariants a future
change must preserve.

The contract is deliberately written as **values and invariants**, not as code. The implementation
lives in `tasks.md`; this document is what a reviewer checks the implementation against, and what the
next maintainer reads before changing a color.

## Mechanism

**Single source of truth**: the `on_highlights` hook of the `tokyonight` entry in
`nvim/plugin/editor.lua` (the hook already occupies lines 150-171 and holds twelve overrides today).

**Why this mechanism** ([research.md](../research.md) R-0005, verified):

- `on_highlights` runs **during** `:colorscheme`, before the buffer-row plugin's own `ColorScheme`
  autocmd;
- that plugin re-applies its highlights on `ColorScheme` with `default = true`, meaning **do not
  clobber an already-defined group** — so a group the colorscheme defined is left alone;
- therefore the override survives `:colorscheme`, survives the plugin re-applying, and survives
  switching away and back.

Verified three ways in probe 6 and probe `h95-final.lua`. The rejected alternatives and why they
fail are in [research.md](../research.md) R-0005.

**Constraints on the mechanism**:

| Rule | Requirement | Why |
|---|---|---|
| No new dependency | FR-018 | The hook belongs to a plugin already pinned in `nvim/nvim-pack-lock.json`. |
| No autocmd, no user command, no keymap | FR-016 | The appearance is a standing default, not a mode. |
| No second place | FR-005, FR-021 | Values must be stated once, explicitly — not derived from another plugin's internal tint math ([research.md](../research.md) R-0008). |
| Values must be literals | FR-021 | A future maintainer must be able to tell an intentional override from an accident. |
| Survive `:colorscheme` | FR-017 | Verified, not assumed. |
| Degrade on reduced-color terminals | FR-022 | Only `fg`/`bg` are emitted, so Neovim maps them to whatever the terminal supports ([research.md](../research.md) R-0006). |

## Group contract

Values verified read-back from a running editor after application
([research.md](../research.md) R-0003). Ratios are contrast against the stated background.

### A. Number column (User Story 2)

| Group | Foreground | Background | Contrast | Floor | Requirement |
|---|---|---|---|---|---|
| `LineNr` | `#7aa2f7` | `Normal` `#222436` | 6.07:1 | 3.0 | SC-004 |
| `LineNrAbove` | `#7aa2f7` | `Normal` `#222436` | 6.07:1 | 3.0 | SC-004 |
| `LineNrBelow` | `#7aa2f7` | `Normal` `#222436` | 6.07:1 | 3.0 | SC-004 |
| `CursorLineNr` | *unchanged* `#ff966c`, bold | `Normal` `#222436` | 7.16:1 | 4.5 | SC-005, Out of Scope |

**Invariants**:

- `contrast(CursorLineNr) > contrast(LineNr)` — FR-010. 7.16 > 6.07. **The ordinal order must
  never invert.**
- `contrast(LineNr) ≥ 3.0` — SC-004. Baseline was **1.56** (the reported defect).
- `CursorLineNr` MUST NOT be recolored — Out of Scope; it is the one number the developer can
  already read.
- All three relative groups MUST hold the same value — they are the same visual role, and a split
  would make the column look inconsistent when the cursor crosses the wrap point.

**Not in this contract**: column width, alignment, and the cursor line number's separate column
position — frozen by FR-013, untouched by design.

### B. Buffer row (User Story 1)

| Group | Foreground | Background | Contrast | Role |
|---|---|---|---|---|
| `BufferLineBufferSelected` | `#e0e2ea`, bold | `#2d3f76` | 7.79:1 | the focused buffer — **owns the emphasis** |
| `BufferLineBufferVisible` | `#a6adf8` | `#1f2131` | 7.54:1 | selected in a **non-focused** window |
| `BufferLineBuffer` | *unchanged* | *unchanged* | 3.47:1 | inactive |
| `BufferLineSeparatorSelected` | `#2d3f76` | `#2d3f76` | 1.00:1 | segment divider inside the active tab — **blends away** |
| `BufferLineIndicatorSelected` | `#7aa2f7` | `#2d3f76` | 4.00:1 | the selected tab's left indicator |

**Invariants**:

- `contrast(BufferLineBufferSelected) ≥ 4.5` — SC-002.
- `contrast(BufferLineBufferSelected) ≥ 1.5 × contrast(BufferLineBuffer)` — SC-002 second clause.
  Measured **2.24×**.
- `contrast(BufferLineBufferSelected.bg, BufferLineBuffer.bg) ≥ 1.3` — derived; FR-001's second
  visual channel. Baseline was **1.05**, the actual defect ([research.md](../research.md) R-0002).
- `contrast(BufferLineBuffer) ≥ 3.0` — SC-003. Measured 3.47. **This is the invariant that tightens
  if the active background is ever raised further** — re-check it on any future change to
  `BufferLineBufferSelected.bg`.
- `contrast(BufferLineBufferVisible, BufferLineBuffer) ≥ 1.25` and
  `contrast(BufferLineBufferVisible.bg, BufferLineBufferSelected.bg) ≥ 1.3` — FR-006.
  Baselines were **1.00** and imperceptible ([research.md](../research.md) R-0004); targets 2.33
  and 1.58.
- **`BufferLineSeparatorSelected`**: `fg == bg == BufferLineBufferSelected.bg`, so its contrast
  against its own background is **exactly 1.00**. The separator divides segments *within* one tab
  (a path, a name, a close icon), so on the active tab it must not draw an edge inside the block
  that is supposed to read as solid. Baseline `BufferLineSeparator` measured 1.08:1 against the
  inactive background; here the requirement is not merely "stay low" but "vanish". Adding a
  separator override would be worse than omitting it, which is why it is in this contract at all.
- **`BufferLineIndicatorSelected`**: `contrast ≥ 3.0` — measured **4.00**. It is a 1–2px marker,
  not text, so it is deliberately **not** held to the 4.5 text floor; 4.5 is unreachable for this
  blue on `#2d3f76` without pushing the hue brighter than the buffer name itself (7.79), which would
  invert the row's reading order. Two constraints therefore bound it: stay `≥ 3.0` so it remains
  visible against the tint it marks, and stay **below `BufferLineBufferSelected`** so it points at
  the name instead of competing with it.

**Why the name is unchanged and only the background moves**: the name already measures 13.99:1 and
1.98× the inactive name — above both SC-002 clauses. Raising it further would be invisible against
a near-black background, while the background is what carries no signal at all (1.05). FR-003 is
satisfied because the name remains the strongest element in the row and the background is the
*second* channel, not a replacement.

### C. Diagnostic overlays on the active tab (FR-008)

Each must be restated against the new selected background, or it inherits a background it was not
chosen for.

| Group | Foreground | Background | Contrast | Floor |
|---|---|---|---|---|
| `BufferLineErrorSelected` | `#ffc0b9`, bold | `#2d3f76` | 6.47:1 | 4.5 |
| `BufferLineWarningSelected` | `#fce094`, bold | `#2d3f76` | 7.79:1 | 4.5 |
| `BufferLineInfoSelected` | `#8cf8f7`, bold | `#2d3f76` | 8.10:1 | 4.5 |
| `BufferLineHintSelected` | `#a6dbff`, bold | `#2d3f76` | 6.81:1 | 4.5 |
| `BufferLineModifiedSelected` | `#b3f6c0` | `#2d3f76` | 8.09:1 | 4.5 |
| `BufferLineCloseButtonSelected` | `#e0e2ea` | `#2d3f76` | 7.79:1 | 4.5 |

**Bold rule**: bold marks the four diagnostic **severities** only — `Error`, `Warning`, `Info`,
`Hint`. `Modified` and `CloseButton` are **state markers, not severities**, and are not bold.

This resolves a contradiction found while writing [tasks.md](../tasks.md) T004: the R-0003
verification probe set `bold = true` on `BufferLineModifiedSelected`, while the table above did not.
**This table is authoritative** — `Modified` measures 8.09:1 against `#2d3f76` and clears the 4.5
floor without any weight, so bold buys nothing measurable there. Reserving bold for severities also
keeps the attribute meaningful: applied to five of six rows it would signal nothing, and an
unsaved-change marker is not a severity.

**Invariants**:

- every overlay ≥ 4.5 against `#2d3f76` — FR-008;
- every overlay ≥ `contrast(BufferLineBuffer)` (3.47) — a tinted active tab must never read as
  weaker than a plain inactive one. On the **baseline** background, error (11.63) and hint (12.24)
  were already weaker than the plain active name (13.99); after this change all six clear the floor
  uniformly.

**Deliberately untouched**: every `…Visible` and unsuffixed overlay (error, warning, info, hint,
modified, close button). They sit on their own backgrounds, clear their floors today, and are out of
this change's scope — FR-015.

## What this contract must NOT change

Verified unchanged by the read-back probe, and asserted by the smoke test so a later change cannot
quietly alter them (FR-015):

| Concern | Why frozen |
|---|---|
| `Normal`, `Comment`, `String`, and every other syntax group | FR-015 — this is a two-region change, not a palette change |
| `SignColumn` | measures 1.56:1 like `LineNr` did, but the developer reported the **numbers**; changing it is out of scope |
| buffer set, order, names, change markers, problem indicators | FR-007 — appearance only; buffer visibility is `specs/011`'s contract |
| `number`, `relativenumber`, `cursorline` options | FR-013 — layout is unchanged; only colors move |
| window title, status line, pickers, indent guides | FR-015 |

## Change protocol

Any future edit to these groups must:

1. re-run the probe in [quickstart.md](../quickstart.md) §6 and record the new ratios;
2. confirm every invariant above still holds — especially `contrast(BufferLineBuffer) ≥ 3.0`, which
   tightens as the selected background rises;
3. update [data-model.md](../data-model.md)'s baseline/target tables with the newly measured values;
4. update the module `README.md` section named in the specification's FR-023, which documents this
   hook as the single source of truth.

A color change that cannot state its new measured ratio does not satisfy this contract.