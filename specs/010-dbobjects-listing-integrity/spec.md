# Feature Specification: Trusted `:DBObjects` Listing

**Feature Branch**: `010-dbobjects-listing-integrity`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "trabaja en este bug https://github.com/aogallo/dotfiles/issues/92"

> **Issue #92 (reported)**: Running `:DBObjects`, choosing a database other than the login
> default, and searching for a procedure returns nothing — and nothing tells the user that
> anything went wrong. The same object is returned by running the reference path by hand
> (`use <database>`, batch terminator, then the built-in object-help procedure with the
> source-revealing option), so the object exists and its text is readable. The listing is
> therefore wrong, not the object.
>
> **Root-cause class established during investigation** (traced to concrete code in
> [research.md](research.md) R-0001–R-0008; summarized here so the requirements below
> are traceable to a cause):
>
> 1. The chosen database is applied to the session but its acceptance is never confirmed. A
>    rejected selection leaves the session on the previous (login default) database, the
>    catalog read succeeds *there*, and the listing is then labelled with the database the
>    user asked for. Every server diagnostic emitted along the way is discarded.
> 2. The listing enumerates a fixed subset of object kinds — tables, views, procedures and
>    functions. Any object of another kind (triggers most notably) is dropped with no notice,
>    even though the source reader would have opened it happily.
> 3. Result rows that cannot be parsed into a name and a recognized kind are dropped with no
>    counter, so a formatting or width change loses objects invisibly.
> 4. The database offered by the chooser is drawn from the server-wide database list, which
>    includes databases the login cannot actually use.
> 5. The user guide and an in-code note describe a *different* kind subset than the one
>    implemented, so the documented contract and the real contract disagree.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A listing always belongs to the database I chose (Priority: P1)

As a developer working against a database server from Neovim, I pick a database other than
the one my connection defaults to and I get a listing that provably belongs to *that*
database. If the server refuses the switch, I get one clear message naming what failed —
I never receive a plausible-looking list of a different database's objects.

**Why this priority**: This is the reported defect, and it is the most damaging failure mode
in the feature. A listing that silently belongs to the wrong database is worse than no
listing: it looks authoritative, it contains real objects, and the one object I am looking
for is missing for no visible reason. The user cannot distinguish this from "the object does
not exist", which is exactly the confusion in issue #92.

**Independent Test**: Connected to database A, choose a database the login can read and
confirm every row belongs to it. Then choose a database the login cannot read, a database
name that does not exist, and a name the server rejects. In all three failure cases the
picker must not present A's (or any other database's) objects as belonging to the chosen
database, and must emit exactly one message. Fully testable without a second database
holding a known object.

**Acceptance Scenarios**:

1. **Given** a connection whose default database is A, **When** the user chooses database B and the login can use B, **Then** the listing contains only objects that exist in B, and the active-scope indicator names B.
2. **Given** the same connection, **When** the user chooses database B and the login cannot use B, **Then** no listing is presented as belonging to B, exactly one message names B and the failure, and the active scope remains A.
3. **Given** the same connection, **When** the user chooses a database name that does not exist, **Then** exactly one message distinguishes this case from the "login lacks access" case.
4. **Given** the same connection, **When** the user chooses B and B contains no objects, **Then** the empty result is reported as an empty result for B, which is visibly different from a failure.
5. **Given** any scope selection, **When** the server confirms the selection, **Then** the confirmation result — not merely the requested name — is what the active-scope indicator and the listing label are derived from.

---

### User Story 2 - Every object the developer works with is listed (Priority: P1)

As a developer, when I search for an object, the kinds I actually work with — tables, views,
procedures, functions **and triggers** — are all listed. Triggers were missing from the listing
even though the tool could have opened one, which is a large part of why issue #92's object never
appeared. The listing says up front which kinds it covers, so I know what I am looking at, and I
am never left wondering whether a miss means "absent" or "not covered".

**Why this priority**: This is the second half of issue #92. The reporter proved the object was
readable; the listing omitted it. Adding triggers closes the largest gap in the curated set at
almost no cost — the listing is a single catalog read, and widening a kind filter costs the
server nothing measurable.

