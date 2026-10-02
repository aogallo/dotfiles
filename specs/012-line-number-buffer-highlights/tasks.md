---

description: "Task list for line number and active buffer emphasis (issue #95)"
---

# Tasks: Line Number and Active Buffer Emphasis

**Input**: Design documents from `/specs/012-line-number-buffer-highlights/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/highlight-contract.md](contracts/highlight-contract.md),
[quickstart.md](quickstart.md)

**Tests**: Included and REQUIRED. FR-027 makes new automated coverage a requirement, SC-012 makes the
existing suite a hard gate, and the constitution (VIII) forbids completing a change with failing
validation. [quickstart.md](quickstart.md) §7 is the authority for what the new suite asserts; §3 and
§8 are the authority for the numbers; §5 is the authority for the six criteria a headless run
cannot assert.

**Organization**: Tasks are grouped by user story so each story can be implemented, tested and
delivered independently. Each user-story phase links to its matching heading in [spec.md](spec.md).

**Order note**: User Story 1 and User Story 2 are both P1 and both write into the same
`on_highlights` hook, so they are **serialized by file** — but they remain **independent by
behavior**: either ships alone, and the specification (Q1) records dropping one as a review decision
rather than an omission. See [Dependencies](#dependencies--execution-order).

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable — touches a different file, or has no dependency on incomplete work.
- **[US#]**: User story marker. The phase's `Story Link` points to the matching `spec.md` heading.
- **[R#]**: Contract reference marker, pointing at a section of
  [contracts/highlight-contract.md](contracts/highlight-contract.md).
- Every task names an exact file path. T### IDs are stable — do not renumber; append instead.

## Legend

| Marker | Meaning |
|--------|---------|
| `- [ ]` | Not started. Flip to `- [X]` when the task is done **and** its test passes. |
| `T###` | Task ID, unique and stable. Assigned in execution order; never reused. |
| `[P]` | May run in parallel with other `[P]` tasks in the same phase — different file, no dependency on incomplete work. |
| `[US#]` | Belongs to that user story's phase. Traceable to the story's acceptance scenarios and its `FR-` requirements. |
| `[R#]` | Implements a specific section of the highlight-group contract. |
| `[X]` | Complete, with the named test passing. A task is not complete because the code was written — it is complete when its test is green. |

Phases **1** (Setup), **2** (Foundational) and the final **Polish** phase carry **no** `[US#]`
label, per the format rules. Only user-story phases are labelled.

**Note on ID order**: T046–T049 were appended by `/speckit.analyze` to close coverage and
constitution gaps. Because IDs are stable and must not be renumbered, they appear out of numeric
order inside Phase 5 (T048, T049) and Phase 6 (T046, T047). Nothing depends on the ordering.

## Path Conventions

Single project (dotfiles repo). Neovim module paths only; no other subtree is touched.

```text
nvim/
├── plugin/
│   └── editor.lua                        # MODIFIED — the tokyonight on_highlights hook gains
│                                        #   the 13 overrides (contracts §A, §B, §C)
├── lua/config/
│   ├── options.lua                       # unchanged — number/relativenumber/cursorline stay
│   │                                     #   (FR-013); carries an unrelated uncommitted change
│   │                                     #   — do not touch, do not commit
│   └── buffers.lua                       # unchanged — buffer visibility is specs/011's contract
├── lua/tests/
│   └── highlight_emphasis_smoke.lua      # NEW — contrast, ordinal and survival assertions
├── README.md                             # MODIFIED — appearance, source of truth, validation, rollback
└── stylua.toml                           # unchanged
```

Nothing else in the repository is read or written (FR-019, constitution IV). No dependency is added
(FR-018, constitution VI).

## The values, in one place

The authoritative values are in [contracts/highlight-contract.md](contracts/highlight-contract.md).
Repeated here so an implementer does not have to cross-reference while editing:

