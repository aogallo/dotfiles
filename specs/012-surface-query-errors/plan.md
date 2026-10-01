# Implementation Plan: Surface Query Errors

**Branch**: `012-surface-query-errors` | **Date**: 2026-10-01 | **Spec**:
[spec.md](spec.md) · **Issue**: [#98](https://github.com/aogallo/dotfiles/issues/98)

**Input**: Feature specification from `specs/012-surface-query-errors/spec.md`

## Summary

A developer pasting a query into this Neovim Sybase setup gets a bare
`invalid value (nil) at index 1 in table for 'concat'` when the text contains a
string literal, and after they fix the SQL the query silently does not run at all.
Independently, a query the server rejects produces no message whatsoever: the
plugin's response handling discards the server's own complaint before anything
reaches the developer.

This plan repairs both halves with a text-processing fix and a reporting fix:

1. **Make text inspection incapable of breaking the editor.** Rewrite
   `strip_noise()` in `nvim/lua/config/db_context.lua` as a single left-to-right
   column walk, which makes the sparse-table crash structurally impossible, and
   fix the two coupled defects in the same function and its pattern
   (`block comment close` and the anchored cross-database regex) that the crash
   was masking. The crash is not cosmetic: an error inside the `User */DBExecutePre`
   listener aborts dadbod's command before the job starts, so a text-inspection
   bug is blocking query execution.

2. **Make every query route report the server's response.** Add a classifier that
   reads the completed output file at `User */DBExecutePost` — the measured point
   at which the server's words are complete and on disk — and surface complaints
   through the notification path the repo already uses, reusing the `severity` and
   `reason` vocabulary already defined in the Sybase adapter.

3. **Stop a failed check from naming a cause it never established.**
   `confirm_database()` compares a Vim string to a number, so `'' == 0` is true and an
   unreadable probe is reported as "database does not exist". Add an `indeterminate`
   outcome, select it by type (the field is polymorphic), and dispatch it explicitly
   in `db_objects.lua` so no `result` value falls into an inference.

Research found **four coupled defects in one text function**, one coercion plus one
inference in the reporting layer, and one reporting gap — more than the two root
causes the spec assumed.

The first and third are independent: the first touches no database code, the second
touches no parsing code. They ship as separate phases, with the cross-database
warning path fixed together with the crash since fixing one alone regresses the
other.

## Technical Context

**Language/Version**: Lua (LuaJIT) and Vimscript, Neovim 0.12.1 — no NEEDS CLARIFICATION

**Primary Dependencies**: vim-dadbod (installed at
`~/.local/share/nvim/site/pack/core/opt/vim-dadbod`), the Sybase adapter
`nvim/autoload/db/adapter/sybase.vim`, and the repo's own `nvim/lua/config/*` and
`nvim/lua/notifications.lua`. No new dependency is introduced (Constitution XI).

**Storage**: N/A for this feature. Read-only local state: the per-session result
slot in `db_results.lua`, the in-memory buffer registry, and the temporary
`.dbout` output file dadbod already writes. Nothing is persisted and no new file
is created.

**Testing**: headless Neovim smoke suites, one Lua file per module under
`nvim/lua/tests/`, run with
`nvim --headless -u NORC -c 'lua require("tests.<name>_smoke")' -c 'qa!'`.
Formatting gate: `stylua --check nvim`.

**Target Platform**: macOS (Apple Silicon and Intel) and Windows — the developer
verifies the final behavior manually on Windows, and every path touched here is
core Neovim Lua/Vimscript with no platform-specific branch.

**Project Type**: Neovim plugin configuration (dotfiles module)

**Performance Goals**: buffer inspection stays in the editor's per-query event
path, so it must remain negligible. The rewrite is a single O(n) pass over each
line with no allocation beyond the result string; classification reads one
already-written file per completed run. No added latency is acceptable to a
query that produces no complaint.

**Constraints**:
- Do not change how queries are executed (spec Out of Scope). The fix reads
  existing output; it does not wrap the client invocation.
- Do not trim the server's response (spec Q2). The full text must stay available
  in `.dbout` and in the result buffer.
- Do not reshape failure into a success shape. Zero rows is a success; a server
  complaint is a failure; they must never share a presentation.
- Must not depend on a running server, a client binary, or credentials for tests.
- Must not depend on one particular client's error wording.

**Scale/Scope**: 2 source modules plus 1 pattern and 1 return shape
(`db_context.lua`, `db_results.lua`, `TWO_PART`, `confirm_database()`), 3
supporting test files, 1 README update. 5 user stories (P1, P1, P2, P2, P3) and
36 functional requirements.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Research is complete and this is the post-Phase-0 re-check.

- **Portability** — PASS. No path, environment, or architecture handling is
  introduced. All changes are core Neovim Lua and Vimscript with no
  user-specific absolute path, no shell invocation, and no platform branch. The
  Windows manual verification required by the developer's own plan is unaffected.
- **Idempotency** — PASS. `db_context.setup()` and the `db_results` listeners are
  already registered at plugin source time and are unchanged in registration
  shape. A re-source re-registers the same listener; no new state is created that
  a second registration would duplicate.
- **Non-destructive safety** — PASS. Nothing is overwritten, installed, or
  removed. The change reads a file dadbod has already written and reports; it
  writes nothing outside the existing result flow.
- **Modularity** — PASS. The fix is confined to the database module. No unrelated
  tool is touched, and none depends on the changed code. The classifier lives in
  `db_results.lua`, the module that already owns per-run result state, rather than
  in a new top-level module.
- **Source of truth** — PASS. Every changed file is repository-managed and
  committed. No generated file, work setting, or personal override is created.
  `.dbout` remains a transient dadbod artifact, not a repository concern.
- **Dependencies** — PASS. No new dependency. `vim-dadbod` and the Sybase adapter
  are already declared prerequisites; the fix uses only APIs they already expose.
- **Security** — PASS. No secret is read, logged, or surfaced. The classifier
  reports the server's own message text, which contains no credential, and no
  new environment variable or file permission is involved.
- **Verification** — PASS. Every claim in `research.md` was measured with headless
  probes rather than inferred, and every probe is reproduced in `quickstart.md`.
  The existing nine smoke suites are the regression gate and are green today;
  the new behavior gets its own suite per module. `stylua --check nvim` is the
  formatting gate.
- **Installer UX** — N/A. No installer operation is added or changed. The
  developer-visible UX change is the notification itself, which reuses the
  existing `notifications.notify()` path.
- **Recovery** — N/A. No install, remove, or unlink path changes. Recovery is
  `git revert` of a self-contained commit, with no partial-state to unwind.
- **Maintainability** — PASS. The design deliberately declines the more
  elaborate option: no new UI, no new state machine, no client abstraction, no
  result truncation, no telemetry. The crash fix replaces one function body with
  a single-pass loop that is shorter than the code it replaces. The reporting fix
  adds one classifier and one listener callback. The smallest thing that fixes
  the reported problem.
- **Documentation** — PASS (planned). `nvim/README.md` gains a section covering
  what a failed query now reports, how the cross-database warning behaves, and
  how to validate it, matching the format of the existing module sections
  (patterned on the `db_context` validation block at `nvim/README.md:154-158`).
  No install, update, customize, or rollback path changes, so those sections are
  not affected.
- **Module README** — PASS (planned). `nvim/README.md` is the affected module
  README and will be updated. `specs/012-surface-query-errors/quickstart.md` and
  this plan's Research section carry the validation and troubleshooting detail.
  No new maintained module directory is created, so no additional `README.md` is
  required.
- **Spec navigation** — PASS (planned). The phase structure in this plan groups
  work by the spec's five user-story headings, and `tasks.md` will carry the
  marker legend and link each story phase to its `spec.md` heading, per the
  Constitution. Two phases (Phase 0 research verification and Phase 4
  documentation) are not story-owned and will remain unlinked unless a story
  claims them.
- **Branch/PR discipline** — PASS (planned). Implementation is planned for the
  feature branch `012-surface-query-errors`, not `main`. The PR will link issue
  #98, and the closing workflow will verify the spec relationship with the active
  feature.

No MUST-level violations. **Constitution Check: PASSED** — no complexity
exceptions required, so the Complexity Tracking table below is intentionally
empty.

## Project Structure

### Documentation (this feature)

```text
specs/012-surface-query-errors/
├── spec.md              # approved specification (input)
├── plan.md              # this file
├── research.md          # Phase 0: measured findings and decisions
├── data-model.md        # Phase 1: entities, states, result shapes
├── quickstart.md        # Phase 1: reproduction and validation
├── contracts/           # Phase 1: internal interfaces
│   ├── query_diagnostics.lua.md
│   └── confirm_database.md
├── checklists/
│   └── requirements.md  # spec quality gate, 16/16
└── tasks.md             # Phase 2: /speckit.tasks output (not created here)
```

### Source Code (repository root)

```text
nvim/
├── lua/
│   ├── config/
│   │   ├── db_context.lua        # MODIFIED: strip_noise() rewrite,
│   │   │                         #   TWO_PART unanchor, listener hardening
│   │   ├── db_results.lua        # MODIFIED: classify response at
│   │   │                         #   DBExecutePost, notify once
│   │   └── db_objects.lua        # MODIFIED: dispatch 'indeterminate' in
│   │                             #   start_listing(); surface_diagnostics() precedent
│   ├── notifications.lua         # REFERENCE: existing notify() path reused
│   ├── tests/
│   │   ├── db_context_smoke.lua  # MODIFIED: FR-008 shape matrix
│   │   ├── db_results_smoke.lua  # MODIFIED: classification + notice tests
│   │   └── sybase_adapter_smoke.lua  # MODIFIED: confirm_database third state
│   └── ...
├── autoload/db/adapter/
│   └── sybase.vim                # MODIFIED: confirm_database() gains
│                                 #   'indeterminate'; compare exists as string
├── plugin/
│   └── database.lua              # REFERENCE: wiring, unchanged
└── README.md                     # MODIFIED: new validation section
```

**Structure Decision**: the existing Neovim module layout is kept as-is. Both
fixes land in the module that already owns the responsibility — text inspection in
`db_context.lua`, per-run result state and presentation in `db_results.lua` — and
the third-state outcome is added in place in the Sybase adapter and dispatched in
`db_objects.lua`, rather than in a new module, because the defect is an
inferential catch-all rather than a coercion and both halves of the vocabulary
must change for the dispatch to become exhaustive. No directory is added, moved, or renamed, and no
new Lua module is introduced: the classifier is a local function in
`db_results.lua`. Test files follow the established `nvim/lua/tests/*_smoke.lua`
convention and extend the three existing suites for the affected modules instead
of creating a new testing layout.

## Phases

Ordered by user story, per the spec's priority order. Each phase is independently
verifiable and each names the spec heading it implements.

| Phase | Story | Spec heading | Change | Gate |
|---|---|---|---|---|
| 0 | — | — | Research (complete) | `research.md` + `quickstart.md` reproduce every claim |
| 1 | US2, US4 (P1) | [User Story 2](spec.md#user-story-2---ordinary-sql-never-breaks-my-editor-priority-p1), [User Story 4](spec.md#user-story-4---the-cross-database-warning-still-works-priority-p2) | `strip_noise()` rewrite (blank on every exit path), block-close fix, `TWO_PART` unanchor | FR-008…FR-023 pass; **output length == input length** on every shape; 9 existing suites green |
| 2 | US1 (P1) | [User Story 1](spec.md#user-story-1---a-failed-query-tells-me-it-failed-priority-p1) | Classifier + `DBExecutePost` notice | FR-001…FR-007, FR-024…FR-027 |
| 3 | US3 (P2) | [User Story 3](spec.md#user-story-3---a-real-problem-is-never-reported-as-a-made-up-one-priority-p2) | `confirm_database()` gains `indeterminate`, selected by type; `db_objects.lua` dispatches it | FR-014…FR-018; the `exists == ''` message contains neither "does not exist" nor "could not enter" |
| 4 | US5 (P3) | [User Story 5](spec.md#user-story-5---failed-queries-leave-no-confusing-trace-behind-priority-p3) | Failure-shaped presentation distinct from zero rows; full response preserved; no duplicate notices | FR-014, FR-025, FR-026, FR-027 |
| 5 | — | — | `nvim/README.md` + `stylua` | Constitution Documentation gate |

Phase 1 is first because it is the defect that prevents queries from running, it
touches no database code, and it is verifiable with no server. Phases 1's two
changes ship in one commit (D-0005) because fixing the strip alone regresses the
cross-database path.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

None. The Constitution Check passed with no MUST-level violations, and the design
declined every larger option that a complexity exception would have been spent on
(new UI, result truncation, client abstraction, persistent state).
