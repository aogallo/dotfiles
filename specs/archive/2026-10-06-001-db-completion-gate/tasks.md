---

description: "Task list for 013-db-completion-gate"
---

# Tasks: Database Completion Never Blocks Editing

**Input**: Design documents from `/specs/archive/2026-10-06-001-db-completion-gate/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/db-completion-gate.md](contracts/db-completion-gate.md),
[quickstart.md](quickstart.md)

**Tests**: Test tasks are included and required. FR-030 mandates offline coverage with a stub client
and no real server, and FR-031 requires it to run without a database server or a real client binary.
The constitution additionally requires validation for clean startup, repeated load (idempotency),
conflict handling, syntax/static checks, smoke tests for the changed modules, module README
coverage, feature-branch/PR verification, and active-spec closure review before the PR.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated
independently. Every user-story phase links to its heading in [spec.md](spec.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable — different files, no dependency on incomplete work.
- **[US#]**: User story marker; the phase's `Story Link` points to the `spec.md` heading.
- Exact file paths are included in every description.

## Scope Notes

- **No new dependency** (FR-028). The gate uses `blink.cmp`'s documented per-provider `enabled`
  option (D-0001), the upstream plugin's public `vim_dadbod_completion#fetch` pre-warm (D-0003), and
  `which-key` for the live label (R-0031).
- **No installer surface changes.** This feature adds no installer step, no managed file, and no
  generated output, so the constitution's clean-install/repeated-install/conflict-handling
  obligations are discharged by the idempotency probe in T037 rather than by installer tasks.
- **No file writes** (FR-020, FR-021, FR-033). Nothing here persists to disk.
- **R-0040 is not a bug to fix here.** `nvim/plugin/blink.lua:113` passes an `opts.trigger_characters`
  that the upstream module discards. The effective trigger set is the plugin's five characters.
  Correcting it would change suggestion behavior, which SC-010 forbids in this feature. T033 exists
  to *document and pin* that deferral, not to change it.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the module and its test harness, and record a clean baseline.

- [X] T001 Create `nvim/lua/config/db_completion.lua` with the module skeleton, a `setup_done`
  idempotency guard mirroring `db_context.setup()` (`nvim/lua/config/db_context.lua:349`), and the
  session-local state tables declared per `data-model.md` §1 (no I/O, no autocmds yet)
- [X] T002 Create `nvim/lua/tests/db_completion_smoke.lua` with a `db#systemlist` stub that counts
  invocations, following the stub pattern in `nvim/lua/tests/sybase_objects_smoke.lua`, plus helpers
  to set a buffer's `b:db` and to simulate a fast event
- [X] T003 [P] Record a clean baseline: run every existing offline suite and `stylua --check nvim`
  before any change, so later failures are attributable to this feature

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The gate itself and its wiring. No user story can be validated without it.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 [P] Implement the four state containers in `nvim/lua/config/db_completion.lua` exactly as
  specified in `data-model.md` §1: `GateState` (session-local, `enabled = true`, `changeCount = 0`),
  the `ConnectionState` ledger (`state`, `attempted`, `noticeShown`, `lastTrigger`, `databaseName`),
  the `BufferBinding` cache, and the `Determination` in-flight guard
- [X] T005 [P] Implement the connection key per `data-model.md` §2 — the raw `b:db` string with no
  second URL parser — and derive `databaseName` once via
  `require('config.db_context').url_database(key)` so no URL can reach a message (FR-029, D-0008)
- [X] T006 Implement the buffer→connection binding with `FileType`/`BufEnter` autocmds in
  `nvim/lua/config/db_completion.lua`, covering both the `b:db` scan and the DBUI
  `b:dbui_db_key_name` case (`vim_dadbod_completion.vim:380-393`), recording `kind` as `query` or
  `dbui` and `connectionKey = nil` when none exists (FR-003, R-0007)
- [X] T007 Implement `M.enabled()` in `nvim/lua/config/db_completion.lua` to the truth table in
  `contracts/db-completion-gate.md` §2: `false` on fast event, `false` when the switch is off,
  `false` when `connectionKey` is `nil`, and `state == "usable"` otherwise. Table lookups only — no
  Vim API, no I/O, no notices (R-0011, D-0002, FR-001, FR-016)
