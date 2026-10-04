# Implementation Plan: Line Number and Active Buffer Emphasis

**Branch**: `012-line-number-buffer-highlights` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/speckit.specify` — issue
[#95](https://github.com/aogallo/dotfiles/issues/95)

## Summary

Give the two pieces of the editor chrome the developer reported as weak a visible, measured,
documented treatment: the relative numbers in the left column (measured at **1.56:1**, far below
any legibility floor) and the active buffer's name in the buffer row.

**Technical approach** — extend the `tokyonight` `on_highlights` hook already present at
`nvim/plugin/editor.lua:150-171` with two groups of overrides: the three number-column groups
(`LineNr`, `LineNrAbove`, `LineNrBelow` → `#737aa2`) and a small set of buffer-row groups that give
the active tab a real background (`#2f334d`) alongside its already-strong name, plus a distinct
treatment for a buffer selected in a non-focused window. No new plugin, no autocmd, no user
command, no keymap, no option.

**The finding that shaped the design** ([research.md](research.md) R-0002): the active buffer's name
is **already** at 13.99:1 against 7.08:1 for inactive tabs — above the 1.5× floor SC-002 sets. A
change justified only by SC-002 would be a no-op that reported success while the complaint
persisted. The real gap is that the active tab's *background* separates from the inactive background
by only 1.05:1, so the tab **region** carries no signal and the name works alone. The fix therefore
raises the background, which is what finally satisfies FR-001's "at least two independent visual
ways".

**Verified end-to-end**, read back from a running editor rather than predicted
([research.md](research.md) R-0003):

| Requirement | Measured | Floor | |
|---|---|---|---|
| relative numbers legible (SC-004) | 3.67:1 | 3.0 | PASS |
| cursor line number (SC-005) | 7.16:1 | 4.5 | PASS |
| ordinal order preserved (FR-010) | 7.16 > 6.07 | — | PASS |
| active name (SC-002) | 8.28:1, 3.30× inactive | 4.5, 1.5× | PASS |
| inactive floor (SC-003) | 3.47:1 | 3.0 | PASS |
| selected region reads as selected | 1.70:1 | 1.3 | PASS |
| non-focused window distinguishable (FR-006) | 2.33:1 vs inactive; 1.58:1 vs selected | 1.25 / 1.3 | PASS |
| diagnostics on the active tab (FR-008) | worst 6.47:1 | 4.5 | PASS |

## Technical Context

**Language/Version**: Lua 5.1 (LuaJIT) · Neovim 0.12.1 (`nvim --version`, measured)

**Primary Dependencies**: `folke/tokyonight.nvim` (colorscheme, already pinned in
`nvim/nvim-pack-lock.json`) · `akinsho/bufferline.nvim` (buffer row, already pinned) · Neovim core
`nvim_get_hl` / `nvim_set_hl` / `nvim_exec_autocmds` for verification. **No new dependency**
(FR-018).

**Storage**: N/A — no persisted state. The appearance is a configuration value, not data.

**Testing**: the repository's per-concern smoke test convention —
`nvim --headless -u nvim/init.lua -c 'lua require("tests.<name>_smoke")' -c 'qa!'`
(§7 of [quickstart.md](quickstart.md)); plus `stylua --check nvim`, a headless start, and the full
existing smoke suite; plus an interactive walkthrough for the four criteria a headless run cannot
assert (§5 of quickstart).

**Target Platform**: macOS on Apple Silicon and Intel (the repository's only supported platform;
no platform branch in this change — R-0009)

**Project Type**: dotfiles / editor configuration (no build, no runtime service)

**Performance Goals**: not applicable — two highlight definitions. The one measurable non-functional
requirement is that the number column not reflow (FR-013), which holds because no column-width
option is touched.

**Constraints**: must not alter syntax highlighting or any other colorscheme decision (FR-015); must
survive `:colorscheme` at runtime (FR-017); must not change which tabs exist, their order or their
names (FR-007); must not add a dependency or a user-visible command (FR-018, FR-016).