**Independent Test**: For a confirmed database, compare the listing against the objects the
server reports for the five covered kinds. Every such object appears and the counts agree.
Separately, confirm the listing states which kinds it covers, and confirm that an object of an
uncovered kind is reachable through User Story 3 rather than being silently absent.

**Acceptance Scenarios**:

1. **Given** a confirmed database, **When** the listing is built, **Then** it contains every table, view, procedure, function and trigger the server reports for that database.
2. **Given** a listing, **When** the developer looks at it, **Then** the tool states which object kinds the listing covers.
3. **Given** an object whose kind the tool does not map to a plain-language name, **When** the listing is built, **Then** the object still appears, labelled with its server-reported kind.
4. **Given** a result the tool cannot interpret at all, **When** the listing is built, **Then** the listing is never presented as complete and the discrepancy is reported (see User Story 5).
5. **Given** the listing for a confirmed database, **When** the developer opens any listed object's source, **Then** the source shown belongs to that same database.

---

### User Story 3 - Open an object the listing does not contain (Priority: P2)

As a developer, when an object is not in the listing, I am not stuck. The picker offers me a way
to name the object directly, and the tool opens it from the confirmed database using the same
reader it uses for listed objects — honouring my configured source mode. If the name does not
resolve or its text cannot be read, I get the existing actionable notice that names the causes.

**Why this priority**: This is the designer's chosen answer to the coverage question, and it is
better than enumerating everything. Enumerating the server's whole catalogue would add thousands
of system rows, slow the flow, and still require the developer to filter — whereas naming the
object reaches it in one step and costs one query *only when asked*. It converts "the listing is
incomplete" from a problem into a non-problem, and it is the exact path the reporter proved works
by hand. It cannot be offered before a database is confirmed, or it would read from an unknown
database and reintroduce issue #92.

**Independent Test**: With a confirmed database, take an object deliberately outside the covered
kinds, choose the direct-open entry, supply the name, and confirm the source opens and belongs to
the confirmed database. Then supply a name that does not exist and confirm exactly one actionable
notice and no buffer. Then run the flow with no confirmed database and confirm the entry is not
offered.

**Acceptance Scenarios**:

1. **Given** a confirmed database, **When** the developer chooses the direct-open entry and supplies an object name, **Then** the object's source opens in a buffer and belongs to the confirmed database.
2. **Given** a supplied name that does not exist, **When** the developer confirms it, **Then** exactly one actionable notice is shown and no buffer is opened.
3. **Given** an object of a kind the listing does not cover, **When** the developer reaches it through the direct-open entry, **Then** it opens successfully and no listing change is required.
4. **Given** no confirmed database, **When** the picker is shown, **Then** the direct-open entry is not offered, or is offered only with a stated warning about which database it will read.
5. **Given** the developer cancels the name prompt, **When** the prompt is dismissed, **Then** nothing is opened and no state changes.
6. **Given** the direct-open entry, **When** it is not used, **Then** no additional request is made to the server.

---

### User Story 4 - Failures name themselves instead of leaving me to guess (Priority: P2)

As a developer, when something goes wrong I get one message that names the object or database
involved and the plausible causes, instead of an empty list, a wrong list, or silence.

**Why this priority**: "It doesn't tell me if there's an error" is stated in the issue. Today's
behavior has three failure shapes — silence, a wrong result, and one message — with no
consistency. A developer debugging a missing object has to guess between "object absent",
"login lacks access", "kind not listed", "output truncated", and "client unavailable". One
actionable message per failure is what turns this from a mystery into a two-minute fix. P2
because a correct listing plus scope verification already removes the reported symptom; this
removes the *rest* of the guessing.

**Independent Test**: Enumerate every failure the tool can hit — no permission on the
selected database, database does not exist, catalog read denied, connection failure, missing
client, unreadable object source, unparseable result. For each, assert exactly one message,
assert it names the subject, and assert the tool does not additionally open a substitute
result.

**Acceptance Scenarios**:

1. **Given** any single failure, **When** the tool reports it, **Then** exactly one message is emitted, it names the database or object involved, and it lists the plausible causes.
2. **Given** a failure while reading a chosen database, **When** the tool reports it, **Then** no listing is opened and no previously obtained listing is re-presented as if it were the new one.
3. **Given** a server diagnostic accompanying a successful result, **When** the listing is presented, **Then** the diagnostic is surfaced rather than discarded.
4. **Given** a connection-level failure, **When** the tool runs, **Then** the developer sees one message naming the connection and no empty picker is opened.
5. **Given** an object whose source cannot be read, **When** the developer opens it, **Then** the existing actionable notice behavior is preserved unchanged.

---

### User Story 5 - I can tell whether a listing is complete (Priority: P3)

As a developer, I can see how many objects the server reported, how many my listing shows, and
how many were left out — so "not in the list" always has an explanation.

**Why this priority**: Silent partial results are the mechanism that turns a formatting change
or a permission quirk into an undebuggable report. Exposing the counts is cheap and makes every
future discrepancy self-describing. P3 because it is a diagnostic aid on top of a now-correct
listing rather than a fix for the reported symptom.

**Independent Test**: Build a listing for databases of varying object counts, including one
where results are deliberately truncated or partially unreadable, and confirm the reported
totals always reconcile with what is displayed.

**Acceptance Scenarios**:

1. **Given** a listing where every reported object is shown, **When** the developer looks at the listing, **Then** the displayed count equals the reported count for the covered kinds and no exclusion is reported.
2. **Given** a listing where objects were excluded, **When** the developer looks at the listing, **Then** the number excluded is reported and the tool states that the listing is partial.
3. **Given** a large database, **When** the listing is truncated for display, **Then** the truncation is stated with the number of objects not shown.

---

### Edge Cases

- The login can see a database's name in the server-wide list but cannot use it.
- The login's own default database is inaccessible, so a no-database connection cannot even be established.
- The chosen database exists and is usable but its catalog cannot be read by the login.
- The chosen database is usable and readable but contains zero objects.
- The connection itself fails: wrong credentials, unreachable host, client not installed, client
  present but non-functional.
- The user types a database name that is syntactically acceptable but does not exist.
- The user types a database name that is syntactically rejected (contains characters outside the
  accepted set) — must remain rejected with the current named message.
- The user re-selects the database that is already active — must remain a no-op with the current
  warning and no re-query.
- The user cancels the database chooser or the typed-name prompt — must remain a pure no-op that
  creates no buffer and changes no scope.
- The user opens the command with no database in the connection at all — must continue to work
  against the login default and say so.
- A result row is truncated or wrapped because the object's name is very long or the client's
  output width is narrow.
- A result row carries a server diagnostic, a row-count trailer, or a heading instead of data.
- An object is reported twice within the same database.
- The same object name exists in two different databases during one session — must remain
  unambiguous, each labelled with its owning database.
- The listing is empty *because* a failure occurred, versus empty *because* the database is empty —
  the two must never look the same.
- Long-running catalog reads against a large database: behavior must not regress relative to today.

## Requirements *(mandatory)*

### Functional Requirements

**Scope verification (User Story 1)**

- **FR-001**: The tool MUST confirm with the server, after a database is selected, that the
  selected database is the one in effect for the catalog read that will follow.
- **FR-002**: The tool MUST NOT present any listing as belonging to a database that the server
  did not confirm as being in effect.
- **FR-003**: When a database selection is not confirmed, the tool MUST emit exactly one message
  that names the requested database and states that the switch did not take effect.
- **FR-004**: When a database selection is not confirmed, the tool MUST leave the previously
  active scope unchanged and MUST NOT present another database's objects as a fallback.
- **FR-005**: The active-scope indicator and the listing label MUST be derived from the
  server-confirmed database, never from the requested name alone.
- **FR-006**: When no database has been confirmed, the active-scope indicator MUST state that
  the listing covers the login's default database rather than naming a database.
- **FR-007**: The tool MUST distinguish, in the failure message, between a database that does
  not exist and a database the login is not permitted to use.
- **FR-008**: A database selection that the server accepts but that yields no objects MUST be
  reported as an empty result for that database, not as a failure and not as a fallback to
  another database.

**Object kind coverage (User Story 2)**

- **FR-009**: The listing MUST cover every table, view, procedure, function and trigger the
  server reports for the confirmed database. The covered kinds are a deliberate, documented
  limit, not an accidental one: the tool MUST state which kinds the listing covers.