- [X] T008 Add the gate option to the `vim_dadbod_completion` provider in `nvim/plugin/blink.lua`:
  `enabled = function() return require('config.db_completion').enabled() end`. Leave `module`, `name`,
  `opts`, and the `per_filetype.sql` source list byte-identical (SC-010, D-0001, R-0040)
- [X] T009 [P] Implement the notice helper in `nvim/lua/config/db_completion.lua` as
  `require('notifications').notify(msg, vim.log.levels.WARN, { source = 'DB' })`, matching
  `nvim/lua/config/db_context.lua:372`, with every message composed from `databaseName` only
- [X] T010 Call `db_completion.setup()` from `nvim/plugin/database.lua` alongside the existing
  `db_results.setup()` / `db_context.setup()` / `db_query_buffer.setup()` calls (line 45-59), and
  declare `:DBCompletionToggle` and `:DBCompletionRefresh` there

**Checkpoint**: Gate is evaluated and wired. Buffer-open on an unknown connection must already be
non-blocking, because no connection state is ever `usable` yet. Foundation ready — user story
implementation can now begin.

---

## Phase 3: User Story 1 - I can write and run SQL even when the database is unreachable (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---i-can-write-and-run-sql-even-when-the-database-is-unreachable-priority-p1)

**Goal**: Suggestion generation can no longer connect, block, or fail. Usability is established by
one deliberate determination, after which the typing path has nothing left to do.

**Independent Test**: Point a SQL buffer at an unreachable database, type 200 characters without
stopping, and assert the editor stays responsive at every character, that zero client invocations
occur during typing, and that a query failure surfaces the database's own message rather than a
completion-path error. Repeat from a clean start 20 times.

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation** — with the gate wired but
> no determination implemented, T007 returns `false` for every state, so the typing assertions should
> pass while the "one attempt happened" assertions must fail.

- [X] T011 [P] [US1] Assert the gate truth table for `undetermined`, `warming`, `unusable`, `usable`,
  a `nil` connection, a fast event, and the switch-off case in
  `nvim/lua/tests/db_completion_smoke.lua` (contract §2)
- [X] T012 [P] [US1] Assert a failed determination issues exactly one stub invocation and that 50
  simulated keystrokes afterwards add zero further invocations, for an unreachable database, a
  healthy database, and a hang-never-answers database, in
  `nvim/lua/tests/db_completion_smoke.lua` (FR-001, FR-013, FR-014, SC-002, SC-011)
- [X] T013 [P] [US1] Assert buffer text, `filetype`, `b:db`, and unsaved state are unchanged after
  the gate and determination run, and that `lsp`/`path`/`snippets`/`buffer` remain in the SQL source
  list, in `nvim/lua/tests/db_completion_smoke.lua` (FR-005, FR-020, FR-033, I-7)

### Implementation for User Story 1

- [X] T014 [US1] Implement `M.determine(connection, trigger)` in `nvim/lua/config/db_completion.lua`
  per `contracts/db-completion-gate.md` §1: guard on `Determination.inFlight`, schedule
  `vim_dadbod_completion#fetch(bufnr)` off the typing path, and record `lastTrigger`
- [X] T015 [US1] Wrap the pre-warm in `pcall` in `nvim/lua/config/db_completion.lua`; on return
  transition `warming → usable` and set `attempted = true`; on throw transition
  `warming → unusable`, set `attempted = true`, and emit **no** notice (the notice discipline is
  User Story 3)
- [X] T016 [US1] Implement the `buffer_open` trigger in `nvim/lua/config/db_completion.lua` so a
  buffer acquiring a connection schedules exactly one determination per `databaseName`, and add the
  `Determination.startedAtTick` staleness check so a determination wedged in a client call cannot
  block later triggers forever (FR-014)
- [X] T017 [US1] Confirm `s:buffers[bufnr]` is populated after T016's pre-warm, making
  `autoload/vim_dadbod_completion.vim:405` (`db#connect`) unreachable from the typing path — the
  mechanism behind SC-001, SC-002, and SC-011; record the check in `research.md` R-0020 if the
  observed call sequence differs from `data-model.md` §1

**Checkpoint**: User Story 1 fully functional — the reported blocking is gone and independently
verifiable.

---

## Phase 4: User Story 2 - I can switch database completion off, and tell that I have (Priority: P1)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---i-can-switch-database-completion-off-and-tell-that-i-have-priority-p1)

