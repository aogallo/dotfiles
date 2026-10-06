# Feature Specification: Database Completion Never Blocks Editing

**Feature Branch**: `013-db-completion-gate`

**Created**: 2026-10-05

**Status**: Draft

**Input**: User description: "Verifica como esta la conexion a la base de datos de sybase, creo saber de porque pasa esto, porque el completion se conecta cada vez que uno escribe para obtener la informacion de completion entiendo que es un proceso. pero esto esta ocasionando que no pueda ejecutar el script, tengo problemas de conexion pero esto no me deberia de impedir hacer el query y ejectuarlo aunque la conexion este mal entonces se me ocurre tener un keymap toggle para desahbilitar el completion para base de datos, que opciones propones?"

> **Reported symptom**: In a SQL buffer, typing makes the editor try to reach the database on
> every keystroke. When the Sybase connection is down, the editor freezes long enough that the
> developer cannot run the query they are trying to run. The developer's own reading is that the
> completion is a process that connects per keystroke to fetch completion information, and that
> this must not be able to prevent writing or executing a query — a broken connection should be
> reported by the query, not by the editor.
>
> **Root-cause class established during investigation** (traced to concrete code; the references
> below are to the installed plugin sources under the editor's plugin directory, not to files in
> this repository, except where a repository file is named). Summarized here so the requirements
> below are traceable to a cause:
>
> 1. The repository enables a database completion source for SQL buffers
>    (`nvim/plugin/blink.lua:107,110-114`). That source's decision about whether to run is made
>    from the file type alone, with no regard for whether the buffer has a connection at all — so
>    it runs even in a plain `.sql` file that has no database behind it.
> 2. When it runs, it synchronously calls the upstream completion entry point on every
>    keystroke (`vim_dadbod_completion/blink.lua:56`). It is not deferred to a background job, so
>    the editor waits for it.
> 3. That entry point connects to the database before it has anything to offer
>    (`autoload/vim_dadbod_completion.vim:405` → `db#connect()`), and the connection helper is
>    itself blocking: it runs the database client as a synchronous process and raises an error on
>    failure (`vim-dadbod/autoload/db.vim:333-376`).
> 4. After connecting, it reads the schema, again through a second blocking client invocation
>    (`autoload/vim_dadbod_completion.vim:228`).
> 5. The guard that would prevent this from repeating is only satisfied *after* the connection
>    succeeds: the per-buffer record the guard tests for is written at
>    `autoload/vim_dadbod_completion.vim:192`, which is downstream of the connect at line 405.
>    So when the connection fails or hangs, the guard is never satisfied and the next keystroke
>    starts the whole sequence again. **This is the loop the developer reported.**
> 6. The consequence is worse than slow completion: the blocking attempt runs on the editor's
>    main path, so a database that is unreachable holds the editor on a network timeout, and the
>    failure surfaces as an editor-level error raised while typing — which is indistinguishable
>    from, and can mask, the real database problem the developer needs to see when running the
>    query.
>
> The defect is therefore **not** "completion is slow". It is that the completion path is allowed
> to open a database connection at all, at a moment when the developer's intent is to type, and
> that a failure there is unrecoverable within the session.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - I can write and run SQL even when the database is unreachable (Priority: P1)

As a developer whose database connection is currently broken, I can open a SQL file, type my query
at normal speed, and run it. The editor never pauses, never hangs on a network timeout, and never
shows me an error about my typing. If the query fails, it fails with the database's own message —
the one I actually need to read — and I can then fix the connection without having first had to
fight the editor.

**Why this priority**: This is the reported defect. A developer who cannot run the query they are
writing cannot do their job, and the blocking is caused by a convenience feature that failed in a
way that is entirely independent of the query. Nothing else matters until this is fixed.

**Independent Test**: Point a SQL buffer at a database that cannot be reached, type 200 characters
without stopping, and assert the editor remains responsive at every character, that no client
process is started by the completion path, and that a subsequent query attempt produces the
database's error rather than an editor error. Repeat from a clean start 20 times.

**Acceptance Scenarios**:

1. **Given** a SQL buffer bound to a connection that cannot be reached, **When** the developer types 200 consecutive characters, **Then** the editor stays responsive at every character and no pause is observable beyond normal typing.
2. **Given** the same buffer, **When** the developer runs the query, **Then** the failure reported is the database client or server's own, and no error originating in the editor's completion path is shown.
3. **Given** a SQL buffer that has no connection configured at all, **When** the developer types, **Then** nothing is attempted against any database and the editing experience is identical to a file type with no database tooling.
4. **Given** the completion path is engaged, **When** any part of the database tooling fails while the developer is typing, **Then** the developer's buffer text is never modified, never truncated, and never discarded as a side effect.
5. **Given** a SQL buffer bound to an unreachable database, **When** the developer types, **Then** no other non-SQL feature of the editor regresses — completion from the language server, snippets, and path completion continue to work.

---

### User Story 2 - I can switch database completion off, and tell that I have (Priority: P1)

As a developer, I can turn database completion off and back on with a single key, and I can tell
which state it is in without hunting through settings. Turning it off is something I do
deliberately — for example when I am writing exploratory SQL I do not want suggestions for, or
when I want to work on a machine where the database is slow to answer.

**Why this priority**: The developer proposed this explicitly, and it is the part that gives them
control back immediately. It is also the escape hatch that makes the rest of the change safe to
adopt: if anything about database completion misbehaves, I can turn it off and keep working.
P1 alongside User Story 1 because the switch and the fix are the two halves of what was asked
for, and the switch alone leaves the reported blocking in place while it is on.

**Independent Test**: Press the key once and assert the state changed and that one notice said
which state it is now; press it again and assert the original state returned, also with one
notice. Read the current state from the keymap label and from the command, and assert the two
agree. Confirm the switch changes only database completion and leaves every other completion
source working.

**Acceptance Scenarios**:

1. **Given** database completion is on, **When** the developer presses the switch, **Then** database completion stops offering suggestions and exactly one notice reports that it is now off.
2. **Given** database completion is off, **When** the developer presses the switch again, **Then** database suggestions are offered again and exactly one notice reports that it is now on.
3. **Given** any state, **When** the developer looks at the keymap label for the switch, **Then** the label states the current state, so the state is visible without pressing it.
4. **Given** database completion was turned off, **When** the developer types in a SQL buffer, **Then** completion from every other source continues to work, and no database process is started.
5. **Given** the switch has been pressed, **When** the developer restarts the editor, **Then** the switch is back at its starting state, and the starting state is documented rather than surprising.

---

### User Story 3 - A connection that failed steps aside by itself, without taking the others with it (Priority: P2)

As a developer with several database connections, when one of them is unreachable, completion for
that connection switches itself off and tells me once — not once per keystroke, and not in a way
that blames me for typing. My other, healthy connections keep completing normally. I am not left
guessing why the suggestions disappeared.

**Why this priority**: User Story 1 removes the blocking; this removes the *silent disappearance*.
Without it, the fix is indistinguishable from a bug: suggestions stop for no stated reason. The
per-connection boundary matters because the developer's whole point is to keep working while one
server is down — a single global switch would take down completion for the connections that are
fine. P2 because the reported defect is already fixed by then.

**Independent Test**: Have one unreachable connection and one healthy connection open at the same
time, type in a buffer on each, and assert the unreachable one disables itself exactly once with
one actionable notice while the healthy one keeps producing suggestions throughout. Then bring
the unreachable one back and confirm it is treated as a fresh attempt.

**Acceptance Scenarios**:

1. **Given** a connection that fails to answer, **When** the completion path first determines its state, **Then** that connection is marked unusable and exactly one notice explains what happened and how to bring it back.
2. **Given** the notice has already been shown, **When** the developer keeps typing in buffers bound to that connection, **Then** no further notice appears and no further connection attempt is made for it.
3. **Given** one unusable connection and one healthy connection, **When** the developer types in a buffer bound to the healthy connection, **Then** suggestions continue to be offered exactly as before.
4. **Given** a connection that was marked unusable, **When** the developer changes something that could make it work again — reconnects, or runs a command against it deliberately — **Then** it is treated as a fresh attempt rather than staying unusable for the rest of the session.
5. **Given** several connections fail independently, **When** each fails, **Then** each produces its own single notice, and none of them affects the others.