| Contract § | Groups | Values | Floor |
|---|---|---|---|
| **A** (US2) | `LineNr`, `LineNrAbove`, `LineNrBelow` | `fg = '#7aa2f7'` | 3.0 vs `Normal` bg `#222436` (6.07:1) |
| A (frozen) | `CursorLineNr` | **unchanged** `#ff966c` bold | 4.5 (7.16:1) — Out of Scope |
| **B** (US1) | `BufferLineBufferSelected` | `fg = '#e0e2ea'`, `bold = true`, `bg = '#2d3f76'` | 4.5 own-bg (7.79:1); ≥ 1.5× inactive; bg vs inactive bg ≥ 1.3 (1.70) |
| B (US1) | `BufferLineBufferVisible` | `fg = '#a6adf8'`, `bg = '#1f2131'` | ordinal vs inactive ≥ 1.25 (2.33); bg vs selected bg ≥ 1.3 (1.58) |
| B (US1) | `BufferLineBuffer` | `fg = '#636da6'`, `bg = '#191b28'` | name ≥ 3.0 (3.47:1) — **overridden, see note below** |
| B (US1) | `BufferLineIndicatorSelected` | `fg = '#7aa2f7'` | ≥ 3.0 (4.00:1) **and** `< BufferLineBufferSelected` (7.79:1) |
| B (US1) | `BufferLineSeparatorSelected` | `fg = '#2d3f76'`, `bg = '#2d3f76'` | `fg == bg == selected bg` → exactly **1.00:1**, must vanish |
| **C** (US1) | `BufferLineErrorSelected` | `fg = '#ffc0b9'`, `bold = true`, `bg = '#2d3f76'` | 4.5 (6.47:1) |
| C (US1) | `BufferLineWarningSelected` | `fg = '#fce094'`, `bold = true`, `bg = '#2d3f76'` | 4.5 (7.79:1) |
| C (US1) | `BufferLineInfoSelected` | `fg = '#8cf8f7'`, `bold = true`, `bg = '#2d3f76'` | 4.5 (8.10:1) |
| C (US1) | `BufferLineHintSelected` | `fg = '#a6dbff'`, `bold = true`, `bg = '#2d3f76'` | 4.5 (6.81:1) |
| C (US1) | `BufferLineModifiedSelected` | `fg = '#b3f6c0'`, `bg = '#2d3f76'`, **no `bold`** | 4.5 (8.09:1) |
| C (US1) | `BufferLineCloseButtonSelected` | `fg = '#e0e2ea'`, `bg = '#2d3f76'`, **no `bold`** | 4.5 (7.79:1) |

All values are **literals**, not derived from another plugin's tint math (FR-021,
[research.md](research.md) R-0008).

**`BufferLineBuffer` is overridden, not frozen.** `akinsho/bufferline.nvim` is configured with no
`theme`, so it paints the inactive row in its built-in `desert` greys (`#9b9ea4` on `#0f1014`,
**7.08:1**) — a palette foreign to tokyonight and absent from every artifact written before T005.
Implementing only the active row against that real baseline fails three clauses of this contract:
SC-002's `≥ 1.5×` measures **1.10×**, FR-008's `tint ≥ inactive` fails for `Error` (6.47) and
`Hint` (6.81), and FR-006 clears 1.25 by only 0.02. Setting the inactive row to `#636da6`/`#191b28`
makes the ordinal margin 2.24×, the region 1.70, and every overlay clear its floor. Fourteen groups
are overridden, not thirteen.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the baseline, confirm the branch, and reconcile one defect found in the
contract while writing this task list. No story code here.

- [X] T001  Record the pre-change baseline: run every existing suite listed in [quickstart.md](quickstart.md) §8 and capture their assertion counts, so a pre-existing failure is not misattributed later. **Recorded: 520 assertions, 0 failures** — `buffer_visibility` 60, `db_connections` 4, `db_context` 133, `db_jump` 7, `db_objects_save` 26, `db_objects_scope` 92, `db_results` 59, `formatter_chains` 27, `keymap_groups` 6, `markdown_whitespace` 18, `no_formatter_warning` 10, `sybase_adapter` 25, `sybase_objects` 53. **Correction after the Phase 1 checkpoint**: the stable figure is **521**, with `buffer_visibility` at 61, and it is deterministic across repeat runs. The first run happened while `nvim/nvim-pack-lock.json` was mid-materialisation (see T039), so one assertion was skipped; `buffer_visibility_smoke.lua` has no plenary conditional, so the mechanism is not established — recorded as a 1-assertion delta in an unrelated suite, all suites green either way, not chased further
- [X] T002  Confirm the working tree is on branch `012-line-number-buffer-highlights` and that the unrelated uncommitted `nvim/lua/config/options.lua` change (a duplicate `vim.o.showmode = false`) is **left out** of this branch's commits — it is not part of issue #95 (constitution XIII)
- [X] T003  [P] Verify nothing outside the [plan.md](plan.md) file list is modified, and that no probe scripts from the R-0001…R-0010 investigation remain in the tree
- [X] T004  **Reconcile three contract defects found while analysing this task list, before any code is written.** (a) The contract claims 13 groups but `BufferLineSeparatorSelected` (`fg = '#2d3f76'`, `bg = '#2d3f76'`) appears in neither §B nor §C **nor in any other artifact** — it exists only in this file. Add it to contract §B, to [data-model.md](data-model.md) Entity 2, and to the probe in [quickstart.md](quickstart.md) §6, so the count of 13 is true in all four documents. (b) The verification probe set `bold = true` on `BufferLineModifiedSelected` while contract §C lists it without bold — decide, write the resolution into §C itself rather than only settling it in conversation, and apply the same value to [data-model.md](data-model.md) Entity 3 and this file's value table above. (c) `BufferLineIndicatorSelected` is named in [plan.md](plan.md) and contract §B but carries **no invariant and no contrast floor** anywhere — either give it a floor in [data-model.md](data-model.md) Entity 2 or state in contract §B that it is decorative and carries none. Re-run [quickstart.md](quickstart.md) §6 to confirm every resolved value still measures as stated. **Resolved** — (a) `BufferLineSeparatorSelected` added to contract §B with the invariant `fg == bg == BufferLineBufferSelected.bg`, contrast exactly **1.00**, and to data-model Entity 2 and quickstart §6; the count of 13 is now true in all four documents. (b) `Modified` is **not** bold: the contract §C table is authoritative and the probe was wrong. Bold is reserved for the four severities; recorded in contract §C, data-model Entity 3, T014 and T015. (c) `BufferLineIndicatorSelected` is **not** decorative — measured 4.00:1, so it gets `≥ 3.0` **and** an upper bound below `BufferLineBufferSelected` (7.79:1), which stops a brighter hue inverting the row's reading order. The 4.5 text floor is deliberately not applied: 4.5 is unreachable for this blue on `#2d3f76` without outshining the buffer name
- [X] T005  [P] Re-run the [quickstart.md](quickstart.md) §6 probe against the **unmodified** configuration and confirm the baseline still reads `LineNr` 1.56, active-bg-vs-inactive-bg 1.05, non-focused-vs-inactive 1.00 — the three broken invariants in [data-model.md](data-model.md). If any differs, stop: the design was measured against different values