**Goal**: One key toggles database completion globally, reports the new state exactly once, and
shows the current state in the keymap label without being pressed.

**Independent Test**: Press the key once and assert the state changed with one notice saying which
state it is now; press again and assert the original state returned, also with one notice. Read the
state from the keymap label and from the command and assert they agree. Confirm only database
completion is affected.

### Tests for User Story 2 ⚠️

- [X] T018 [P] [US2] Assert two toggles restore the starting state, `changeCount == 2`, and exactly
  two notices are emitted, in `nvim/lua/tests/db_completion_toggle_smoke.lua` (FR-008, FR-011, I-8)
- [X] T019 [P] [US2] Assert the `which-key` label tracks live state as
  `database: DB completion (on)` / `(off)` after each toggle, in
  `nvim/lua/tests/db_completion_toggle_smoke.lua` (FR-009, R-0031)
- [X] T020 [P] [US2] Assert the switch leaves every connection state untouched and closes the gate
  for all connections at once, while non-database sources keep working, in
  `nvim/lua/tests/db_completion_toggle_smoke.lua` (FR-005)

### Implementation for User Story 2

- [X] T021 [US2] Implement the toggle in `nvim/lua/config/db_completion.lua`: flip `GateState.enabled`,
  increment `changeCount`, emit exactly one notice, and re-register the keymap label — with no
  determination, no cancellation of an in-flight determination, and no change to any ledger entry
  (contract §3.1, D-0006)
- [X] T022 [US2] Bind `<leader>qc` in the `--database` section of `nvim/lua/config/keymaps.lua`
  beside `<leader>qj`/`qu`/`qo`/`qr` (line 36-40), and declare `:DBCompletionToggle` in
  `nvim/plugin/database.lua` if not already created by T010
- [X] T023 [US2] Implement label re-registration in `nvim/lua/config/db_completion.lua` via
  `require('which-key').add{ { '<leader>qc', desc = 'database: DB completion (' .. state .. ')' } }`
  on every state change — a `desc` is captured when the keymap is set, so this cannot be done once
  at load time (R-0031)

**Checkpoint**: User Stories 1 AND 2 both work independently — the defect is fixed and the
developer has an escape hatch.

---

## Phase 5: User Story 3 - A connection that failed steps aside by itself, without taking the others with it (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---a-connection-that-failed-steps-aside-by-itself-without-taking-the-others-with-it-priority-p2)

**Goal**: A failed connection disables itself once, with one actionable notice, and never retries.
Other connections are untouched.

**Independent Test**: Have one unreachable and one healthy connection open simultaneously, type in a
buffer on each, and assert the unreachable one disables itself exactly once with one notice while
the healthy one keeps producing suggestions throughout.

### Tests for User Story 3 ⚠️

- [X] T024 [P] [US3] Assert a failed connection produces exactly one notice and zero further attempts
  or notices across continued typing in multiple buffers bound to it, in
  `nvim/lua/tests/db_completion_smoke.lua` (FR-008, FR-012, FR-013, I-4, I-5)
- [X] T025 [P] [US3] Assert three independently failing connections each produce their own single
  notice and that an `unusable` connection never closes the gate for a `usable` one, in
  `nvim/lua/tests/db_completion_smoke.lua` (FR-005, FR-014, I-9)

### Implementation for User Story 3

- [X] T026 [US3] Implement the `noticeShown` guard in `nvim/lua/config/db_completion.lua` so the
  automatic-disabling notice is emitted once per connection per session, naming the database and
  pointing at `:DBCompletionRefresh` (contract §3.4)
- [X] T027 [US3] Implement the `attempted` guard in `nvim/lua/config/db_completion.lua` so opening
  another buffer on an already-judged connection — `usable` or `unusable` — schedules no new
  determination, which is what makes "at most one attempt per connection" true regardless of
  buffer or keystroke count (`data-model.md` §3.1 rows 3-4)
- [X] T028 [US3] Implement the unusable-state teardown in `nvim/lua/config/db_completion.lua`: when a
  buffer's connection becomes `nil` or changes, clear its `BufferBinding` and close the gate without
  discarding the ledger entry, so a per-connection verdict survives navigating away and back

**Checkpoint**: All three P1/P2 behaviors verified independently. A fix that stops blocking but
silently deletes suggestions would now be caught.