---

### User Story 4 - I can bring database completion back without restarting the editor (Priority: P2)

As a developer, once my database is reachable again — I fixed the network, the server came back,
the login was fixed — I can make database completion work again myself, with one deliberate action,
without closing and reopening the editor and without losing my unsaved work.

**Why this priority**: The fix that stops the blocking must not become a fix that also requires a
restart to undo. A developer whose database comes back mid-session needs a way forward that costs
one action. This is also what makes User Story 3's automatic behavior acceptable: it is safe to
turn something off automatically precisely because turning it back on is cheap.

**Independent Test**: Disable a connection's completion, restore the database, use the recovery
action, and assert suggestions return within the same session on a buffer whose text was never
saved or closed. Confirm the recovery works for both routes offered, and that a connection that is
still down does not come back as "working".

**Acceptance Scenarios**:

1. **Given** a connection whose completion was switched off, **When** the developer uses the explicit refresh action, **Then** completion is offered again on that connection if the database answers, within the same session.
2. **Given** the same connection, **When** the developer runs a query that succeeds against it, **Then** completion returns on that connection without any further action.
3. **Given** the same connection, **When** the refresh action is used and the database still cannot be reached, **Then** completion stays off and the failure is reported once, as the database's own failure.
4. **Given** an open, unsaved SQL buffer, **When** completion is disabled, refreshed, or re-enabled, **Then** the buffer's text, its unsaved state, and its database binding are all unchanged.
5. **Given** the developer has not asked for it, **When** time passes or other queries run, **Then** a connection that was switched off does not turn itself back on.

---

### User Story 5 - With a healthy connection, completion is as useful as it is today (Priority: P3)

As a developer with a working connection, table-name suggestions inside SQL buffers keep working
exactly as they do now — the same names, the same behavior after a dot, the same reserved words.
Fixing the blocking must not quietly cost me the completion I rely on.

**Why this priority**: This is the regression guard. A fix that stops the blocking by simply
removing database completion would satisfy Users 1 through 4 and leave the developer worse off,
and the natural way to fail-closed is to always return nothing. P3 because nothing here is broken
today; it is the check that the fix was not taken by deleting the feature.

**Independent Test**: On a working connection, in the same buffer, before and after the change,
compare the set of names offered for the same prefixes and the same trigger positions. Repeat with
a table prefix, with a bare prefix, and with a reserved word prefix, and assert the results match.

**Acceptance Scenarios**:

1. **Given** a working connection, **When** the developer types a table prefix, **Then** the same names are offered as before this change.
2. **Given** a working connection, **When** the developer types after a dot, **Then** the same behavior occurs as before this change.
3. **Given** a working connection, **When** the developer types a reserved word prefix, **Then** the same reserved words are offered as before this change.
4. **Given** any of the above, **When** the developer accepts a suggestion, **Then** the same text is inserted as before this change.
5. **Given** a healthy connection, **When** the developer has made no switch and nothing has failed, **Then** no notice about database completion is ever shown.

### Edge Cases

- **A connection that hangs instead of failing.** The server accepts the TCP connection and never
  answers. The completion path must still never wait on it — a hang is the worst case of the
  reported symptom and must be bounded, not merely "eventually" bounded.
- **A connection that fails intermittently**, alternating between answering and not answering.
  Each transition must be reported at most once, and the notice must not accumulate.
- **A connection that becomes healthy again** without the developer doing anything explicit — the
  server is restarted by someone else. Per User Story 4 scenario 5, it must stay off until asked.
- **A buffer with no connection at all**, and a buffer bound to a connection name that is not in
  the registry. Neither may attempt any connection.
- **The developer's environment providing a database URL globally**, which the upstream completion
  path will pick up even for a buffer that has no connection of its own. The fix must govern this
  case too, or the connection would still be attempted from a buffer that never asked for one.
- **Two SQL buffers on two different databases**, one healthy and one not, open at the same time.
  Their states are independent.
- **The same database reached through two different connection entries** (for example with
  different logins or one with a database in its path and one without). Their states are
  independent, because their failure modes can differ.