- **FR-010**: The tool MUST NOT enumerate the server's system object catalogue as part of the
  listing. Doing so would add thousands of rows, slow the flow, and provide nothing the developer
  can act on. Objects outside the covered kinds remain reachable through FR-015.
- **FR-011**: An object whose kind the tool cannot map to a plain-language name MUST still
  appear in the listing, labelled with the server-reported kind.
- **FR-012**: A single unparseable, truncated, or wrapped result row MUST NOT cause a real
  object to be omitted from the listing without being counted as an exclusion.
- **FR-013**: The listing MUST be built such that an object's identity does not depend on its
  position in the server's output, so a width or formatting change cannot merge or lose
  objects.
- **FR-014**: Selecting any listed object MUST read that object's source from the confirmed
  database, so a listing is never a mixture of databases.

**Direct open by name (User Story 3)**

- **FR-015**: The picker MUST offer an entry that lets the developer open an object by name
  without it appearing in the listing.
- **FR-016**: The direct-open entry MUST read the named object's source from the confirmed
  database, using the same reader and the same configured source mode as the listing uses.
- **FR-017**: The direct-open entry MUST NOT be offered, or MUST carry a stated warning naming
  the database it will read, when no database has been confirmed. It MUST never read from an
  unconfirmed or unknown database.
- **FR-018**: The direct-open entry MUST NOT issue any request to the server until the developer
  supplies a name and confirms it.
- **FR-019**: A name that does not resolve MUST produce exactly one actionable notice naming the
  object and the plausible causes, and MUST NOT open a buffer.
- **FR-020**: Cancelling the name prompt MUST be a pure no-op that opens nothing and changes no
  state.
- **FR-021**: The direct-open entry MUST operate on the confirmed scope only. It MUST NOT search
  other databases and MUST NOT accept a qualified cross-database name, so that the capability
  closed in `specs/archive/2026-09-25-001-multidb-object-search/` stays closed. To reach another
  database the developer changes scope first.

**Diagnostics (User Story 4)**

- **FR-022**: Any diagnostic or error the server emits while building a listing MUST be
  surfaced to the developer; a diagnostic MUST NOT be silently discarded.
- **FR-023**: A connection-level failure MUST produce exactly one message naming the
  connection, and MUST NOT open an empty picker or a substitute listing.
- **FR-024**: Each failure message MUST name the database or object it concerns and MUST list
  the plausible causes.
- **FR-025**: On failure, the tool MUST NOT additionally re-present a previously obtained
  listing in a way that suggests it answers the failed request.
- **FR-026**: The existing actionable notice for an unreadable object source MUST be preserved
  unchanged.
- **FR-027**: The existing no-op behaviors — cancelling the chooser or the typed-name prompt,
  and re-selecting the already-active database — MUST be preserved unchanged.
- **FR-028**: A database name the server rejects as syntactically unacceptable MUST continue to
  be rejected before any server round trip, with the current message naming the accepted
  character set.

**Completeness reporting (User Story 5)**

- **FR-029**: The tool MUST be able to report how many objects the server reported, how many are
  shown, and how many were excluded, each counted over the covered kinds.
- **FR-030**: When any object is excluded, the tool MUST state that the listing is partial
  together with the number excluded.
- **FR-031**: When a listing is shortened for display, the tool MUST state how many objects are
  not shown.

**Server load**

- **FR-041**: The number of requests the tool makes to the server for one invocation MUST NOT
  grow with the size of the database or the number of objects it holds.
- **FR-042**: Confirming a database selection MUST cost a bounded, constant number of requests,
  independent of database size.
- **FR-043**: Opening the listing without the developer using the direct-open entry MUST NOT
  issue any request beyond the confirmation and the single catalog read.
- **FR-044**: The tool MUST NOT issue a request it can answer from a result it already holds.

**Repository obligations (constitution)**

- **FR-032**: The change MUST contain no user-specific absolute paths and MUST behave the same on
  Apple Silicon and Intel (constitution I).
- **FR-033**: The change MUST be read-only against the server: no writes, no schema changes, no
  temporary objects, and no locks that could block other work in any database (constitution III).
- **FR-034**: The change MUST be confined to the Neovim database module and MUST NOT require
  unrelated tools or modules to be present, changed, or updated (constitution IV).
