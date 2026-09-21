---

description: "Task list for feature implementation"
---

# Tasks: Sybase / Neovim Database Client

**Input**: Design documents from `/specs/001-sybase-nvim-client/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Validation tasks are REQUIRED per the constitution: headless start, formatting/static checks, dependency validation, registry-load test, missing-client behavior, missing-registry behavior, adapter argv smoke tests (incl. the `objects`/`source` hooks), module README coverage, feature-branch/PR workflow verification, and active spec closure review before PR creation. Live-server acceptance is manual-only (documented in quickstart.md) because CI has no database servers.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Each user-story phase links to its matching heading in `spec.md`.

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable task that can run independently because it touches different files or has no dependency on incomplete work.
- **[US#]**: User story marker. The phase's `Story Link` points to the matching `spec.md` heading.
- Include exact file paths in task descriptions.

## Marker Legend

- **[P]** = parallelizable (no file conflicts with other pending tasks)
- **[US#]** = belongs to user story # (`US1`..`US4` matching `spec.md` headings)
- **[setup]**, **[foundational]**, **[polish]** = phase scope markers

## Path Conventions

- Single project at repository root; all source changes scoped to the `nvim/` module and `.gitignore` (see `plan.md` → Project Structure).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline validation before any change, plus the committed template artifact.

- [ ] T001 [P] [setup] Record baseline: run headless startup (`nvim --headless -u nvim/init.lua '+quitall'`) and `stylua --check nvim` on the current tree; capture the pass/fail state before any edits.
- [ ] T002 [setup] Create committed example registry `nvim/db-connections.example.lua` (secret-free name→URL table with `$ENV_VAR` placeholders and comments) per `contracts/connections-registry.md` format.
- [ ] T003 [P] [setup] Add `nvim/db-connections.lua` to `.gitignore` (only the real registry file, never the `.example`).

**Checkpoint**: Baseline known; example template exists; real registry cannot be staged.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 Create registry loader `nvim/lua/config/db_connections.lua`: resolve path via `NVIM_DB_CONNECTIONS` env var with default `stdpath('config')/db-connections.lua`; `loadfile` + execute; on parse error warn once and continue with empty registry (never crash startup); assign result to `g:dbs`. (Contract: connections-registry.md)
- [ ] T005 [P] Add vim-dadbod-completion plugin to `nvim/plugin/database.lua` via `add { src = 'kristijanhusak/vim-dadbod-completion', setup = false }` and require the loader module.
- [ ] T006 [P] Declare external clients in `nvim/dependencies.tsv` as optional: `sqsh|sqsh|no|homebrew|brew install sqsh|nvim/autoload/db/adapter/sybase.vim` (macOS Sybase), `sqlcmd|sqlcmd|no|homebrew/go|...|nvim/README.md` (SQL Server), `mongosh|mongosh|no|homebrew|brew install mongosh|nvim/README.md` (MongoDB). SAP ASE `isql` documented for Windows (no macOS tsv row).
- [ ] T007 [P] Update `nvim/nvim-pack-lock.json` with deterministic pinned revisions for vim-dadbod-completion (follow existing lockfile format).
- [ ] T008 Add `g:db_ui_table_helpers['sybase']` = `select top 200 * from {table}` in `nvim/plugin/database.lua` `on_setup` (ASE has no `LIMIT`; dadbod-ui default helper uses `LIMIT 200`).

**Checkpoint**: Foundation ready — registry loads into `g:dbs`, completion plugin declared, table helper wired. User story implementation can now begin.

---

## Phase 3: User Story 1 - Execute large stored procedures against Sybase ASE from Neovim (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---execute-large-stored-procedures-against-sybase-ase-from-neovim-priority-p1)

**Goal**: Run a whole buffer/selection containing a `create procedure` batch (with `go` separators) against Sybase ASE from Neovim; see all result sets and `print`/`raiserror` messages with no truncation; cancel long queries.

**Independent Test**: Open a buffer with a `create procedure` batch, run it against a reachable ASE, then execute the procedure and confirm all result sets and messages render.

### Implementation for User Story 1

- [ ] T010 [P] [US1] Create `nvim/autoload/db/adapter/sybase.vim` with scheme registration mirroring dadbod's sqlserver.vim pattern: `interactive(url)`, `input(url, infile)`, `input_extension() → 'sql'`, `output_extension() → 'dbout'`. (Contract: contracts/sybase-adapter.md)
- [ ] T011 [US1] Implement client selection inside the adapter: `has('win32')` → SAP ASE `isql`, else `sqsh`; honor `g:db_sybase_client` override (string or argv list); expose `executable()` check so a missing client yields one actionable dadbod error naming the missing binary.
- [ ] T012 [US1] Implement `input(url, infile)`: on macOS/sqsh only, write a transformed temp copy where lines matching `^\s*go\s*$` (case-insensitive) become `\go`; never modify the user's original file. Build argv (`sqsh -S host[:port] -U user [-P pass] [-D db] [-L semicolon_hack=false] -i file` / `isql -S host[:port] -U user [-P pass] [-D db] -i infile`); merge stdout+stderr; nonzero exit → dadbod "Query aborted".
- [ ] T013 [US1] Implement `interactive(url)` returning argv for an interactive console (sqsh macOS with `\go` batches / isql Windows with `go`) for US1 interactive flow and `:DB`.
- [ ] T014 [US1] Add cancellation + status support: verify long queries show "DB: Running query..." status and `<C-c>` in the result buffer cancels (dadbod jobstart-based; confirm on the sybase adapter path).
- [ ] T015 [P] [US1] Create adapter argv smoke test `tests/sybase_adapter_smoke.lua` (stubbed `db#url#parse`): assert sqsh/isql argv for `sybase://u:p@h:5000/db` incl. the `go`→`\go` transform (matches quickstart automated check 4).

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently.