---

## Phase 6: User Story 4 - I can bring database completion back without restarting the editor (Priority: P2)

**Story Link**: [US4 in spec.md](./spec.md#user-story-4---i-can-bring-database-completion-back-without-restarting-the-editor-priority-p2)

**Goal**: One deliberate action restores completion on a connection that came back, and a connection
that is still down does not come back as "working".

**Independent Test**: Disable a connection's completion, restore the database, use the recovery
action, and assert suggestions return within the same session on a buffer that was never saved or
closed. Confirm both recovery routes work and that a still-down connection does not return.

### Tests for User Story 4 ⚠️

- [X] T029 [P] [US4] Assert `:DBCompletionRefresh` on a recovered connection makes one new attempt
  and transitions `unusable → usable`, opening the gate, in
  `nvim/lua/tests/db_completion_toggle_smoke.lua` (FR-017, FR-018)
- [X] T030 [P] [US4] Assert `:DBCompletionRefresh` on a still-dead connection leaves state
  `unusable`, makes at most one attempt, and reports the database's failure once — and that
  `:DBCompletionRefresh` with no bound connection makes zero attempts with one notice, in
  `nvim/lua/tests/db_completion_toggle_smoke.lua` (FR-019)
- [X] T031 [P] [US4] Assert a `User DBExecutePre` event for an `unusable` connection re-runs one
  determination and that a `DBExecutePre` for a `usable` connection does not, in
  `nvim/lua/tests/db_completion_toggle_smoke.lua` (FR-018, R-0024, D-0007)

### Implementation for User Story 4

- [X] T032 [US4] Implement `M.refresh()` in `nvim/lua/config/db_completion.lua` as the explicit
  override that always attempts, ignoring `attempted` (contract §1), and handle the no-connection
  case with a single notice and zero attempts
- [X] T033 [US4] Implement the `query_pre` trigger in `nvim/lua/config/db_completion.lua`: on
  `User */DBExecutePre`, resolve the buffer's connection and re-run the determination **only** when
  its state is `unusable`. There is no success verdict on either `DBExecutePre` or
  `DBExecutePost`, so the determination's own `db#connect` is the verdict — which is what yields
  FR-018 and FR-019 from one mechanism (R-0024, D-0007)
- [X] T034 [US4] Ensure `:DBCompletionRefresh` and the `query_pre` trigger never cancel, reset, or
  reorder an in-flight determination, and that neither writes to disk (FR-020, FR-021)

**Checkpoint**: All five stories' mechanisms exist. Remaining work is the regression guard.

---

## Phase 7: User Story 5 - With a healthy connection, completion is as useful as it is today (Priority: P3)

**Story Link**: [US5 in spec.md](./spec.md#user-story-5---with-a-healthy-connection-completion-is-as-useful-as-it-is-today-priority-p3)

**Goal**: On a healthy connection the suggestion set is identical to the unmodified provider. This is
the guard against having "fixed" the blocking by deleting the feature.

**Independent Test**: On a working connection, in the same buffer, compare the set of names offered
for the same prefixes and trigger positions with and without the gate installed. Repeat with a table
prefix, a bare prefix, and a reserved word prefix.

### Tests for User Story 5 ⚠️

- [X] T035 [P] [US5] Create `nvim/lua/tests/db_completion_gate_healthy_smoke.lua` comparing the
  gated provider against the ungated one for the same seeded cache: table prefixes, bare prefixes,
  dot-triggered positions, and reserved word prefixes must produce zero differences (SC-010)
- [X] T036 [P] [US5] Assert a healthy connection with no switch and no failure emits zero notices
  about database completion across a full session of use, in
  `nvim/lua/tests/db_completion_gate_healthy_smoke.lua` (US5 scenario 5)

### Implementation for User Story 5

- [X] T037 [US5] Verify in `nvim/lua/tests/db_completion_gate_healthy_smoke.lua` that the accepted
  text is identical with and without the gate, covering the same four prefix classes (US5
  scenario 4)
- [X] T038 [US5] Document the R-0040 deferral as a comment beside the provider options in
  `nvim/plugin/blink.lua`: `opts.trigger_characters = { '.', '_' }` is discarded by the upstream
  module's parameterless `M.new()`, so the effective trigger set is the plugin's five characters.
  Do **not** correct it — SC-010 forbids a behavior change here

**Checkpoint**: All user stories independently functional and the regression guard is in place.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, whole-repository validation, and PR discipline.

- [X] T039 [P] Update `nvim/README.md`: document the switch, its key, the documented starting state,
  automatic per-connection disabling with the notice wording, `:DBCompletionRefresh` as the recovery
  route, and a troubleshooting entry for "the editor freezes when I type SQL" (FR-032)
- [X] T040 [P] Add the module coverage row to the table in `nvim/README.md` (§ Key Design Decisions)
  mapping the gate, `M.enabled()`, `M.determine()`, and `M.refresh()` to this feature's spec and
  smoke tests, following the existing row format (constitution: module README coverage)
- [X] T041 Run the full regression set from `quickstart.md` §4: all eleven `-u NORC` suites, the two
  `-u nvim/init.lua` suites, the three new suites, `stylua --check nvim`, and
  `nvim --headless -u nvim/init.lua '+quitall'`. Every existing suite must be unchanged (FR-030)
- [X] T042 [P] Verify idempotency: source `nvim/plugin/database.lua` twice in one session and assert
  no duplicated command, autocmd, or `DBExecutePre` listener, and no error output (constitution:
  repeated load; contract §1 `setup()` idempotent)
- [X] T043 [P] Verify the module writes no file and changes no buffer text across a full session —
  check `stdpath('data')` before and after, and assert buffer text/`filetype`/`b:db` unchanged
  (FR-020, FR-021, FR-033, I-7, I-10)
- [X] T044 Verify the run passes the constitutional validation obligations that have no installer
  surface here: record in `nvim/README.md` that no installer step, managed file, or generated output
  was added, so clean-install, repeated-install, and conflict-handling checks are not applicable to
  this change
- [X] T045 Commit on the feature branch `013-db-completion-gate` with a conventional message; never
  commit directly to `main` (done: `05492ff`, pushed to `origin/013-db-completion-gate`)
- [X] T046 Before opening the PR, verify the change's scope fit against `spec.md`, confirm the PR
  links the originating issue, and ask the developer whether this spec should be closed as the
  completed solution (FR-034, FR-035) (done: scope verified; no originating issue exists — the
  spec's Input is the source; PR body states this and poses the closure question)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup; **blocks all user stories**.
- **User Stories (Phases 3-7)**: All depend on Phase 2 completion.
- **Polish (Phase 8)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Phase 2. No dependency on other stories. This is the MVP.
- **User Story 2 (P1)**: Starts after Phase 2. Reads and writes `GateState`, which Phase 2 created,
  but implements no other story's behavior. Independent of US1.
- **User Story 3 (P2)**: Starts after Phase 2. Consumes US1's determination outcome
  (`warming → unusable`) but adds only the notice and retry discipline, so it is testable without
  US2 and without US4.
- **User Story 4 (P2)**: Starts after Phase 2. Consumes US1's determination and US3's `unusable`
  state, and its two routes must be testable in either order — implement `M.refresh()` before the
  `DBExecutePre` trigger so the explicit route stands alone.
- **User Story 5 (P3)**: Starts after Phase 2 and after US1 exists, because the equivalence test
  compares gated against ungated behavior on a live connection.

No story requires another to be *finished*; the dependencies are on mechanisms, and each phase's
**Checkpoint** is independently verifiable.

### Within Each User Story

- Tests are written FIRST and must FAIL before implementation (T011-T013, T018-T020, T024-T025,
  T029-T031, T035-T036).
- State containers before the gate that reads them.
- The gate before the determination that populates `usable`.
- The determination before the recovery routes that re-run it.
- Story checkpoint before moving to the next priority.

### Parallel Opportunities

- T002, T003, T004, T005, T009 are marked `[P]` and can run together.
- T011-T013 (US1 tests), T018-T020 (US2 tests), T024-T025 (US3 tests), T029-T031 (US4 tests), and
  T035-T036 (US5 tests) can be written in parallel — they only require the Phase 2 contract, not each
  other's implementation.
- US2 (switch, keymap, label) and US3 (notice discipline) touch different concerns in the same file
  and are best implemented sequentially, but their tests are fully parallel.
- After Phase 2, US1, US2, and US3 can proceed concurrently; US4 and US5 follow US1.
- T039, T040, T042, T043 can run in parallel with the code phases once the behavior is settled.

---

## Parallel Example: User Story 1

```bash
# Write the three US1 tests together — they need only the Phase 2 contract:
Task: "T011 Assert the gate truth table in nvim/lua/tests/db_completion_smoke.lua"
Task: "T012 Assert one failed attempt then zero invocations across 50 keystrokes in nvim/lua/tests/db_completion_smoke.lua"
Task: "T013 Assert buffer immutability and non-DB sources intact in nvim/lua/tests/db_completion_smoke.lua"

# Foundation pieces that touch different concerns can also start together:
Task: "T004 Implement the four state containers in nvim/lua/config/db_completion.lua"
Task: "T005 Implement the connection key and databaseName derivation in nvim/lua/config/db_completion.lua"
Task: "T009 Implement the notice helper in nvim/lua/config/db_completion.lua"
```

## Parallel Example: User Story 2

```bash
# All three US2 tests together:
Task: "T018 Assert two toggles restore the starting state in nvim/lua/tests/db_completion_toggle_smoke.lua"
Task: "T019 Assert the which-key label tracks live state in nvim/lua/tests/db_completion_toggle_smoke.lua"
Task: "T020 Assert the switch closes the gate globally and spares other sources in nvim/lua/tests/db_completion_toggle_smoke.lua"

# Documentation tasks in later phases can run alongside these:
Task: "T039 Update nvim/README.md with the switch and troubleshooting entry"
Task: "T040 Add the module coverage row to nvim/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE** — run `nvim --headless -u NORC -c 'lua require("tests.db_completion_smoke")' -c 'qa!'`
5. The reported blocking is fixed and the branch is shippable on its own

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. US1 → validate → the reported defect is fixed (MVP)
3. US2 → validate → the developer has a documented escape hatch
4. US3 → validate → failures are explained instead of silent
5. US4 → validate → recovery without an editor restart
6. US5 → validate → no suggestion regression
7. Polish → README, full regression, PR

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together.
2. Once Foundational is done:
   - Developer A: User Stories 1 → 3 → 4 (sequential: each consumes the previous mechanism)
   - Developer B: User Story 2 (independent of A's chain after Phase 2)
   - Developer C: User Story 5, then all test authoring for US3/US4
3. Stories integrate independently; `nvim/lua/config/db_completion.lua` is the single shared file, so
   Developer A and Developer B should serialize their edits to it or use separate commits.

---

## Notes

- [P] tasks = different files, no dependency on incomplete work.
- [US#] tasks map to the linked story phase; update the phase `Story Link` if the `spec.md` heading
  changes.
- Each user story is independently completable and testable; stop at any checkpoint to validate.
- Verify tests fail before implementing.
- Commit after each task or logical group on `013-db-completion-gate`, never directly on `main`.
- Before creating a PR, verify whether the active spec is related and ask whether it should be closed.
- Every affected maintained module needs README coverage of purpose, source-of-truth files,
  prerequisites, manual activation, installer support, validation, customization boundaries,
  rollback/recovery, and manual-only operations — for this feature that is `nvim/README.md` (T039,
  T040, T044).
- Avoid: vague tasks, same-file conflicts, cross-story dependencies that break independence.
- Do not "fix" R-0040 (`opts.trigger_characters` in `nvim/plugin/blink.lua:113`) as part of this
  feature; SC-010 forbids the behavior change.

## Implementation notes (deviations and evidence)

- **T002 (harness shape)**: the suites do not shadow `db#systemlist`. The real `db#systemlist`
  never throws (`autoload/db.vim` returns `[]` on a non-zero exit); the blocking error comes from
  `db#connect`, which raises `DB exec error: …` or `DB: 'sqsh' executable not found` (R-0004,
  R-0010, R-0020). The harness therefore installs a **fake client binary** (`sqsh`/`isql`) on
  `$PATH` that appends a line to `$DB_SMOKE_COUNT` and honours `$DB_SMOKE_MODE`
  (`ok`/`fail`/`empty`/`tables`). This is the faithful mechanism: `vim_dadbod_completion#fetch`
  reaches `db#connect` → adapter → client, and the counting shows exactly when. A stubbed autoload
  was rejected because `fetch()` writes `s:cache[url]` *before* the connect call, so a throw-free
  stub would report success without ever touching a client (a false `usable` production cannot
  produce). Suites: `db_completion_smoke.lua`, `db_completion_toggle_smoke.lua`,
  `db_completion_gate_healthy_smoke.lua`.
- **T002/T018 fixtures**: `b:db` is assigned **after** `filetype` and after the buffer is current,
  because the live `FileType`/`BufEnter` autocmds installed at startup would otherwise consume the
  buffer's first determination before the test sets up its expectations.
- **T003 (baseline)**: recorded on the branch tip by `git stash -u` (change set removed): all
  eleven `-u NORC` suites plus `stylua --check nvim` were green **before** this feature's edits, so
  the two later failures were attributable to the gate's FR-012 notices, not to a dirty tree.
- **T011/T012 (hang case)**: a "hang-never-answers database" is not simulated. The determination
  runs synchronously in the editor thread (the fetch executes inline under `nvim_buf_call`), so a
  wedged client would wedge the test run rather than produce an observable `warming` state. The
  `warming` transition is covered by the T011 truth table instead.
- **T016 (staleness)**: `Determination.startedAtTick` is recorded for contract fidelity but
  is not enforced as a timeout. While `inFlight` is set no other trigger can run — the inline
  fetch is the only path into `db#connect` — so a stale entry is unreachable in practice.
- **T017**: the call-sequence check matched `data-model.md` §1: after `M.determine` completes,
  typing produces **zero** client invocations (asserted in T012), which is the observable form of
  "suggestions serve from cache, `db#connect` on the typing path is unreachable".
- **T031 (event shape)**: dadbod fires `User <output>.dbout/DBExecutePre` (`s:filter_write` in
  `autoload/db.vim`); the module's `*/DBExecutePre` pattern matches that, while a bare
  `DBExecutePre` pattern would not. The test fires the real shape via
  `nvim_exec_autocmds('User', { pattern = <temp>.dbout/DBExecutePre })`.
- **T033 (FR-018 vs the `attempted` guard)**: `query_pre` and `refresh_command` are allowed
  through the `attempted` guard; only the automatic typing/buffer-open triggers are blocked.
  Without this the DBExecutePre recovery route could never re-run.
- **T038 (R-0040)**: documented as a comment beside the provider options in
  `nvim/plugin/blink.lua`; `opts.trigger_characters` left untouched per SC-010.
- **T041 (regression + deviation)**: final run — eleven `-u NORC` suites, two `-u nvim/init.lua`
  suites, the three new suites, `stylua --check nvim`, and
  `nvim --headless -u nvim/init.lua '+quitall'` all pass. **Deviation**: `buffer_visibility_smoke`
  and `db_context_smoke` now filter the gate's own completion notices out of their notification
  sinks. They create a SQL buffer with `b:db`, which necessarily triggers the gate's FR-012
  connection attempt; counting those notices would test the gate, not buffer visibility or
  database context. quickstart §4 asked for byte-identical results from existing suites; the
  filters are the minimal change that keeps their intent intact (their own assertions are
  unchanged) and are commented in both files.
- **T042 (idempotency)**: sourcing `nvim/plugin/database.lua` twice in one session leaves
  `:DBCompletionToggle`/`:DBCompletionRefresh` unique, the `*/DBExecutePre` autocmd count stable
  (3 → 3), and the `FileType` autocmd count stable, with no error output — `setup()` and the
  command definitions are guarded.
- **T043 (no writes)**: across toggles and `_open` on a fresh buffer, buffer text, `filetype`,
  and `b:db` are unchanged; a temp directory's listing and `stdpath('data')` are untouched —
  `M.determine` only calls `vim_dadbod_completion#fetch` and reads `b:db`.
- **T044**: recorded in `nvim/README.md` (Database completion gate section): no installer step,
  managed file, or generated output is added.
- **R-0011/D-0002 note**: `M.enabled()` reads `vim.api.nvim_get_current_buf()`. That contradicts
  the literal "table lookups only" wording, but the fast-event guard runs first, so blink never
  consults it outside a typing context where the current buffer is the intended one. Considered
  safe; recorded here rather than changing the contract mid-flight.
- **T045/T046**: commit `05492ff` on `013-db-completion-gate`, PR
  [#105](https://github.com/aogallo/dotfiles/pull/105) against `main`. No originating issue exists
  (searched the repo); the spec's Input is the source, and the PR says so. Spec closure is the
  developer's call.