**Checkpoint**: Baseline recorded, branch correct, contract reconciled, baseline re-confirmed. No
behavior change — the existing suites from T001 must still pass.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the measurement harness every story asserts through. No story assertions here.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Create `nvim/lua/tests/highlight_emphasis_smoke.lua` with the harness and **zero** story cases: the WCAG relative-luminance math (`lin`/`lum`/`cr`) and a `hex()` formatter, a `g(name)` accessor over `vim.api.nvim_get_hl(0, { name = n, link = false })`, and a `check(ok, name, got, want)` helper that prints `PASS`/`FAIL` with `vim.inspect` and calls `:cquit` on failure. Copy the harness shape of `nvim/lua/tests/markdown_whitespace_smoke.lua`
- [X] T007 Add to `nvim/lua/tests/highlight_emphasis_smoke.lua` the two shared yardstick values as named constants — `PRIMARY = 4.5` and `SECONDARY = 3.0`, with a comment naming SC-002/SC-005 and SC-003/SC-004 as their source — plus a `normal_bg()` accessor, so every later case measures against one definition instead of a repeated literal ([data-model.md](data-model.md) Entity 4)
- [X] T008 Add to `nvim/lua/tests/highlight_emphasis_smoke.lua` a self-check of the ratio implementation before any real assertion depends on it: `#000000` on `#ffffff` must equal 21.00 and `#777777` on `#ffffff` must equal 4.48, each within 0.01. A broken `cr()` that silently returned 1.0 would make every later case pass for the wrong reason
- [X] T009 Follow the convention at `nvim/lua/tests/markdown_whitespace_smoke.lua:15-18` and open a scratch buffer at the top of `nvim/lua/tests/highlight_emphasis_smoke.lua` (`vim.fn.tempname()`), because this repository puts its plugin pack on the runtimepath lazily and the highlight groups are absent before that
- [X] T010 Verify `nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'` exits 0 with only the harness output, and that `stylua --check nvim` passes on the new file

**Checkpoint**: Foundation ready. The suite runs, self-verifies its own math, and asserts nothing
about the feature yet — so it passes on the unmodified configuration by design. That is what makes
T009's later red phase meaningful.

---

## Phase 3: User Story 1 - The buffer I am editing is unmistakable (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---the-buffer-i-am-editing-is-unmistakable-priority-p1)

**Goal**: The focused tab carries the strongest name in the row **and** a visibly distinct
background, and the six diagnostic overlays on that tab stay readable on the new background.

**Independent Test**: Open eight or more buffers, move the cursor between them, and confirm the
active tab is identifiable without reading names ([quickstart.md](quickstart.md) §5.1). Headlessly:
the §B and §C assertions in `nvim/lua/tests/highlight_emphasis_smoke.lua` pass while every §A
assertion still fails — the buffer row improves with the number column untouched.

**Note on the baseline**: SC-002's two clauses **already pass today** (13.99:1 and 1.98×). This
phase must be validated against the two channels FR-001 names — name and background — and against
the bg-separation invariant, not against SC-002 alone, or it would pass without changing anything
visible ([research.md](research.md) R-0002).

### Tests for User Story 1 ⚠️ write first, watch them fail

> **NOTE**: each case must be observed **failing** against the unmodified configuration before the
> implementation lands. A suite that passes before the change proves nothing.

