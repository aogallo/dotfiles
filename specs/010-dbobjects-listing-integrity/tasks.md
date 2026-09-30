---

description: "Task list for the trusted :DBObjects listing (issue #92)"
---

# Tasks: Trusted `:DBObjects` Listing

**Input**: Design documents from `/specs/010-dbobjects-listing-integrity/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/sybase-listing-integrity.md](contracts/sybase-listing-integrity.md),
[quickstart.md](quickstart.md)

**Tests**: Included and REQUIRED. The constitution (VIII) requires smoke tests covering the
success path and the failure paths before the change is complete, and the specification makes
validation a hard gate (FR-037, SC-009). [quickstart.md](quickstart.md) §3 is the authority for
what each test must assert.

**Organization**: Tasks are grouped by user story so each story can be implemented, tested and
delivered independently. Each user-story phase links to its matching heading in
[spec.md](spec.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable — touches a different file, or has no dependency on incomplete work.
- **[US#]**: User story marker. The phase's `Story Link` points to the matching `spec.md` heading.
- **[R#]**: Contract reference marker, pointing at a section of
  [contracts/sybase-listing-integrity.md](contracts/sybase-listing-integrity.md).
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

Phases **1** (Setup) and **2** (Foundational) and the final **Polish** phase carry **no** `[US#]`
label, per the format rules. Only user-story phases are labelled.

## Path Conventions

Single project (dotfiles repo). Neovim module paths only; no other subtree is touched.

```text
nvim/
├── autoload/db/adapter/sybase.vim      # SQL + autoload adapter surface
├── lua/config/db_objects.lua           # picker flow
├── lua/config/db_context.lua           # UNCHANGED — url_database() already supplies the request
├── plugin/database.lua                 # UNCHANGED — :DBObjects already takes the optional arg
├── README.md                           # module documentation (constitution XIV)
└── lua/tests/*_smoke.lua               # headless smoke suites
```

Files explicitly **not** modified, listed so a task does not wander into them: `db_context.lua`,
`plugin/database.lua`, `db_connections.lua`, `keymaps.lua`, `plugin/fzf-lua.lua`,
`db_objects_save_smoke.lua`, `keymap_groups_smoke.lua`, every installer script, every module
outside `nvim/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the baseline and the shared helpers every story depends on. No story code
here.

- [X] T001 Record the pre-change baseline: run all four existing suites and capture their assertion counts per [quickstart.md](quickstart.md) §2, so a pre-existing failure is not misattributed later
- [X] T002 [P] Verify the working tree is clean apart from intended changes, and that HEAD is not `main`; create/switch to branch `010-dbobjects-listing-integrity` (constitution XIII)
- [X] T003 [P] Add the `char(2)` root-cause note as a header comment above `db#adapter#sybase#objects` in `nvim/autoload/db/adapter/sybase.vim`, citing the SAP ASE `sysobjects` type table, so the single-letter mistake cannot be reintroduced
- [X] T004 [P] Correct the stale documented kind set in `nvim/lua/config/db_objects.lua` (comment above `fetch_objects`, currently `'P','FN','IF','TF','V','U'`) to match the contract; it currently matches neither the code nor the server
- [X] T005 [P] [R1] Add the `DOBJ~` / `DCNT~` / `DDB~` row markers and the two-character type table (`U`,`V`,`P`,`SF`,`TR`,`XP`,`IT`) as shared script-local constants in `nvim/autoload/db/adapter/sybase.vim`
- [X] T006 [P] [R5] Rewrite `s:object_kind()` in `nvim/autoload/db/adapter/sybase.vim` to trim the `char(2)` value and map all six covered types, passing an unmapped type through verbatim instead of dropping it

**Checkpoint**: Baseline recorded, constants and kind mapping in place. No behaviour change yet —
the four suites from T001 must still pass.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T007 [R1.2] Change `db#adapter#sybase#objects()` in `nvim/autoload/db/adapter/sybase.vim` to emit marker-prefixed rows (`DOBJ~<name>~<type>`) plus a count row (`DCNT~<n>`) in **one** batch, and to return `{ rows, reported, excluded, diagnostics }` instead of a bare list — breaking, per [contracts](contracts/sybase-listing-integrity.md) §1.2
- [X] T008 [R1.2] Replace the positional two-token parser in `nvim/autoload/db/adapter/sybase.vim` with a marker-only parser: accept a row **only** if it starts with `DOBJ~` and carries a non-empty trimmed name and type; classify every other output line as a diagnostic or a dropped-row record, never silently
- [X] T009 [R1.2] Stop discarding server diagnostics: remove the listing's use of the single-token filtering helper in `nvim/autoload/db/adapter/sybase.vim` and return a `diagnostics` list, since dropping every `Msg …` line is the mechanism behind the reported silence (FR-022)
- [X] T010 [R1.1] Add `db#adapter#sybase#confirm_database(url)` to `nvim/autoload/db/adapter/sybase.vim`, returning `{ requested, confirmed, result, exists }` and detecting by state via `select 'DDB~' + db_name()` compared against the request — never by parsing diagnostic text, and never via the client's `Changed database context` line, which `isql` does not emit
- [X] T011 [R1.1] Add the existence probe to `nvim/autoload/db/adapter/sybase.vim` in the **same batch** as the confirmation, reading the server-wide database list by name, so `rejected_absent` and `rejected_forbidden` are distinguishable at zero extra round trips (FR-007, [research.md](research.md) R-0004)
- [X] T012 Add the confirmed-scope state accessor and the direct-open request shape to `nvim/lua/config/db_objects.lua` per [data-model.md](data-model.md) §3 and §7, including the `source = 'verified' | 'none'` distinction and the `qualified` flag
- [X] T013 [P] Update `fetch_objects` in `nvim/lua/config/db_objects.lua` to consume the new `{ rows, reported, excluded, diagnostics }` return shape and to stamp each row's `database` from the **confirmed** scope rather than the URL's requested name
- [X] T014 [P] Add the reconciliation arithmetic in `nvim/lua/config/db_objects.lua` per [data-model.md](data-model.md) §4, including the invariant `shown + excluded = reported` and the missing-count-row case that marks the listing partial

**Checkpoint**: Foundation ready. The adapter compiles, `objects()` returns the new shape, and
confirmation exists. The picker does not yet use either — user stories do that.

---

## Phase 3: User Story 1 - A listing always belongs to the database I chose (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---a-listing-always-belongs-to-the-database-i-chose-priority-p1)

**Goal**: A listing is only ever presented under a database the server confirmed, and a rejected
switch produces one actionable message instead of another database's objects.
**Requirements**: FR-001 – FR-008, FR-025, FR-028.

**Independent Test**: Connected to database A, choose B and confirm every row belongs to B. Then
choose a database the login cannot read, a name that does not exist, and a syntactically invalid
name. In all three failure cases no listing is presented as belonging to the chosen database, and
exactly one message is emitted. The single most important assertion: **stub a confirmation
mismatch and confirm the picker label does not read as the requested database** (invariant I3).

### Tests for User Story 1 ⚠️

> Write these first and confirm they FAIL before implementing. Per [quickstart.md](quickstart.md) §3.3.

- [X] T015 [P] [US1] [R1.1] Assert `confirm_database` returns `confirmed` when the reported name matches the request, and `no_database` when the URL carries none, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T016 [P] [US1] [R1.1] Assert `confirm_database` returns `rejected_absent` when the reported name differs and the existence probe reports 0, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T017 [P] [US1] [R1.1] Assert `confirm_database` returns `rejected_forbidden` when the reported name differs and the probe reports 1, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T018 [P] [US1] Assert confirmation costs exactly **one** client invocation, and that the count is identical for a 3-row and a 3,000-row stub, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T019 [P] [US1] Assert each rejection path yields exactly one `vim.notify` and **no** listing, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T020 [P] [US1] Assert the picker label derives from the confirmed value, not the requested one — a stubbed mismatch must not render the requested name, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T021 [P] [US1] Assert a missing client yields exactly one message naming the connection and no empty picker, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T022 [P] [US1] Assert a syntactically invalid database name is rejected locally with zero client invocations, in `nvim/lua/tests/db_objects_scope_smoke.lua`

### Implementation for User Story 1

- [X] T023 [US1] Wire `apply_database_scope()` in `nvim/lua/config/db_objects.lua` to call `confirm_database` and set the confirmed scope only on `result = 'confirmed'`; on any rejection emit exactly one message and leave the previous scope untouched
- [X] T024 [US1] Derive the picker header and the `Database: <scope> — change…` label in `nvim/lua/config/db_objects.lua` from the confirmed scope, and render `login default` when `source = 'none'`, so no label ever names an unconfirmed database
- [X] T025 [US1] Distinguish the two rejection messages in `nvim/lua/config/db_objects.lua` (database absent vs. login not permitted) so the developer gets a different hint for a typo and for a permission problem
- [X] T026 [US1] Handle `result = 'no_database'` in `nvim/lua/config/db_objects.lua` so a connection with no database still lists against the login default, labelled as such
- [X] T027 [US1] Report an empty listing on a **confirmed** scope as an empty result for that database, visibly distinct from a failure, in `nvim/lua/config/db_objects.lua`
- [X] T028 [US1] Change the failure path in `nvim/lua/config/db_objects.lua` so a failed selection does **not** re-present a previously obtained listing as if it answered the new request (FR-025) — this deliberately reverses the current last-good-reopen behaviour
- [X] T029 [US1] Surface any `diagnostics` returned with a successful listing in `nvim/lua/config/db_objects.lua` instead of dropping them (FR-022)

**Checkpoint**: User Story 1 fully functional and independently testable. A wrong-database listing
is no longer reachable. **This is the MVP** — it alone resolves the reported symptom of issue #92.

---

## Phase 4: User Story 2 - Every object the developer works with is listed (Priority: P1)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---every-object-the-developer-works-with-is-listed-priority-p1)

**Goal**: The listing covers tables, views, procedures, user-defined functions and triggers — the
kinds that were silently missing because ASE stores `type` as `char(2)`.
**Requirements**: FR-009 – FR-014.

**Independent Test**: For a confirmed database, compare the listing against the objects the server
reports for the five covered kinds; every one appears and the counts agree. Confirm the `SF` and
`TR` cases specifically, which are impossible today. Confirm the listing states which kinds it
covers.

### Tests for User Story 2 ⚠️

> Per [quickstart.md](quickstart.md) §3.1. A failure here means the root cause was not fixed.

- [X] T030 [P] [US2] [R1.5] Assert each covered type maps correctly — `P`→procedure, `SF`→function, `TR`→trigger, `V`→view, `U`→table, `XP`→function — in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T031 [P] [US2] [R1.5] Assert a blank-padded `char(2)` value (`U ` with trailing space) is trimmed and still classified as a table, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T032 [P] [US2] [R1.5] Assert an unmapped type such as `SQ` is carried through verbatim as the row's kind and is **not** dropped, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T033 [P] [US2] [R1.2] Assert the emitted query contains `'SF'`, `'TR'` and `'XP'` and does **not** contain the single-letter `'F'` or `'X'` as standalone kind values, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T034 [P] [US2] [R1.2] Assert a heading, a dashed separator, a `(N rows affected)` trailer and a `Changed database context to 'X'.` line are each classified as a diagnostic or dropped row and never become objects, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T035 [P] [US2] [R1.2] Assert the listing costs exactly **one** client invocation and obtains `reported` from the `DCNT~` row rather than `len(rows)`, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T036 [P] [US2] Assert the picker states which object kinds the listing covers, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T037 [P] [US2] Assert opening a listed object reads its source from the confirmed database, never the connected one, in `nvim/lua/tests/db_objects_scope_smoke.lua`

### Implementation for User Story 2

- [X] T038 [US2] [R1.2] Change the listing query filter in `db#adapter#sybase#objects` (`nvim/autoload/db/adapter/sybase.vim`) to exactly `type in ('U','V','P','SF','TR','XP')`, removing the never-matching `'X'` and the SQLJ-only `'F'`
- [X] T039 [US2] Ensure `nvim/lua/config/db_objects.lua` renders the new `trigger` kind without breaking the existing `table`/`view` routing in `open_row()` (tables and views open the list query; everything else opens source)
- [X] T040 [US2] Add the covered-kinds declaration to the picker header in `nvim/lua/config/db_objects.lua` so the developer always knows what the listing covers
- [X] T041 [US2] Confirm the extended-procedure and function cases are reachable end-to-end in `nvim/lua/config/db_objects.lua` — both were listed as supported but have never actually worked

**Checkpoint**: User Stories 1 AND 2 both independently functional. Triggers and user-defined
functions are now listable, which no prior version of this command achieved.

---

## Phase 5: User Story 3 - Open an object the listing does not contain (Priority: P2)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---open-an-object-the-listing-does-not-contain-priority-p2)

**Goal**: A picker entry that opens any object by name from the confirmed database, reusing the
existing source reader — so listing incompleteness stops mattering.
**Requirements**: FR-015 – FR-021, FR-033 – FR-039.

**Independent Test**: With a confirmed database, take an object of an uncovered kind, choose the
entry, supply the name, and confirm the source opens from the confirmed database. Then supply a
nonexistent name (one notice, no buffer). Then run with no confirmed database and confirm the entry
is not offered.

### Tests for User Story 3 ⚠️

> Per [quickstart.md](quickstart.md) §3.4.

- [X] T042 [P] [US3] [R3.2] Assert the entry is **absent** when no database is confirmed, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T043 [P] [US3] [R3.2] Assert **zero** requests are issued between opening the name prompt and confirming a name, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T044 [P] [US3] [R3.2] Assert a valid name opens the source bound to the confirmed database, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T045 [P] [US3] [R3.2] Assert an unknown name yields exactly one actionable notice and **no** buffer, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T046 [P] [US3] [R3.2] Assert cancelling the prompt is a pure no-op — no buffer, no request, no state change, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T047 [P] [US3] [R3.2] Assert a two-part qualified name is rejected with a message pointing at the scope control, in `nvim/lua/tests/db_objects_scope_smoke.lua`

### Implementation for User Story 3

- [X] T048 [US3] [R3.1] Add the `Open object by name…` entry to the picker in `nvim/lua/config/db_objects.lua`, positioned after the object rows
- [X] T049 [US3] [R3.2] Guard the entry on a `verified` confirmed scope in `nvim/lua/config/db_objects.lua`; without this guard it would read from an unknown database and reintroduce issue #92 (FR-035)
- [X] T050 [US3] [R3.2] Implement the name prompt in `nvim/lua/config/db_objects.lua` that issues no request until confirmed, and reuses `db#adapter#sybase#source()` with the confirmed scope's URL and the existing `g:db_sybase_source_mode`
- [X] T051 [US3] [R3.2] Reject a qualified two-part name in `nvim/lua/config/db_objects.lua` with a message pointing at the scope control, so the capability closed in `specs/archive/2026-09-25-001-multidb-object-search/` stays closed (FR-039)
- [X] T052 [US3] Confirm the direct-open path issues exactly **one** source read and adds no new SQL, no new mode and no new dependency in `nvim/autoload/db/adapter/sybase.vim`

**Checkpoint**: User Stories 1, 2 and 3 independently functional. Any object in the confirmed
database is reachable regardless of the listing's coverage.

---

## Phase 6: User Story 4 - Failures name themselves instead of leaving me to guess (Priority: P2)

**Story Link**: [US4 in spec.md](./spec.md#user-story-4---failures-name-themselves-instead-of-leaving-me-to-guess-priority-p2)

**Goal**: Exactly one message per failure, naming the subject and the plausible causes, with no
empty picker and no substitute result.
**Requirements**: FR-022 – FR-028, FR-035.

**Independent Test**: Enumerate every failure the tool can hit — no permission, absent database,
catalog read denied, connection failure, missing client, unreadable source, unparseable result —
and for each assert exactly one message naming the subject and no substitute listing.

### Tests for User Story 4 ⚠️

- [X] T053 [P] [US4] Assert a catalog-read denial produces exactly one message naming the database and the likely cause, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T054 [P] [US4] Assert the preserved no-ops still hold — chooser cancel, prompt cancel, re-selecting the active database — in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T055 [P] [US4] Assert the existing unreadable-source notice is unchanged in wording and count, in `nvim/lua/tests/db_objects_save_smoke.lua`
- [X] T056 [P] [US4] Assert a diagnostic accompanying a successful listing is surfaced exactly once, not once per line, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T057 [P] [US4] Assert no failure path opens an empty picker in `nvim/lua/tests/db_objects_scope_smoke.lua`

### Implementation for User Story 4

- [X] T058 [US4] Centralize failure reporting in `nvim/lua/config/db_objects.lua` so every path emits exactly one message naming its subject and the plausible causes
- [X] T059 [US4] Add the catalog-read-denied message in `nvim/lua/config/db_objects.lua`, distinct from an empty result
- [X] T060 [US4] Upgrade the missing-client path in `nvim/lua/config/db_objects.lua` from silent-empty to an actionable message naming the connection and the missing prerequisite (FR-035)
- [X] T061 [US4] Verify by inspection that the existing no-op behaviours in `nvim/lua/config/db_objects.lua` are unchanged, and that no failure path re-presents a prior listing (FR-027, FR-025)

**Checkpoint**: User Stories 1–4 independently functional. Every failure is self-describing.

---

## Phase 7: User Story 5 - I can tell whether a listing is complete (Priority: P3)

**Story Link**: [US5 in spec.md](./spec.md#user-story-5---i-can-tell-whether-a-listing-is-complete-priority-p3)

**Goal**: The listing reports what the server said, what is shown, and what was left out, so
"not in the list" always has an explanation.
**Requirements**: FR-029 – FR-031.

**Independent Test**: Build listings for databases of varying object counts, including one where
results are deliberately truncated or partially unreadable, and confirm the reported totals always
reconcile with what is displayed.

### Tests for User Story 5 ⚠️

- [X] T062 [P] [US5] Assert `shown + excluded = reported` for a listing with excluded rows, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T063 [P] [US5] Assert a **missing** `DCNT~` row yields `reported = 0` and marks the listing partial rather than complete, in `nvim/lua/tests/sybase_objects_smoke.lua`
- [X] T064 [P] [US5] Assert `excluded > 0` makes the picker state the listing is partial with the count, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T065 [P] [US5] Assert a display-limited listing states how many objects were not shown, in `nvim/lua/tests/db_objects_scope_smoke.lua`
- [X] T066 [P] [US5] Assert raw dropped-row text is shown only when the count is non-zero and is trimmed, never dumped unbounded, in `nvim/lua/tests/db_objects_scope_smoke.lua`

### Implementation for User Story 5

- [X] T067 [US5] Render the reconciliation record in `nvim/lua/config/db_objects.lua`: objects reported, shown, and excluded, each counted over the covered kinds
- [X] T068 [US5] State that the listing is partial, with the number excluded, whenever `excluded > 0`, in `nvim/lua/config/db_objects.lua`
- [X] T069 [US5] State the number not shown when rows are withheld for display, in `nvim/lua/config/db_objects.lua`
- [X] T070 [US5] Summarize dropped-row records once, trimmed, and only when non-zero, in `nvim/lua/config/db_objects.lua`

**Checkpoint**: All user stories independently functional. Every listing is self-describing.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements and obligations that affect multiple user stories.

- [X] T071 [P] Update `nvim/README.md` with the covered kind set as plain language, the `char(2)` explanation and why the earlier single-letter set was wrong (FR-038)
- [X] T072 [P] Document in `nvim/README.md` the direct-open entry, that it requires a confirmed database, and that the system catalogue is deliberately not enumerated, with the reason
- [X] T073 [P] Add the live-server validation steps from [quickstart.md](quickstart.md) §4 to `nvim/README.md` as documented manual-only operations (constitution XIV)
- [X] T074 Run the full validation set from [quickstart.md](quickstart.md) §3 and record the results in `specs/010-dbobjects-listing-integrity/verify-report.md`
- [ ] T075 Run the live-server validation from [quickstart.md](quickstart.md) §4.2 and record the outcome, including the reproduction of issue #92 against the old code (§4.1)
- [ ] T076 Answer the two open questions in [quickstart.md](quickstart.md) §4.3 — whether `IT` rows accompany `TR`, and whether `db_id()` conflates absent with not-permitted — and record both in `verify-report.md`
- [X] T077 Verify the server-load budget from [contracts](contracts/sybase-listing-integrity.md) §2: 1–2 client invocations per invocation, identical for 50 and 50,000 objects, and zero statements that write, create a temporary object, or take a blocking lock
- [X] T078 Confirm no secret, credential, or machine-specific absolute path entered `nvim/autoload/db/adapter/sybase.vim`, `nvim/lua/config/db_objects.lua` or `nvim/README.md` (constitution VII)
- [X] T079 [P] Verify no change was made to `nvim/lua/config/db_context.lua`, `nvim/plugin/database.lua`, `nvim/lua/config/db_connections.lua`, `nvim/lua/config/keymaps.lua`, `nvim/plugin/fzf-lua.lua`, or anything outside `nvim/` (constitutions IV, V)
- [X] T080 [P] Re-run the two untouched suites — `tests/db_objects_save_smoke` and `tests/keymap_groups_smoke` — and confirm they pass unmodified, proving the save flow and keymaps are unaffected
- [ ] T081 Commit on branch `010-dbobjects-listing-integrity` with conventional commit messages; never commit directly to `main` (constitution XIII)
- [ ] T082 Before opening the PR: confirm the PR scope is related to this specification, link issue #92 in the PR body, and **ask the developer whether `specs/010-dbobjects-listing-integrity/spec.md` should be closed as the completed solution**, recording the outcome in `specs/010-dbobjects-listing-integrity/verify-report.md` (constitution XIII, FR-039)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — **BLOCKS all user stories**.
- **User Stories (Phases 3–7)**: All depend on Foundational completion.
  - US1 and US2 are both P1 and touch the same two files; run them **sequentially** (US1 then US2)
    to avoid same-file conflicts.
  - US3, US4 and US5 are P2/P3 and also touch `nvim/lua/config/db_objects.lua`; run them
    sequentially after US2, or in parallel only by different people on separate branches.
- **Polish (Phase 8)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational. No dependency on any other story. **Delivers the MVP.**
- **US2 (P1)**: Starts after Foundational. Independent of US1, but shares
  `nvim/autoload/db/adapter/sybase.vim` with it — sequence after US1 to avoid conflicts.
- **US3 (P2)**: Starts after Foundational. **Soft dependency on US1**: it requires a *verified*
  confirmed scope, so it is only reachable once US1 exists. Hard-blocked on T023/T024.
- **US4 (P2)**: Starts after Foundational. Independent in principle; touches the same Lua file as
  US1/US3, so sequence it. Depends on US1's single-message paths to avoid duplicating them.
- **US5 (P3)**: Starts after Foundational. Depends on the `reported`/`excluded` fields from
  Phase 2 (T007, T014), not on any other story.

### Within Each User Story

- Tests MUST be written and confirmed to fail before implementation.
- Adapter (SQL) before picker (flow/UI) when both are in the same story.
- Core implementation before integration with another story.
- Story complete before moving to the next priority.
- A task is complete only when its test is green — not when the code is written.

### Parallel Opportunities

- Phase 1: T002, T003, T004, T005, T006 are all `[P]`.
- Phase 2: T013 and T014 are `[P]`; T007–T012 are sequential within the adapter.
- Within every story phase, the test tasks are `[P]` and can all be written together, then run
  together to confirm they fail.
- Phase 8: T071, T072, T073, T079, T080 are `[P]`.
- **Not parallel**: any two tasks that both edit `nvim/autoload/db/adapter/sybase.vim`, or any two
  that both edit `nvim/lua/config/db_objects.lua`.

---

## Parallel Example: User Story 1

```bash
# Launch the adapter-level confirmation tests together (different file from the picker tests):
Task: "Assert confirm_database returns confirmed / no_database in nvim/lua/tests/sybase_objects_smoke.lua"
Task: "Assert confirmation costs one client invocation in nvim/lua/tests/sybase_objects_smoke.lua"
Task: "Assert confirm_database returns rejected_absent in nvim/lua/tests/sybase_objects_smoke.lua"
Task: "Assert confirm_database returns rejected_forbidden in nvim/lua/tests/sybase_objects_smoke.lua"

# Then, separately, the picker-level tests (must not run while the adapter file is mid-edit):
Task: "Assert each rejection yields one notify and no listing in nvim/lua/tests/db_objects_scope_smoke.lua"
Task: "Assert the label derives from the confirmed value in nvim/lua/tests/db_objects_scope_smoke.lua"
Task: "Assert a missing client yields one message in nvim/lua/tests/db_objects_scope_smoke.lua"
Task: "Assert an invalid database name is rejected locally in nvim/lua/tests/db_objects_scope_smoke.lua"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (baseline + constants + kind mapping)
2. Complete Phase 2: Foundational (**CRITICAL** — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: confirm a wrong-database listing is unreachable
5. Demo — this alone resolves the reported symptom of issue #92

### Incremental Delivery

1. Setup + Foundational → foundation ready
2. US1 → validate → **MVP**: a listing can no longer belong to the wrong database
3. US2 → validate → triggers and user-defined functions become listable for the first time
4. US3 → validate → any object is reachable by name
5. US4 → validate → every failure explains itself
6. US5 → validate → every listing reports its own completeness
7. Polish → docs, live-server validation, PR

Each story adds value without breaking the previous ones. US1 and US2 together close the
`char(2)` root cause; US3 makes the remaining curated limit harmless.

### Parallel Team Strategy

With multiple people, split by **file**, not by story, because US1–US5 all touch the same two
files:

1. Team completes Setup + Foundational together
2. Then, on separate branches:
   - Developer A: the adapter (`nvim/autoload/db/adapter/sybase.vim`) — owns T015–T018, T030–T035
   - Developer B: the picker (`nvim/lua/config/db_objects.lua`) — owns T019–T022, T036–T037
3. Merge adapter before picker; the picker's tasks consume the new `objects()` return shape

---

## Notes

- [P] tasks = different files, no dependencies on incomplete work
- [US#] tasks map to the linked story phase; update the phase `Story Link` if the spec heading changes
- [R#] tasks trace to a contract section; update the reference if the contract is renumbered
- Each user story must be independently completable and testable
- Verify tests fail before implementing — for this feature that matters most, since the current
  behaviour is the bug
- Commit after each task or logical group on the feature branch, never directly on `main`
- Before creating a PR, verify the active spec is related to the PR and ask whether it should be closed
- Every affected maintained module must have a README with purpose, source-of-truth files,
  prerequisites, manual install/activation, installer support, validation, customization
  boundaries, rollback/recovery, and manual-only operations
- Stop at any checkpoint to validate a story independently
- Avoid: vague tasks, same-file conflicts, cross-story dependencies that break independence
- **No open questions remain.** The one assumption that gated T050 — whether "execute the function
  with the params you provide" meant running the object-help command or executing the object — was
  confirmed by the developer (2026-09-25) as *reuse the existing source path*. T050 proceeds as
  written ([research.md](research.md) R-0006).
