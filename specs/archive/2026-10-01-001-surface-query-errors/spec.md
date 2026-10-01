# Feature Specification: Query Errors Are Always Surfaced

**Feature Branch**: `012-surface-query-errors`

**Created**: 2026-10-01

**Status**: Closed (archived 2026-10-01; see [verify-report.md](./verify-report.md))

**Input**: User description: "ahora tengo este issue https://github.com/aogallo/dotfiles/issues/98. Basicamente es que si hay un error de sintxis no se muestra el error"

> **Issue #98 (reported)**: The developer wrote a query whose text has a syntax error, ran it
> from the editor, and **nothing was shown** — no message, no error, nothing to indicate the
> query had failed. Copying the same text into the standalone database client produced an
> immediate, precise complaint (`incorrect syntax near the keyword 'else'`, then
> `incorrect syntax near 'end'`), which confirmed the query was invalid and that the editor
> was the thing failing to report it.
>
> After correcting the query, the developer hit a **second** failure: running the now-valid
> query in the editor raised an internal error pointing at the editor's own database-context
> module (`invalid value (nil) at index 1 in table`), and **the query did not run at all**.
> The same corrected query runs correctly in the standalone client and returns the expected
> row.
>
> **Root causes established during investigation** (both reproduced against this repository's
> own code; each is traceable to a specific place, so the requirements below are traceable to
> a cause rather than to a guess):
>
> 1. **Nothing in the query path classifies what the server said.** When a query runs, its
>    output is written to a result file and the editor records *where* that file is, so it can
>    be summoned later. From that moment on the content is never looked at again. A server
>    complaint is indistinguishable from a successful result set, so a failed run and a
>    successful run look exactly the same. The report is precisely this: the run finished,
>    nothing appeared, and the developer had no way to tell failure from success.
> 2. **A server complaint does not always even reach a place where it could be read.** Some
>    parts of the database tooling explicitly discard the server's diagnostic lines and
>    reduce a failure to the same empty answer a legitimately empty result produces. So a
>    syntax error is not merely unreported in one path — it is actively thrown away in others.
> 3. **One failure is reported as a different, wrong failure.** A database-selection check
>    ignores the server's complaint and infers its answer from markers that a syntax error
>    also removes. The check then reports that a database "does not exist", sending the
>    developer to fix a name that was correct all along. The code's own comment documents the
>    opposite of what it does.
> 4. **A self-check crashes on ordinary SQL, and the crash blocks execution.** Before a query
>    runs, the editor inspects the query's text to warn when it would target a different
>    database than the connection declares. That inspection blanks out comments and string
>    literals — and it miscounts the text it blanks. On a line whose first comment or literal
>    is not at the very start of the line, the routine that rejoins the blanked text fails
>    outright. This is the reported internal error, at the exact line and with the exact
>    message the developer quoted. Because the inspection runs immediately before execution,
>    the crash **prevents the query from running**, which is why a corrected query appeared
>    not to run.
> 5. **The same miscount silently loses the warning instead of crashing.** When the routine
>    does not crash, it blanks far more of the line than it should — frequently the entire
>    line. A `use other_database` statement that carries a trailing comment, or a
>    cross-database reference that carries a literal, is therefore not recognised. The
>    developer loses the cross-database warning with no message at all, which is the more
>    dangerous half of the same defect: a crash is noticed, a silently missing warning is not.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A failed query tells me it failed (Priority: P1)

As a developer, when I run a query and the server rejects it, I find out — in a place I am
already looking, without having to go hunting. I see what the server said, so I know whether
the problem is my syntax or my assumptions, and I do not have to reproduce the query in a
separate tool to find out what went wrong. A query that succeeds and a query that fails never
look the same to me.

**Why this priority**: This is the report. The developer ran a query, nothing was shown, and
the only way to learn the truth was to leave the editor and re-run the text in another tool.
That is not a missing convenience — it removes the editor's ability to be trusted with a
failed statement. P1 because the rest of the work in this feature is worthless if a failed
query is still indistinguishable from a successful one.

**Independent Test**: Run a query whose text the server rejects with a syntax error. Assert
that a message naming the server's complaint reaches the developer, and that it is not
possible to complete the run believing it succeeded. Then run a query that succeeds and
assert no failure is reported. Repeat across every route by which a query can be run.

**Acceptance Scenarios**:

1. **Given** a query whose text the server rejects, **When** the developer runs it, **Then** the server's own complaint is shown to the developer.
2. **Given** a query that ran and failed, **When** the developer looks at the run, **Then** it is unmistakably not presented as a success — no success-shaped summary, no empty result presented as "no rows".
3. **Given** a query that succeeded, **When** the developer looks at the run, **Then** no error is reported and the result is presented as it is today.
4. **Given** a query the server rejects for more than one reason, **When** it runs, **Then** every complaint the server raised is available, not only the first.
5. **Given** a query that fails, **When** the developer wants the full detail, **Then** the complete server text remains reachable without re-running the query.

---

### User Story 2 - Ordinary SQL never breaks my editor (Priority: P1)

As a developer, I can write normal SQL — with string literals, with trailing comments, with
block comments — and neither the status line nor my query execution breaks. A query that the
server accepts runs, every time, whether or not its text contains a quoted value or a
comment. I am never told my query failed when it did not.

**Why this priority**: The second half of the report is that a **corrected** query stopped
running, with an error message pointing into the editor's own code. That is the worst outcome
in this feature: the developer fixed their SQL and the editor broke instead. It is also the
half that blocks the first story from mattering — if the crash stands, the query never
reaches the server and there is no result to report at all. P1 alongside User Story 1: they
are the two halves of the reported symptom, and a fix that addresses only the missing message
leaves the developer unable to run the corrected query.

**Independent Test**: For each ordinary SQL shape — a line with a string literal, a line with
a trailing line comment, a line with a block comment before and after code, an unterminated
block comment spanning lines, and a line whose literal or comment is the very first thing on
it — assert that the status line renders, that a pre-execution check completes, and that a
valid query actually reaches the server. Reproduce the reported query both as originally
written and in its corrected form.

**Acceptance Scenarios**:

1. **Given** a query buffer whose lines contain string literals, comments, or both, **When** the developer views the status line, **Then** the status line renders normally and never shows an internal error.
2. **Given** the same buffer, **When** the developer runs a query the server accepts, **Then** the query runs and its result is returned.
3. **Given** the reported query in its corrected form — a conditional whose condition contains
   a string literal — **When** the developer runs it, **Then** it runs and returns the same row
   the standalone client returns.
4. **Given** the reported query in its original, invalid form, **When** the developer runs it,
   **Then** the only thing reported is the server's complaint about the query (User Story 1) —
   never an internal error from the editor.
5. **Given** any query text whatsoever, **When** a pre-execution check runs over it, **Then** the check completes without an internal error and without discarding any part of the text it did not understand.

---

### User Story 3 - A real problem is never reported as a made-up one (Priority: P2)

As a developer, when something is wrong with my database setup, the message I get names the
real cause. A tool never tells me a database does not exist when the truth is that the tool's
own check failed, and never tells me "no results" when the truth is that the request was
rejected. If the editor cannot determine what happened, it says so rather than guessing.

**Why this priority**: Root cause 3 is a false diagnosis, which is worse than no diagnosis: it
costs the developer time chasing a database name that was correct. It was found while
tracing this issue, so it belongs here, but it is not what the developer reported and it is
reached through database selection rather than through query execution. P2 because User
Stories 1 and 2 are the reported defect; this is the correctness rule that stops the fix for
them from introducing a misleading message in place of a missing one.

**Independent Test**: Make each of the editor's own database requests fail in a way it does
not expect, and assert the message shown names the actual failure and never asserts a
conclusion the check did not establish. Cover the case where a request's answer could not be
read at all.

**Acceptance Scenarios**:

1. **Given** the editor cannot complete a database check because the request failed, **When** it reports, **Then** it does not claim a database does not exist.
2. **Given** a request that failed, **When** the developer reads the message, **Then** the underlying reason the request failed is included.
3. **Given** a check that cannot determine whether a database exists, **When** it reports, **Then** it says it could not determine that, rather than asserting either answer.
4. **Given** a database that genuinely does not exist, **When** the developer asks, **Then** they are still told it does not exist, exactly as today.

---

### User Story 4 - The cross-database warning still works (Priority: P2)

As a developer, the warning that tells me my query will run against a different database than
my connection declares keeps working — including when my statement carries a trailing comment,
a string literal, or is a cross-database reference. If the warning is wrong in my favour, I
want to know that the editor could not tell rather than being left with silence.

**Why this priority**: Root cause 5 is the quiet half of the crash: the same miscount, in the
cases where it does not crash, blanks so much of the line that the switch is never recognised.
The result is that a warning which exists specifically to stop a query running against the
wrong database stops firing. A crash is noticed on the first run; a warning that silently
stops working is not noticed until the query has already run against the wrong data. P2
because it is the same code path as User Story 2 — the same routine that crashes is the one
that misses the switch — but it is a distinct user-visible outcome and a distinct guarantee.

