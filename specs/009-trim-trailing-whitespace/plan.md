# Implementation Plan: Trailing Whitespace Cleanup + Database Context Indicator

**Branch**: `009-trim-trailing-whitespace` | **Date**: 2026-09-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-trim-trailing-whitespace/spec.md`

## Summary

Two independent features, one specification (the user chose to keep them together; the tradeoff is
recorded in the spec's clarification session and in the checklist notes).

**Track A — trailing whitespace (US1, US2, US3).** The save-time cleanup already works. This track
makes the guarantee real instead of accidental: the Markdown chain that a project configuration
routes to a different formatter gains the whitespace fallback, and a save with nothing available to
run reports the file type on every attempt instead of once per session. The hard-break exception is
documented, and a regression check locks the behavior in.

**Technical approach**: move the chain selection into a loadable module so it can be verified
offline, extend the project-routed chain with the existing whitespace steps behind
`stop_after_first`, and add one notification-only save check that reuses the formatting tool's own
availability query.

**Track B — database context indicator (US4).** A status-line element shows the database a query
will run against, taken from the buffer's connection, and marks the buffer when its own text changes
that database. The same check runs once at execution time as a warning that never blocks the query.

**Technical approach**: a new module owns "which database is this buffer talking to", including the
URL-to-database derivation that the query path already uses, so the two cannot disagree. The
status-line element is a thin rendering of that module, and the execution check listens to the
pre-execution event the query tool already emits.

## Technical Context

**Language/Version**: Lua (LuaJIT) on Neovim 0.12.1; Vimscript only in the database adapter, which
this feature does not modify.

**Primary Dependencies**: `stevearc/conform.nvim` (save-time formatting; version pinned in
`nvim/nvim-pack-lock.json`), `nvim-lualine/lualine.nvim` (status line), `tpope/vim-dadbod`
(pre-execution event source), and this repository's own `config.db_objects`, `config.db_results` and
`notifications` modules.

**Storage**: N/A. Nothing is persisted; every value is derived from the buffer and its connection on
demand. No registry, cache or state file is introduced.

**Testing**: headless Neovim smoke tests under `nvim/lua/tests/*_smoke.lua`, each run in isolation
with `nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'`; `stylua --check nvim` for
formatting; `nvim --headless -u nvim/init.lua '+quitall'` to prove the real configuration boots.

**Target Platform**: macOS on Apple Silicon and Intel; Neovim 0.10 or newer. No platform-specific
behavior is introduced and no absolute path is hardcoded.

**Project Type**: dotfiles / editor configuration for a single user, with an offline-verifiable
module boundary.

**Performance Goals**: the status-line element performs no server call and no expensive scan; the
buffer-text scan is linear in the number of lines and runs on render, so it must stay under a
millisecond for a query-sized buffer. No measurable change to save latency.

**Constraints**: no new runtime dependency (FR-015); no new configuration file; the status line and
any message never expose a connection URL, because a URL can carry credentials; nothing may run a
server round trip while rendering; the indicator never blocks a query.

**Scale/Scope**: 1 new database-context module, 1 new chain-selection module, 1 status-line element,
1 pre-execution listener, 1 save-time notification check, 2 new smoke tests, 2 chain changes, and
the module documentation. Live-server scenarios stay manual.

## Constitution Check

*GATE: evaluated before Phase 0 research and re-evaluated after the Phase 1 design.*

| Principle / gate | How this plan satisfies it |
| --- | --- |
| I. Portable by Default | No path is hardcoded. Formatter availability is resolved through the plugin's own executable lookup, so a machine without `prettier` behaves as specified instead of erroring. Both architectures behave identically. |
| II. Idempotency | The new save check is created in its own augroup with `clear = true`, so re-sourcing the configuration cannot stack checks. Chain selection is a pure function of the buffer. |
| III. Non-Destructive | No file is rewritten by this feature. The only content change is trailing whitespace, only when the fallback is the only available mechanism, and never on a line the formatter handles. |
| IV. Modular Tool Boundaries | Changes stay inside the Neovim module. The new database-context module is required by the database plugin file and by nothing else; the indicator is absent, not broken, when its dependencies are missing. |
| V. Repository as Source of Truth | All files are repository-managed. No generated file, no local override, no secret. The connection registry stays ignored and untouched. |
| VI. Reproducible Dependencies | No dependency is added or upgraded. Formatter availability is reported, never installed, which is the existing documented behavior. |
| VII. Security and Secret Hygiene | The status line and every message carry the database name only, never the URL, because a Sybase URL can embed a password. The notification check reports the file type only, never content. |
| VIII. Verification Before Completion | Two new offline smoke tests plus the existing eight, `stylua --check nvim`, and a real-configuration boot. Failure paths are covered: missing main formatter, no formatter at all, conflicting query text, absent connection. |
| IX. Clear Installer Experience | Both new messages are actionable: one names the file type that has no formatter, the other names the two databases a query will span. Neither is an error the user cannot act on. |
| X. Recovery and Rollback | Each track is a small, self-contained commit. Reverting removes the element and the checks with no residual state, no written file, and nothing to clean up. |
| XI. Simplicity and Maintainability | Two new modules, each with one responsibility; one of them exists only so the chain selection is testable offline. No framework, no abstraction layer, no new dependency. The alternative of a custom hard-break-aware formatter was rejected as more code for a narrower payoff. |
| XII. Documentation and Governance | `nvim/README.md` is updated in the same change: behavior table, validation commands, customization notes, and the hard-break degradation. |
| XIV. Module README Contract | `nvim/README.md` is the module README for `nvim/`, and this change alters module behavior, validation, and user-facing configuration, so it is mandatory and included in the task list. |
| XV. Spec Artifact Navigation | `tasks.md` will carry a marker legend and link each user-story phase to its heading in `spec.md`; setup, documentation, and convergence phases stay unlinked. |
| XIII. Branch/PR Discipline | Work is already on `009-trim-trailing-whitespace`; commits are conventional and land on that branch. PR #91 links the approved issue #90. No commit targets `main`. |

**Post-design re-evaluation**: the design added no new principle obligation. The one item that
needed a second look was the security gate: the first draft of the component would have rendered the
connection URL, which is a credential risk, so the contract fixes the database name as the only
rendered value ([contracts/db-indicator.md](contracts/db-indicator.md) section 2 rule 5). Verified
satisfied.

**Result**: PASS. No violation requires the Complexity Tracking table.

## Project Structure

### Documentation (this feature)

```text
specs/009-trim-trailing-whitespace/
├── spec.md              # requirements for both tracks
├── plan.md              # this file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── db-indicator.md        # status-line and execution-message contract
│   └── whitespace-fallback.md # save-time guarantee and failure-reporting contract
├── checklists/
│   └── requirements.md  # 16/16 quality items
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── plugin/
│   ├── conform.lua                  # chain config: uses config.formatter_chains; notify guard
│   ├── database.lua                 # calls db_context.setup() next to existing setups
│   └── editor.lua                   # status line: the new element in lualine_y
├── lua/
│   ├── config/
│   │   ├── formatter_chains.lua     # NEW: which chain a buffer uses
│   │   ├── db_context.lua           # NEW: buffer -> database, switch, label, message
│   │   ├── db_objects.lua           # requires db_context for the shared URL derivation
│   │   └── db_results.lua           # unchanged
│   ├── notifications.lua            # reused for both messages
│   └── tests/
│       ├── formatter_chains_smoke.lua  # NEW
│       └── db_context_smoke.lua        # NEW
└── README.md                        # module README, updated in the same change
```

**Structure Decision**: both new modules live in `nvim/lua/config/` beside the database modules they
sibling with, and are loaded the same way: required from a `plugin/` file at boot. No module depends
on another except the two intended edges — `db_objects` → `db_context` for the shared URL
derivation, and `plugin/conform.lua` → `formatter_chains` for the chain selection. The indicator is a
rendering of `db_context`, not a second source of truth, and the save check is a rendering of the
formatting tool's own availability query, not a second formatter.

## Known trade-off to carry into implementation

FR-004 (preserve two-space Markdown hard breaks) and FR-007 (trim even when the main formatter is
missing) cannot both hold in the same save. The fallback whitespace step trims trailing spaces
bluntly, so on a machine without the main formatter, a Markdown document's two-space prose hard
breaks are flattened. This is pre-existing behavior for the non-project chain, and this plan extends
it to the project-routed chain for consistency instead of adding a second mechanism. It is recorded
in [contracts/whitespace-fallback.md](contracts/whitespace-fallback.md) section 2, in
[research.md](research.md) Decision 1, and it needs a human decision if the user wants hard breaks
preserved unconditionally, which would mean a hard-break-aware trim step and a relaxation of FR-009.

## Complexity Tracking

> No constitution violation was found, so nothing is tracked here. The one rejected complexity — a
> hard-break-aware formatter — is recorded in [research.md](research.md) Decision 1 with its
> rationale, and the one narrowed requirement (the hard-break exception in the fallback path) is
> recorded in the Known trade-off section above.
