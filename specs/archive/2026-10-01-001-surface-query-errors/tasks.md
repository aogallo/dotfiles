---

description: "Task list for Surface Query Errors"
---

# Tasks: Surface Query Errors

**Input**: Design documents from `specs/archive/2026-10-01-001-surface-query-errors/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: REQUIRED for this change. The Constitution (VIII) and FR-032 require coverage for a rejected query, each
ordinary SQL shape, every cross-database warning form, a failed database check, and a legitimate zero-row result, with
no failing check at completion. Existing smoke suites are the regression gate.

**Organization**: Tasks are grouped by user story. US2 and US4 share one phase because D-0005 measured them as coupled
(fixing the text scan alone regresses the cross-database warning). Every user-story phase links to its matching heading
in [spec.md](spec.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable — touches different files or has no dependency on incomplete work.
- **[US#]**: User-story marker; the phase's Story Link points to the matching `spec.md` heading.
- Include exact file paths in every task description.

## Path Conventions

- Neovim module at repository root: `nvim/lua/config/`, `nvim/autoload/db/adapter/`, `nvim/lua/tests/`, `nvim/README.md`.
- Run a smoke suite with `nvim --headless -u NORC -c 'lua require("tests.<name>_smoke")' -c 'qa!'` (keep the `_smoke` suffix).
- Formatting gate: `stylua --check nvim`.

## Marker Legend

| Marker | Plan phase | Spec heading |
|---|---|---|
| [US2] | Phase 1 | [User Story 2 — Ordinary SQL never breaks my editor](spec.md#user-story-2---ordinary-sql-never-breaks-my-editor-priority-p1) |
| [US4] | Phase 1 | [User Story 4 — The cross-database warning still works](spec.md#user-story-4---the-cross-database-warning-still-works-priority-p2) |
| [US1] | Phase 2 | [User Story 1 — A failed query tells me it failed](spec.md#user-story-1---a-failed-query-tells-me-it-failed-priority-p1) |
| [US3] | Phase 3 | [User Story 3 — A real problem is never reported as a made-up one](spec.md#user-story-3---a-real-problem-is-never-reported-as-a-made-up-one-priority-p2) |
| [US5] | Phase 4 | [User Story 5 — Failed queries leave no confusing trace behind](spec.md#user-story-5---failed-queries-leave-no-confusing-trace-behind-priority-p3) |

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch, baseline, and prerequisites. No source change.

- [X] T001 Create the feature branch `012-surface-query-errors` from an up-to-date `main` (FR-035)
- [X] T002 [P] Record the baseline: run all nine smoke suites in `nvim/lua/tests/` (`sybase_objects`, `sybase_adapter`, `db_results`, `db_context`, `db_objects_scope`, `db_objects_save`, `db_jump`, `db_connections`, `buffer_visibility`) and `stylua --check nvim`; confirm all green before any change
- [X] T003 [P] Confirm prerequisites on `PATH`: `nvim --version` reports 0.12.1, vim-dadbod is present at `~/.local/share/nvim/site/pack/core/opt/vim-dadbod`, and `stylua` is available

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The per-run record and single notice path that US1 and US5 both consume. Both tasks are in the module that
already owns per-run result state (`nvim/lua/config/db_results.lua`).

**⚠️ CRITICAL**: Complete before any user-story phase.

- [X] T004 Extend the per-session `slot` in `nvim/lua/config/db_results.lua` to expose the finished run's output path and retain its full response lines, adding `M._current_slot()` and `M._store(slot, outcome)` per [contracts/query_diagnostics.lua.md](contracts/query_diagnostics.lua.md); document each with the module's Purpose/Called by/SQL/Args/Returns/Side effects header (FR-005, FR-025)
- [X] T005 Add `M._notify_once(slot, outcome)` in `nvim/lua/config/db_results.lua`, keyed on output path plus complaint text, so US1 and US5 share one deduplicated notice path (FR-027)

**Checkpoint**: Run-slot access and notice dedup exist; user-story phases can begin.

---

## Phase 3: User Story 2 + User Story 4 - Ordinary SQL never breaks the editor, and the cross-database warning still works (Priority: P1/P2) 🎯 FIRST DELIVERABLE

**Story Links**: [US2 in spec.md](spec.md#user-story-2---ordinary-sql-never-breaks-my-editor-priority-p1) · [US4 in spec.md](spec.md#user-story-4---the-cross-database-warning-still-works-priority-p2)

**Goal**: Any buffer text is inspected without an internal error and without discarding text, so an ordinary query runs;
and every statement form that declares another database still produces the warning.

**Independent Test**: For each ordinary SQL shape assert no internal error **and** `#out[i] == #line`; for each
cross-database form assert the same database is named; assert a literal/comment mid-line no longer aborts the
`*/DBExecutePre` command.

