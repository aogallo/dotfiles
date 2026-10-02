# Data Model: Line Number and Active Buffer Emphasis

**Feature**: [`012-line-number-buffer-highlights`](spec.md) · **Date**: 2026-10-01

This feature has no persisted data. Nothing is written to disk, nothing survives a restart, and no
database or file schema changes. What it *does* have is a small set of **visual entities** with
**measurable contrast invariants** — states the editor must be in at render time, each with a number
attached that a reviewer can check. That is what this document models: the entities, their states,
the invariant each state must satisfy, and the measured baseline that the change must clear.

Every "baseline" value below was read from a running editor with the **unmodified** configuration
([research.md](research.md) probes 3, 7, 11). Every "target" value was read back **after** applying
the proposed change (probe `h95-final.lua`). Neither set is predicted.

## Contrast: the yardstick for every invariant

A contrast ratio is WCAG 2.x: convert each sRGB channel to linear light, take the luminance
`0.2126R + 0.7152G + 0.0722B`, then `(lighter + 0.05) / (darker + 0.05)`. 1.00 means invisible;
21.00 is the maximum (black on white). Verified against known pairs before use — `#000000` on
`#ffffff` = 21.00, `#777777` on `#ffffff` = 4.48 (probe 8).

Two thresholds are used throughout, taken from the specification:

- **3.0** — the floor for a secondary element: an inactive tab name, a relative line number.
- **4.5** — the floor for the element the developer is meant to read first: the active tab's name,
  the cursor line's number.

A third measure appears where "readable" is not the right question. For the **ordinal** question
("is this element more prominent than that one?") the ratio between the two elements' own foregrounds
is used instead, because a background change alters contrast-against-own-background without making
anything more prominent. This distinction is what R-0002 turned on, and it is why several invariants
below carry an ordinal measure rather than only an absolute one.

---

## Entity 1: Number column entry

Each rendered line in the left-hand column carries exactly one of three states. The states are
ordered by prominence, and the order is a requirement (FR-010), not a coincidence.

| State | Group | Baseline (today) | Target | Invariant |
|---|---|---|---|---|
| cursor's line | `CursorLineNr` | `#ff966c` bold, **7.16:1** | **unchanged** | strongest number in the column |
| relative number | `LineNr`, `LineNrAbove`, `LineNrBelow` | `#3b4261`, **1.56:1** | `#7aa2f7`, **6.07:1** | ≥ 3.0, and weaker than the cursor's |
| background | `Normal` | `#222436` | **unchanged** | — |

**Fields**: `foreground` (hex), `bold` (bool), `measured_contrast` (float).

**Validation rules**:

- `contrast(cursor) > contrast(relative)` — FR-010. Baseline 7.16 > 6.07 after; **1.56 < 7.16
  before**, so this ordering already held and must not invert.
- `contrast(relative) ≥ 3.0` — SC-004. **Baseline 1.56 FAILS.** This is the defect (R-0001).
- `contrast(cursor) ≥ 4.5` — SC-005. Baseline 7.16 passes and is frozen by Out of Scope.

**State transitions**: none. The three states are a function of where the cursor is; nothing
persists and nothing transitions.

**Explicitly not modeled**: column width, alignment, and the cursor line number's separate column
position. These are frozen by FR-013 and are not properties of this entity.

---

## Entity 2: Buffer tab

One entry in the buffer row per listed buffer. Carries three states, and — unlike Entity 1 — the
baseline for two of the three is **already correct**, which is the finding that reshaped the design.

| State | Group | Baseline (today) | Target | Invariant |
|---|---|---|---|---|
| focused buffer | `BufferLineBufferSelected` | name `#e0e2ea` on bg `#14161b`, **13.99:1**, bg-vs-inactive **1.05** | name `#e0e2ea` on bg `#2d3f76`, **7.79:1**, bg-vs-inactive **1.70** | name ≥ 4.5; ordinal ≥ 1.5× inactive; **bg separation ≥ 1.3** |
| selected in a non-focused window | `BufferLineBufferVisible` | name `#9b9ea4` on bg `#121418` | name `#a6adf8` on bg `#1f2131` | ordinal vs inactive ≥ 1.25 **and** bg vs selected ≥ 1.3 |
| inactive | `BufferLineBuffer` | name `#636da6` on bg `#191b28`, **3.47:1** | **unchanged** | name ≥ 3.0 |

