---

description: "Task list for implementation of database scope for object search"
---

# Tasks: Database Scope for Object Search

**Input**: Design documents from [`specs/archive/2026-09-25-005-database-scope/`](./)

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories),
[research.md](./research.md) (decisions D-1..D-5), [data-model.md](./data-model.md) (entities),
[contracts/sybase-db-scope.md](./contracts/sybase-db-scope.md) (adapter + flow contract),
[quickstart.md](./quickstart.md) (automated + manual acceptance).

**Tests**: `FR-013` requires new smoke coverage, so test tasks ARE included (TDD: write-test-first,
verify they FAIL, then implement). For dotfiles changes, constitution-applicable validation tasks are
REQUIRED and included in the Polish phase (syntax/static checks, smoke suite, module README
coverage, feature-branch/PR workflow, active-spec closure review). Installer-surface gates
(clean/repeated install, conflict handling, partial failure) are NOT applicable: this change alters
no installer or repository-managed config surface (plan.md Constitution Check, "Installer UX: not
applicable").

## Marker Legend

- **T###**: stable task ID, sequential in execution order.
- **[P]**: parallelizable — different files or no dependency on incomplete work.
- **[US#]**: user-story phase marker; links to the matching `spec.md` heading in that phase.
- Setup / Foundational / Polish tasks carry no `[US#]` label (constitution XV).

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the feature branch, prove a green baseline, and scaffold the (failing) scope
smoke harness so every later test task has a home.

- [X] T001 Create feature branch `005-database-scope` from current HEAD (`git checkout -b 005-database-scope`); confirm the local unstaged modification to `nvim/plugin/editor.lua` is left untouched and is never included in commits (constitution XIII; user-local file)
- [X] T002 [P] Baseline validation BEFORE any change: run `nvim --headless -u nvim/init.lua '+quitall'` (whole-config startup), `stylua --check nvim`, and the existing smoke suite (`tests.sybase_adapter_smoke`, `tests.sybase_objects_smoke`, `tests.db_connections_smoke`, `tests.db_jump_smoke`, `tests.db_objects_save_smoke`) via `nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'` — all must pass; record the result (FR-013)
- [X] T003 [P] Scaffold `nvim/lua/tests/db_objects_scope_smoke.lua` with the existing harness pattern (PASS/FAIL prints, `vim.cmd('cq')` on failure, exit 0 on success) and failing placeholder cases covering scope selection, owning-database binding, row labels, and error/no-match paths; verify each placeholder FAILS (TDD) (FR-013)

**Checkpoint**: Baseline is green, scope smoke harness exists with failing red cases.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The adapter surface that every user story depends on — `with_database()` (D-1/contract
§1.1) and the `database` field on `objects()` rows (D-3/contract §1.2). No user story may start until
this phase is complete.

- [X] T004 [!requires T003] Implement `db#adapter#sybase#with_database(url, database)` in `nvim/autoload/db/adapter/sybase.vim`: validate `database` against `^[A-Za-z0-9_$#]+$` (return `''` otherwise — reject `%`, path separators, unsafe chars); rebuild the URL from `db#url#parse()` fields preserving scheme, user, password, host, port, and query params (e.g. `charset=...`) with the chosen database as the path; never log or persist credentials (contract §1.1; FR-008)
- [X] T005 [P] Extend `db#adapter#sybase#objects(url)` in `nvim/autoload/db/adapter/sybase.vim` so every returned row carries `database` = the database the listing ran in (`s:database(url)`), alongside `name` and `kind` (contract §1.2; entity Object Search Result)
- [X] T006 [!requires T004, T005] Turn the `with_database()` / `objects()` placeholders in `nvim/lua/tests/db_objects_scope_smoke.lua` into PASSING contract cases: URL swap preserves auth/host/port/params, invalid names (including `%`) return `''`, scoped rows carry the `database` field (contract §1.1, §1.2)

**Checkpoint**: Foundation ready — the adapter can produce a scoped URL and database-aware rows, with
smoke coverage green. User-story implementation can now begin.

## Phase 3: User Story 1 - Choose the database the object search runs in (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---choose-the-database-the-object-search-runs-in-priority-p1)

**Goal**: Running `:DBObjects` offers a database-scope choice (the databases the login can read,
seeded with the connection's current database) and the search runs inside the chosen database;
default behavior without arguments is unchanged.

**Independent Test**: Run `:DBObjects`, choose a target database other than the current one, and
confirm the object listing comes only from that database (spec.md US1).

### Tests for User Story 1 (FR-013) ⚠️

> **NOTE: Written FIRST, must FAIL before implementation (harness from T003)**

- [X] T007 [P] [US1] Add smoke cases in `nvim/lua/tests/db_objects_scope_smoke.lua`: with `vim.ui.select` captured/injected, the scope flow picks database B, builds the scoped URL, re-fetches objects, and the reopened picker shows scope B and B's rows (FR-001/FR-002/SC-001); verify they fail before implementing T008-T010

### Implementation for User Story 1

- [X] T008 [US1] Add the scope entry as the first picker row — `Database: <current-missing> — change…` showing the connection's current database — in `nvim/lua/config/db_objects.lua`, present only for `sybase://` resolutions (skip for non-Sybase fallback, FR-012); the listing under default shows the connected database exactly as today (FR-006)
- [X] T009 [US1] Implement the scope chooser in `nvim/lua/config/db_objects.lua`: `vim.ui.select` over the databases from `complete_database()` (ordered by name) seeded with `[use current: <db>]` as default; ESC/cancel returns to the previous picker with no state change (FR-001/FR-009)
- [X] T010 [!requires T004] Apply the choice in `nvim/lua/config/db_objects.lua`: `db#adapter#sybase#with_database(url, db)` → scoped URL; on `''`, surface the canonical error and do not proceed; otherwise re-fetch objects against the scoped URL and reopen the picker with the scope row reading `Database: <chosen> — change…` (FR-002/SC-001); then make T007's smoke cases pass (FR-013)

**Checkpoint**: US1 fully functional and independently testable — the reported defect (cannot set a
database) is resolved for the search flow.

## Phase 4: User Story 2 - Open and execute results in their owning database (Priority: P1)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---open-and-execute-results-in-their-owning-database-priority-p1)

**Goal**: Objects found in another database open into buffers bound to the owning database — source
is read from the owner, executing runs in the owner, and buffer/save names stay database-qualified.

**Independent Test**: Search database B from a connection to A, open a procedure of B, and confirm
its buffer executes in B (not A) and its buffer name is database-qualified (spec.md US2).

**Depends on**: US1 (scoped URL threading) and the foundational `database` field.

### Tests for User Story 2 (FR-013) ⚠️

> **NOTE: Written FIRST, must FAIL before implementation**

- [X] T011 [P] [US2] Add smoke cases in `nvim/lua/tests/db_objects_scope_smoke.lua`: opening a scoped result binds `b:db` to the scoped URL; buffer display name and save file name are `<database>.<object>.sql`; verify they fail before implementing T012-T014 (FR-004/FR-005/SC-003)

### Implementation for User Story 2

- [X] T012 [US2] Thread the scoped URL through `open_row`/`open_buffer` in `nvim/lua/config/db_objects.lua` so every opened buffer — table/view list buffers and procedure/function source buffers — binds `b:db` to the scoped URL (owning database), never the connected one (FR-004)
- [X] T013 [US2] Make buffer display names database-qualified in `nvim/lua/config/db_objects.lua`: `<database>.<object>.sql` when the row carries `database` (FR-005; keeps buffers of same-named objects distinct)
- [X] T014 [US2] Make the save-flow default file name database-qualified in `nvim/lua/config/db_objects.lua` (`<database>.<object>.sql`, overridable in the existing dialog), superseding object-name-only naming (FR-005); then make the T011 smoke cases pass (FR-013)

**Checkpoint**: US1 AND US2 both work — searching, opening, executing, and saving all honor the
owning database.

## Phase 5: User Story 3 - Clear labels and safe failures (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---clear-labels-and-safe-failures-priority-p2)

**Goal**: Every picker row shows its owning database; unknown/inaccessible or invalid database
choices and empty listings produce exactly one actionable outcome — never an empty or wrong picker.

**Independent Test**: Choose an unknown database name and search a database with zero matching
objects, confirming the distinct outcomes (spec.md US3).

**Depends on**: the foundational `database` field and `with_database()` validation.

### Tests for User Story 3 (FR-013) ⚠️

> **NOTE: Written FIRST, must FAIL before implementation**

- [X] T015 [P] [US3] Add smoke cases in `nvim/lua/tests/db_objects_scope_smoke.lua`: rows labelled with owning database (FR-003/SC-002); invalid/unknown database yields exactly one error and no picker/buffer (FR-007/SC-004); empty scoped listing yields the no-match message; repeated apply/cancel cycles leave no duplicated buffers or stale state (idempotency, spec Edge Cases); verify they fail before implementing T016-T018

### Implementation for User Story 3

- [X] T016 [US3] Render every `sybase://` picker row as `<kind> <database> <name>` in `nvim/lua/config/db_objects.lua` using the row `database` field; non-Sybase fallback rows keep the current label (FR-003/FR-012)
- [X] T017 [US3] Surface exactly one actionable error naming the database (`DBObjects: cannot access database '<name>'`, or the invalid-name message with the accepted charset) when `with_database()` rejects the value or the database is unknown/inaccessible; no empty picker or buffer opens (FR-007/FR-008/SC-004)
- [X] T018 [US3] Show a clear no-match message when a scoped listing is empty (no buffer opened) (FR-007); then make the T015 smoke cases pass, including the repeated-run idempotency case (FR-013)

**Checkpoint**: All three user stories are independently functional and covered by green smoke tests.

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, full verification, scope/security audit, and governance closure.
Installer-surface constitution gates (clean/repeated install, conflict handling, partial failure)
are explicitly N/A — no installer surface changed (plan.md Constitution Check).

- [X] T019 [P] Update `nvim/README.md` (module README, constitution XII/XIV): document the database-scope control, its default (connection's current database), owning-database binding, database-qualified names, the out-of-scope cross-database `%` search (owned by `001-multidb-object-search`), validation commands, customization boundaries, and rollback = `git revert` of the `nvim/` changes (FR-014)
- [X] T020 [P] Full verification gate (FR-013/VIII): run `nvim/lua/tests/db_objects_scope_smoke.lua` plus the entire existing database smoke suite, `stylua --check nvim`, and whole-config headless startup (`nvim --headless -u nvim/init.lua '+quitall'`); all must pass and `nvim/plugin/database.lua` must be confirmed unchanged (command surface, contract §4)
- [X] T021 [P] Scope/security audit: confirm every change is confined to `nvim/`, no new dependencies declared, no credentials/secrets added (passwords only in-memory URLs, never logged), `nvim/plugin/editor.lua` local modification excluded from all commits (FR-015; constitution V/VII)
- [X] T022 [P] Governance: verify commits use conventional messages on feature branch `005-database-scope` only (never `main`); prepare the pull request linking the approved issue; at PR creation, review whether the active spec (`005-database-scope`) or a completed related spec (`004-fix-object-save`, `001-multidb-object-search`) is related and should be closed, and ask the user (FR-016; constitution XIII/XV)

**Checkpoint**: Feature complete, verified, documented, and ready for PR review.

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — starts immediately (branch, baseline, harness).
- **Foundational (Phase 2)**: depends on Setup (T003 harness); BLOCKS all user stories.
- **US1 (Phase 3)**: depends on Foundational (T004). No dependency on US2/US3.
- **US2 (Phase 4)**: depends on US1 (scoped-URL threading, T010) + Foundational (T005).
- **US3 (Phase 5)**: depends on Foundational (T004 validation + T005 `database` field). Independent of US1/US2.
- **Polish (Phase 6)**: depends on all desired user stories complete.

### User Story Dependencies

- **User Story 1 (P1)**: can start after Foundational. Independent of US2/US3 → MVP.
- **User Story 2 (P1)**: can start after US1 threading lands (sequential in `db_objects.lua`).
- **User Story 3 (P2)**: can start after Foundational; independent of US1/US2 (different
  `db_objects.lua` functions than US1/US2, but same file — implement after US1/US2 for safety).

### Within Each User Story

- Tests written first and RED before implementation; implementation RECHECKs them green.
- Core adapter/URL work before picker UI; picker UI before binding/naming; labels/errors last.

### Parallel Opportunities

- Setup: T002 and T003 are [P].
- Foundational: T004 and T005 are [P].
- Story test tasks are [P] (T007, T011, T015) — they only touch the smoke file and can be drafted
  together, then implemented against the story's [P] tasks after story scoping.
- Adapter work (T004/T005) is fully parallel to the picker smoke scaffolding (T003).
- Polish tasks (T019-T022) are all [P].
- US2 and US3 both touch `nvim/lua/config/db_objects.lua`; keep their edits sequential (follow the
  phase order or review-merge carefully) to avoid same-file conflicts.

## Parallel Example: User Story 1

```bash
# Draft the failing US1 smoke cases (test-first):
Task: "T007 [P] [US1] scope-flow smoke cases in nvim/lua/tests/db_objects_scope_smoke.lua"

# Implement US1 picker flow after the smoke file and foundational T004 are in place:
Task: "T008 [US1] scope entry row in nvim/lua/config/db_objects.lua"
Task: "T009 [US1] scope chooser via vim.ui.select in nvim/lua/config/db_objects.lua"
Task: "T010 [US1] apply choice -> with_database(url, db) -> re-fetch in nvim/lua/config/db_objects.lua"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (branch + baseline + red harness).
2. Complete Phase 2 (adapter `with_database()` + `objects()` `database` field, green contract cases).
3. Complete Phase 3 (US1 scope entry + chooser + apply/re-fetch). This alone resolves the reported
   defect — returning the ability to set the target database.
4. **STOP and VALIDATE**: US1 independent test (quickstart.md manual acceptance US1) — list of a
   different database without touching connections.

### Incremental Delivery

1. Foundation (adapter surface) ready — no behavior change yet.
2. Add US1 → verify scope selection → MVP demo.
3. Add US2 → verify binding/names/save honor the owning database.
4. Add US3 → verify labels and safe failure paths.
5. Polish → docs, full green suite, scope/security audit, PR.

## Notes

- [P] tasks = different files or no dependency on incomplete work.
- [US#] tasks map to the linked story phase; update the phase `Story Link` if the spec heading changes.
- Adapter contract truth: `contracts/sybase-db-scope.md` (§1.1 `with_database`, §1.2 `objects`,
  §3 errors, §4 non-goals — do not implement the `%` scan here).
- Commit after each task or logical group on branch `005-database-scope`, never on `main`.
- Before creating a PR, verify whether the active spec is related and ask whether a related completed
  spec (`004-fix-object-save`, `001-multidb-object-search`) should be closed.
- Do not touch `nvim/plugin/editor.lua` (user-local modification) and do not include it in commits.