- **FR-035**: Any new prerequisite MUST be declared and its absence MUST be detected with an
  actionable message rather than a silent empty result (constitution VI).
- **FR-036**: No credential, token, private key, or real local secret may appear in the change or
  in its documentation; connection details continue to come from the existing local registry
  (constitution VII).
- **FR-037**: The change MUST pass the relevant existing smoke tests, MUST add coverage for
  successful confirmation, for each rejection path, and for partial listings, and MUST NOT be
  marked complete with a failing check (constitution VIII).
- **FR-038**: The Neovim module `README.md` MUST be updated in the same change, and the stale
  object-kind description in the user guide and in the function documentation MUST be corrected
  so the documented contract matches the implemented contract (constitutions XII, XIV).
- **FR-039**: Implementation MUST be developed on a feature branch, committed with conventional
  commit messages, and submitted through a pull request that links this issue; before the pull
  request is created, this specification MUST be checked for scope fit and the contributor MUST
  be asked whether it should be closed as the completed solution (constitution XIII).
- **FR-040**: Spec artifacts MUST remain navigable by relative Markdown links, and every
  user-story task phase MUST link back to the matching heading in this specification
  (constitution XV).

### Out of Scope

- Searching for an object **by name across all accessible databases**. That capability was
  evaluated and closed in `specs/archive/2026-09-25-001-multidb-object-search/`; this feature
  makes the single-database listing trustworthy and keeps the direct-open entry inside the
  confirmed scope so the closed capability does not reopen by the side door (FR-039).
- Enumerating the server's **system** object catalogue in the listing. Deliberately excluded
  (FR-010): it is thousands of unusable rows and real server load for no developer benefit, and
  the direct-open entry already reaches any object by name.
- Grouping, sorting modes, or multi-column filtering of the listing. The existing single-line
  fuzzy filter is sufficient; the developer chose reachability over presentation.
- Support for database backends other than the one where database scope exists.
- A stored-procedure-based team search, per the closure decision in the same archived spec.
- Any change to how an object's source is read, edited, or saved, beyond binding it to the
  confirmed database.

### Key Entities

- **Object row**: one database object as the developer sees it — its name, its kind (or the
  server-reported kind when unmapped), and the database that owns it.
- **Scope selection**: a database the developer asks the tool to list, together with whether the
  server confirmed it.
- **Confirmed scope**: the database the server reported as being in effect for the catalog read
  that produced the current listing. At most one exists per session, and a scope selection that
  is not confirmed never becomes one. The direct-open entry requires one; this is what keeps it
  from reading an unknown database.
- **Covered kinds**: the object kinds the listing enumerates — tables, views, procedures,
  functions and triggers. A declared, documented set rather than whatever happens to match.
- **Reconciliation record**: the counts that make a listing self-describing — objects reported,
  objects shown, objects excluded, objects not shown because of display limits, each counted over
  the covered kinds.
- **Diagnostic**: a message from the server or the client accompanying a result. A diagnostic is
  never dropped without being surfaced.
- **Request budget**: the bounded number of server requests one invocation may make, fixed by
  FR-041 to FR-044 so that a larger database never costs more round trips.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a test pass covering every reachable scope selection, 0 listings are presented
  under a database label for objects that do not belong to that database.
- **SC-002**: For a confirmed database, the number of covered-kind objects shown equals the number
  the server reports for those kinds, in 100% of cases measured across at least 10 databases of
  varying size.
- **SC-003**: Every table, view, procedure, function and trigger readable through the reference
  path (`use` the database, batch terminator, then the built-in object-help procedure) also
  appears in the listing for that database — 0 discrepancies.
- **SC-004**: 100% of failed scope selections produce exactly one message within 5 seconds, and
  0 produce an empty picker, a silent return, or a listing from another database.
- **SC-005**: 0 covered-kind objects disappear from a listing without being counted in the
  reconciliation record.
- **SC-006**: 0 server diagnostics accompanying a listing are discarded without being surfaced.
- **SC-007**: A developer reaches and opens a known object in a non-default database in 3
  interactions or fewer (open the listing, choose the database, choose the object), on 10
  consecutive attempts.