**Independent Test**: For every statement form that declares a different database — a bare
switch, a switch with a trailing comment, a switch preceded by a block comment, a switch with
a trailing block comment, a cross-database reference, and a cross-database reference carrying
a string literal — assert the warning still identifies the same database as before. Then assert
that when the editor genuinely cannot tell, it says so instead of staying silent.

**Acceptance Scenarios**:

1. **Given** a query declaring a database other than the connection's, **When** the developer runs it, **Then** the cross-database warning is shown, naming the same database it names today.
2. **Given** that same query with a trailing line comment, **Then** the warning is still shown and names the same database.
3. **Given** that same query preceded or followed by a block comment, **Then** the warning is still shown.
4. **Given** a cross-database reference carrying a string literal, **Then** the warning is still shown and names the same database and object as without the literal.
5. **Given** text the editor cannot interpret, **When** the developer runs it, **Then** the editor says it could not determine the context rather than reporting no conflict.
6. **Given** a query whose switch names the database the connection already points at, **Then** no warning is shown, exactly as today.

---

### User Story 5 - Failed queries leave no confusing trace behind (Priority: P3)

As a developer, a failed query does not leave me looking at output that looks like data. I can
still see the server's full response, and the editor's own hints do not get mixed into it in a
way that makes the response harder to read.

**Why this priority**: Once errors are surfaced, the natural next step is to reshape the output,
and the natural mistake is to filter it — dropping the lines the editor thinks are noise so
the message looks tidier. That trades an honest, complete record for a prettier one. FR-014
exists so the fix cannot smuggle that in. P3 because nothing here is broken today; it is the
guard rail that keeps User Stories 1 and 2 from being "improved" into something lossy.

**Independent Test**: Capture the full text the server returned for a failing query, then
assert it is still reachable in full afterwards, byte for byte. Repeat for a query that mixes
a complaint with partial output.

**Acceptance Scenarios**:

1. **Given** a query that failed with a multi-line complaint, **When** the developer reads the run's full output, **Then** every line the server produced is present.
2. **Given** a failing query that also produced partial output before failing, **Then** both the partial output and the complaint are present and distinguishable.
3. **Given** any failing query, **When** the developer looks at the editor's own hints around the run, **Then** a hint is never presented as if it were part of the server's response.

### Edge Cases

- The reported query exactly as written (missing `end` before `else`) and as corrected. Both
  must behave per User Story 2 — the invalid one with the server's complaint, the corrected one
  with a successful run.
- A statement whose first character is a literal or a comment (`'x' = 1`, `-- comment`,
  `/* comment */ select 1`) — the boundary between "starts with noise" and "noise mid-line".
- A line where the literal or comment is the last thing on it, with no code after it.
- An unterminated block comment, and a block comment that opens on one line and closes several
  lines later — including a closing line that also contains code after it.
- A quoted literal containing an apostrophe escaped by doubling (`'it''s'`), and one containing
  the other quote character.
- A quoted literal containing a comment marker, a block-comment opener, or a `go` terminator.
- A block comment containing a quoted string, and a line comment containing a quoted string.
- Several statements in one buffer where only some carry comments or literals — a routine that
  works line by line must not succeed on some lines by discarding others.
- An empty buffer, a buffer of only blank lines, and a buffer of only comments.
- A very long line (thousands of characters) with a literal at the end.
- Non-ASCII / multibyte characters in a query buffer, before and after a comment or literal —
  column counting must not desynchronize from the characters the developer sees.
- A query with no database bound to the buffer at all, and a query whose binding names no
  database.
- A server complaint that is the *only* output, a complaint plus a result set, and a complaint
  raised mid-result-set.
- Server complaints that are not syntax errors: missing object, permission denied, timeout,
  deadlock, and a network failure mid-query.
- A query that legitimately returns zero rows — must never be presented as a failure.
- A query cancelled by the developer, and a query cancelled by a timeout — the cancellation
  message must not be presented as a server complaint.
- A failing query in the `:DBObjects` listing flow, in database selection, and in reading a
  procedure body — the same reporting rule must hold, not just in the query-execution flow.
- Repeated failures in one session — the failure notice does not accumulate into a wall of
  duplicates.
- Two query buffers failing at once, so the notice for one is never attributed to the other.

## Requirements *(mandatory)*

### Functional Requirements