Two further groups belong to the active tab without being states of it. They are resolved in T004
and recorded here so this document, the contract, [quickstart.md](quickstart.md) §6 and
[tasks.md](tasks.md) all name the same thirteen groups:

| Element | Group | Baseline | Target | Invariant |
|---|---|---|---|---|
| segment divider inside the active tab | `BufferLineSeparatorSelected` | not overridden | fg `#2d3f76`, bg `#2d3f76` | `fg == bg == selected bg`, contrast exactly **1.00** — it must vanish |
| left indicator on the active tab | `BufferLineIndicatorSelected` | not overridden | fg `#7aa2f7` | `≥ 3.0` (measured **4.00**) **and** `< contrast(BufferLineBufferSelected)` (7.79) |

**Fields**: `name_foreground`, `background`, `bold`, `visible_width` (for truncation — Edge Case,
"very long buffer names"), `ordinal_against(state)`.

**Validation rules**:

- `contrast(name, own_bg) ≥ 4.5` — SC-002. **Baseline 13.99 already passes.**
- `contrast(name, own_bg) ≥ 1.5 × contrast(inactive name, own_bg)` — SC-002 second clause.
  **Baseline 1.98× already passes.**
- `contrast(active bg, inactive bg) ≥ 1.3` — **no requirement in the specification states this
  number**, but R-0002 measured it at **1.05** and identified it as the actual defect: the tab
  *region* carries no signal, so FR-001's "at least two independent visual ways" is not met by the
  baseline. Target 1.70.
- `contrast(visible name, inactive name) ≥ 1.25` — FR-006, second half. **Baseline 1.00 FAILS**:
  both groups hold the identical foreground `#9b9ea4` (R-0004).
- `contrast(visible bg, selected bg) ≥ 1.3` — FR-006, third half: it must not mimic focus. Target
  1.58.
- `contrast(inactive name, own_bg) ≥ 3.0` — SC-003. Baseline 3.47 passes; target 3.47 unchanged. This
  is the invariant that **tightens** as the active background rises, and the one to re-check if the
  active background is ever raised further.

**Relationships**: a tab is in exactly one state per window. In a multi-window session the focused
window's tab is `…Selected`, a tab displayed in another window is `…Visible`, and all others are
plain. FR-006 requires these three to remain distinguishable from one another; FR-007 requires the
**set, order and names** to be untouched by this change.

**State transitions**: driven entirely by cursor and window focus. FR-005 requires the transition to
be visible in the same frame as the content change — a redraw-timing property, verified
interactively rather than headlessly (R-0007).

---

## Entity 3: Tab indicator state

When a tab carries a diagnostic or an unsaved change, bufferline substitutes a tinted name. These
are not extra entities — they are **overlays on Entity 2** — but they carry their own invariant,
because a tint can weaken the very emphasis the active tab is supposed to have.

| Overlay | Group | Baseline on selected bg | Target | Invariant |
|---|---|---|---|---|
| error | `BufferLineErrorSelected` | `#ffc0b9`, 11.63:1 on `#14161b` | `#ffc0b9` on `#2d3f76`, **6.47:1** | ≥ 4.5 |
| warning | `BufferLineWarningSelected` | `#fce094`, 13.99:1 | **7.79:1** | ≥ 4.5 |
| info | `BufferLineInfoSelected` | `#8cf8f7`, 14.55:1 | **8.10:1** | ≥ 4.5 |
| hint | `BufferLineHintSelected` | `#a6dbff`, 12.24:1 | **6.81:1** | ≥ 4.5 |
| modified | `BufferLineModifiedSelected` | `#b3f6c0`, 14.53:1 | **8.09:1**, **not bold** | ≥ 4.5 |
| close icon | `BufferLineCloseButtonSelected` | `#e0e2ea`, 13.99:1 | `#e0e2ea` on `#2d3f76`, **not bold** | ≥ 4.5 |