- **SC-008**: The documented object-kind contract in the user guide, the module `README.md`, and
  the function documentation matches the implemented behavior — 0 discrepancies found by review.
- **SC-009**: All pre-existing Neovim database smoke tests continue to pass, and the new coverage
  for confirmation, each rejection path, partial listings and the direct-open entry passes, with
  0 failures.
- **SC-010**: One `:DBObjects` invocation issues at most 3 server requests (confirmation, catalog
  read, and the diagnostic scan that accompanies them), and the count is identical for a database
  with 50 objects and one with 50,000.
- **SC-011**: The listing of a database with N objects opens in no more than 2× the time it takes
  today, confirming the added verification does not make the flow unusable.
- **SC-012**: A developer whose object is not in the listing reaches it in 2 additional
  interactions (choose the direct-open entry, supply the name) on 10 consecutive attempts, with
  0 wrong-database reads.

## Assumptions

- The reference path in issue #92 is the ground truth for "this object exists and its text is
  readable". A listing that disagrees with it is a defect in the listing.
- **Server load is an explicit design constraint, not an afterthought.** The developer asked for
  this feature on the condition that it not degrade the database. Everything below follows from
  that: a single catalog read for the listing, a bounded confirmation cost, a request count that
  does not scale with database size (FR-041 to FR-044, SC-010), and no system-catalogue sweep
  (FR-010). Any design that would issue one request per database, or one per object, is out.
- The developer named tables, views, procedures, functions and triggers as the kinds that matter.
  Tables were not named but are the basis of the existing "list rows" flow, so they are retained;
  dropping them would be a regression, not a simplification.
- "Execute the function with the params you provide" is read as: run the *object-help command* with
  the options the tool already uses (the source-revealing option, honouring the configured source
  mode), not as executing the object itself. **Confirmed by the developer** (2026-09-25): reuse the
  path that already exists. No new SQL, no new execution path, no new mode.
- Database scope exists today only for the Sybase/ASE backend. This feature extends that backend's
  behavior; other backends keep their current single-connection listing, which already reports its
  own emptiness.
- The server can report which database is in effect for a session, and that report can be obtained
  with the same credentials already used for the listing. No additional privilege is assumed.
- The tool cannot be assumed to know in advance which databases the login may use — the server-wide
  database list includes databases the login cannot use. Detection therefore happens at selection
  time, and the failure is reported then.
- Confirming a selection costs one additional exchange with the server. This is accepted in
  exchange for a listing that can be trusted; the cost bound is captured in SC-010 and SC-011.
- No additional dependency is introduced. The existing database client, connection registry,
  picker and source reader are reused as they are.
- Connection details continue to come from the existing local registry file, which is untracked;
  this feature adds no new configuration surface and no new secrets.
- The existing no-op and last-good-listing behaviors for the chooser are intentional and are
  preserved, except where they would present a wrong listing as the answer to a failed selection
  (FR-004, FR-025).
- Where the archived multi-database search spec already recorded a decision, this feature defers
  to it rather than reopening it.

## Clarifications

### Session 2026-09-25

- **Q1 (object-kind coverage)**: *Answer*: keep the listing to the kinds the developer actually
  works with — procedures, views, functions and triggers (tables retained, see Assumptions) — and
  do **not** enumerate the server's system catalogue. *Rationale given by the developer*: avoid
  degrading the database. A system sweep would add thousands of unusable rows and real load for
  no benefit. *Chosen approach*: rather than accept a listing with a silent hole, the picker gains
  a **direct-open entry** so any object can be reached by name from the confirmed database, using
  the same reader and the same configured source mode as the listing. This makes listing
  incompleteness harmless and costs one request *only when the developer asks* (FR-036).
  *Effect on the spec*: FR-009 and FR-010 replace the old FR-009; User Story 2 is rescoped to the
  covered kinds; User Story 3 is new; the "Out of Scope" list now records the deliberate exclusion
  of the system catalogue; FR-041 to FR-044 and SC-010 make the request budget testable.
  *Alternatives rejected*: enumerating everything flat (usable only after filtering, and the
  filtering is the same work the direct-open entry avoids); enumerating everything grouped and
  filterable (solves the same problem with a new interaction the developer did not ask for).