- [X] T011 [US1] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` the contract §B cases: `BufferLineBufferSelected` name ≥ `PRIMARY` against its own background; that value ≥ 1.5 × `BufferLineBuffer`'s own contrast; `BufferLineBufferSelected.bg` vs `BufferLineBuffer.bg` ≥ 1.3; `BufferLineBuffer` ≥ `SECONDARY`; `BufferLineBufferVisible` name vs `BufferLineBuffer` name ≥ 1.25; `BufferLineBufferVisible.bg` vs `BufferLineBufferSelected.bg` ≥ 1.3; and that no inactive name reaches the selected name's contrast (FR-002, FR-001, FR-003, FR-004, FR-006; SC-002, SC-003). Also assert the two invariants T004 added to §B, which are contract clauses and would otherwise go unasserted anywhere runnable: `BufferLineSeparatorSelected` has `fg == bg` with contrast exactly 1.00, and `BufferLineIndicatorSelected` is ≥ `SECONDARY` **and** below `BufferLineBufferSelected`
- [X] T012 [US1] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` the contract §C cases: each of `BufferLine{Error,Warning,Info,Hint,Modified,CloseButton}Selected` ≥ `PRIMARY` against the selected background, **and** each ≥ `contrast(BufferLineBuffer, its own bg)` so a tinted active tab never reads weaker than a plain inactive one (FR-008)
- [X] T013 [US1] Run the suite and record which US1 cases fail. Expect the bg-separation case and the non-focused cases to fail; expect the name-contrast cases to pass already. **If a name case fails, stop** — the palette has drifted from the contract and T004's reconciliation is incomplete. **Recorded** — 4 failures, and no name case failed, so the palette is intact:

| US1 case | measured | floor | red phase |
|---|---|---|---|
| active bg vs inactive bg | **1.05** | ≥ 1.3 | ✗ FAIL — the defect |
| non-focus name vs inactive name | **1.00** | ≥ 1.25 | ✗ FAIL |
| non-focus bg vs active bg | **1.02** | ≥ 1.3 | ✗ FAIL |
| separator vanishes (T004) | **1.08** | == 1.00 | ✗ FAIL — new invariant, unset today |
| active name vs own bg | 13.99 | ≥ 4.5 | ✓ passes already |
| active name ≥ 1.5× inactive | 1.98× | ≥ 1.5 | ✓ passes already |
| inactive name vs own bg | 7.08 | ≥ 3.0 | ✓ passes already |
| inactive name below active name | 7.08 < 13.99 | ordinal | ✓ passes already |

The suite is fail-fast, matching the convention in the other 13 suites, so it reports the first failure
(`active background separates from the inactive background`, 1.05). The full set above was enumerated
from the read-only [quickstart.md](quickstart.md) §6 probe, which reports every ratio without
asserting. All six §C overlays pass at baseline (11.63–14.55 on the old `#14161b`), and their bold
flags already match the T004 rule, so T012 contributes no red cases.

### Implementation for User Story 1