**Note**: US2 and US4 are fixed in one change and one test file (D-0005); splitting them ships a regression window.

### Tests for User Story 2 + User Story 4

- [X] T006 [US2] Add the FR-008 shape matrix to `nvim/lua/tests/db_context_smoke.lua`: for every shape (string literal mid-line, trailing line comment, block comment before/after code, unterminated block comment spanning lines, literal/comment as the first character, empty and comment-only buffers) assert no internal error **and** output byte length equals input; include multibyte `select 1 from t -- cafe 中文` = 30 bytes and the multi-line block state from quickstart 2.2 (FR-008, FR-012, SC-005, SC-007)
- [X] T007 [US2] Add the execution-abort regression to `nvim/lua/tests/db_context_smoke.lua`: with the `*/DBExecutePre` pattern, a literal or comment mid-line no longer prevents a later-registered listener from running (FR-010; trap documented in quickstart 1.3 — use the prefixed pattern)
- [X] T008 [US4] Add the cross-database forms to `nvim/lua/tests/db_context_smoke.lua`: `select * from a..t1` bare, with a trailing line comment, with a block comment before, with a block comment after, and as `select * from a..t1 where c = 'z'` all name `a..t1`; a `use` naming the connected database yields no warning (FR-019, FR-020, FR-021, FR-023, SC-011)

### Implementation for User Story 2 + User Story 4

- [X] T009 [US2] Rewrite `strip_noise()` in `nvim/lua/config/db_context.lua` as a single left-to-right column walk that writes every column and blanks on all four exit paths (block body, marker, unterminated literal tail, comment tail); sparse `table.concat` becomes structurally impossible and non-crashing truncation is eliminated (FR-008, FR-012)
- [X] T010 [US2] Fix the block-comment close in `nvim/lua/config/db_context.lua`: the close probe must be a pattern search, not the plain match at the current `line:find('%*/', ..., true)`, so a block comment ends on the line that closes it, including a closing line with code after it (FR-008, R-0007)
- [X] T011 [US4] Drop the `..'$'` end anchor from the `TWO_PART` match in `M.switches()` in `nvim/lua/config/db_context.lua`, so a correctly-stripped line with trailing content still yields the cross-database reference (FR-019, FR-020, FR-021, D-0004)
- [X] T012 [US2] Guard the `*/DBExecutePre` callback in `nvim/lua/config/db_context.lua` so an internal error is reported as an internal error and cannot abort the command that fired it or be reported as a server complaint (FR-010, FR-011)

**Checkpoint**: Ordinary SQL runs and the cross-database warning fires for every required form; the nine existing suites stay green.

---

## Phase 4: User Story 1 - A failed query tells me it failed (Priority: P1) 🎯 HEADLINE VALUE