**A failed run is reported as a failure (User Story 1)**

- **FR-001**: When a query run produces a complaint from the server, the developer MUST be shown
  that complaint.
- **FR-002**: A failed run MUST NOT be presented to the developer in the same shape as a
  successful run. A failure MUST NOT be summarized, counted, or labelled as a successful
  execution with no rows.
- **FR-003**: A successful run MUST keep its current presentation, and MUST NOT report a failure.
- **FR-004**: Where the server raises more than one complaint about a run, every complaint MUST
  remain available to the developer.
- **FR-005**: The developer's ability to read the complete text the server returned MUST be
  preserved. Surfacing a complaint MUST NOT require re-running the query.
- **FR-006**: The rule in FR-001 MUST hold for every route by which a query can be run, not only
  for one of them.
- **FR-007**: A run that legitimately returns zero rows MUST NOT be reported as a failure.

**Ordinary SQL does not break the editor (User Story 2)**

- **FR-008**: The editor's own checks MUST complete without an internal error for **any** buffer
  text, including text containing string literals, line comments, and block comments in any
  combination and position.
- **FR-009**: The status line MUST render for every buffer, including one whose text contains
  string literals or comments. It MUST NOT display an internal error.
- **FR-010**: A query the server accepts MUST be executed, MUST return its result, and MUST NOT
  be prevented from running by any internal error.
- **FR-011**: A query the server rejects MUST be reported with the server's complaint about the
  query. An internal error from the editor MUST NOT be the outcome, and MUST NOT be reported in
  addition to the complaint.
- **FR-012**: The inspection of a buffer's text MUST NOT silently discard any part of the text it
  failed to interpret. Where text cannot be interpreted, the editor MUST say so rather than
  treat the remainder as though it carried no meaning.
- **FR-013**: The reported query MUST be covered by test coverage in both its original and its
  corrected form, and both forms MUST behave as FR-011 and FR-010 respectively require.
- **FR-014**: The complete text the server returned MUST remain available unmodified. Surfacing
  a complaint MUST NOT filter, reorder, or rewrite that text.

**No invented diagnoses (User Story 3)**

- **FR-015**: A check that could not complete MUST NOT assert a conclusion it did not establish.
  In particular, a failed request MUST NOT be reported as a missing database.
- **FR-016**: Where a check fails, the message MUST include the reason the request failed.
- **FR-017**: Where a check cannot determine whether something is true, it MUST report that it
  could not determine it, rather than asserting or denying it.
- **FR-018**: Genuine findings MUST be preserved: a database that truly does not exist MUST
  still be reported as not existing, exactly as today.

**The cross-database warning keeps working (User Story 4)**

- **FR-019**: A statement declaring a database other than the connection's MUST produce the
  cross-database warning, naming the same database it names today.
- **FR-020**: FR-019 MUST hold when the declaring statement carries a trailing line comment, a
  block comment before or after it, or a string literal — the declared database MUST NOT change
  because of unrelated text on the same line.
- **FR-021**: A cross-database reference carrying a string literal MUST produce the warning, and
  MUST name the same database and object as the same reference without the literal.
- **FR-022**: Where the editor cannot determine the context, it MUST report that it could not
  determine it rather than reporting that there is no conflict.
- **FR-023**: A statement whose declared database is the one the connection already points at
  MUST continue to produce no warning, exactly as today.
- **FR-024**: Where the editor declares a conflict, the notice MUST name the conflict. The
  editor MUST NOT present its own reasoning as part of the server's response (FR-014).

**Failed runs leave no confusing trace (User Story 5)**

- **FR-025**: The complete text the server returned for a failing run MUST remain available to
  the developer after the failure is reported.
- **FR-026**: Where a failing run produced partial output as well as a complaint, both MUST be
  available and MUST be distinguishable from each other.
- **FR-027**: Repeated failures MUST NOT accumulate duplicate notices.

**Repository obligations (constitution)**

- **FR-028**: The change MUST contain no user-specific absolute paths and MUST behave the same on
  Apple Silicon and Intel (constitution I).
- **FR-029**: The change MUST be confined to the Neovim module and MUST NOT require unrelated
  tools or modules to be present, changed, or updated (constitution IV).
- **FR-030**: The change MUST NOT introduce a new dependency; where an existing capability needs a
  configuration flag or a hook, it MUST be declared in the change and documented (constitution VI).
- **FR-031**: No credential, token, private key, or real local secret may appear in the change or
  in its documentation. No notice may render a connection URL, which can carry credentials
  (constitution VII).