- **The switch pressed repeatedly and quickly**, including twice within the same second. The final
  state must match the number of presses and the notices must not pile up.
- **The switch pressed while a completion menu is open.**
- **A query that succeeds while another query on the same connection is still running.**
- **A completion request issued at the exact moment the developer closes or reopens the buffer.**
- **Restarting the editor** with the switch off, with one connection marked unusable, and with
  neither: all three must start from the documented starting state with no leftover from the
  previous session.
- **The database client binary missing entirely.** Completion must be off for that connection with
  one notice naming the missing prerequisite, and must not retry per keystroke.
- **Repeating every scenario 20 times in one session**, to catch anything that only degrades with
  repetition.
- **Windows**, where a different database client is used. The requirement is stated as "never
  connects", which must hold for every supported client.
- Existing database behavior governed by
  [`specs/010-dbobjects-listing-integrity/`](../010-dbobjects-listing-integrity/spec.md) and
  [`specs/011-query-buffer-tab-visibility/`](../011-query-buffer-tab-visibility/spec.md) must be
  unaffected in every one of these cases.

## Requirements *(mandatory)*

### Functional Requirements

**The completion path never opens a connection (User Story 1)**

- **FR-001**: Suggestion generation for SQL buffers MUST NOT open a database connection, MUST NOT
  start a database client process, and MUST NOT wait on a network round trip. This MUST hold on
  every invocation, for every keystroke, for every buffer, and for every connection state.
- **FR-002**: When a connection cannot be used, suggestion generation MUST fail closed: it MUST
  return no database suggestions, MUST NOT raise an error, and MUST NOT alter the buffer.
- **FR-003**: A buffer with no database connection MUST NOT cause any database interaction. Where a
  database URL is available from the environment rather than from the buffer, the requirement still
  holds: the buffer's absence of a connection MUST be sufficient to prevent the interaction.
- **FR-004**: The set of database client processes started by the editor while the developer types
  MUST be zero, whether the database is healthy, unreachable, or slow to answer.
- **FR-005**: A failure of the database tooling that occurs while the developer is typing MUST NOT
  be presented as an error about the developer's typing, and MUST NOT be presented in a way that
  can be mistaken for the failure of the query the developer is about to run.
- **FR-006**: Suggestion generation MUST NOT be able to delay, abort, or prevent the execution of a
  query, including when the suggestion path fails, throws, or is switched off.

**The manual switch (User Story 2)**

- **FR-007**: The developer MUST be able to switch database suggestion generation off and on with a
  single key, and with a single named command, and both routes MUST drive the same state.
- **FR-008**: Each change of state MUST produce exactly one notice stating the new state. Repeated
  presses MUST each produce their notice, and no press may produce zero or more than one.
- **FR-009**: The current state MUST be readable from the keymap label without pressing it, and the
  label MUST agree with what the state actually is.
- **FR-010**: The switch MUST affect only database suggestion generation. Every other suggestion
  source MUST continue to work while it is off, in SQL buffers and in every other buffer.
- **FR-011**: The state the switch starts in MUST be documented in the module documentation, and
  MUST be restored to that starting state when the editor restarts.

**A failing connection steps aside by itself (User Story 3)**

- **FR-012**: When the editor determines that a connection cannot be used, it MUST mark that
  connection unusable, MUST stop generating suggestions for it, and MUST emit exactly one notice
  that states what happened and how to bring it back.
- **FR-013**: Once a connection has been marked unusable, suggestion generation for it MUST NOT
  make any further connection attempt, and MUST NOT emit any further notice, for the remainder of
  the session unless the developer asks for a fresh attempt.
- **FR-014**: A connection's unusable state MUST be scoped to that connection. Buffers bound to
  other connections MUST continue to generate suggestions, including connections that are also
  unreachable, which follow FR-012 independently.
- **FR-015**: The notice MUST NOT be shown from inside suggestion generation. It MUST be shown from
  a deliberate developer action or a single background determination, so that it cannot be
  triggered once per keystroke by construction.
- **FR-016**: A connection's usability MUST NOT be inferred from the absence of suggestions. It
  MUST be established by a positive determination, and an undetermined connection MUST be treated
  as not-yet-determined rather than as healthy.