**Story Link**: [US1 in spec.md](spec.md#user-story-1---a-failed-query-tells-me-it-failed-priority-p1)

**Goal**: Every route by which a query runs surfaces the server's own complaint, and a failed run is never presented as a
success.

**Independent Test**: Call `M.classify()` on fixture response arrays and drive `User */DBExecutePost` with fixture
`.dbout` files; assert a rejected query produces one notice naming the server's text, a zero-row success produces none,
and the full response stays readable.

### Tests for User Story 1

- [X] T013 [US1] Add classification and notice tests to `nvim/lua/tests/db_results_smoke.lua` using fixture `.dbout` files: one `Msg` line → one notice naming the server's own text; two `Msg` lines → both present; complaint plus partial rows → both available; zero rows and no `Msg` → success with no notice; ten distinct zero-row responses → zero reported as failures; unrecognized non-zero output → warning, never silence; a cancelled run → no failure notice; the full response readable afterwards (FR-001, FR-002, FR-003, FR-004, FR-005, FR-007, FR-012, SC-001, SC-002, SC-003, SC-004)

### Implementation for User Story 1

- [X] T014 [US1] Implement `M.classify(lines)` in `nvim/lua/config/db_results.lua` per the ordered recognition rules in [contracts/query_diagnostics.lua.md](contracts/query_diagnostics.lua.md): cancelled; any `Msg N, Level N` line → `failed` capturing **all** such lines; non-zero exit with no `Msg` → `unreadable`; otherwise `success` with `row_count` (FR-001, FR-003, FR-004, FR-007, FR-012)
- [X] T015 [US1] Implement `M.setup_diagnostics()` and extend `on_post` in `nvim/lua/config/db_results.lua` to read the output file, classify it, retain the full lines via `M._store`, and dispatch `failed`/`unreadable` through `M._notify_once`; register it from the existing `M.setup()` so the single `User */DBExecutePost` point covers every route (FR-001, FR-005, FR-006, FR-025, FR-027)
- [X] T016 [US1] Compose the notice text in `nvim/lua/config/db_results.lua` from the server's complaint text verbatim plus the originating buffer, never rewriting it and never rendering a connection URL (FR-005, FR-014, FR-024, FR-031)

**Checkpoint**: A query the server rejects reports the complaint; a success and a failure never share a shape; US2/US4 behavior unaffected.

---

## Phase 5: User Story 3 - A real problem is never reported as a made-up one (Priority: P2)

**Story Link**: [US3 in spec.md](spec.md#user-story-3---a-real-problem-is-never-reported-as-a-made-up-one-priority-p2)

**Goal**: A check that did not complete says so and names the real reason, instead of asserting a database does not exist.

**Independent Test**: Feed the outcome selection the three **real** types (`''` String, Number `0`, Number `1`); assert
only `''` becomes `indeterminate`, and the `indeterminate` message names no cause. Drive the consumer with an
`indeterminate` confirmation and assert it reports "could not determine" and opens nothing.

### Tests for User Story 3

- [X] T017 [US3] Add the third-state tests to `nvim/lua/tests/sybase_adapter_smoke.lua`: `confirm_database()` fed the three real types — String `''` → `indeterminate`, Number `0` → `rejected_absent`, Number `1` → `rejected_forbidden`; assert the `indeterminate` message contains neither "does not exist" nor "could not enter"; assert `reason` is non-empty for all non-`confirmed` outcomes (FR-015, FR-016, FR-017, FR-018, SC-010)
- [X] T018 [US3] Add the consumer dispatch test to `nvim/lua/tests/db_objects_scope_smoke.lua`: an `indeterminate` confirmation reports "could not determine" and opens nothing; the four existing `result` values keep their messages (FR-015, FR-018)

### Implementation for User Story 3

- [X] T019 [US3] In `nvim/autoload/db/adapter/sybase.vim` `confirm_database()`: select the outcome by `type(exists)` — String `''` → new `indeterminate`, otherwise the existing numeric comparison — and add a `reason` to every return shape (FR-015, FR-016, FR-017)
- [X] T020 [US3] In `nvim/lua/config/db_objects.lua` `start_listing()`: add an explicit `indeterminate` branch before the catch-all (`report_failure('could not determine whether ... exists', ...)`) and make the catch-all report the outcome as undetermined rather than naming a cause (FR-015, FR-017)

**Checkpoint**: A probe that established nothing is never reported as a missing database; genuine absence is unchanged.

---

## Phase 6: User Story 5 - Failed queries leave no confusing trace behind (Priority: P3)

**Story Link**: [US5 in spec.md](spec.md#user-story-5---failed-queries-leave-no-confusing-trace-behind-priority-p3)

**Goal**: The full server response stays reachable byte-for-byte after a failure, partial output and the complaint are
distinguishable, editor hints are never mixed into the server text, and repeated failures do not pile up notices.

**Independent Test**: Capture a failing run's full response, assert it is still reachable in full; assert a run that
produced partial output and a complaint keeps both, distinguishable; fire the same failed run twice and assert one notice.

### Tests for User Story 5

- [X] T021 [US5] Add retention tests to `nvim/lua/tests/db_results_smoke.lua`: after a failure the full response is readable byte-for-byte; a run with partial rows plus a complaint keeps both and they are distinguishable; the editor's own hint text is never part of the stored server response (FR-014, FR-025, FR-026, SC-008)
- [X] T022 [US5] Add the dedup tests to `nvim/lua/tests/db_results_smoke.lua`: the same failed run observed twice emits one notice, and two different failing runs each get their own (FR-027, SC-013)

### Implementation for User Story 5

- [X] T023 [US5] In `nvim/lua/config/db_results.lua` keep the full response in the slot and preserve partial rows alongside the complaints in the stored outcome, so presentation distinguishes a failure from a zero-row success and never appends editor reasoning to the server text (FR-002, FR-014, FR-025, FR-026)

**Checkpoint**: All five stories independently functional; no failure is success-shaped and no server text is lost.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, repository gates, and delivery.

- [X] T024 [P] Update `nvim/README.md` with a section covering how a failed query is reported, how to read the full server response, and a troubleshooting entry for "my query failed and nothing was shown", patterned on the existing `db_context` validation block (FR-033, SC-015)
- [X] T025 [P] Run the full gate from [quickstart.md](quickstart.md): all nine existing suites plus the new coverage in `db_context_smoke.lua`, `db_results_smoke.lua`, `sybase_adapter_smoke.lua`, `db_objects_scope_smoke.lua`, then `stylua --check nvim` and `nvim --headless -u nvim/init.lua '+quitall'`; no failing check (FR-032, SC-014)
- [X] T026 [P] Re-run Part 2 of [quickstart.md](quickstart.md) and update any expected-value text that changed, so the documented reproductions match the fixed behavior (SC-015)
- [X] T027 Verify non-regression for FR-034: the close semantics and tab visibility of `specs/011-query-buffer-tab-visibility/` and the `:DBObjects` guarantees of `specs/010-dbobjects-listing-integrity/` still hold
- [ ] T028 Manual verification on Windows by the developer (FR-028): a query with a string literal does not break the status line; an invalid query names the server's complaint; a valid zero-row query does not warn; an `a..t1` reference with a trailing comment warns
- [X] T029 Commit on the feature branch with conventional messages and open a pull request linking issue #98; before opening it, review the active spec for scope fit and ask whether `specs/archive/2026-10-01-001-surface-query-errors/` should be closed as the completed solution (FR-035)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup — blocks US1 and US5.
- **US2 + US4 (Phase 3)**: Depends on Setup only; independent of the Foundational phase and of every other story.
- **US1 (Phase 4)**: Depends on Foundational; independent of US2/US4 in code, but in practice US2 must land first so a query reaches the server at all.
- **US3 (Phase 5)**: Depends on Setup only; independent of all other stories.
- **US5 (Phase 6)**: Depends on Foundational and US1 (it refines US1's outcome and notice).
- **Polish (Phase 7)**: Depends on all desired user stories.

### User Story Dependencies

- **US2 + US4 (P1/P2)**: Can start after Setup — no dependency on other stories. Coupled internally (D-0005).
- **US1 (P1)**: Can start after Foundational — no dependency on US2, US3, US4, or US5.
- **US3 (P2)**: Can start after Setup — no dependency on any other story.
- **US5 (P3)**: Depends on US1; does not affect US2, US3, or US4.

### Within Each User Story

- Tests are written first and must FAIL before implementation.
- `strip_noise()` rewrite (T009) precedes the block-close fix (T010) and the `TWO_PART` change (T011).
- `M.classify()` (T014) precedes listener wiring (T015) and notice composition (T016).
- The producer change (T019) precedes the consumer dispatch (T020).
- Story complete before moving to the next priority.

### Parallel Opportunities

- T002 and T003 in Setup run in parallel.
- After Setup, US2+US4 (Phase 3) and US3 (Phase 5) can proceed in parallel; US1 (Phase 4) can start once Foundational is done.
- T013 (US1) and T017+T018 (US3) are in different files and can run in parallel.
- T024, T025, and T026 in Polish are different files and can run in parallel.

---

## Parallel Example: User Story 3

```bash
# Test tasks touch different files and can run together:
Task: "Add third-state tests to nvim/lua/tests/sybase_adapter_smoke.lua"
Task: "Add consumer dispatch test to nvim/lua/tests/db_objects_scope_smoke.lua"
```

## Parallel Example: Polish

```bash
# Different files, no dependencies:
Task: "Update nvim/README.md with the failed-query reporting section"
Task: "Run the full gate in quickstart.md"
Task: "Re-run quickstart.md Part 2 and update expected values"
```

---

## Implementation Strategy

### MVP First (the two P1 halves)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: US2 + US4 — this unblocks query execution and is verifiable offline.
4. Complete Phase 4: US1 — this delivers the headline value: the server's complaint is shown.
5. **STOP and VALIDATE** against the US2 and US1 independent tests.

This order is deliberate (plan.md): a fix for US1 alone leaves the crash that stops the query from running, so there
would be no result to report.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. US2 + US4 → ordinary SQL runs and the cross-database warning holds.
3. US1 → failures are reported (MVP value complete).
4. US3 → no invented diagnoses in database selection.
5. US5 → the failure trace stays honest and non-duplicating.
6. Polish → docs, gates, PR.

### Parallel Team Strategy

1. Complete Setup + Foundational together.
2. Then: one developer on US2+US4, one on US3; US1 once Foundational is done.
3. US5 follows US1.

---

## Notes

- [P] tasks touch different files and have no incomplete dependency.
- [US#] tasks map to the phase's Story Link; update the link if a spec heading changes.
- Verify tests fail before implementing.
- A shape matrix that only asserts "no error" will pass a truncated implementation — assert byte-length equality (research.md).
- Commit after each logical group on the feature branch, never on `main`.
- Before creating the PR, verify the branch and that the PR links issue #98, and ask whether the active spec should be closed.