- **FR-032**: The change MUST pass every existing Neovim smoke test and MUST add coverage for: a
  query rejected with a syntax error; each ordinary SQL shape in FR-008; the cross-database
  warning in every form required by FR-020 and FR-021; a database-check failure required by
  FR-015; and a legitimate zero-row result required by FR-007. It MUST NOT be marked complete
  with a failing check (constitution VIII).
- **FR-033**: The Neovim module `README.md` MUST be updated in the same change, covering how a
  failed query is reported, how to read the full server response, and a troubleshooting entry for
  "my query failed and nothing was shown" (constitutions XII, XIV).
- **FR-034**: The change MUST NOT alter close semantics, force-close behavior, or the buffer-row
  behavior governed by `specs/011-query-buffer-tab-visibility/`, and MUST NOT regress the
  `:DBObjects` listing guarantees governed by `specs/010-dbobjects-listing-integrity/`.
- **FR-035**: Implementation MUST be developed on a feature branch, committed with conventional
  commit messages, and submitted through a pull request that links issue #98; before the pull
  request is created, this specification MUST be checked for scope fit and the contributor MUST
  be asked whether it should be closed as the completed solution (constitution XIII).
- **FR-036**: Spec artifacts MUST remain navigable by relative Markdown links, and every
  user-story task phase MUST link back to the matching heading in this specification
  (constitution XV).

### Out of Scope

- **Preventing a failed run from executing.** The server's decision to reject a statement is the
  server's. This feature makes the decision visible; it does not change what the server accepts
  and does not add client-side SQL validation or linting.
- **Parsing or rewriting the developer's SQL.** The requirements concern what the editor does
  with a statement and with the server's answer to it, not whether the statement is well-formed.
  Note that removing the reported statement's missing `end` is the developer's change, not this
  feature's (FR-013 covers both forms only as test material).
- **A new query-cancellation design.** A cancelled or timed-out run must be distinguishable from a
  server complaint (FR-002, FR-016), but changing how cancellation works is a separate change.
- **Changing how results are presented on success.** The success path keeps its current shape
  (FR-003). Only the failure path gains a report.
- **The `:DBObjects` listing scope, save flow, and catalog behavior** governed by
  `specs/010-dbobjects-listing-integrity/`. FR-006 requires that failures *in* those flows are
  reported, not that those flows change.
- **Buffer visibility, tab presence, and close semantics** governed by
  `specs/011-query-buffer-tab-visibility/`, frozen by FR-034.
- **Query completion, schema browsing, and the drawer UI.** Unrelated to whether a failure is
  reported.

### Key Entities

- **Run**: one execution of a query, from submission to a finished outcome. A run either
  succeeds or fails, and the developer MUST be able to tell which.
- **Server complaint**: a message the database server itself raised about a run — a syntax
  error, a missing object, a permission failure, a timeout. It is the server's own words about
  the developer's statement, and it is the only authoritative evidence of why a run failed.
- **Server response**: everything the server wrote back for a run. A run that fails still
  produces one, and it MUST remain available in full (FR-005, FR-025).
- **Internal error**: a fault in the editor's own machinery, reported to the developer as such.
  It is distinct from a server complaint, and it MUST NOT be the reported outcome of a rejected
  query (FR-011).
- **Declared database context**: the database a buffer's text says it will run against. It is
  what the cross-database warning compares against the connection's own database.
- **Connection's database**: the database the buffer's connection declares — the fixed side of
  the comparison above. It never changes as a result of the buffer's text.
- **Check outcome**: the result of one of the editor's own database requests. It MUST distinguish
  "established", "not established", and "could not determine" (FR-015, FR-017). Collapsing the
  third into the second is the defect behind User Story 3.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For the reported query in its original form, 1 failure message reaching the developer
  names the server's own complaint about the statement.
- **SC-002**: Across a test pass covering every route by which a query can be run, 100% of routes
  surface a server complaint when one is raised; 0 routes report a failed run as a success.
- **SC-003**: 0 runs present a failure in the same shape as a successful run; specifically, 0
  occurrences of a failure summarized with a success-shaped summary or an empty result shown as
  "no rows".
- **SC-004**: 0 legitimate zero-row results are reported as failures, across at least 10
  zero-row queries.
- **SC-005**: 0 internal errors attributable to a buffer whose text contains a string literal, a
  line comment, or a block comment, measured across the full shape set in FR-008 — at minimum 20
  representative lines per shape.
- **SC-006**: The reported query in its corrected form executes and returns the same value the
  standalone database client returns for it, on 10 consecutive runs.
