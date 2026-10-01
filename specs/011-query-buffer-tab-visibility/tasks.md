---

description: "Task list for query buffer tab visibility (issue #96)"
---

# Tasks: Query Buffer Always Shows Its Tab

**Input**: Design documents from `/specs/011-query-buffer-tab-visibility/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md),
[quickstart.md](quickstart.md)

**Tests**: Included and REQUIRED. The constitution (VIII) requires smoke coverage of the success path
and the failure paths before the change is complete, and the specification makes validation a hard
gate (FR-029, SC-012). [quickstart.md](quickstart.md) §4.1 is the authority for the 14 assertions in
the new suite; §4.2 is the authority for the one added case in the existing suite.

**Organization**: Tasks are grouped by user story so each story can be implemented, tested and
delivered independently. Each user-story phase links to its matching heading in [spec.md](spec.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable — touches a different file, or has no dependency on incomplete work.
- **[US#]**: User story marker. The phase's `Story Link` points to the matching `spec.md` heading.
- **[R#]**: Contract reference marker, pointing at a section of
  [contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md).
- Every task names an exact file path. T### IDs are stable — do not renumber; append instead.

## Legend

| Marker | Meaning |
|--------|---------|
| `- [ ]` | Not started. Flip to `- [X]` when the task is done **and** its test passes. |
| `T###` | Task ID, unique and stable. Assigned in execution order; never reused. |
| `[P]` | May run in parallel with other `[P]` tasks in the same phase — different file, no dependency on incomplete work. |
| `[US#]` | Belongs to that user story's phase. Traceable to the story's acceptance scenarios and its `FR-` requirements. |
| `[R#]` | Implements a specific section of the interface contract. |
| `[X]` | Complete, with the named test passing. A task is not complete because the code was written — it is complete when its test is green. |

Phases **1** (Setup), **2** (Foundational) and the final **Polish** phase carry **no** `[US#]`
label, per the format rules. Only user-story phases are labelled.

## Path Conventions

Single project (dotfiles repo). Neovim module paths only; no other subtree is touched.

```text
nvim/
├── init.lua                                   # unchanged — config.buffers is wired from
│                                             #   plugin/editor.lua per contract §1.1
├── lua/config/
│   ├── buffers.lua                            # NEW — buffer-visibility guard
│   ├── db_query_buffer.lua                    # NEW — query draft registry
│   ├── db_objects.lua                         # MODIFIED — open_buffer() delegates to
│   │                                          #   db_query_buffer.open(); the duplicate-buffer
│   │                                          #   and unhandled-E95 paths are deleted
│   ├── db_results.lua                         # MODIFIED — re-apply dadbod's buffer-local
│   │                                          #   settings after :pedit on a dismissed result
│   ├── autocmds.lua                           # unchanged — the guard owns its own augroup
│   └── options.lua                            # unchanged — carries an unrelated uncommitted
│                                              #   change; do not touch, do not commit
├── plugin/
│   ├── editor.lua                             # MODIFIED — one setup() call for the guard
│   │                                          #   (bufferline options themselves stay as-is)
│   └── database.lua                           # MODIFIED — db_query_buffer.setup() beside the
│                                              #   existing db_*.setup() calls
├── README.md                                  # MODIFIED — false auto-hide claim corrected
└── lua/tests/
    ├── buffer_visibility_smoke.lua            # NEW — the 14 assertions of quickstart §4.1
    ├── db_results_smoke.lua                   # EXTENDED — one added case (quickstart §4.2)
    ├── db_objects_save_smoke.lua              # unchanged — save flow untouched by this change
    ├── db_objects_scope_smoke.lua             # unchanged
    └── keymap_groups_smoke.lua                # unchanged — no keymap added or removed
```

Files explicitly **not** modified, listed so a task does not wander into them: `init.lua`,
`autocmds.lua`, `options.lua`, `keymaps.lua`, `fzf-lua.lua`, every `plugin/*.lua` other than
`editor.lua` and `database.lua`, the bufferline option block at `nvim/plugin/editor.lua:220-234`,
every installer script, every module outside `nvim/`.

