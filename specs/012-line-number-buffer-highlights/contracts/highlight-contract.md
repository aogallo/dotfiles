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

**Single source of truth**: the function `apply_editor_highlights` in `nvim/plugin/editor.lua`,
passed to tokyonight as `on_highlights`. It holds **14 overrides** and is the only place these colors
are stated.

**Why this mechanism** ([research.md](../research.md) R-0005, verified):

- `on_highlights` runs **during** `:colorscheme`, which happens **before** bufferline's `setup()`;
- bufferline derives its palette from the highlight groups present at that moment;
- it then applies that palette with `nvim_set_hl(..., { default = true })`, because its `themable`
  option defaults to `true` and this configuration does not disable it — which means it does **not**
  clobber a group that is already defined;
- therefore defining the overrides first is sufficient, and they survive bufferline's own pass, and
  they survive switching away and back.

Verified three ways in probe 6 and probe `h95-final.lua`. The rejected alternatives and why they
fail are in [research.md](../research.md) R-0005.

**Load order is part of this contract.** The colorscheme must be applied **before** bufferline is set
up, because bufferline derives from the highlight groups that exist when it runs.
`nvim/plugin/editor.lua` therefore applies `:colorscheme tokyonight` in a batch **before** the
`add{}` that contains bufferline. Tokyonight stays under `vim.pack` management and its
`nvim-pack-lock.json` entry is unchanged — only the batch order moved.

This is the whole of the fix for #101 and it is sufficient on its own; an earlier draft of this
contract claimed a second re-apply from bufferline's `on_setup` was also required. That was wrong,
and [research.md](../research.md) R-0009 records the check that disproved it: removing such a re-apply
changed no measured value, because `default = true` already prevents the clobber.

**Known coupling**: this reasoning depends on `themable` staying `true`. Setting `themable = false` in
the bufferline options would let bufferline's derived palette overwrite these groups, and an
explicit re-apply after its `setup()` would then be required.

The observable check: `vim.g.colors_name` is non-nil and equal to a tokyonight style at the moment
bufferline derives, and `BufferLineBuffer` reads the values in §B afterwards.

**Switching colorscheme.** `apply_editor_highlights` runs only for tokyonight, so under any other
colorscheme bufferline derives the row natively from that colorscheme and none of these values leak
into it. Switching away and back to tokyonight restores §B and §C exactly. Verified with
`habamax` and by switching tokyonight's own `style`.

**Constraints on the mechanism**:

| Rule | Requirement | Why |
|---|---|---|
| No new dependency | FR-018 | The function belongs to a plugin already pinned in `nvim/nvim-pack-lock.json`. |
| No autocmd, no user command, no keymap | FR-016 | The appearance is a standing default, not a mode. |
| No second place | FR-005, FR-021 | Values must be stated once, explicitly — not derived from another plugin's internal tint math ([research.md](../research.md) R-0008). |
| Colors are palette tokens | FR-021 | Every value is a `c.*` token from the active tokyonight style, so switching style carries them. A future maintainer must still be able to tell an intentional override from an accident, which the token names and the contract table preserve. |
| Survive `:colorscheme` | FR-017 | Verified, not assumed. |
| Degrade on reduced-color terminals | FR-022 | Only `fg`/`bg` are emitted, so Neovim maps them to whatever the terminal supports ([research.md](../research.md) R-0006). |

## Group contract

Values verified read-back from a running editor after application
([research.md](../research.md) R-0003). Ratios are contrast against the stated background.

### A. Number column (User Story 2)

| Group | Foreground | Background | Contrast | Floor | Requirement |
|---|---|---|---|---|---|
| `LineNr` | `#737aa2` | `Normal` `#222436` | 3.67:1 | 3.0 | SC-004 |
| `LineNrAbove` | `#737aa2` | `Normal` `#222436` | 3.67:1 | 3.0 | SC-004 |
| `LineNrBelow` | `#737aa2` | `Normal` `#222436` | 3.67:1 | 3.0 | SC-004 |
| `CursorLineNr` | *unchanged* `#ff966c`, bold | `Normal` `#222436` | 7.16:1 | 4.5 | SC-005, Out of Scope |

**Invariants**:

- `contrast(CursorLineNr) > contrast(LineNr)` — FR-010. 7.16 > 3.67. **The ordinal order must
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
| `BufferLineBufferSelected` | `#c8d3f5`, bold | `#2f334d` | 8.28:1 | the focused buffer — **owns the emphasis** |
| `BufferLineBufferVisible` | `#828bb8` | `#191b29` | 5.15:1 | selected in a **non-focused** window |
| `BufferLineBuffer` | `#636da6` | `#191b29` | 3.47:1 | inactive |
| `BufferLineSeparatorSelected` | `#2f334d` | `#2f334d` | 1.00:1 | segment divider inside the active tab — **blends away** |
| `BufferLineIndicatorSelected` | `#82aaff` | `#2f334d` | 5.37:1 | the selected tab's left indicator |

**Invariants**:

- `contrast(BufferLineBufferSelected) ≥ 4.5` — SC-002.
- `contrast(BufferLineBufferSelected) ≥ 1.5 × contrast(BufferLineBuffer)` — SC-002 second clause.
  Measured **3.30×**.
- `contrast(BufferLineBufferSelected.bg, BufferLineBuffer.bg) ≥ 1.3` — derived; FR-001's second
  visual channel. Baseline was **1.05**, the actual defect ([research.md](../research.md) R-0002).