**Bold is a severity marker, not a row marker**: only the four diagnostic overlays are bold. The
R-0003 probe set `bold = true` on `Modified`, which contradicted
[contracts/highlight-contract.md](contracts/highlight-contract.md) §C; the contract wins, and the
resolution is written there and here rather than left in conversation (T004).

**Why this is a real invariant and not a formality**: on the baseline background, three of the six
already measure *below* the plain active name (13.99) — error at 11.63 and hint at 12.24 are weaker
than doing nothing (R-0003 probe 7). On the target background all six clear 4.5. FR-008 exists
because raising the active background raises the bar every one of these must clear.

**Validation rule**: for each overlay, `contrast(tint, selected bg) ≥ 4.5` **and**
`contrast(tint, selected bg) ≥ contrast(inactive name, inactive bg)` — a tinted active tab must
never read as weaker than a plain inactive one.

---

## Entity 4: Legibility threshold

The shared yardstick, not a stored value. It exists as an entity because **the same two numbers are
reused by both user stories**, and a change that clears 4.5 for one element must not silently lower
it for another.

| Threshold | Applies to | Source |
|---|---|---|
| **4.5** | the active tab's name, the cursor line's number, every diagnostic overlay | SC-002, SC-005, FR-008 |
| **3.0** | every inactive tab name, every relative line number | SC-003, SC-004 |
| **1.5×** | active name vs the least-contrasted inactive name | SC-002 |
| **1.3** | active region vs inactive region; non-focused window vs focused window | derived — FR-001, FR-006 |
| **1.25** | non-focused window name vs inactive name | derived — FR-006 |

**Validation rule**: no change may lower a measured value below its threshold without an explicit
decision recorded in the specification. This is the invariant the smoke test enforces
(FR-027, [quickstart.md](quickstart.md) §7).

---

## Entity 5: Appearance source

The single documented place where these values are stated, and the subject of FR-021 and FR-023.

**Location**: the `on_highlights` hook of the `tokyonight` entry in `nvim/plugin/editor.lua:150-171` —
already the repository's established place for exactly this, holding twelve overrides today.

**Fields**: `hook` (the colorscheme's highlight hook) · `groups` (13 groups) · `documented` (bool).

**Validation rules**:

- the mechanism MUST survive `:colorscheme` at runtime (FR-017) — verified in
  [research.md](research.md) R-0005;
- the values MUST be stated explicitly rather than derived implicitly from another plugin's internal
  tint math (FR-021) — the reason [research.md](research.md) R-0008 leaves the load-order bug to a
  separate issue;
- the mechanism MUST be documented in the module README with its effect and its validation commands
  (FR-023);
- it MUST be the only place these colors are decided (FR-005's sibling requirement, V — source of
  truth): no second file, no local override, no autocmd re-applying the same values.

**Relationships**: Entity 5 owns the values for Entities 1, 2 and 3. Entities 1–3 are not
independently configurable; changing a value means changing Entity 5.

---

## Invariant summary — baseline vs target

| Invariant | Baseline | Target | Status |
|---|---|---|---|
| relative number ≥ 3.0 | **1.56** | 6.07 | **fixed** |
| cursor number ≥ 4.5 | 7.16 | 7.16 | holds, frozen |
| cursor stronger than relative | holds | holds | preserved |
| active name ≥ 4.5 | 13.99 | 7.79 | holds |
| active name ≥ 1.5× inactive | 1.98× | 2.24× | holds |
| inactive name ≥ 3.0 | 3.47 | 3.47 | holds |
| active region vs inactive region ≥ 1.3 | **1.05** | 1.70 | **fixed** |
| non-focused name vs inactive ≥ 1.25 | **1.00** | 2.33 | **fixed** |
| non-focused bg vs active bg ≥ 1.3 | 1.02 | 1.58 | **fixed** |
| worst diagnostic on active ≥ 4.5 | **11.63** (but 3 below plain name) | 6.47 | holds, now uniformly |

Three of the ten invariants are genuinely broken at baseline — the two the developer reported, plus
the non-focused-window case R-0004 found while measuring. Two more already hold and are **frozen**:
the active name's contrast (13.99) and the ordinal multiplier (1.98×). The design deliberately
does not chase those two, because doing so would have satisfied SC-002 without changing anything
visible (R-0002).