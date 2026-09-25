# Tasks: Trailing Whitespace Cleanup + Database Context Indicator

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/db-indicator.md](contracts/db-indicator.md),
[contracts/whitespace-fallback.md](contracts/whitespace-fallback.md)

**Tests**: two new offline smokes, `nvim/lua/tests/formatter_chains_smoke.lua` and
`nvim/lua/tests/db_context_smoke.lua`, plus one check that needs the real configuration
(`markdown_whitespace_smoke`, self-skipping when the formatter is absent). Validation commands are
in [quickstart.md](quickstart.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: stable task ID. `T0xx` phases are build phases, `T1xx` is manual acceptance.
- **[P]**: parallelizable — different file, or no dependency on incomplete work.
- **[US#]**: user-story phase. Every phase links to its heading in [spec.md](spec.md).
- **FR-### / SC-### / D#**: the requirement, outcome, or research decision being satisfied.
- Exact paths are given in each task.

## Two independent slices

The whitespace track (Phases 2–4) and the database-indicator track (Phase 5) share only Phase 0 and
Phase 1. Neither is a prerequisite for the other, and either can ship alone. The user's reported pain
is the indicator, so **Phase 5 is the slice to land first**; Phase 2–4 is hardening of behavior that
already works.

---

## Phase 0: Baseline and provenance

**Purpose**: attribute later failures correctly, and record what entered the branch from outside
this spec (constitution XII).

- [ ] T001 Baseline before touching anything: `stylua --check nvim`, the 8 existing offline smokes, and `nvim --headless -u nvim/init.lua '+quitall'`, all green, with the assertion counts written down
- [X] T002 [P] Record in the PR #91 body that the branch also carries the user's out-of-scope `folke/todo-comments.nvim` commit, with the risk accepted explicitly
- [X] T003 [P] Commit the planning artifacts (`plan.md`, `research.md`, `data-model.md`, `quickstart.md`, both contracts) — done in `8c58a0a`; `.specify/feature.json` already points at this spec

---

## Phase 1: Foundational modules

**Purpose**: make both features testable offline and give them one source of truth (FR-025, D3, D8).

**Story Link**: unlinked — shared plumbing for two stories (constitution XV).

- [ ] T010 Create `nvim/lua/config/formatter_chains.lua` holding `markdown_project_markers`, `has_signal(bufnr)` and `M.markdown(bufnr)`, moved verbatim out of `nvim/plugin/conform.lua` so the chain is reachable without the plugin being installed (D8)
- [ ] T011 [P] Create `nvim/lua/config/db_context.lua` holding `M.url_database(url)` and `M.url_from_buffer(buf)`, moved verbatim out of `nvim/lua/config/db_objects.lua:98-141`, so the status line and the query path cannot derive the name differently (FR-025, D3)
- [ ] T012 Require `config.formatter_chains` from `nvim/plugin/conform.lua` and delete the moved locals; `formatters_by_ft.markdown` keeps pointing at the function, with no behavior change
- [ ] T013 Rewire `nvim/lua/config/db_objects.lua` to require `config.db_context` for those two functions; keep `is_sybase()` local (it is not shared) and leave every call site unchanged
- [ ] T014 [P] Create `nvim/lua/tests/formatter_chains_smoke.lua`: harness that builds a temp directory with and without a project marker, calls `M.markdown()` for a buffer inside each, and asserts the chain contents (T010 is the only dependency)
- [ ] T015 [P] Create `nvim/lua/tests/db_context_smoke.lua`: harness with a `check()` helper, a `vim.notify` capture, and helpers to create a scratch buffer with given lines and a `b:db` value (T011 is the only dependency)

---

## Phase 2: Save and it is already clean (FR-001, FR-007)

**Story Link**: [User Story 1 — Save a document and it is already clean (P1)](spec.md#user-story-1---save-a-document-and-it-is-already-clean-priority-p1)

- [ ] T020 Extend the project-signal branch in `M.markdown()` with `'trim_whitespace'` and `'trim_newlines'` **and** `stop_after_first = true`; without the flag the trims would run alongside the main formatter and flatten every hard break (FR-007, D1)
- [ ] T021 Assert in `formatter_chains_smoke.lua` that both chains carry the whitespace fallback and stop after the first available formatter, so a missing main formatter degrades to trimming rather than to nothing (FR-007, SC-003)
- [ ] T022 [P] Assert in `formatter_chains_smoke.lua` that the main formatter is still first in both chains, that a second call returns an equal chain, and that a buffer in a temp directory without any marker takes the other branch (FR-009, SC-005)
- [ ] T023 Create `nvim/lua/tests/markdown_whitespace_smoke.lua`, the one check that needs the real configuration: it requires the formatting toolchain and, when that require fails, prints `SKIP` and exits 0 so the offline suite stays green. Assert the content invariants here, because the steps that perform the cleanup are the toolchain's own: a whitespace-only line becomes an empty line and is not deleted, leading indentation and tabs survive byte for byte, a CRLF file keeps its endings, a save with auto-formatting disabled changes nothing, and a non-Markdown file type is cleaned by the same mechanism rather than a special case (FR-002, FR-003, FR-006, FR-010, FR-011, FR-012, SC-001)
- [ ] T024 [P] Green run of everything built so far — the 8 original smokes, the 2 new offline smokes, `stylua --check nvim`, and the real-configuration boot — with the assertion counts written into the PR body (SC-004)

---

## Phase 3: A missing formatter keeps reporting (FR-008)

**Story Link**: [User Story 2 — The cleanup survives a missing formatter and never stays quiet for long (P2)](spec.md#user-story-2---the-cleanup-survives-a-missing-formatter-and-never-stays-quiet-for-long-priority-p2)

- [ ] T030 Add the save-time availability check in `nvim/plugin/conform.lua`: its own augroup created with `clear = true`, registered on `BufWritePre`, skipping non-file buffers and the same guards `format_on_save` honors (`vim.g.minifiles_active`, `vim.g.skip_formatting`), and calling `require('conform').list_formatters_to_run(bufnr)`; on an empty list with no LSP formatter, emit exactly one WARN through `config.notifications` naming the filetype (FR-008, D2)
- [ ] T031 Set `notify_no_formatters = false` in the same file so the toolchain's own first-failure notice cannot duplicate the new message (FR-008, [contracts/whitespace-fallback.md](contracts/whitespace-fallback.md) §3 rule 1)
- [ ] T032 Extend `markdown_whitespace_smoke.lua` with the [quickstart.md](quickstart.md) §5.3 case: with the formatter directory off `PATH`, save twice and assert two messages naming the file type, and no third message from the toolchain (SC-003)
- [ ] T033 [P] Assert in the same check that a save with an available formatter emits nothing, and that a save excluded from formatting by the `skip_formatting` guard emits nothing ([contracts/whitespace-fallback.md](contracts/whitespace-fallback.md) §4 rule 3)

---

## Phase 4: The formatter's real rules are documented, not assumed (FR-004, FR-005)

**Story Link**: [User Story 3 — Intentional line breaks keep working (P3)](spec.md#user-story-3---intentional-line-breaks-keep-working-priority-p3)

- [ ] T040 Extend `markdown_whitespace_smoke.lua` with the Markdown rule cases: write a canned file and assert the four verified outcomes — a two-space break with following text preserved, three spaces reduced to two, a two-space break on a paragraph's last line removed, heading and fenced-block spaces removed (FR-004, FR-005, SC-002)
- [ ] T041 [P] Add the full-configuration invocation of that check to [quickstart.md](quickstart.md) §5 and to the README validation block, so the rule assertions actually run somewhere instead of skipping silently (constitution VIII)
- [ ] T042 [P] Write the four rules, with a one-line reason for each, into the `nvim/README.md` behavior notes: what is preserved, what is normalized, what is removed, and that none of it changes the rendered output (FR-004, FR-005, FR-013, constitution XIV)
- [ ] T043 [P] Record the accepted degradation in the same section: on a machine without the main formatter the fallback trims bluntly and flattens this document's hard breaks, which is pre-existing behavior now shared by both chains (D1, [contracts/whitespace-fallback.md](contracts/whitespace-fallback.md) §2 rule 3)

---

## Phase 5: Know which database a query will run against (FR-016–FR-025)

**Story Link**: [User Story 4 — Know which database a query will run against (P2)](spec.md#user-story-4---know-which-database-a-query-will-run-against-priority-p2)

- [ ] T050 Add to `nvim/lua/config/db_context.lua`: `M.database(bufnr)` (the URL's database or nil), `M.switches(bufnr)` (the last `use`, else the first two-part name, as `{ kind, name }`), `M.label(bufnr)` and `M.conflict(bufnr)`; the text scan strips `--` comments, carries `/* … */` state across lines, removes single-quoted literals, and matches names with a class allowing `$` and `#` (FR-016, FR-017, FR-021, FR-023, D5)
- [ ] T051 [P] Add the status-line component in `nvim/plugin/editor.lua`: a function that renders `M.label(bufnr)` for `filetype = sql` buffers and an empty string for every other filetype, registered in both `sections.lualine_y` and `inactive_sections.lualine_y`, with a distinct highlight when a conflict is present (FR-016, FR-017, FR-018, FR-024, D4, D7)
- [ ] T052 [P] Add `M.setup()` in `nvim/lua/config/db_context.lua`: guarded by a `setup_done` flag like `db_results.setup()`, registering a `User */DBExecutePre` callback that emits one WARN naming the connection's database and the reported switch, and returns without touching the query. The event is the one the query tool already emits, so no new trigger is registered and the other result module stays untouched (FR-019, FR-020, FR-022, SC-010, D6)
- [ ] T053 Call `db_context.setup()` from `nvim/plugin/database.lua` beside the existing `db_objects.setup()` and `db_results.setup()` calls; `db_results` itself stays untouched (D6, constitution IV)
- [ ] T054 Assert in `db_context_smoke.lua`: database from a string connection and from both table forms, absent connection, `use` detected, last `use` wins, two-part name detected, `$`/`#` names intact, `use` inside a line comment ignored, `db..object` inside a string ignored, a block comment spanning lines ignored, a non-`sql` filetype renders nothing, a connection-less SQL buffer renders the marker (FR-016–FR-024, SC-006, SC-007, SC-008)
- [ ] T055 [P] Assert in `db_context_smoke.lua`, driving `nvim_exec_autocmds('User', { pattern = '*/DBExecutePre' })` the way `db_results_smoke.lua` does: one message for a conflicting buffer, zero for a clean one, and the buffer's lines unchanged afterwards (SC-010, FR-020)
- [ ] T056 [P] Assert in `db_context_smoke.lua` that no label and no message ever contains the connection URL or its host, only the database name ([contracts/db-indicator.md](contracts/db-indicator.md) §2 rule 5, constitution VII)

---

## Phase 6: Out of spec — the plugin the user added

**Purpose**: keep the branch honest about what it carries. The user included
`folke/todo-comments.nvim` in this PR on purpose and accepted the risk; it is not a story of this
spec.

**Story Link**: unlinked — not a user story of this spec (constitution XV).

- [ ] T060 Replace the placeholder comment in the `folke/todo-comments.nvim` entry in `nvim/plugin/editor.lua` with a one-line comment in the repository's style stating that the defaults are intentional, and keep the empty `opts`
- [ ] T061 [P] Document the plugin in `nvim/README.md`: what it is for, that it has no configuration surface, that it is pinned in `nvim/nvim-pack-lock.json`, and that it is unrelated to the two stories of this spec (constitutions VI, XIV)

---

## Phase 7: Documentation and governance

**Story Link**: unlinked — module and workflow obligations (constitution XV).

- [ ] T070 [P] Add the database-indicator row and the whitespace-fallback row to the `nvim/README.md` behavior table, and add traceability entries for every new function to the function table (constitution XIV, FR-013)
- [ ] T071 [P] Add the new validation commands to the `nvim/README.md` validation block: both offline smokes and the full-configuration Markdown check (constitution VIII)
- [ ] T072 Give every new production function the module's uniform header block — name, called by, SQL, args, returns, side effects — in `formatter_chains.lua`, `db_context.lua`, and the touched functions of `plugin/conform.lua` (constitution XII)
- [ ] T073 Confirm the invariants the constitution and the spec care about: no new runtime dependency from these two features, no new configuration file, no new save-time cleanup mechanism, no change outside the Neovim module, and the validation suite green (FR-009, FR-015, SC-004, constitution XI)
- [ ] T074 Commit on `009-trim-trailing-whitespace` with conventional messages, push, and update the PR #91 body with the phase status; no commit targets `main`, and issue #90 is already approved and linked (FR-014)

---

## Phase 8: Manual acceptance

**Purpose**: the only work that cannot be automated. Live database required for the indicator
scenarios; a restricted `PATH` for the fallback scenario.

- [ ] T101 Run [quickstart.md](quickstart.md) §6 scenarios 6.1–6.9: indicator with and without a conflict, one warning per execution and none without, marker with no connection, nothing in the drawer or a result buffer, owning database on a procedure source, indicator following a scope change (SC-006, SC-010)
- [ ] T102 Run [quickstart.md](quickstart.md) §5.2: with the formatter off `PATH`, a Markdown file is still trimmed and its hard breaks are flattened as documented (FR-007, FR-004 qualification)
- [ ] T103 Confirm with the server unreachable that the indicator still renders and still reports the right database, proving no round trip is involved (SC-009, FR-021)
- [ ] T104 Write `verify-report.md` with the real gate output and the manual results, and mark this spec for archival — it is not closed until T101–T103 are recorded

---

## Dependencies

| Task | Blocked by | Blocks |
| --- | --- | --- |
| T010, T014 | — | T012, T020, T021, T022 |
| T011, T015 | — | T013, T050, T054, T055, T056 |
| T012 | T010 | T020 |
| T020 | T012 | T021, T022 |
| T030 | — | T032 |
| T031 | — | T032 |
| T050 | T011 | T051, T052, T054 |
| T051, T052 | T050 | T101 |
| T053 | T052 | T101 |
| T070–T072 | T030, T040, T050 | T074 |

**Critical path to the user's reported pain**: T011 → T050 → T051/T052 → T053 → T101.

## Parallel execution waves

```text
Wave 1  T001 | T002 | T003
Wave 2  T010 | T011 | T030 | T031 | T060
Wave 3  T012 | T013 | T014 | T015 | T032 | T061
Wave 4  T020 | T040 | T050
Wave 5  T021 | T022 | T023 | T024 | T041 | T042 | T043 | T051 | T052
Wave 6  T033 | T053 | T054
Wave 7  T055 | T056
Wave 8  T070 | T071 | T072
Wave 9  T073 → T074
Wave 10 T101 | T102 | T103 → T104
```

## Independent test per story

Each story can be validated on its own, without the others, as required by the spec:

| Story | Independent test |
| --- | --- |
| US1 | Save a Markdown file in a directory with and without a formatter configuration, with the formatter off `PATH`, and confirm trimming still happens (T021, T022, T102) |
| US2 | Save a file type with nothing available, twice, and confirm two messages (T032) |
| US3 | Run the canned Markdown file through the real formatter and confirm the four outcomes (T040) |
| US4 | Open a query buffer, type a `use`, and read the status line — no server involved (T054, T101) |
