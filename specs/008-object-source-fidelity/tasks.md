# Tasks: Object Source Fidelity (`:DBObjects`)

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/object-source-extraction.md](contracts/object-source-extraction.md)

**Status note**: This task list was written after the implementation shipped in PR #89
(see [Provenance](spec.md#provenance)). `[X]` means the work is present in that PR's diff, not
that it was performed here. `T101` is the one genuinely open item and needs a real ASE server.

**Tests**: `nvim/lua/tests/sybase_objects_smoke.lua` (canned `sqsh` output; no server).
Validation commands are in [quickstart.md](quickstart.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: stable task ID.
- **[P]**: parallelizable — different file or no dependency on incomplete work.
- **[US#]**: user-story phase. Every phase links to its heading in [spec.md](spec.md).
- Exact paths are given in each task.

---

## Phase 0: Specification (retroactive)

**Purpose**: leave an SDD trail for code that already shipped (constitution XII).

- [X] T001 Create `specs/008-object-source-fidelity/` via `.specify/scripts/bash/create-new-feature.sh --number 8 --short-name object-source-fidelity` and point `.specify/feature.json` at it
- [X] T002 [P] Write [spec.md](spec.md) (P1–P3 stories, FR-001–FR-014, SC-001–SC-004, edge cases incl. the `~`-at-boundary limit) with an explicit [Provenance](spec.md#provenance) section
- [X] T003 [P] Write [plan.md](plan.md) (technical context, constitution check, phases, complexity)
- [X] T004 [P] Write [research.md](research.md) (R1–R6: framing is a result set, catalog vs showsql, marker scheme, hidden detection, framing rules, scope discipline)
- [X] T005 [P] Write [data-model.md](data-model.md) (E1–E5 + invariants) and [contracts/object-source-extraction.md](contracts/object-source-extraction.md)
- [X] T006 [P] Write [checklists/requirements.md](checklists/requirements.md) and [quickstart.md](quickstart.md)
- [X] T007 Write [verify-report.md](verify-report.md) with the real gate output and the open live-server acceptance

---

## Phase 1: Framing removal (FR-003)

**Story Link**: [User Story 1 — Open a stored procedure and get its real source (P1)](spec.md#user-story-1---open-a-stored-procedure-and-get-its-real-source-priority-p1)

- [X] T010 [P] Add `s:clean_result(out)` in `nvim/autoload/db/adapter/sybase.vim`: drop `# Lines of Text` blocks with their counter lines, `[-=]{3,}` rules, `N rows affected` trailers, and column headings with their separator row; return `[]` on `Msg <n>, Level <n>` (FR-003, research R5)
- [X] T011 [P] Add `s:trim_edges(lines)` to drop blank leading/trailing lines from a source (contract: extraction return value)

---

## Phase 2: Catalog read and reassembly (FR-001, FR-002)

**Story Link**: [User Story 1 — Open a stored procedure and get its real source (P1)](spec.md#user-story-1---open-a-stored-procedure-and-get-its-real-source-priority-p1)

- [X] T020 [P] Add `s:source_catalog(url, safe_name)` running `select convert(varchar(255), text) + '~' + case when text like '%' + char(10) then ' ' else '+' end from syscomments where id = object_id('<name>') order by number, colid2, colid` (FR-001, [data-model.md](data-model.md#e1-catalog-row))
- [X] T021 Add `s:join_chunks(out)`: skip the standalone `~ ` marker line, strip a trailing `\~+` and keep the line open, append `"\n"` for complete rows, then `split(text, "\n", 1)`, strip a trailing `\r`, and trim edges (FR-002; the `\~` escape is required — a bare `~` never matches a Vimscript pattern, research R3)
- [X] T022 Record the accepted limits in the `s:join_chunks()` header: a source line ending in exactly `~` at a row boundary is dropped; CR-only endings are not breaks

---

## Phase 3: Hidden/encrypted detection (FR-006, FR-007)

**Story Link**: [User Story 2 — Understand why a source cannot be read (P2)](spec.md#user-story-2---understand-why-a-source-cannot-be-read-priority-p2)

- [X] T030 [P] Add `s:text_is_hidden(url, safe_name)` querying `case when count(*) > 0 then 'HIDDEN' else 'OK' end … and (status & 1 = 1 or version is not null)`, comparing against the **label** so a stray numeric client line cannot read as "hidden" (FR-007, research R4)
- [X] T031 Call it from `s:source_catalog()` before extraction and return `[]` when hidden (FR-006)

---

## Phase 4: Source modes and dispatch (FR-005)

**Story Link**: [User Story 3 — Opt into regenerated SQL when the catalog will not do (P3)](spec.md#user-story-3---opt-into-regenerated-sql-when-the-catalog-will-not-do-priority-p3)

- [X] T040 [P] Add `s:source_mode()` reading `g:db_sybase_source_mode` with default `catalog` (FR-005)
- [X] T041 [P] Add `s:source_showsql(url, safe_name)` running `exec sp_helptext '<name>', NULL, NULL, 'showsql,noparams'` through `s:clean_result()` + `s:trim_edges()`, with the ASE 15.0.2+ requirement and the reformatting caveat in the header (FR-005)
- [X] T042 Rewire `db#adapter#sybase#source(url, name)`: missing client → `[]`, escape `'` → `''`, then dispatch to `showsql` or `catalog` (FR-005, FR-009, FR-010)

---

## Phase 5: One actionable notice (FR-008)

**Story Link**: [User Story 2 — Understand why a source cannot be read (P2)](spec.md#user-story-2---understand-why-a-source-cannot-be-read-priority-p2)

- [X] T050 Update `open_procedure_source()` in `nvim/lua/config/db_objects.lua`: on an empty result open no buffer and emit exactly one WARN notice naming the object and listing hidden text / missing `select` on `syscomments.text` / missing object / unavailable client; keep the save flow only on success (FR-008, SC-003)

---

## Phase 6: Tests (FR-011)

**Story Link**: [User Story 1 — Open a stored procedure and get its real source (P1)](spec.md#user-story-1---open-a-stored-procedure-and-get-its-real-source-priority-p1)

- [X] T060 [P] Rewrite `nvim/lua/tests/sybase_objects_smoke.lua` around `captured_batches()` / `batches_contain()` so every sent batch is asserted, not just the last line (harness itself was part of the defect's blast radius)
- [X] T061 Cover the P1 reassembly: canned rows `create procedure usp_calc as` / `  select @var = substring(@dat~+` / `o, @poscicion, 1)` / `go` / `~ ` must yield 3 whole lines with no cut and no framing (FR-002, FR-004, SC-002)
- [X] T062 Cover framing removal (`# Lines of Text`, heading + separator, `Msg 2812` → `[]`) and the escaped-name query (FR-003, FR-009)
- [X] T063 Cover `HIDDEN` detection and the opt-in `showsql` dispatch, including that an unset/other mode value stays on `catalog` (FR-005, FR-006, FR-007)
- [X] T064 Green run: 28 assertions in this smoke, 141 across the 8-smoke suite, exit 0 (SC-004)

---

## Phase 7: Documentation and governance (FR-012, FR-013, FR-014)

**Story Link**: unlinked — module contract and workflow obligations, not a user story (constitution XV).

- [X] T070 [P] Document in `nvim/README.md`: the `:DBObjects` source behavior, both modes, the `~ `/`~+` marker scheme, the accepted limits, the notice text, plus the module map, function traceability table, and the "Documenting a function" convention (FR-012, constitutions XII/XIV)
- [X] T071 [P] Give every production function in the touched modules the uniform header block (name, called by, SQL, args, returns, side effects) — 67 functions; test helpers intentionally exempt (FR-012)
- [X] T072 [P] Update the DB objects module docs in `nvim/lua/config/db_objects.lua` header to name both extraction queries (FR-012)
- [X] T073 Ship through branch `fix/nvim-db-source-and-docs` → PR #89, linking approved issue #88; deviation from the `008-…` branch name documented in [verify-report.md](verify-report.md) (FR-013)
- [X] T074 Confirm no new dependency, no config file, and no change outside source extraction and its docs (FR-014)

---

## Phase 8: Acceptance

**Purpose**: the only open work. Requires a real ASE instance.

- [ ] T101 Run the live-server acceptance in [quickstart.md](quickstart.md#manual-acceptance-live-server-required): open a >255-byte procedure and confirm byte-exact lines, no framing, no mid-token cuts; re-run the save flow; optionally repeat with `g:db_sybase_source_mode = 'showsql'` (SC-001, SC-002)
- [ ] T102 Confirm the notice path against a real hidden object (`sp_hidetext`) or a login without `select` on `syscomments.text` (SC-003)
- [ ] T103 Update [verify-report.md](verify-report.md) with the live results and mark this spec for archival (the spec is not closed until T101–T102 pass)