**Recovery (User Story 4)**

- **FR-017**: The developer MUST be able to request a fresh determination for a connection with a
  single deliberate action, without restarting the editor and without closing or reopening any
  buffer.
- **FR-018**: When a query on a connection succeeds, that connection MUST be treated as usable
  again, and suggestions MUST resume on it within the same session without further action.
- **FR-019**: A fresh determination on a connection that is still unreachable MUST leave it
  unusable and MUST report the database's own failure once. It MUST NOT mark the connection usable.
- **FR-020**: Switching, refreshing, and re-enabling suggestion generation MUST NOT change any
  buffer's text, its unsaved state, or its database binding.
- **FR-021**: A connection marked unusable MUST NOT return to usable on its own, and MUST NOT
  return because another query, another buffer, or the passage of time succeeded against it. Only
  FR-017 and FR-018 may restore it.

**No loss of usefulness when healthy (User Story 5)**

- **FR-022**: With a usable connection and no switch pressed, the set of suggestions offered MUST be
  identical to the set offered before this change, for the same buffer, prefix, and cursor
  position.
- **FR-023**: The behavior of suggestion generation after a dot, and the set of reserved words
  offered, MUST be unchanged by this feature.
- **FR-024**: With a usable connection, no switch pressed, and nothing failed, no notice about
  database suggestion generation MUST be shown.
- **FR-025**: The change MUST NOT alter the set of database objects a connection exposes, the
  database a query runs against, or any catalog read. FR-001 constrains only what happens *during*
  suggestion generation.

**Repository obligations (constitution)**

- **FR-026**: The change MUST contain no user-specific absolute paths and MUST behave the same on
  Apple Silicon and Intel, and on macOS and Windows (constitution I).
- **FR-027**: The change MUST be confined to the Neovim module and MUST NOT require unrelated tools
  or modules to be present, changed, or updated (constitution IV).
- **FR-028**: The change MUST NOT introduce a new dependency. Where an existing capability needs
  configuration or a wrapper, it MUST be declared in the change and documented (constitution VI).
- **FR-029**: No credential, token, private key, or real local secret may appear in the change or in
  its documentation. **No notice, label, or message produced by this feature may display a
  connection's credentials** — the same rule
  `nvim/lua/config/db_context.lua` already follows when it derives a database name from a URL.
- **FR-030**: The change MUST pass every existing Neovim smoke test, MUST add offline coverage for
  FR-001 through FR-004 with a stub client and no real server, for the switch and its notices, for
  per-connection scoping, and for recovery, and MUST NOT be marked complete with a failing check
  (constitution VIII).
- **FR-031**: Offline tests MUST be runnable without a database server and without a real client
  binary, consistent with the existing offline smoke tests.
- **FR-032**: The Neovim module `README.md` MUST be updated in the same change, covering the
  switch and its key, the starting state, the automatic disabling behavior, the recovery actions,
  and the troubleshooting entry for "the editor freezes when I type SQL" (constitutions XII, XIV).
- **FR-033**: The change MUST be non-destructive: it MUST NOT alter the text or filetype of any
  buffer, MUST NOT write to disk, and MUST NOT change any behavior outside suggestion generation
  without an explicit developer action (constitution III).
- **FR-034**: Implementation MUST be developed on a feature branch, committed with conventional
  commit messages, and submitted through a pull request; before the pull request is created, this
  specification MUST be checked for scope fit and the contributor MUST be asked whether it should be
  closed as the completed solution (constitution XIII).
- **FR-035**: Spec artifacts MUST remain navigable by relative Markdown links, and every
  user-story task phase MUST link back to the matching heading in this specification
  (constitution XV).

### Out of Scope

- **Column-level completion for Sybase and MongoDB.** The module documentation already states that
  these schemes do not provide column completion and degrade to table names. Adding it is a
  feature of its own, and it is not what is reported.
- **Caching column or schema data across connections, or persisting a schema cache to disk.**
  FR-001 removes the need for a cache on the typing path. A cache warmed deliberately elsewhere is
  a design question for `plan.md`, not a requirement here, and nothing about it may reintroduce a
  connection on the typing path.