**Scale/Scope**: 2 highlight groups of primary interest (`LineNr` family, `BufferLineBufferSelected`
family) plus 8 secondary buffer-row groups; 1 source file edited (`nvim/plugin/editor.lua`), 1 new
test file, 1 README updated. ~15 lines of configuration.

## Constitution Check

*GATE: evaluated before Phase 0 research and re-evaluated after Phase 1 design. Result below is the
post-design evaluation.*

| Gate | Applicable | Plan | Status |
|---|---|---|---|
| **I. Portable by Default** | yes | `nvim/plugin/editor.lua` has no absolute paths; the change adds hex literals to an existing hook. Identical on Apple Silicon and Intel. No local/private/work override is created, so the source-of-truth split is unchanged (R-0009). | PASS |
| **II. Idempotent Installation** | no | Not an installer. Installing, updating and removing are unaffected — no file is generated, linked or copied. | N/A |
| **III. Non-Destructive Operations** | no | No user-owned file is read, written, replaced or backed up. The change edits repository-managed source only (R-0010). | N/A |
| **IV. Modular Tool Boundaries** | yes | Confined to `nvim/`. No other module is read or written; the change needs no terminal emulator, multiplexer, shell or installer component (FR-019). | PASS |
| **V. Repository as Shared Source of Truth** | yes | The colors are stated in shared repository configuration, not in a local override, and not generated. FR-021 requires the mechanism to be documented so an intentional override is distinguishable from an accidental one. | PASS |
| **VI. Reproducible Dependencies** | yes | No dependency is added (FR-018). Both plugins involved are already declared and pinned in `nvim/nvim-pack-lock.json`; verification runs the existing suite rather than a new toolchain. | PASS |
| **VII. Security and Secret Hygiene** | yes | The change is eleven hex color literals. No credential, token, key, personal identifier or local secret is introduced (FR-025). | PASS |
| **VIII. Verification Before Completion** | yes | See the Verification gate row. | PASS |
| **IX. Clear Installer Experience** | no | No installer command is added or changed. | N/A |
| **X. Recovery and Rollback** | yes | Rollback is an ordinary repository revert; no backup, unlink or interrupted-install path exists because nothing is created or replaced (R-0010). Recorded in the module README (FR-023). | PASS |
| **XI. Simplicity and Maintainability** | yes | Two highlight groups plus eight secondary ones, added to a hook that already exists for exactly this purpose. No framework, no abstraction, no new file in the source tree. The alternative — moving `colorscheme` above `add{}` — was rejected as *less* maintainable because it leaves the appearance implicit and coupled to bufferline's internal `tint()` derivation (R-0002, R-0008). | PASS |
| **XII. Documentation and Governance** | yes | The module `README.md` is updated in the same change: what decides the number column and the buffer row appearance, where to change it, its effect, the validation commands, and rollback (FR-023). This plan evaluates every applicable gate above and is re-evaluated post-design, as required. | PASS |
| **XIII. Feature Branch and PR Discipline** | yes | Implementation is planned for branch `012-line-number-buffer-highlights`, not `main`, with conventional commits. The PR links issue #95. Before the PR is created, the active specification is checked against scope and the developer is asked whether this spec closes as the completed solution for #95 (FR-028). | PASS |
| **XIV. Module README Contract** | yes | `nvim/README.md` is updated in the same change — purpose, source-of-truth files, prerequisites, manual activation, installer support, validation commands, customization boundaries, rollback, manual-only operations (FR-023). | PASS |
| **XV. Spec Artifact Navigation** | yes | `tasks.md` will carry a visible marker legend and link each user-story phase to its matching `spec.md` heading; setup, foundational, polish and convergence phases stay unlinked (FR-029). This plan links to [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [quickstart.md](quickstart.md) and [contracts/highlight-contract.md](contracts/highlight-contract.md) by relative link. | PASS |

**Complexity Tracking**: no violations, so the table is intentionally empty.

### Verification gate — concrete commands

Per Principle VIII, the plan names the checks rather than asserting the work is verified:

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'
# plus the full existing suite: buffer_visibility, db_connections, db_context, db_jump,
# db_objects_save, db_objects_scope, db_results, formatter_chains, keymap_groups,
# markdown_whitespace, no_formatter_warning, sybase_adapter, sybase_objects
```

The new smoke test asserts every numeric threshold in the table above and fails if a later change
removes the emphasis (FR-027). The four criteria a headless run cannot assert — first-glance
identification, redraw timing, tab-set equality, and the visual walkthrough — are in
[quickstart.md](quickstart.md) §5, following the precedent of `specs/011` §5 and `nvim/README.md:241`
(R-0007).

**Re-evaluation after Phase 1 design**: all fifteen gates re-checked against
[data-model.md](data-model.md) and [contracts/highlight-contract.md](contracts/highlight-contract.md).
Still no violations. The design added no file, no module and no interface beyond the highlight
contract; it stayed inside the existing hook, so gates II, III and IX remain N/A and gate XI is
strengthened rather than strained.

## Project Structure

### Documentation (this feature)

```text
specs/012-line-number-buffer-highlights/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output — measurements R-0001..R-0010
├── data-model.md        # Phase 1 output — the entities and their contrast invariants
├── quickstart.md        # Phase 1 output — validation runbook (§5 interactive, §6 probe, §7 smoke)
├── contracts/
│   └── highlight-contract.md   # Phase 1 output — the highlight-group contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

Only one existing source file is modified and one file is added. Everything else is documentation
under `specs/`.

```text
nvim/
├── plugin/
│   └── editor.lua                    # MODIFIED: tokyonight on_highlights gains the overrides
│                                     #   (R-0003 palette, R-0004 visible group)
├── lua/
│   ├── config/
│   │   ├── options.lua               # untouched: number/relativenumber/cursorline stay (FR-013)
│   │   └── buffers.lua               # untouched: buffer-visibility guard unaffected (FR-007)
│   ├── tests/
│   │   └── highlight_emphasis_smoke.lua   # ADDED: contrast + ordinal + survival assertions
│   └── ...                           # untouched: no other module
├── README.md                         # MODIFIED: appearance, source of truth, validation, rollback
└── stylua.toml                       # untouched
```

**Structure Decision**: the existing single-module `nvim/` layout, unchanged. The change is
configuration — eleven hex literals inside a hook that already exists in
`nvim/plugin/editor.lua:150-171` — so there is nothing to restructure. No new source directory, no
new module boundary. The one new source file is a test, which the repository already keeps in
`nvim/lua/tests/` (`nvim/README.md:115` names that directory as the home of the regression tests).

Deliberately **not** introduced: a dedicated highlights module (a new file and a new load point for
eleven literals that belong next to the other twelve overrides already in that hook — gate XI),
and moving `colorscheme tokyonight` above the `add{}` block (R-0008: correct in isolation, but it
leaves this feature's appearance implicit and coupled to bufferline's internal derivation, and it
belongs in its own issue).

## Phase 0 → Phase 1 map

| Plan artifact | Contents |
|---|---|
| [research.md](research.md) | R-0001 the number defect (1.56:1) · R-0002 **the bufferline premise is false; the background is the gap** · R-0003 the verified palette · R-0004 the non-focused-window defect · R-0005 override survival · R-0006 reduced-color terminals · R-0007 the verification surface · R-0008 load order out of scope · R-0009 portability · R-0010 rollback |
| [data-model.md](data-model.md) | the five entities, their contrast invariants, and the measured baseline each one must clear |
| [contracts/highlight-contract.md](contracts/highlight-contract.md) | the 13 highlight groups, their exact values, the mechanism, and the invariants a change must preserve |
| [quickstart.md](quickstart.md) | §5 interactive walkthrough · §6 the contrast probe · §7 the smoke test · §8 the full validation suite |