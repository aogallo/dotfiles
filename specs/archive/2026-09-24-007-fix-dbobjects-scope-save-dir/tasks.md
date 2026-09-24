---

description: "Task list for implementation of DBObjects scope feedback and save confirmation"
---

# Tasks: Fix DBObjects Scope Feedback and Save Confirmation

**Input**: Design documents from [`specs/007-fix-dbobjects-scope-save-dir/`](./)

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories),
[research.md](./research.md) (decisions D-1..D-6), [data-model.md](./data-model.md) (entities),
[contracts/dbobjects-scope-save-feedback.md](./contracts/dbobjects-scope-save-feedback.md) (behavior contract),
[quickstart.md](./quickstart.md) (automated + manual acceptance).

**Tests**: Constitution VIII (Verification Before Completion) requires smoke coverage for this Neovim-module
change, so test tasks ARE included (TDD: write-test-first, verify they FAIL, then implement). The change alters
no installer or repository-managed config surface, so installer gates (clean/repeated install, conflict handling,
partial failure) are NOT applicable (plan.md Constitution Check, "Installer UX: not applicable").

## Marker Legend

- **T###**: stable task ID, sequential in execution order.
- **[P]**: parallelizable — different files or no dependency on incomplete work.
- **[US#]**: user-story phase marker; links to the matching `spec.md` heading in that phase.
- **[!requires T###]**: hard dependency on a previous task within this feature.
- Setup / Foundational / Polish tasks carry no `[US#]` label (constitution XV).

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the feature branch, prove a green baseline, and ensure the pending `editor.lua` change
rides onto the branch for the US3 commit.

- [X] T001 Create feature branch `007-fix-dbobjects-scope-save-dir` from current `main` HEAD
  (`git checkout -b 007-fix-dbobjects-scope-save-dir`); confirm the pending unstaged `nvim/plugin/editor.lua`
  `<leader>q` → `database` group line (line 156) rides onto the branch and is committed ONLY in the US3 phase
  (constitution XIII; user directive: "incluirlo en la siguiente spec" / engram #1488)
- [X] T002 [P] Baseline validation BEFORE any change: run `nvim --headless -u nvim/init.lua '+quitall'`
  (whole-config startup), `stylua --check nvim`, and the existing smoke suite (`tests.sybase_adapter_smoke`,
  `tests.sybase_objects_smoke`, `tests.db_connections_smoke`, `tests.db_jump_smoke`,
  `tests.db_objects_save_smoke`, `tests.db_objects_scope_smoke`, `tests.db_results_smoke`) via
  `nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'` — all must pass; record the result
  (constitution VIII)

**Checkpoint**: Baseline is green on the feature branch; the pending keymap-group line is tracked.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The shared test scaffold every story phase needs — notify-capture in the save harness and the
new keymap-group harness. US2/US3 depend only on this scaffold plus Phase 1; US1 additionally depends on the
foundational scope-display helper surfaced here.

**⚠️ CRITICAL**: No user-story test work can begin until this phase is complete.

- [X] T003 [P] Extend `nvim/lua/tests/db_objects_save_smoke.lua` with a `vim.notify` capture (mirror the
  `notices` table already present in `db_objects_scope_smoke.lua` lines 22/121-122), and create
  `nvim/lua/tests/keymap_groups_smoke.lua` with the repo's PASS/FAIL harness pattern (prints + `vim.cmd('cq')`
  on failure, exit 0 on success); the keymap harness loads the leader prefix registry from
  `nvim/plugin/editor.lua` and has no assertions yet (contract §5, constitution VIII)

**Checkpoint**: Foundation ready — both smoke harnesses can capture and assert the new behaviors.

## Phase 3: User Story 1 - Database scope stays visible and stable (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---database-scope-stays-visible-and-stable-while-browsing-objects-priority-p1)

**Goal**: Every scope outcome is explicit: success re-lists inside the chosen database with a readable header;
any failure produces exactly one actionable notification and stays on the last-good listing — never a silent
revert to the unscoped list and never a vanished picker.

**Independent Test**: Scope to a database whose name contains `_` by typing it, then search for a stored
procedure that exists there — it appears and the header shows the scoped database; scope to an invalid name and
confirm one clear error with the picker still open (spec.md US1).

### Tests for User Story 1 (constitution VIII) ⚠️

> **NOTE: Written FIRST, must FAIL before implementation (harness from T003)**

- [X] T004 [!requires T003] [US1] Add failing scope-feedback cases to `nvim/lua/tests/db_objects_scope_smoke.lua`:
  (a) scoping to `my_schema_db` via the typed-name path re-lists in it and the header/scope label read
  `my_schema_db` (FR-002/FR-004); (b) a scope whose fetched listing is empty emits exactly one `vim.notify` and
  the picker re-opens on the last-good rows/url (FR-003); (c) typing the current scope emits one notification and
  does not refresh the listing (FR-003); (d) cancelling the chooser returns to the last-good list with zero
  side effects (FR-005). Verify they FAIL before implementing T005-T007 (contract §2, SC-002)

### Implementation for User Story 1

- [X] T005 [US1] Add a shared `active_scope_label(url)` helper in `nvim/lua/config/db_objects.lua` (database
  read from the URL path via the existing `url_database`, else `login default`) and use it in the object-list
  header prompt AND the scope-row `format_item` so both always agree (FR-001, research D-2, contract §1)
- [X] T006 [!requires T005] [US1] Rework the scope failure paths in `nvim/lua/config/db_objects.lua`
  (`apply_database_scope`, `choose_database`): an invalid-charset name, a typed name equal to the current scope,
  and an empty `fetch_objects(scoped)` each emit exactly one actionable `vim.notify` and then
  `pick(last_good_rows, last_good_url)` so the picker stays on the last-good listing with the scope unchanged —
  remove the current empty-result `return` that leaves no picker (FR-003, contract §2, D-1)
- [X] T007 [US1] In `nvim/lua/config/db_objects.lua`, make the typed-name path explicit: `vim.trim`, reject empty
  input, detect equality with `current_db` with a clear message (no silent `pick(rows, url)`), and confirm
  `[A-Za-z0-9_$#]` names incl. `_` (e.g. `my_schema_db`) pass through `db#adapter#sybase#with_database` unchanged
  (FR-004)
- [X] T008 [!requires T004-T007] [US1] Make T004's cases green; run
  `nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'` and the full smoke suite to
  confirm no regression in the 005 scenarios (FR-003/SC-001/SC-002/SC-005)

**Checkpoint**: US1 fully functional and independently testable — the reported defect (scope silently reverts /
SP not found) is resolved for the search flow.

## Phase 4: User Story 2 - Saving a stored procedure confirms where it was saved (Priority: P2)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---saving-a-stored-procedure-confirms-where-it-was-saved-priority-p2)

**Goal**: After every confirmed save the user receives a notification with the full destination path; the write
stays exactly one file in the confirmed directory and the dialog keeps starting at the startup root.

**Independent Test**: Open any procedure source, choose `[type a path…]`, type a destination, confirm — a
notification appears with the exact path and the file exists there and only there (spec.md US2).

### Tests for User Story 2 (constitution VIII) ⚠️

> **NOTE: Written FIRST, must FAIL before implementation (harness from T003)**

- [X] T009 [!requires T003] [P] [US2] Add failing save-notification cases to `nvim/lua/tests/db_objects_save_smoke.lua`:
  a confirmed save (fresh path AND overwrite-confirmed path) produces exactly one captured `vim.notify` containing
  the full resolved path+filename, and `Keep existing (cancel)` produces zero writes and zero notifications
  (FR-006/FR-007/FR-009). Verify they FAIL before implementing T010 (contract §3, SC-003)

### Implementation for User Story 2

- [X] T010 [US2] In `nvim/lua/config/db_objects.lua`, in `run_save_flow`'s single write point, after
  `M.write_source` returns `{ ok = true, path = ... }`, emit `vim.notify('DBObjects: saved ' .. path, INFO)` — this
  fires exactly once per confirmed save for both the fresh and overwrite paths (FR-006, research D-3, contract §3)
- [X] T011 [!requires T010] [US2] Verify single-write/no-duplication semantics: only the confirmed directory
  receives the file (nothing in earlier browse locations or the startup root), the dialog still opens at
  `M.default_save_dir()` on every invocation with no memory of prior directories, and T009's cases are green
  (FR-007/FR-008/SC-004)

**Checkpoint**: US2 complete and independently testable — every save is confirmed with a path, no duplicates.

## Phase 5: User Story 3 - The database keymap group appears in the keymap help (Priority: P3)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---the-database-keymap-group-appears-in-the-keymap-help-priority-p3)

**Goal**: `<leader>q` is registered as the `database` which-key group (the pending `editor.lua` line), matching
the four existing actions and the module README.

**Independent Test**: Press `<leader>q` — the popup shows a `database` group with `qj`/`qu`/`qo`/`qr`; all actions
behave unchanged (spec.md US3).

### Tests for User Story 3 (constitution VIII) ⚠️

> **NOTE: The pending `editor.lua` line already sits in the working tree; the test verifies the invariant and may
> be green from branch creation — confirm and record either way (T001).**

- [X] T012 [!requires T003] [US3] Add group assertions to `nvim/lua/tests/keymap_groups_smoke.lua`: the leader
  prefix registry loaded from `nvim/plugin/editor.lua` registers `<leader>q` → group `database`, and the four
  action maps (`<leader>qj`, `<leader>qu`, `<leader>qo`, `<leader>qr`) remain defined in
  `nvim/lua/config/keymaps.lua` (FR-010, contract §4)

### Implementation for User Story 3

- [X] T013 [US3] Include the pending `{ '<leader>q', group = 'database' }` line (already staged in the working
  tree `nvim/plugin/editor.lua:156`, carried from T001) in this feature's commit; confirm the four keymap actions
  in `nvim/lua/config/keymaps.lua:37-40` are unchanged and T012 is green (FR-010, contract §4)

**Checkpoint**: US3 complete — the which-key `database` group matches the documented keys.

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, full verification, and branch/PR governance.

- [X] T014 [P] Update `nvim/README.md`: document the scope-feedback behavior (header shows the active clarif
  database; scope failures notify once and stay in the picker — never a silent revert), the save-confirmation
  notification, and the `<leader>q` `database` keymap group; align with contract §1-§4, validation commands, and
  rollback notes; keep the existing save-dialog "always starts at launch directory" wording consistent with
  FR-008 (constitution XIV; module README gate)
- [X] T015 [P] Run the full validation set and record results: `stylua --check nvim`,
  `nvim --headless -u nvim/init.lua '+quitall'`, `git diff --check`, and the complete smoke suite incl.
  `keymap_groups_smoke`; run `setup/validate-nvim-deps.sh` (expect 0 required missing); run the quickstart
  US1/US2/US3 manual scenarios where a live Sybase server is available (constitution VIII; quickstart.md)
- [X] T016 Commit all remaining changes on branch `007-fix-dbobjects-scope-save-dir` with conventional commit
  messages and create a PR targeting `main`; verify whether the active spec (007) is related and should be closed,
  and ask the user before closing (constitution XIII/XV; spec.md Requirements Constitution obligations)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — starts immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 — provides the smoke harness extensions all stories assert on.
- **User Stories (Phase 3-5)**: US2 and US3 need only Phases 1-2; US1 additionally depends on T005/T006 within its
  phase. Stories can run in parallel after Foundational.
- **Polish (Final Phase)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: requires T003 (harness) + its own T004-T008. No cross-story dependencies.
- **User Story 2 (P2)**: requires T003 (harness) + its own T009-T011. Independent of US1.
- **User Story 3 (P3)**: requires T003 (harness) + its own T012-T013. Independent of US1/US2.

### Within Each User Story

- Tests are written first and verified FAILING (red) before implementation (except T012, which may already pass
  because the pending `editor.lua` line rides in from T001 — record the observed state).
- Core implementation before wire-up/passing; story complete before moving to next priority.

### Parallel Opportunities

- T002 [P] runs alone with Phase 1.
- Story test tasks T004 / T009 / T012 are [P] and start together after T003.
- US1 implementation tasks T005 and T007 are independent; T006 depends on T005; T008 depends on all four.
- US2 and US3 phases can run in parallel with junior team members once Foundational completes.
- Polish tasks T014 and T015 are [P].

---

## Parallel Example: User Story 1

```bash
# Launch failing tests and the independent helper together (T004 after T003):
Task: "Add failing scope-feedback cases to nvim/lua/tests/db_objects_scope_smoke.lua (T004)"
Task: "Add active_scope_label(url) helper in nvim/lua/config/db_objects.lua (T005)"

# Then the dependent rework, then make tests green:
Task: "Rework failure paths in nvim/lua/config/db_objects.lua (T006 — requires T005)"
Task: "Make T004 green and confirm full suite (T008)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational harness scaffold).
3. Complete Phase 3: User Story 1 (scope feedback / no silent revert).
4. **STOP and VALIDATE**: run the scope smoke suite + quickstart US1 scenarios.
5. Deploy/demo if ready.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. Add US1 → test independently → MVP.
3. Add US2 (save confirmation) → test independently.
4. Add US3 (keymap group) → test independently.
5. Polish: README, full validation, PR governance.

### Parallel Team Strategy

- Developer A: US1 (invalid/empty scope feedback + header label).
- Developer B: US2 (save-notification at single write point).
- Developer C: US3 (keymap-group invariant + commit of the pending line).
- All three need T003 first; integration risks are minimal because each story touches distinct code paths.

---

## Notes

- [P] tasks = different files, no dependencies.
- [US#] tasks map to the linked story phase; update the phase `Story Link` if the spec heading changes.
- The pending `nvim/plugin/editor.lua` `<leader>q` change is deliberately included in this feature as US3
  (user directive + engram #1488); it must not be committed in Phase 1.
- Commit after each logical group on the feature branch, never directly on `main`.
- Before creating the PR, verify whether the active spec is related and ask whether a related completed spec should
  be closed.
- Every affected maintained module must have a README covering purpose, source-of-truth files, prerequisites,
  manual install/activation, installer support, validation, customization boundaries, rollback/recovery, and
  manual-only operations — `nvim/README.md` is updated in T014.
- Rollback is a normal `git revert` of the merged `nvim/` changes; the feature writes no persistent state beyond
  user-confirmed saved procedure files.