- `contrast(BufferLineBuffer) ≥ 3.0` — SC-003. Measured 3.47. **This is the invariant that tightens
  if the active background is ever raised further** — re-check it on any future change to
  `BufferLineBufferSelected.bg`.

**The inactive row is overridden too, and that is a correction, not a preference.**
`akinsho/bufferline.nvim` is configured in [plan.md](../plan.md) with no `theme` option, so it
derives the row from the highlight groups present when it is set up. Its `setup()` ran inside the
same eager `add{}` call as every other plugin and therefore **before** `:colorscheme tokyonight`
existed — at that moment `vim.g.colors_name` was `<none>` and it fell back to Neovim's built-in
defaults, painting the row in `#9b9ea4` on `#0f1014`. That is issue #101, and it was **not** a
bufferline `desert` theme: the fix is load order, recorded in [research.md](../research.md) R-0008.
The three-state design above was measured against `#636da6` on `#191b29`, values that **never
existed in this configuration**. Implementing §B and §C while leaving the inactive row alone was
measured and fails three of this contract's own clauses:

| Clause | Floor | With the real inactive row | With the values above |
|---|---|---|---|
| SC-002, `selected ≥ 1.5 × inactive` | 1.5× | **1.10× FAIL** | 3.30× pass |
| FR-008, `tint ≥ inactive name` | 7.08 | **Error 6.47, Hint 6.81 FAIL** | all six pass at ≥ 4.76 |
| FR-006, `visible ≥ 1.25 × inactive` | 1.25 | 1.27, by 0.02 | 1.48 pass |

The emphasis would have been 1.10× over an almost equally bright inactive row — the feature not
delivering what it exists to deliver. Setting `BufferLineBuffer` explicitly is therefore load-bearing:
it is what makes every number in this contract true, and it also removes a foreign grey palette from
the middle of a tokyonight editor.
- `contrast(BufferLineBufferVisible, BufferLineBuffer) ≥ 1.25` and
  `contrast(BufferLineBufferVisible.bg, BufferLineBufferSelected.bg) ≥ 1.3` — FR-006.
  Baselines were **1.00** and imperceptible ([research.md](../research.md) R-0004); targets 1.48
  and 1.38.
- **`BufferLineSeparatorSelected`**: `fg == bg == BufferLineBufferSelected.bg`, so its contrast
  against its own background is **exactly 1.00**. The separator divides segments *within* one tab
  (a path, a name, a close icon), so on the active tab it must not draw an edge inside the block
  that is supposed to read as solid. Baseline `BufferLineSeparator` measured 1.08:1 against the
  inactive background; here the requirement is not merely "stay low" but "vanish". Adding a
  separator override would be worse than omitting it, which is why it is in this contract at all.
- **`BufferLineIndicatorSelected`**: `contrast ≥ 3.0` — measured **5.37**. It is a 1–2px marker,
  not text, so it is deliberately **not** held to the 4.5 text floor. Two constraints bound it:
  stay `≥ 3.0` so it remains visible against the tint it marks, and stay **below
  `BufferLineBufferSelected`** (8.28) so it points at the name instead of competing with it.

**Why the name moves with the background**: at baseline the name already measured 13.99:1 and
1.98× the inactive name, but the background carried no signal at all (1.05) — the row did not
identify the focused buffer. Both channels are now explicit tokyonight tokens (`c.fg` on
`c.bg_highlight`), so the pair is a deliberate, reproducible pair rather than one derived from
bufferline's internal `tint()` math. FR-003 holds because the name remains the strongest element
in the row and the background is the *second* channel, not a replacement.

### C. Diagnostic overlays on the active tab (FR-008)

Each must be restated against the new selected background, or it inherits a background it was not
chosen for.

| Group | Foreground | Background | Contrast | Floor |
|---|---|---|---|---|
| `BufferLineErrorSelected` | `#ff757f`, bold | `#2f334d` | 4.76:1 | 4.5 |
| `BufferLineWarningSelected` | `#ff966c`, bold | `#2f334d` | 5.78:1 | 4.5 |
| `BufferLineInfoSelected` | `#0db9d7`, bold | `#2f334d` | 5.25:1 | 4.5 |
| `BufferLineHintSelected` | `#89ddff`, bold | `#2f334d` | 8.14:1 | 4.5 |
| `BufferLineModifiedSelected` | `#c3e88d` | `#2f334d` | 8.96:1 | 4.5 |
| `BufferLineCloseButtonSelected` | `#c8d3f5` | `#2f334d` | 8.28:1 | 4.5 |

**Bold rule**: bold marks the four diagnostic **severities** only — `Error`, `Warning`, `Info`,
`Hint`. `Modified` and `CloseButton` are **state markers, not severities**, and are not bold.

This resolves a contradiction found while writing [tasks.md](../tasks.md) T004: the R-0003
verification probe set `bold = true` on `BufferLineModifiedSelected`, while the table above did not.
**This table is authoritative** — `Modified` measures 8.96:1 against `#2f334d` and clears the 4.5
floor without any weight, so bold buys nothing measurable there. Reserving bold for severities also
keeps the attribute meaningful: applied to five of six rows it would signal nothing, and an
unsaved-change marker is not a severity.

**Invariants**:

- every overlay ≥ 4.5 against `#2f334d` — FR-008;
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