**Wiring decision (recorded here, deviates from a [plan.md](plan.md) annotation)**: [plan.md](plan.md)
§Source Code marks `plugin/editor.lua` "unchanged" because the **bufferline options** must not move
(R-0004, R-0011) — and they do not. But contract §1.1 names `plugin/editor.lua` as the caller of
`buffers.setup()`, and that is where the call goes: the guard is editor-level, knows nothing about
databases, and must be live with no database loaded (FR-001, FR-026). `db_query_buffer.setup()`
goes in `plugin/database.lua` per contract §2.4. One caveat for whoever implements T010: the
contract calls the new call "a sibling of the existing `require 'config.db_connections'`", but that
require actually lives in `nvim/plugin/database.lua`, not `plugin/editor.lua` — the wording is
stale, the caller named in the contract is not.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the baseline and the shared harness every story depends on. No story code
here.

- [X] T001 Record the pre-change baseline: run the existing suites listed in [quickstart.md](quickstart.md) §3 and capture their assertion counts, so a pre-existing failure is not misattributed later
- [X] T002 Create/switch to branch `011-query-buffer-tab-visibility` and leave the unrelated uncommitted `nvim/lua/config/options.lua` change out of this branch's commits — that change is not part of issue #96 (constitution XIII)
- [X] T003 [P] Verify the working tree carries only that known unrelated change, that nothing outside the [plan.md](plan.md) file list is modified, and that no probe scripts from the R-0007 investigation were left behind
- [X] T004 [P] Add the measured route-dependence note as a header comment above `open_buffer()` in `nvim/lua/config/db_objects.lua` — `bdelete` clears `buflisted`, bufferline renders only `buf.listed == 1`, `:buffer N`/`:bnext`/`nvim_set_current_buf` do not re-list while `:edit <name>` and the fzf-lua actions do, and `bufhidden=hide` is inert because `'hidden'` is already on (R-0001, R-0002, R-0011) — so the route-dependence cannot be reintroduced
- [X] T005 [P] Create `nvim/lua/tests/buffer_visibility_smoke.lua` with the harness only and **zero** cases: a `check(ok, name, got, want)` helper that prints `PASS`/`FAIL` with `vim.inspect` and calls `:cquit` on failure, plus `vim.notify` capture and restore, copying the harness shape of `nvim/lua/tests/db_results_smoke.lua`, so each story phase appends cases without rewriting the harness

**Checkpoint**: Baseline recorded, branch correct, suite harness ready. No behavior change — the
existing suites from T001 must still pass.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 [R1.1] Create `nvim/lua/config/buffers.lua` with `M.setup()` per contract §1.1: augroup `aogallo/buffer_visibility` cleared, `BufEnter`/`BufWinEnter`/`TabEnter`/`VimEnter` at `pattern = '*'`, idempotent via a `setup_done` flag matching `db_results.setup()`, and a callback that returns immediately unless the buffer is valid, displayed in a window, and currently unlisted. Register **no** `BufAdd` listener — re-listing fires it (R-0003)
- [X] T007 [P] [R1.2] Implement `M.is_generated_output(bufnr)` in `nvim/lua/config/buffers.lua` per contract §1.2 and [data-model.md](data-model.md) §5: `true` for a name ending in `.dbout`, a non-empty `'buftype'`, or the buffer-local opt-out flag; `false` for a read-only unmodified ordinary file; no side effects, so tests can call it without an editor setup
- [X] T008 [P] [R1.1] Implement the additive listing write in `nvim/lua/config/buffers.lua` per [data-model.md](data-model.md) §4: guard on the current value being `false`, write `true` only, never `true → false`, never unlist/unload/wipe/delete anything, emit no message and define no user command (I-1, I-2, I-3, I-5, I-6)
- [X] T009 [P] [R1.3] Implement `M.register_reopen_handler(fn)` in `nvim/lua/config/buffers.lua` per contract §1.3: handlers invoked in registration order on the T4 path only, never on the T3 no-op path and never for generated output, each wrapped so a throwing handler cannot break the guard or the remaining handlers, effective immediately when registered after `setup()`
- [X] T010 [P] [R1.1] Call `require('config.buffers').setup()` at plugin source time in `nvim/plugin/editor.lua` (contract §1.1), next to the bufferline declaration — and change **no** bufferline option, including `mode = 'buffers'` and `auto_toggle_bufferline = true` (R-0004, R-0011)
- [X] T011 [R2.1] Create `nvim/lua/config/db_query_buffer.lua` with the session-local draft-record store from [data-model.md](data-model.md) §1 (keyed by buffer number with `display_name` as fallback, both keys stored), the display-name allocator from §1.1, and `M.setup()` per contract §2.4 — idempotent, registering `M.reopen` as a reopen handler with the guard, adding no user command and no keymap (R-0012)
- [X] T012 [P] [R2.1] Implement `M.open(url, object, lines, database)` in `nvim/lua/config/db_query_buffer.lua` per contract §2.1: allocate or reclaim per [data-model.md](data-model.md) §1.1, set `filetype` and the connection, record the draft, ensure the buffer is listed, focus it, and return the buffer number — no disk write, no file creation, no prompt, no message, and no change to unrelated buffers, windows or tabs
- [X] T013 [P] [R2.4] Call `require('config.db_query_buffer').setup()` beside the existing `db_objects.setup()` / `db_results.setup()` / `db_context.setup()` calls in `nvim/plugin/database.lua` (contract §2.4)