- **SC-007**: 100% of buffer texts are inspected without an internal error, measured across a
  corpus of at least 200 lines combining code, literals, line comments, and block comments in
  every position including the first character and the last character.
- **SC-008**: 0 notices present the editor's own reasoning as part of the server's response; and
  the full server response is byte-for-byte available for 100% of failing runs checked.
- **SC-009**: 0 checks report a database as non-existent when the underlying request failed; the
  message names the actual failure in 100% of induced request failures.
- **SC-010**: 0 cases where the editor asserts or denies a database's existence after a check it
  could not complete.
- **SC-011**: 100% of the cross-database warning forms required by FR-020 and FR-021 produce the
  warning, naming the same database and object as the bare form; 0 regressions across all forms.
- **SC-012**: A database that genuinely does not exist is still reported as not existing in 100%
  of checks, with the current message.
- **SC-013**: 0 duplicate notices from repeated failures of the same query in one session.
- **SC-014**: Every pre-existing Neovim smoke test continues to pass, and the new coverage
  required by FR-032 passes, with 0 failures.
- **SC-015**: 0 discrepancies between the module `README.md` claims about failure reporting and
  actual behavior, found by review of each claim.

## Assumptions

- **The reported query's missing `end` is the developer's to fix.** The server rejects it, and the
  server is right to. This feature's obligation is to report that rejection clearly; the
  corrected form is the developer's edit (FR-013 covers both forms only as test material).
- **The server's own words are the authoritative diagnosis.** Where the server said why, that
  reason is what the developer is shown; the editor does not substitute its own interpretation.
- **The reported internal error is a fault in the editor's text inspection, not in the database
  tooling.** The message names the editor's own database-context module and its line, and the
  fault reproduces against the editor's code with no database involved.
- **A missing message is the worse of the two reported failures only for the first run.** After
  the crash the developer sees a message — an internal one. So both halves matter: the crash is
  noticed, and the silence is not.
- **The editor already has a notification path for database messages**, used today by the
  cross-database warning and by the object listing. Nothing here needs a new presentation
  concept; the gap is that query failures never reach that path.
- **The query's full server response is already preserved and summoned today.** Surfacing the
  complaint is a matter of reading something that already exists, not of retaining something new.
- **Zero-row results are a success.** A query that returns nothing is not a failure and must not
  be reported as one.
- **Windows is a first-class target for this module** — the client selects itself per platform,
  and the report was filed from a Windows path. The requirements are written platform-agnostically
  so both clients are covered without naming either.
- **No new dependency is introduced and no new keymap is added.** Existing capabilities are
  configured or extended as needed (FR-030).
- **Behavior that is correct today is preserved unchanged**: successful query presentation,
  buffer close semantics, tab visibility, and the `:DBObjects` guarantees from
  `specs/010-dbobjects-listing-integrity/` (FR-003, FR-034).

## Clarifications

### Defaults chosen during specification — 2026-10-01

No blocking question remained after investigation, because every open point had a default the
repository itself already established. The defaults are recorded here so they can be overridden at
review rather than discovered later.

- **Q1 (scope — should the "no message" fix also cover the internal failures found while tracing
  it?)** — *Answer*: yes, as User Story 3, at P2. *Rationale*: the false diagnosis is reached
  through the same reporting gap as the reported defect and produces a message that sends the
  developer to fix the wrong thing. Leaving it out would mean shipping a fix that makes failures
  *louder* while one of them lies. *Alternative rejected*: leaving it out of this spec entirely,
  which keeps the spec smaller but leaves a known false diagnosis in the path being repaired.
- **Q2 (should a complaint be reported by trimming the server's response to just the complaint?)**
  — *Answer*: no; the full response is preserved (FR-014, FR-025, User Story 5). *Rationale*: the
  developer came here because they could not see the truth; filtering the truth to make it tidier
  is the wrong trade, and partial output before a failure is often the clue. *Alternative
  rejected*: trimming to the complaint only, which looks cleaner and loses evidence.
- **Q3 (should the editor refuse to run a query whose text it cannot interpret?)** — *Answer*: no;
  it runs the query and says it could not determine the context (FR-012, FR-022). *Rationale*: the
  editor's inspection exists to warn about a cross-database switch, not to gate execution. Making
  it a gate would let an inspection defect block queries — which is exactly the reported failure.
  *Alternative rejected*: blocking execution on an uninterpretable buffer, which converts a
  cosmetic defect into a hard block.