---

## Phase 4: User Story 2 - Single user-controlled connection registry (Priority: P2)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---single-user-controlled-connection-registry-priority-p2)

**Goal**: All connections (Sybase ASE, SQL Server, MongoDB) live in one user-owned file the developer locates via `NVIM_DB_CONNECTIONS`; edits appear in the browser without restarting Neovim; credentials never reach git.

**Independent Test**: Point Neovim at a registry file, add one connection per supported type, refresh the browser (`R` in `:DBUI`), confirm all three appear — while a repo credential scan finds nothing.

### Tests for User Story 2 ⚠️

- [ ] T020 [P] [US2] Registry-load test script: with `NVIM_DB_CONNECTIONS` pointing at a throwaway registry, assert `g:dbs` is populated and matches the file; with the env var unset and no file, assert empty registry + no crash (headless nvim). (Matches quickstart automated check 5.)

### Implementation for User Story 2

- [ ] T021 [US2] Wire the loader from T004 into `nvim/plugin/database.lua` startup path so `g:dbs` feeds dadbod-ui at launch (registry = single source of truth, replaces any prior `g:dbs`).
- [ ] T022 [US2] Verify browser refresh: `:DBUI` + `R` picks up registry edits without restarting Neovim (FR-006/SC-004).
- [ ] T023 [US2] Verify credential hygiene: real password in the local registry; `git status` and `git log -p` show no credential; confirm `nvim/db-connections.lua` is untracked (FR-007/SC-005, edge case "Credential leakage").

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently.

---

## Phase 5: User Story 3 - Schema-aware SQL autocompletion (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---schema-aware-sql-autocompletion-priority-p2)

**Goal**: SQL buffers get schema-object suggestions (tables/views/procedures) from the active dadbod connection via blink.cmp; degrades gracefully with no connection.

**Independent Test**: Open a SQL buffer against an active connection whose server exposes metadata and confirm schema-object suggestions appear in the completion popup; with no connection, Neovim still completes normally.

### Implementation for User Story 3