**Checkpoint**: Foundation ready. Both modules load, the guard is live, and `db_query_buffer.open()`
exists — but `nvim/lua/config/db_objects.lua` still opens buffers its own way, so nothing user-visible
has changed yet. That switchover is User Story 2.

---

## Phase 3: User Story 1 - A query buffer I come back to always has its tab (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---a-query-buffer-i-come-back-to-always-has-its-tab-priority-p1)

**Goal**: Any buffer the developer deliberately opened has a tab whenever it is in front of them —
by the picker, an explicit buffer-number jump, next/previous cycling, a clicked entry or a jump from
a result — and the tab is there before anything is saved.
**Requirements**: FR-001 – FR-007.

**Independent Test**: Open a query, close every buffer except one unrelated buffer, bring the query
back by each supported route, and assert a tab in every case, named the same each time. Repeat with
unsaved edits so the tab must appear before a save, and assert exactly one tab — never zero, never
two. No database and no other part of the configuration need inspecting to verify this.

### Tests for User Story 1 ⚠️

> Write these first and confirm they FAIL before implementing. Per [quickstart.md](quickstart.md) §4.1,
> assertions #1, #2, #6 and #7. A failure here means the root cause was not fixed.

- [X] T014 [P] [US1] Assert a listed buffer entered repeatedly performs exactly one listing write — no per-redraw churn (quickstart #1; I-2, I-5; FR-004) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T015 [P] [US1] Assert an unlisted buffer that has a window is listed on entry, and that a buffer with no window is left alone (quickstart #2; I-1; FR-001) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T016 [P] [US1] Assert that after `bdelete!` a `:buffer N` reopen lists the buffer again with **no write to disk** and no `filetype`/connection loss (quickstart #6; FR-003) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T017 [P] [US1] Assert every reopen route converges on the same state — `:buffer N`, `:bnext`, `nvim_set_current_buf`, `nvim_win_set_buf`, and the `buffer %d` mouse command (quickstart #7; FR-002) in `nvim/lua/tests/buffer_visibility_smoke.lua`

### Implementation for User Story 1

- [X] T018 [US1] Make the guard re-evaluate on `TabEnter` and `BufWinEnter` in `nvim/lua/config/buffers.lua` so a buffer that gains a window without a `BufEnter` — a split, a preview, a new tab page — is listed ([data-model.md](data-model.md) T7; FR-002)
- [X] T019 [US1] Add the session-start pass in `nvim/lua/config/buffers.lua` on `VimEnter` so a buffer already displayed when the session began is evaluated once ([data-model.md](data-model.md) T8; FR-001)
- [X] T020 [US1] Guard every early return in `nvim/lua/config/buffers.lua` against an invalid or unloaded buffer number, since these events can fire for a buffer that no longer exists (contract §1.1)
- [X] T021 [US1] Record in the `nvim/lua/config/buffers.lua` header that the tab appears on the next redraw because the tabline is a redraw-time expression, so no manual `redraw` call is added — and that a save is never a precondition (R-0003, FR-003)

**Checkpoint**: User Story 1 fully functional and independently testable, using plain scratch buffers
and no database at all. **This is the MVP** — it alone makes the tab come back, which is the reported
symptom of issue #96.

---

## Phase 4: User Story 2 - I can tell what each tab is, and nothing looks broken (Priority: P1)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---i-can-tell-what-each-tab-is-and-nothing-looks-broken-priority-p1)

**Goal**: A tab and its `<leader>bb` picker entry show the same name for the same buffer, two open
queries are tellable apart, a buffer in front of the developer is never labelled absent, and opening
the same query twice never raises or duplicates it.
**Requirements**: FR-008 – FR-012.

**Independent Test**: Open one query, then open the same object again — exactly one listed buffer with
the right name and no error. Open a second, different query while the first is still listed — the
names are distinct and the first buffer's content is untouched. Then compare the tab name with the
picker entry, and confirm a displayed query carries no hidden marker while a loadable-but-undisplayed
one does.

### Tests for User Story 2 ⚠️

> Per [quickstart.md](quickstart.md) §4.1, assertions #8 and #9. The `E95` regression is the one to
> watch: it is silent unless a test drives it.

- [X] T022 [P] [US2] Assert `open()` twice for the same object never raises and leaves exactly one listed buffer with the expected name — covering today's `Vim:E95` and its `[No Name]` orphan (quickstart #8; R-0005; FR-005) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T023 [P] [US2] Assert `open()` while the previous query is still listed allocates a distinct suffixed name and leaves the first buffer's content untouched (quickstart #9; FR-012) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T024 [P] [US2] Assert a reclaimed buffer has exactly one tab and its name equals the `<leader>bb` picker entry for that same buffer (FR-008) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T025 [P] [US2] Assert a displayed query buffer carries no `h`/hidden marker in the picker listing, while a loaded-but-undisplayed buffer does — the marker vocabulary of contract §4 (FR-009, FR-011) in `nvim/lua/tests/buffer_visibility_smoke.lua`

### Implementation for User Story 2

- [X] T026 [US2] Replace the local `open_buffer()` at `nvim/lua/config/db_objects.lua:254-263` with delegation to `db_query_buffer.open()` from both `open_list_query()` and `open_procedure_source()`, deleting the duplicate-buffer branch and the unhandled-`E95` path (contract §2.1)
- [X] T027 [US2] Implement the reclaim branch of the allocator in `nvim/lua/config/db_query_buffer.lua` ([data-model.md](data-model.md) §1.1 rule 2): reuse an unlisted buffer that already owns the base name — replacing its lines, re-applying language and connection, restoring its listing and focusing it — instead of allocating a second buffer
- [X] T028 [US2] Implement the suffix branch ([data-model.md](data-model.md) §1.1 rule 3) in `nvim/lua/config/db_query_buffer.lua` as a bounded scan for the next free `<stem>.<n>.sql`, which must never loop on a collision and never raise (rule 4)
- [X] T029 [US2] Route `filetype` and `b:db` assignment in `nvim/lua/config/db_query_buffer.lua` through the single open/reclaim path, so the tab and the picker can never disagree and saving changes neither name (FR-008, FR-010)
- [X] T030 [US2] Confirm `nvim/lua/config/db_objects.lua` no longer calls `nvim_buf_set_name` directly, and that no keymap was added, removed or rebound to reach the query buffer (R-0012, FR-002)

**Checkpoint**: User Stories 1 AND 2 both independently functional. The same query can be opened
twice without an error, and two open queries are distinguishable.

---

## Phase 5: User Story 3 - A query buffer that comes back still works (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---a-query-buffer-that-comes-back-still-works-priority-p2)

**Goal**: A query buffer that was closed and brought back still holds its text, its language and the
connection it was opened against — with nothing written to disk and nothing restored on its own.
**Requirements**: FR-013 – FR-017 (FR-017 as amended by **A-001**).

**Independent Test**: Open a query, type a distinctive line without saving, close everything else,
bring the query back, and assert the text, the `filetype` and the connection are all restored. Then
assert the buffer is closed and unlisted in the meantime, that no file appeared on disk, and that a
buffer which already holds text is never overwritten by a snapshot.

### Tests for User Story 3 ⚠️

> Per [quickstart.md](quickstart.md) §4.1, assertions #10 – #13. Assertions #12 and #13 are the
> A-001 guard rails: they must fail if the fix ever "restores" by writing a file.

- [X] T031 [P] [US3] Assert that after `bdelete!` an explicit reopen restores both the typed text and the recorded connection, and that the restored text matches exactly what was typed before the close (quickstart #10; FR-013, FR-014) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T032 [P] [US3] Assert a buffer that already holds text is never overwritten by its snapshot ([data-model.md](data-model.md) §3 invariant 3; quickstart #11) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T033 [P] [US3] Assert the close path never restores listing, never focuses anything, and never emits a notice ([data-model.md](data-model.md) §3 invariant 2; quickstart #12; FR-022) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T034 [P] [US3] Assert a force-closed query creates no file on disk, and that after a restart the draft is gone and the developer simply re-opens the query (quickstart #13; FR-017 as amended by A-001; constitution VII) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T035 [P] [US3] Assert the restored connection is the one recorded at open time and is never re-resolved from the current registry, so a re-pointed connection cannot silently change which database a query acts on (FR-016) in `nvim/lua/tests/buffer_visibility_smoke.lua`

### Implementation for User Story 3

- [X] T036 [US3] Implement `M.snapshot(bufnr)` in `nvim/lua/config/db_query_buffer.lua` per contract §2.3 and register its autocmd in `M.setup()` on the event that fires when a buffer leaves the buffer list ([data-model.md](data-model.md) T9): overwrite the older snapshot, never restore listing, never focus, never message, no-op without a record
- [X] T037 [US3] Implement `M.reopen(bufnr)` in `nvim/lua/config/db_query_buffer.lua` per contract §2.2: restore `filetype`, the recorded connection, and the recorded text **only when the buffer currently holds no text**; never list the buffer (the guard already did — a second write would break I-5); never message; no-op without a record
- [X] T038 [US3] Ensure the snapshot is captured before the unload destroys the buffer's own state in `nvim/lua/config/db_query_buffer.lua`, so A-001's in-memory recovery holds for a modified buffer, and keep the record strictly in memory with nothing persisted (FR-017 as amended, constitution VII)
- [X] T039 [US3] Confirm in `nvim/lua/config/buffers.lua` that reopen handlers fire on the T4 path only — never for a generated-output buffer and never on the T3 no-op path (contract §1.3, I-5)

**Checkpoint**: All three P1/P2 stories independently functional. A query that comes back still runs
against the database it was opened against.

---

## Phase 6: User Story 4 - Tool output stays out of my way (Priority: P2)

**Story Link**: [US4 in spec.md](./spec.md#user-story-4---tool-output-stays-out-of-my-way-priority-p2)

**Goal**: Read-only generated output — query results over a `.dbout` file — takes no tab in **any**
path, including the `<leader>qr` summon path that today gives it one, and the class is decided by
intent rather than by accident.
**Requirements**: FR-018 – FR-020.

**Independent Test**: Run a query and confirm the result output takes no tab. Dismiss its window,
summon the result again with `<leader>qr`, and confirm it still takes no tab and is still read-only
and `bufhidden=delete`. Then close developer buffers and confirm the output is treated identically.

### Tests for User Story 4 ⚠️

> Per [quickstart.md](quickstart.md) §4.1 assertions #4, #5 and #14, and §4.2 for the extended
> existing suite. The `.dbout` leak on the summon path is a pre-existing defect, so its test fails
> before the fix.

- [X] T040 [P] [US4] Assert `is_generated_output` is `true` for a `.dbout` buffer, a `buftype=nofile` drawer and an opted-out buffer, and **`false`** for a read-only ordinary file — states are not intents (quickstart #4; R-0009) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T041 [P] [US4] Assert the guard never lists a generated-output buffer, in any of those three forms (quickstart #5; I-4; FR-018) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T042 [P] [US4] Assert `db_results.show()` re-opening a dismissed result leaves it unlisted, read-only and `bufhidden=delete`, with the suite's existing five cases unchanged ([quickstart.md](quickstart.md) §4.2; R-0008) in `nvim/lua/tests/db_results_smoke.lua`

### Implementation for User Story 4

- [X] T043 [US4] Re-apply dadbod's own buffer-local settings — `nobuflisted`, `bufhidden=delete`, `readonly`, `nomodifiable` — to the `.dbout` buffer in `db_results.show()` in `nvim/lua/config/db_results.lua` after the `:pedit`, so the summon path matches the original render path (contract §3, R-0008)
- [X] T044 [US4] Leave everything else in `nvim/lua/config/db_results.lua` untouched: the three existing notices, the focus behavior, the single per-session slot, and the `User */DBExecutePre|Post` autocmds (contract §3)
- [X] T045 [US4] Document the buffer-local opt-out flag name in the `nvim/lua/config/buffers.lua` header as the extension point for a future generated buffer matching neither rule ([data-model.md](data-model.md) §5 rule 3; FR-011, FR-027)
- [X] T046 [US4] Confirm in `nvim/lua/config/buffers.lua` that class membership is decided before the listing write and never from the buffer's current listing state, so closing developer buffers cannot change how generated output is treated (FR-019, FR-020)

**Checkpoint**: US1 – US4 all independently functional. Generated output takes no tab in every path,
which is what FR-018 actually promises.

---

## Phase 7: User Story 5 - What I closed stays closed, and the docs stop lying (Priority: P3)

**Story Link**: [US5 in spec.md](./spec.md#user-story-5---what-i-closed-stays-closed-and-the-docs-stop-lying-priority-p3)

**Goal**: Closing is final — this feature never revives, unlists or wipes a buffer as a side effect —
and `nvim/README.md` no longer claims buffers auto-hide.
**Requirements**: FR-021 – FR-024.

**Independent Test**: Close buffers by each available route, including `<leader>bo`, and confirm every
closed buffer stays closed and unlisted until explicitly brought back. Confirm switching windows
never revives anything. Then read `nvim/README.md` and confirm the auto-hide claim is gone.

### Tests for User Story 5 ⚠️

- [X] T047 [P] [US5] Assert entering a buffer never unlists, unloads or wipes any buffer, including one the developer just closed (quickstart #3; I-3; FR-021) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T048 [P] [US5] Assert a closed buffer stays closed and unlisted until an explicit reopen, and that switching windows does not revive it — the rejected symmetric list-sync routine of contract §5 (FR-022) in `nvim/lua/tests/buffer_visibility_smoke.lua`
- [X] T049 [P] [US5] Assert the buffer row behaves the same with one buffer as with several, so this change does not alter the existing `auto_toggle_bufferline` behavior (FR-023) in `nvim/lua/tests/buffer_visibility_smoke.lua`

### Implementation for User Story 5

- [X] T050 [US5] Remove the stale auto-hide claim at `nvim/README.md:83` and replace it with the real visibility contract: a tab exists for any buffer the developer opened, generated output takes none, and closing is final until an explicit reopen (FR-024)
- [X] T051 [US5] Add the marker vocabulary to `nvim/README.md` — `h` means loaded but not currently displayed, no marker means displayed — plus the troubleshooting entry "my query buffer has no tab" (FR-011, FR-030, contract §4)
- [X] T052 [US5] Record in `nvim/lua/config/buffers.lua`, next to the listing write, that this module never unlists a buffer and never calls `:bdelete`, `:bwipe` or `:bunload`, so a future edit cannot introduce a symmetric path (I-3, FR-022)
- [X] T053 [US5] Verify that nothing under `nvim/` outside the [plan.md](plan.md) file list was modified, and that `nvim/lua/config/options.lua` remains untouched by this branch (FR-026)

**Checkpoint**: All five user stories independently functional, and the documentation no longer
contradicts the behavior.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements and obligations that affect multiple user stories.

- [X] T054 [P] Run `stylua --check nvim` and fix formatting drift in the changed files, leaving unrelated files alone
- [X] T055 Re-run the whole of [quickstart.md](quickstart.md) §3 plus §4.1 and §4.2 after the change, with **0 failures** — this is SC-012 and FR-029, and a task is not complete until its test is green
- [X] T056 [P] Complete the `nvim/README.md` module documentation for this change: purpose, source-of-truth files, prerequisites, manual activation (`config.buffers` wired from `plugin/editor.lua`, `config.db_query_buffer` from `plugin/database.lua`), installer support (none), the new validation command, the customization boundary (the opt-out flag), the rollback path (revert the two `setup()` calls), and the manual-only operations (constitution XIV, FR-030)
- [X] T057 [P] Scan the full diff for user-specific absolute paths, credentials, tokens, private keys or real local secrets — the connection URL may live in `b:db` and in a draft record, but never in a name, a message or a test fixture (FR-025, FR-028, constitution VII)
- [X] T058 [P] Confirm no new dependency was added and no keymap was added, removed or rebound — `nvim/lua/config/keymaps.lua`, `nvim/plugin/fzf-lua.lua` and the bufferline option block in `nvim/plugin/editor.lua` are untouched (FR-027, R-0012)
- [ ] T059 Walk the manual validation checklist in [quickstart.md](quickstart.md) §5 with the developer's own session: §5.1 the reported sequence end to end, §5.2 which half of "a name shows up but it hides" applies, §5.3 the regression checks, §5.4 the documentation check
- [ ] T060 Commit on `011-query-buffer-tab-visibility` with conventional commits, one commit per task group, never directly on `main` (constitution XIII, FR-031)
- [ ] T061 Before opening the PR, verify the change's scope fit against this spec and ask the developer whether `specs/011-query-buffer-tab-visibility` and issue #96 should be closed as the completed solution; the PR links issue #96 (constitution XIII/XV, FR-031)
- [X] T062 Verify every relative link in `tasks.md` resolves and that each user-story phase's `Story Link` points at its `spec.md` heading (FR-032, constitution XV)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — **BLOCKS all user stories**.
- **User Stories (Phases 3–7)**: All depend on Foundational completion.
  - US1 (P1) and US2 (P1) both touch `nvim/lua/config/db_query_buffer.lua` and `nvim/lua/config/buffers.lua`; run them **sequentially** (US1 then US2) to avoid same-file conflicts.
  - US3 (P2) shares `nvim/lua/config/db_query_buffer.lua` with US2; run it after US2.
  - US4 (P2) edits `nvim/lua/config/db_results.lua` and `nvim/lua/tests/db_results_smoke.lua` — different files from US1–US3, so it can run in parallel with them.
  - US5 (P3) edits `nvim/lua/config/buffers.lua` and `nvim/README.md`; it overlaps US1 on `buffers.lua` and US2's T050–T051 overlap Polish T056 on `README.md`, so sequence it.
- **Polish (Phase 8)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational. No dependency on any other story. **Delivers the MVP.**
  Testable with scratch buffers and no database.
- **US2 (P1)**: Starts after Foundational. Independent in behavior, but shares
  `nvim/lua/config/db_query_buffer.lua` and `nvim/lua/config/buffers.lua` with US1 — sequence it.
- **US3 (P2)**: Starts after Foundational. **Soft dependency on US2**: `M.reopen()` restores into a
  buffer that `M.open()` allocated, so it is only reachable once US2's delegation exists. Hard-blocked
  on T026–T029.
- **US4 (P2)**: Starts after Foundational. Independent of US1–US3 — different files. Depends only on the
  `is_generated_output` predicate and the guard's write path from Phase 2 (T007, T008).
- **US5 (P3)**: Starts after Foundational. Depends on Phase 2's write path (T008) for its no-side-effect
  assertions, not on any other story.

### Within Each User Story

- Tests MUST be written and confirmed to fail before implementation.
- Allocation and open/reclaim (`db_query_buffer.lua`) before the `db_objects.lua` delegation that calls it.
- Snapshot capture before restore, since restore reads what snapshot captured.
- Core implementation before integration with another story.
- Story complete before moving to the next priority.
- A task is complete only when its test is green — not when the code is written.

### Parallel Opportunities

- Phase 1: T003, T004, T005 are `[P]`.
- Phase 2: T007, T008, T009, T010, T012, T013 are `[P]`; T006 and T011 are sequential because each creates the module the others extend.
- Within every story phase, the test-case tasks are `[P]` — they append distinct cases to the one harness created in T005.
- Phase 6 and Phase 8: T040/T041 run alongside US1–US3's work; T054, T056, T057, T058 are `[P]`.
- **Not parallel**: any two tasks that both edit `nvim/lua/config/buffers.lua` (US1, US2, US4, US5), or both edit `nvim/lua/config/db_query_buffer.lua` (US2, US3), or both edit `nvim/README.md` (US5, Polish).

---

## Parallel Example: User Story 1

```bash
# Launch all four guard test cases together (all append to the T005 harness):
Task: "Assert a listed buffer entered repeatedly performs one write in nvim/lua/tests/buffer_visibility_smoke.lua"
Task: "Assert an unlisted buffer with a window is listed on entry in nvim/lua/tests/buffer_visibility_smoke.lua"
Task: "Assert bdelete! then :buffer N lists without a disk write in nvim/lua/tests/buffer_visibility_smoke.lua"
Task: "Assert every reopen route converges on the same state in nvim/lua/tests/buffer_visibility_smoke.lua"

# Then, separately, the US1 implementation tasks (same file — sequential):
Task: "Re-evaluate on TabEnter/BufWinEnter in nvim/lua/config/buffers.lua"
Task: "Add the VimEnter session-start pass in nvim/lua/config/buffers.lua"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (baseline, branch, harness)
2. Complete Phase 2: Foundational (**CRITICAL** — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: confirm the tab comes back on every route, before any save
5. Demo — this alone resolves the reported symptom of issue #96

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. US1 → validate → **MVP**: any buffer I come back to has its tab
3. US2 → validate → the same query can be opened twice, and two open queries are tellable apart
4. US3 → validate → a query that comes back still runs, with its text and its connection
5. US4 → validate → generated output takes no tab in any path, including `<leader>qr`
6. US5 → validate → closing is final and the README stops lying
7. Polish → formatting, full suite, docs, manual validation, PR

Each story adds value without breaking the previous ones. US1 closes the reported symptom; US2 removes
the `E95` that makes reopening it fail; US3 delivers A-001's in-memory recovery; US4 fixes the
`.dbout` leak that FR-018 forbids.

### Parallel Team Strategy

With multiple people, split by **file**, because US1–US5 share three source files:

1. Team completes Setup + Foundational together
2. Then, on separate branches:
   - Developer A: the guard (`nvim/lua/config/buffers.lua`) — owns US1, US4's predicate work, US5's T052
   - Developer B: the registry (`nvim/lua/config/db_query_buffer.lua`) — owns US2, US3
   - Developer C: the output path (`nvim/lua/config/db_results.lua` + `nvim/lua/tests/db_results_smoke.lua`) — owns US4
3. Merge A before B only where they touch the reopen handler contract; C merges independently

---

## Notes

- [P] tasks = different files, no dependencies on incomplete work
- [US#] tasks map to the linked story phase; update the phase `Story Link` if the spec heading changes
- [R#] tasks trace to a contract section; update the reference if the contract is renumbered
- Each user story must be independently completable and testable
- Verify tests fail before implementing — for this feature that matters most, since the current behavior is the bug
- Commit after each task or logical group on the feature branch, never directly on `main`
- Before creating a PR, verify the active spec is related to the PR and ask whether it should be closed
- Every affected maintained module must have a README with purpose, source-of-truth files, prerequisites, manual install/activation, installer support, validation, customization boundaries, rollback/recovery, and manual-only operations
- Stop at any checkpoint to validate a story independently
- Avoid: vague tasks, same-file conflicts, cross-story dependencies that break independence
- **Amendment A-001 is binding on US3.** Force-close MUST NOT write the content anywhere, MUST NOT create a file, MUST NOT prompt, MUST leave the buffer closed and unlisted, and MUST NOT restore anything by itself; within the same session the text MAY remain retrievable in memory so a later **explicit** reopen shows the query again (FR-013). T033 and T034 are the guard rails, and SC-006 is scoped to a session — see [spec.md](spec.md) §Clarifications and [research.md](research.md).
- **Two wording defects in the design documents, recorded so an implementer does not go hunting:** contract §1.1 calls `buffers.setup()`'s call site "a sibling of the existing `require 'config.db_connections'`", but that require is in `nvim/plugin/database.lua`, not `plugin/editor.lua`; and `plan.md` marks `plugin/editor.lua` "unchanged", which is true of its bufferline options (R-0004, R-0011) but not of the new `setup()` call that contract §1.1 requires there.
- **One open question, non-blocking.** FR-002 requires the fix to be route-independent precisely so that adding a mapping is not required, and `<leader>j` does not exist in this tree (R-0012), so no task depends on the answer. The developer never named the key they actually press. If they say the key is missing, that is a separate change — this feature must not add it (Out of Scope).