- **Adding a timeout to the database client.** FR-001 makes the typing path never connect, which
  is stronger than bounding how long it waits. A client timeout addresses a different code path —
  the query path — which the developer needs to keep reporting the database's own error.
- **Changing how a query is executed, or how a failure is reported when it fails.** The query path
  is explicitly the thing that must keep working; this feature changes nothing about it.
- **Improving what the listing and object-search features offer**, or the database-scope and
  save-flow behavior, governed by
  [`specs/010-dbobjects-listing-integrity/`](../010-dbobjects-listing-integrity/spec.md). Those
  MUST NOT regress; this feature changes no catalog or server behavior.
- **Query-buffer tab behavior**, governed by
  [`specs/011-query-buffer-tab-visibility/`](../011-query-buffer-tab-visibility/spec.md).
- **Reaching the schema without the developer's request at all** — for example pre-fetching
  everything on editor start. That trades one blocking path for a slow start.
- **Rewriting or patching the upstream completion plugin.** The requirements are about this
  repository's behavior. Whether the fix is a wrapper, a replacement source, or a configuration
  change is a `plan.md` decision; forking the plugin is not on the table.

### Key Entities

- **Connection**: one configured database endpoint, identified by its registry name and carrying
  its own credentials and database. It is the unit that usability is tracked on, and the unit the
  switch's scope is broader than. Two entries pointing at the same server are still two
  connections, because their failure modes can differ.
- **Connection usability**: whether a connection has been positively established as usable, has
  been positively established as unusable, or has never been determined. The third state is
  distinct and MUST NOT be read as the first — that conflation is what turns "we don't know" into
  "it works" and back.
- **Suggestion generation**: the act of producing candidates while the developer types. In SQL
  buffers it has one database-backed part and several non-database parts; only the database-backed
  part is in scope here, and FR-010 keeps the rest untouched.
- **Switch state**: the session-wide, developer-controlled on/off choice about database suggestion
  generation. Distinct from connection usability: the switch is what the developer decided,
  usability is what the editor observed.
- **Usability determination**: an explicit, deliberate check that establishes a connection's
  usability. Distinct from any activity triggered by typing, because FR-015 forbids the notice
  from originating on the typing path.
- **Notice**: a single message shown to the developer. Every automatic behavior in this feature is
  allowed at most one notice per connection per transition, and no notice may carry credentials.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Writing 200 consecutive characters in a SQL buffer bound to an unreachable database
  produces no observable pause beyond normal typing, across 20 consecutive trials from a clean
  start.
- **SC-002**: Suggestion generation makes zero connection attempts during those 200 characters, for
  an unreachable database, a healthy database, and a database that accepts the connection and never
  answers.
- **SC-003**: In 20 trials, a query run from a buffer with an unreachable database surfaces the
  database's own failure in 20 cases, and zero cases surface an editor failure from the suggestion
  path.
- **SC-004**: With an unreachable database, the developer sees exactly one notice about suggestion
  generation being switched off per connection per session — never one per keystroke, and never more
  than one.
- **SC-005**: With one unreachable connection and one healthy connection open at the same time,
  suggestions continue to be offered on the healthy connection in 100% of the trials, and the two
  connections' states never affect one another.
- **SC-006**: Switching suggestion generation off and on takes one keystroke each way, the current
  state is readable from the keymap label alone, and the label agrees with the actual state in 20
  consecutive trials.
- **SC-007**: With suggestion generation switched off, non-database suggestions remain available in
  SQL buffers in 20 of 20 trials, and zero connection attempts are made.
- **SC-008**: After a query succeeds on a connection that had been marked unusable, suggestions
  resume on that connection within the same session in 10 of 10 trials, with no editor restart.
- **SC-009**: A fresh determination against a connection that is still unreachable leaves it
  unusable and reports the database's failure once, in 10 of 10 trials.
- **SC-010**: On a healthy connection with nothing switched off, the set of suggestions offered is
  identical to the set offered before this change — zero differences across bare prefixes, table
  prefixes, dot-triggered positions, and reserved word prefixes.
- **SC-011**: Typing in a SQL buffer with no connection configured makes zero connection attempts
  across 20 trials.