- [X] T014 [US1] [R§B] Add to the `on_highlights` hook of the `tokyonight` entry in `nvim/plugin/editor.lua` the five §B overrides: `BufferLineBufferSelected` (`fg = '#e0e2ea'`, `bold = true`, `bg = '#2d3f76'`), `BufferLineBufferVisible` (`fg = '#a6adf8'`, `bg = '#1f2131'`), `BufferLineBuffer` (`fg = '#636da6'`, `bg = '#191b28'` — see the note above; this replaces bufferline's own `desert` palette), `BufferLineIndicatorSelected` (`fg = '#7aa2f7'`), and `BufferLineSeparatorSelected` (`fg = '#2d3f76'`, `bg = '#2d3f76'` — must vanish, contrast exactly 1.00)
- [X] T015 [US1] [R§C] In the same hook, add the six §C overrides from the value table above, each restating `bg = '#2d3f76'`. Bold on `Error`, `Warning`, `Info`, `Hint` only; **no** `bold` on `Modified` or `CloseButton` — bold marks severity, not row state ([contracts/highlight-contract.md](contracts/highlight-contract.md) §C bold rule)
- [X] T016 [US1] Declare a new local `active_tab_bg = '#2d3f76'` in the `on_highlights` hook in `nvim/plugin/editor.lua`, beside the existing `readable_comment` / `hidden_path` / `explorer_row` locals, and use it for the selected-tab background. **Do not reuse `explorer_row`**, even though both hold `'#2d3f76'` today: `explorer_row` drives `SnacksPickerListCursorLine`, so sharing the name would let a change to the picker's row silently repaint the active buffer tab. FR-021 requires an intentional override to be tellable from an accidental one, and two unrelated concerns sharing one variable is the opposite. Comment the local with a pointer to [contracts/highlight-contract.md](contracts/highlight-contract.md) as the authority
- [X] T017 [US1] Re-run the suite: all US1 cases green, all US2 cases still failing, exit 0 (SC-002, SC-003, SC-008's measurable half; FR-001, FR-003, FR-004, FR-006, FR-008)
- [X] T018 [P] [US1] Confirm `nvim/lua/config/buffers.lua` and the bufferline option block in `nvim/plugin/editor.lua` are untouched — no option, no tab ordering, no naming, no close-icon behavior (FR-007)

**Checkpoint**: User Story 1 is fully functional and independently testable. The buffer row reads
correctly while the number column is still the reported defect — which is exactly the state
[spec.md](spec.md) (Q1) says can ship on its own.

---

## Phase 4: User Story 2 - I can read the numbers while I move (Priority: P1)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---i-can-read-the-numbers-while-i-move-priority-p1)

**Goal**: Every number in the left column is legible, with the cursor's line still the strongest.

**Independent Test**: Open a file of several hundred lines, scroll, and confirm every number is
legible and the cursor's line is still identifiable ([quickstart.md](quickstart.md) §5.1's sibling,
§5.2). Headlessly: the §A assertions pass while §B and §C keep passing — the number column improves
with the buffer row untouched.

### Tests for User Story 2 ⚠️ write first, watch them fail

- [X] T019 [US2] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` the contract §A cases: `LineNr`, `LineNrAbove` and `LineNrBelow` each ≥ `SECONDARY` against `normal_bg()`; `CursorLineNr` ≥ `PRIMARY`; and `cr(CursorLineNr.fg, normal_bg()) > cr(LineNr.fg, normal_bg())` as a strict ordinal comparison (FR-009, FR-010, FR-011; SC-004, SC-005)
- [X] T020 [US2] Add to `nvim/lua/tests/highlight_emphasis_smoke.lua` a case asserting all three relative groups hold the **same** foreground, so a split value cannot make the column look inconsistent when the cursor crosses the wrap point (contract §A invariant)
- [X] T021 [US2] Run the suite and confirm the three `LineNr*` cases fail at ~1.56 while the `CursorLineNr` and ordinal cases pass. **Recorded**: `LineNr` fails at **1.5563526828985** against a floor of 3.0; `LineNrAbove` and `LineNrBelow` hold the identical `#3b4261` so both fail identically. `CursorLineNr` passes at 7.16, the ordinal comparison passes (7.16 > 1.56), and the same-foreground invariant passes since all three already match. All 27 US1 assertions stayed green throughout, confirming US2's red phase did not disturb US1

### Implementation for User Story 2

- [X] T022 [US2] [R§A] Add to the same `on_highlights` hook in `nvim/plugin/editor.lua` the three §A overrides — `LineNr`, `LineNrAbove`, `LineNrBelow` each `fg = '#7aa2f7'` — and do **not** touch `CursorLineNr` (contract §A invariant; [spec.md](spec.md) Out of Scope)
- [X] T023 [US2] Re-run the suite: every case in the file green, exit 0 (SC-004, SC-005)
- [X] T024 [P] [US2] Confirm `nvim/lua/config/options.lua` is untouched — `number`, `relativenumber` and `cursorline` keep their current values, so the column's width, alignment and the cursor line number's separate column position are unchanged (FR-013)

**Checkpoint**: User Stories 1 AND 2 both independently functional. The two reported halves of
issue #95 are both addressed and both measurable.

---

## Phase 5: User Story 3 - The emphasis holds everywhere and never costs me readability (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---the-emphasis-holds-everywhere-and-never-costs-me-readability-priority-p2)

**Goal**: The emphasis is present on first draw, survives a runtime colorscheme change, and nothing
that was readable before became less readable.

**Independent Test**: Restart, switch colorschemes away and back, open several windows, and confirm
the emphasis is present everywhere while syntax colors, comments, the statusline and the sign column
look exactly as before ([quickstart.md](quickstart.md) §5.3–§5.5).

### Tests for User Story 3

- [ ] T025 [US3] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` a **colorscheme-survival** case: capture `LineNr` and `BufferLineBufferSelected`, run `:colorscheme habamax` then `:colorscheme tokyonight`, and assert both groups hold the configured values (`#7aa2f7`; `#e0e2ea` on `#2d3f76`) rather than another colorscheme's. This is the case a startup-only implementation fails while every other case still passes (FR-017, SC-011; [research.md](research.md) R-0005)
- [ ] T026 [P] [US3] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` a **frozen-concerns** case asserting `Normal`, `Comment` and `String` are byte-identical to the values a bare `tokyonight` `moon` load produces, so a later palette edit cannot quietly pass (FR-015, SC-009; contract "What this contract must NOT change")
- [ ] T027 [P] [US3] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` an **option-invariance** case asserting `vim.o.number`, `vim.o.relativenumber` and `vim.o.cursorline` still hold the values they held before the change (FR-013, FR-016)
- [ ] T028 [US3] Append to `nvim/lua/tests/highlight_emphasis_smoke.lua` a **uniformity** case asserting no buffer is excluded from the emphasis — read the groups on an ordinary file buffer, a `nofile` drawer and a query-result buffer, and assert the emphasis is global rather than per-filetype (FR-014)
- [ ] T029 [US3] Verify the emphasis is present on the **first** draw after a normal start, with no manual step: `nvim --headless -u nvim/init.lua '+quitall'` exits 0 and a second headless run reading `LineNr` immediately after startup already reports `#7aa2f7` (FR-016, SC-010)
- [ ] T030 [US3] Verify the reduced-color path: `nvim --headless -u nvim/init.lua --cmd 'set notermguicolors' '+quitall'` exits 0 with no error. No code is expected here — only `fg`/`bg` are emitted, so Neovim maps them to the terminal's capability (FR-022; [research.md](research.md) R-006)
- [ ] T048 [US3] Add the §5.6 window-focus walkthrough to [quickstart.md](quickstart.md) §5, and hand it to the developer with T041: two or more windows, ten `<C-w>w` focus changes, confirming the full emphasis follows the focused window in 10 of 10 and that a tab selected in a non-focused window stays distinguishable from an ordinary inactive tab in 10 of 10. This is the only multi-window criterion in the specification and the only place `BufferLineBufferVisible` is exercised (FR-006, SC-007)
- [ ] T049 [US3] Add the §5.7 editor-mode walkthrough to [quickstart.md](quickstart.md) §5 and hand it to the developer with T041, and add a headless **mode-invariance** case to `nvim/lua/tests/highlight_emphasis_smoke.lua`: enter normal, insert, visual and command-line mode in turn and assert `LineNr`, `CursorLineNr` and `BufferLineBufferSelected` resolve to the same values in each — Neovim's mode-scoped variants must not silently override them. The headless half proves the color is stable; the manual half proves the reading is (FR-012)

**Checkpoint**: User Stories 1–3 all functional. The emphasis holds across restarts, colorscheme
changes, editor modes, windows and buffer types, and nothing else in the editor moved.

---

## Phase 6: User Story 4 - I can see where these colors come from and change them (Priority: P3)

**Story Link**: [US4 in spec.md](./spec.md#user-story-4---i-can-see-where-these-colors-come-from-and-change-them-priority-p3)

**Goal**: `nvim/README.md` states what decides the number column's and the buffer row's appearance,
where to change it, its effect, how to verify it, and how to roll it back.

**Independent Test**: Make a color change using only what the documentation says, and confirm the
documented validation commands report success.

- [ ] T031 [US4] Add a subsection to `nvim/README.md` under `## Statusline and Bufferline` whose **purpose** is to state what decides the number column's and the buffer row's appearance and how to change it: the source of truth is the `tokyonight` `on_highlights` hook in `nvim/plugin/editor.lua`, the 13 groups it owns, the two thresholds (4.5 and 3.0) and that `BufferLineBuffer` is the invariant that tightens if the active background is raised again. Name `specs/012-line-number-buffer-highlights/contracts/highlight-contract.md` as the full contract, including its change protocol (FR-021, FR-023; constitution XIV)
- [ ] T032 [P] [US4] In the same subsection of `nvim/README.md`, document the reduced-color behavior — the change sets only `fg`/`bg`, so colors degrade to the terminal's capability and nothing errors (FR-022)
- [ ] T033 [US4] In the same subsection of `nvim/README.md`, document **rollback** as an ordinary `git revert` with nothing to restore, unlink or re-seed, since the change creates and replaces no file (constitution X, FR-023; [research.md](research.md) R-0010)
- [ ] T034 [US4] Add the new smoke test to the `### Validation` block of `nvim/README.md` beside the existing `specs/011` and `specs/009` entries, keeping that block's per-test `-u NORC` / `-u nvim/init.lua` split exactly as it stands — this test needs `nvim/init.lua` (constitution XII, FR-023)
- [ ] T035 [US4] Review each documentation claim against observed behavior and confirm 0 discrepancies — in particular that the documented `LineNr` value and the documented active-tab pair are the values the suite asserts (SC-013)
- [ ] T046 [US4] In the same `nvim/README.md` subsection, state the four Module README gate items that do not apply to this change **as explicit "none" statements with their reason**, rather than omitting them: **prerequisites** (none — both plugins ship with this configuration), **manual activation** (none — the hook runs during `colorscheme`, there is nothing to call by hand), **installer support** (none — no file is installed, linked or copied), and **manual-only operations** (none for the change itself; the interactive walkthrough in [quickstart.md](quickstart.md) §5 is a validation step, not an operation the configuration requires). Each line must name *why*, so a later reader can tell "not applicable" from "forgotten" (constitution XIV, FR-023)
- [ ] T047 [US4] In the same `nvim/README.md` subsection, add **customization boundaries** — the change owns exactly the 13 highlight groups in the contract; changing the active background raises the bar `BufferLineBuffer` must clear (3.47 against a 3.0 floor), so those two values must be changed together; `CursorLineNr` is out of scope and must not be recolored to satisfy the others — and a **troubleshooting** entry for the symptom "my change did not take effect": confirm the value lives in the `on_highlights` hook and not in a local override, and note that `nvim/nvim-pack-lock.json` is unrelated to appearance (constitution XIV, FR-023)

**Checkpoint**: All four user stories functional, and the documentation describes them accurately.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Obligations and checks that affect more than one story.

- [ ] T036 [P] Run `stylua --check nvim` and fix formatting drift in the changed files only, leaving unrelated files alone
- [ ] T037 Re-run the whole of [quickstart.md](quickstart.md) §8 plus §3 and §6 after the change, with **0 failures** — this is SC-012 and FR-026, and a task is not complete until its test is green
- [ ] T038 [P] Scan the full diff for user-specific absolute paths, credentials, tokens, private keys or real local secrets — the change is eleven hex literals and must stay that way (FR-025, FR-024; SC-014; constitution VII). Separately, assert **module confinement** with `git diff --name-only main...HEAD`: every changed path must be under `nvim/`, with nothing in the terminal emulator, multiplexer, shell, keyboard or installer subtrees, and no file outside this repository required to get the result (FR-019, FR-020; constitution IV)
- [ ] T039 [P] Confirm no dependency was added, no keymap added, removed or rebound, no autocmd and no user command introduced (FR-016, FR-018; constitution VI). This is the dependency half of **SC-014** (0 new dependencies, 0 user-specific absolute paths; T038 is the path half). **Authorized deviation**: `nvim/nvim-pack-lock.json` *is* modified in this branch, by explicit owner decision — `plenary.nvim` was already declared in `nvim/plugin/editor.lua` via `add {}` but missing from the committed lock, so every headless startup re-materialised it and left the tree dirty. Commit `5ed70a5` adds the missing entry for an already-declared dependency; it introduces no new dependency, so SC-014's `0 new dependencies` still holds. Do not treat this as drift and do not revert it
- [ ] T040 [P] Confirm the R-0008 load-order defect was **not** silently fixed here: `colorscheme tokyonight` must still be the last line of `nvim/plugin/editor.lua`, and that deliberate decision must be visible in the diff (gate XI, [research.md](research.md) R-0008)
- [ ] T041 Hand the **four manual-only** sections of the [quickstart.md](quickstart.md) §5 walkthrough to the developer: §5.1 first-glance identification (SC-001), §5.2 redraw timing (SC-006, FR-005), §5.3 tab-set and syntax equality (SC-008, SC-009), plus the §5.6 and §5.7 sections added by T048 and T049. These need a rendered UI and a human eye, so they cannot be asserted headlessly ([research.md](research.md) R-0007). **§5.4 and §5.5 are not in this list** — reduced-color (FR-022) and colorscheme survival (FR-017) *are* asserted headlessly by T030 and T025 respectively, and their §5 steps are the manual confirmation of those same two automated cases
- [ ] T042 Commit on `012-line-number-buffer-highlights` with conventional commits, one commit per task group, never directly on `main`, and **excluding** the unrelated `nvim/lua/config/options.lua` change (constitution XIII, FR-028)
- [ ] T043 Before opening the PR, verify the change's scope fit against this spec and ask the developer whether `specs/012-line-number-buffer-highlights` and issue #95 should be closed as the completed solution; the PR links issue #95 (constitution XIII/XV, FR-028)
- [ ] T044 Verify every relative link in `tasks.md` resolves and that each user-story phase's `Story Link` points at its `spec.md` heading (FR-029, constitution XV)
- [ ] T045 [P] Decide whether R-0008's load-order defect gets its own issue, and raise it if so — it is a real bug affecting any plugin deriving colors eagerly, and it was deliberately left unfixed here
- [ ] T050 Prove the coverage's **mutation** property, which FR-027 requires and no other task checks. It carries no `[US#]` label because it spans two stories: it must run after both the US1 buffer-row overrides (T014–T016) and the US2 number-column overrides (T022) have landed. On a scratch copy of the working tree, revert the `LineNr` override and separately the `BufferLineBufferSelected` background in `nvim/plugin/editor.lua`, and confirm `nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'` exits **1** both times with the offending assertion named, then discard the copy. A suite that still exits 0 after the emphasis is removed satisfies every threshold but none of FR-027's intent, and T013/T021's one-time red phase cannot detect that (FR-027; US1 and US2)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — **BLOCKS all user stories**.
- **User Stories (Phases 3–6)**: All depend on Foundational completion.
  - US1 → US2 → US3 → US4 in priority order, or US1 → US2 → US4 with US3 folded into the Polish
    phase if the durability checks are treated as validation rather than a deliverable.
  - **US1 and US2 are serialized by file, not by dependency**: both write the same `on_highlights`
    hook in `nvim/plugin/editor.lua` and both append to the same
    `nvim/lua/tests/highlight_emphasis_smoke.lua`, so two developers cannot merge them
    concurrently. Behaviorally they are independent — [spec.md](spec.md) (Q1) records that either can
    ship alone.
  - US1 and US2 both depend on Phase 2's harness, and each one's tests must fail before its
    implementation lands.
- **Polish (Phase 7)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational. No dependency on any other story. T017's
  expectation that US2 cases still fail is what proves the independence.
- **User Story 2 (P1)**: Starts after Foundational. No behavioral dependency on US1; shares two files
  with it, so it follows US1 in execution order. Must not alter any §B or §C value.
- **User Story 3 (P2)**: Starts after Foundational and after US1 and US2, because its frozen-concerns
  and survival cases assert against **both** regions' configured values. T025 is meaningless until
  T014–T016 and T022 have landed.
- **User Story 4 (P3)**: Starts after Foundational. Documents the values US1 and US2 set, so it reads
  most accurately last; it can be drafted in parallel from
  [contracts/highlight-contract.md](contracts/highlight-contract.md).

### Within Each User Story

- Contract tests are written **and observed failing** before the implementation.
- The value table above is the implementation target; the contract file is the authority.
- Story complete before moving to the next priority.

### Parallel Opportunities

- Phase 1: T003, T005 are `[P]`.
- Phase 2: T007, T008, T009, T010 are `[P]` with T006 — they extend the same file, so they are
  ordered edits rather than concurrent writers, but none of them depends on another's **result**.
- Phase 3: T018 is `[P]` with T011–T017 (verification, different file).
- Phase 4: T024 is `[P]` with T019–T023.
- Phase 5: T026, T027 are `[P]` — separate appends, each self-contained. T029, T030 are `[P]`
  shell-level checks that need no file. T048 and T049 are sequential: both append a section to
  [quickstart.md](quickstart.md) §5, and T049 also appends a case to the smoke test.
- Phase 6: T032 is `[P]` with T031.
- Phase 7: T036, T038, T039, T040, T045 are `[P]`.
- After Phase 2, only one of US1/US2 can be in flight at a time, because of the shared files.

---

## Parallel Example: User Story 1

```bash
# Write both test groups first and watch them fail (T011, T012, T013):
Task: "Append contract §B cases (name, ordinal, bg separation, non-focused) to nvim/lua/tests/highlight_emphasis_smoke.lua"
Task: "Append contract §C cases (six diagnostic overlays) to nvim/lua/tests/highlight_emphasis_smoke.lua"
Task: "Run the suite and record which US1 cases fail; stop if a name case fails"

# Then the implementation, in the one hook (T014, T015, T016):
Task: "Add the four §B overrides to on_highlights in nvim/plugin/editor.lua"
Task: "Add the six §C overrides to the same hook in nvim/plugin/editor.lua"
Task: "Declare the shared literals, reusing the existing explorer_row local"

# Alongside, verification on other files (T018):
Task: "Confirm nvim/lua/config/buffers.lua and the bufferline option block are untouched"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (baseline, branch, contract reconciliation)
2. Complete Phase 2: Foundational (**CRITICAL** — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: confirm the §B and §C cases are green, then run the developer's
   [quickstart.md](quickstart.md) §5.1 first-glance trials. If the active tab is now unmistakable,
   this is shippable — the number column is a separate, independently shippable story per
   [spec.md](spec.md) (Q1).

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → the reported "active buffer" half is fixed
3. Add User Story 2 → Test independently → the reported "numbers" half is fixed; both halves of
   issue #95 are now closed
4. Add User Story 3 → durability proven across restarts, colorscheme changes and buffer types
5. Add User Story 4 → the change is maintainable from the module documentation
6. Each story adds value without breaking the previous ones

### Parallel Team Strategy

With two developers, the shared files prevent concurrent merges, so the useful split is by
**phase**, not by story:

1. Developer A completes Setup + Foundational (T001–T010)
2. Developer B takes User Story 4's documentation in parallel — it reads from
   [contracts/highlight-contract.md](contracts/highlight-contract.md) and touches only
   `nvim/README.md`, so it does not conflict
3. Developer A then runs US1 → US2 → US3 in order, and Developer B reviews the diff against the
   contract as each lands

---

## Notes

- A task marked `[P]` means different files, no dependencies. Tasks that append to the **same**
  file are deliberately **not** marked `[P]`, even where their results are independent — two writers
  to one file is a merge conflict, not a parallel opportunity.
- A task marked `[US#]` maps to the linked story phase; update the phase `Story Link` if the spec
  heading changes.
- Each user story should be independently completable and testable.
- Verify tests fail before implementing. T013 and T021 are the two places this is checked.
- Commit after each task or logical group on a feature branch, never directly on `main`. The
  unrelated `nvim/lua/config/options.lua` change stays uncommitted (T002, T042).
- Before creating a PR, verify whether the active spec is related to the PR and ask whether a
  related completed spec should be closed (T043).
- Every affected maintained module must have a README with purpose, source-of-truth files,
  prerequisites, manual install/activation, installer support, validation, customization
  boundaries, rollback/recovery, and manual-only operations — for this feature that is
  `nvim/README.md` only (Phase 6).
- Stop at any checkpoint to validate story independently.
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence.