- [ ] T030 [P] [US3] Register blink provider in `nvim/plugin/blink.lua`: add `vim_dadbod_completion.blink` to `sources.providers` and enable it for the `sql` per-filetype (adapt the LazyVim snippet to this repo's blink `opts` style — no lazy.nvim).
- [ ] T031 [US3] Implement adapter `tables(url)` and `complete_database(url)` in `nvim/autoload/db/adapter/sybase.vim` (`select name from sysobjects where type in ('U','V') order by name`; `select name from sysdatabases order by name`), parsing output; missing client → `[]` (FR-008/SC-008).
- [ ] T032 [US3] Verify graceful degradation: with no active dadbod connection, blink's other sources (LSP, snippets, buffer, path) keep working with no error (FR-009/SC-008). Document in `nvim/README.md` that Sybase column completion is not provided by vim-dadbod-completion (tables only); SQL Server column completion works.

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all be independently functional.

---

## Phase 6: User Story 4 - Interactive console and schema browsing for all supported databases (Priority: P3)

**Story Link**: [US4 in spec.md](./spec.md#user-story-4---interactive-console-and-schema-browsing-for-all-supported-databases-priority-p3)

**Goal**: SQL Server and MongoDB run through the same workflow as Sybase; schema browser lists tables/views/procedures for any connected server exposing metadata; SSMS-like name filter (`:DBObjects`, fzf-lua) works across all supported databases; selecting a stored procedure loads its full source into a buffer for editing.

**Independent Test**: Connect to SQL Server and MongoDB via the registry, run a query and a schema listing for each; open `:DBObjects` on a Sybase connection with many procedures, filter by name, pick one, confirm its full source opens in a buffer.

### Implementation for User Story 4

- [ ] T040 [P] [US4] Verify SQL Server path: registry `sqlserver://` URLs connect and render results via dadbod's native sqlserver adapter (T022 + manual quickstart US4 scenario 1).
- [ ] T041 [P] [US4] Verify MongoDB path: registry `mongodb://` URLs connect and render results via dadbod's native mongodb adapter (auto-detects mongosh/mongo; quickstart US4 scenario 2).
- [ ] T042 [P] [US4] Verify schema browser: `:DBUI` lists tables/views/procedures for connected servers exposing metadata, with the Sybase "List" helper running `select top 200 * from {table}` (FR-019, quickstart US4 scenario 3).
- [ ] T043 [US4] Confirm interactive console flow for all three types through the same workflow (`:DB <url>`), leaving no stale session state on switch (FR-020, edge case "Mid-session switching").
- [ ] T044 [P] [US4] Implement `objects(url)` and `source(url, name)` in `nvim/autoload/db/adapter/sybase.vim`: `objects()` returns `{name, kind}` rows from `sysobjects` (types `U`/`V`/`P`/`F`/`X`); `source()` runs `sp_helptext <name>` and returns full output lines; escape single quotes and never interpolate raw user input into SQL; missing client → `[]`. (Contract: contracts/sybase-adapter.md → Schema Object Search & Source Loading.)
- [ ] T045 [US4] Create `nvim/lua/config/db_objects.lua` exposing an object-search entry point: resolve the current/selected connection URL, delegate to `db#adapter#sybase#objects(url)` for `sybase://` and dadbod's `tables(url)` for `sqlserver://`/`mongodb://`, present rows as `kind  name` in an fzf-lua picker (fuzzy name filter = SSMS-like, FR-022).
- [ ] T046 [US4] Wire picker actions in `nvim/lua/config/db_objects.lua`: table/view selection opens the ASE-safe "List" query (`select top 200 * from <name>`); procedure/function selection calls `db#adapter#sybase#source(url, name)` and opens the full text in a new `sql` buffer ready for edit-and-re-run through the US1 flow (FR-022/SC-011).
- [ ] T047 [US4] Register `:DBObjects` command (completion over `g:dbs` names / current buffer URL) in `nvim/plugin/database.lua`; verify no-connection invocation produces a clear prompt/error, no crash.
- [ ] T048 [P] [US4] Create `tests/sybase_objects_smoke.lua` (stubbed `db#url#parse`): assert the `objects`/`source` hooks build the expected sqsh/isql argv (matches quickstart automated check 7).

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validation, docs, and delivery discipline covering all stories.

- [ ] T050 [P] [polish] Run full automated validation: headless startup, `stylua --check nvim`, adapter source/syntax check, adapter argv smoke tests (stubbed `db#url#parse` asserting sqsh/isql argv + `go`→`\go` transform + `objects`/`source` argv; T015/T048), registry-load test, missing-client behavior (single actionable error naming the binary + install command). (quickstart.md → Automated validation; FR-013/SC-006/SC-009.)
- [ ] T051 [polish] Verify idempotent/non-destructive behavior: re-running setup/linking does not duplicate `g:dbs` entries, overwrite existing saved dadbod-ui connections (`g:db_ui_save_location` data), or reinstall unchanged deps (FR-012/SC-006; edge cases "Repeated runs", "Existing saved connections").
- [ ] T052 [polish] Verify recovery: removing the registry file or unsetting `NVIM_DB_CONNECTIONS` restores prior behavior; no registry state written elsewhere (FR-016).
- [ ] T053 [polish] Update `nvim/README.md`: source-of-truth files, connection registry usage (`NVIM_DB_CONNECTIONS` + default path), client prerequisites (macOS: `sqsh`/`sqlcmd`/`mongosh` Homebrew; Windows: SAP ASE `isql`, SQL Server ODBC/`sqlcmd`, `mongosh` per FR-021/SC-010), table helper, `:DBObjects` usage and its Sybase-only source-load limitation, customization/override boundaries (`g:db_sybase_client`, registry path), validation, rollback/recovery, and manual-only operations (live-server acceptance).
- [ ] T054 [polish] Reference `docs/windows-tooling-audit.md` from `nvim/README.md` for Neovim-on-Windows install (no change to that file).
- [ ] T055 [polish] Run manual acceptance per `quickstart.md` against reachable servers (US1..US4 scenarios incl. SC-001: <1s server query renders in Neovim within 5s), record results.
- [ ] T056 [polish] Confirm all changes are scoped to the `nvim/` module + `.gitignore`; no unrelated tool module touched (FR-014).
- [ ] T057 [polish] Verify commits are conventional commits on feature branch `001-sybase-nvim-client`; prepare PR that links the required approved issue; PR creation review verifies whether the active spec (`specs/001-sybase-nvim-client/spec.md`) is related and should be closed (FR-017).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1) must be implemented and validated first (MVP)
  - US2, US3, US4 can then proceed sequentially; [P] tasks inside them can run in parallel
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Needs the adapter (T010-T014) + foundational g:dbs wiring; no dependency on US2-4.
- **User Story 2 (P2)**: Needs loader (T004) and database.lua wiring (T005/T021); independent of adapter internals.
- **User Story 3 (P2)**: Needs adapter `tables()`/`complete_database()` (T031) and blink provider (T030); independent of registry UX.
- **User Story 4 (P3)**: Needs registry (US2), the adapter `objects()`/`source()` hooks (T044), and the already-present fzf-lua picker; independent of US3.

### Within Each User Story

- Core implementation before integration
- Story complete before moving to next priority
- Stop at any checkpoint to validate the story independently

### Parallel Opportunities

- Setup tasks marked [P] (T001, T003) can run in parallel
- Foundational tasks marked [P] (T005, T006, T007) can run in parallel
- US1 smoke test (T015) and US4 smoke test (T048) can run in parallel once the adapter exists
- US4 [P] tasks (T040, T041, T042, T044, T048) can run in parallel; T045/T046/T047 are sequential on `db_objects.lua`

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Add User Story 4 → Test independently → Deploy/Demo

---

## Notes

- [P] tasks = different files, no dependencies
- [US#] tasks map to the linked story phase; the phase `Story Link` points to the matching `spec.md` heading
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group on feature branch `001-sybase-nvim-client`, never directly on `main`
- Before creating a PR, verify whether the active spec is related and ask whether a related completed spec should be closed
- `nvim/README.md` must be updated in the same change (FR-015): purpose, source-of-truth files, prerequisites, manual install/activation, installer support, validation, customization boundaries, rollback/recovery, and manual-only operations
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- `:DBObjects` (US4): object filter works on all schemes via adapter `objects()` (sybase) or native `tables()` (sqlserver/mongodb); procedure source-loading is Sybase-only — no new dependency (fzf-lua already present)