- **SC-012**: Every pre-existing Neovim smoke test continues to pass and the new offline coverage
  passes, with zero failures, and every new test runs with no database server and no real client
  binary present.
- **SC-013**: Zero discrepancies between the module `README.md` claims about database suggestion
  generation and the observed behavior, found by checking each claim.
- **SC-014**: Zero notices, labels, or messages produced by this feature display a connection's
  credentials, verified by inspection of every message path.
- **SC-015**: Across 20 sessions' worth of repeated trials, zero buffer texts are modified,
  truncated, or unsaved state lost as a side effect of suggestion generation or of switching.

## Assumptions

- **The reported behavior is completion connecting on every keystroke, not a slow query.** The
  developer stated the mechanism themselves and the traced code confirms it. The symptom is treated
  as caused by the suggestion path, and the query path is treated as a victim rather than the
  cause.
- **A broken connection must still be reported by the query.** The developer's expectation is
  explicit: a bad connection should not stop the query from running and reporting its own failure.
  So nothing in this feature suppresses, delays, or rewrites query-time reporting.
- **Suggestion generation must be safe to give up entirely on the typing path.** The requirements
  are written fail-closed (FR-002) because that is the only way to guarantee FR-001; a design that
  keeps connecting lazily cannot satisfy it.
- **The developer's editor configuration is shared, version-controlled configuration rather than a
  single machine's private setup.** The change therefore belongs in the repository and is subject
  to the constitution, not in a local override.
- **The switch starts on.** Beginning with database completion disabled would be a behavior change
  the developer did not ask for; US5 and SC-010 protect the useful behavior when the database is
  healthy, and US1 protects typing when it is not.
- **Usability is tracked per session, not persisted.** A connection marked unusable in one session
  does not need to be remembered in the next, and persisting it would need a place to store it,
  which this feature does not have.
- **Both connection sources are in scope**: connections the developer opens through the database
  tooling's own UI, and connections bound to a query buffer. Neither is singled out, so the
  requirements are written about "a connection" rather than about one entry point.
- **Existing behavior that is correct today is preserved**: the listing and object-search features,
  the pre-execution database check, the query-result summon, the database window navigation, and
  the non-database suggestion sources. This feature is scoped to what runs during typing.
- **The offline stub-client pattern already used by this repository's smoke tests is sufficient** to
  prove SC-002, SC-004, and SC-011 without a real server, so no new test mechanism is required.

## Clarifications

### Defaults chosen during specification — 2026-10-05

Three decisions were put to the developer before this specification was written, because each of
them changes the scope of the feature rather than only its shape. All three were answered
explicitly, and each answer is recorded here so it can be overridden at review rather than
discovered later.

- **Q1 (which combination of options should be specified?)** — *Answer*: gate plus manual switch.
  A completion path that can be switched off, **and** a path that never connects in the first
  place, with the switch as the deliberate escape hatch. **Rationale**: the switch alone was the
  developer's own first idea and is worth having on its own merits, but while the switch is on the
  blocking the developer reported would still be there. The gate is what actually fixes it, and the
  switch is what makes the fix safe to adopt. *Alternatives rejected*: switch only, which leaves the
  reported defect in place by default; adding a client timeout, which bounds the wait but keeps one
  attempt per keystroke.
- **Q2 (what granularity should the switch and the connection state have?)** — *Answer*: a global
  session switch **and** per-connection state. **Rationale**: the developer's stated situation is a
  broken connection that must not stop the rest of their work, so usability has to be tracked per
  connection. The global switch is still wanted as an explicit way to say "no database suggestions
  right now" regardless of health. *Alternatives rejected*: switch only, which lets one dead server
  silence completion for every healthy one; per-buffer state, which adds a third place to look for
  the answer without a case the developer asked for.
- **Q3 (what should happen by default when a connection is down?)** — *Answer*: switch that
  connection off automatically, and say so once. **Rationale**: silent disabling would be
  indistinguishable from a new bug the developer did not ask for. A single notice names what
  happened and how to bring it back, which makes the automatic behavior trustworthy. *Alternatives
  rejected*: failing silently, which loses the explanation; retrying on a budget, which keeps the
  per-keystroke traffic alive in exactly the case the developer reported.