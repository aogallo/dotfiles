# Feature Specification: Object Source Fidelity (`:DBObjects`)

**Feature Branch**: `fix/nvim-db-source-and-docs` (PR #89; the implementation landed before this specification was formalized — see [Provenance](#provenance))

**Created**: 2026-09-25

**Status**: Implemented — pending live-server acceptance

**Input**: User description: "Read DB object source from syscomments with opt-in showsql fallback"

## Provenance

This specification was written **after** the implementation, on request, to formalize the
SDD trail for work that shipped in PR #89 (issue #88). It describes the behavior that
PR #89 implements — it is not the origin of that work, and no requirement here is
retro-fitted to hide a gap. Two consequences are deliberate:

- Every task in [tasks.md](tasks.md) is marked `[X]` because the code, tests and docs
  already exist in PR #89; the exception is the live-server acceptance recorded in
  [quickstart.md](quickstart.md), which needs a real ASE instance.
- The implementation is on branch `fix/nvim-db-source-and-docs`, not `008-object-source-fidelity`,
  because the fix had to ship with the archival of specs 001/003/004/005 in a single PR
  (constitution XIII: one branch, one PR, and the contributor asked for everything in one).
  The directory name follows the spec-kit convention; the branch does not. This deviation is
  documented in [verify-report.md](verify-report.md).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a stored procedure and get its real source (Priority: P1)

As a developer working against a Sybase/ASE database from Neovim, I open `:DBObjects`,
pick a stored procedure, and get the exact text stored in the catalog — with no
`# Lines of Text` banner, no column headings, no row counts, and no line broken in the
middle of a token.

**Why this priority**: This is the defect that made the feature unusable. `sp_helptext`
returns 255-byte `convert(char(255)...)` slices, so a procedure could open as a buffer
containing headings and a mangled line such as `substring(@dat` / `o, @poscicion, 1)`.
Reading the source at all is worthless if the text is corrupted.

**Independent Test**: Pick any non-hidden procedure in `:DBObjects`, press Enter, and read
the buffer. Every line must be a complete source line and the buffer must contain no
client framing.

**Acceptance Scenarios**:

1. **Given** a procedure whose body is longer than 255 characters, **When** the user opens its source, **Then** the buffer contains the full body, with no line cut mid-token and no banner/heading/count lines.
2. **Given** a procedure with blank lines, comments, and `go` terminators, **When** the user opens its source, **Then** the blank lines and the original line structure are preserved.
3. **Given** a procedure in the current database, **When** its source is opened, **Then** the text comes from `syscomments` for that database (no cross-database leakage).

---

### User Story 2 - Understand why a source cannot be read (Priority: P2)

As a developer, if I open an object whose source I am not allowed to read, I get exactly
one notice that names the object and lists the plausible causes, instead of an empty or
garbled buffer.

**Why this priority**: The previous behavior opened an empty buffer and left the user
guessing between hidden text, missing permissions, a missing object, and a missing
client. One actionable notice resolves all four in one line.

**Independent Test**: Attempt to open an object with `sp_hidetext` applied, or a login
without `select` on `syscomments.text`, and confirm the notice and that no buffer opens.

**Acceptance Scenarios**:

1. **Given** an object whose text is hidden or encrypted, **When** the user opens it, **Then** no buffer opens and one WARN notice names the object and the likely causes.
2. **Given** a login without `select` on `syscomments.text`, **When** the user opens an object, **Then** the result is the same single notice, not a partial or garbled buffer.
3. **Given** an object that does not exist, **When** the user opens it, **Then** the same single notice is shown.
4. **Given** the database client binary is unavailable, **When** the user opens an object, **Then** the same single notice is shown and no query is attempted.

---

### User Story 3 - Opt into regenerated SQL when the catalog will not do (Priority: P3)

As a developer on ASE 15.0.2+, I can opt into a `showsql` source mode that returns
regenerated, formatted SQL without the parameter block, for the cases where the stored
text is not what I want to read.

**Why this priority**: It is a deliberate escape hatch, not the default. The default
`catalog` mode is byte-exact; `showsql` reformats. It stays available because it works
where the catalog path cannot be trusted, but defaulting to it would trade correctness
for convenience.

**Independent Test**: Set `g:db_sybase_source_mode = 'showsql'`, open a procedure, and
confirm the buffer is formatted SQL with no `sp_helptext` counter and no generated
parameter block.

**Acceptance Scenarios**:

1. **Given** `g:db_sybase_source_mode = 'showsql'`, **When** the user opens a procedure, **Then** the source is regenerated SQL without the `# Lines of Text` counter and without the generated parameter block.
2. **Given** any other value of `g:db_sybase_source_mode` (including unset), **When** the user opens a procedure, **Then** the byte-exact `catalog` mode is used.
3. **Given** `showsql` mode on an ASE older than 15.0.2, **When** the user opens a procedure, **Then** the call fails into the single actionable notice instead of a garbled buffer.

### Edge Cases

- **Source line ending in `~` at a row boundary**: the row marker is indistinguishable from
  real content, so such a line can be dropped. Accepted limit, documented in the code header
  of `s:join_chunks()`.
- **Lone CR line endings**: not treated as line breaks; trailing CR is stripped per line.
- **Grouped procedures** (`order by number, colid2, colid`): the clustered-index order keeps
  `create procedure` / `text` / `grant` in definition order.
- **Line of only dashes or equals signs**: always treated as client framing; accepted
  because such a line cannot appear in valid SQL.
- **Very large objects**: the 255-byte slicing applies per row, so a 200 KB procedure
  yields ~800 catalog rows in one query; no pagination is implemented.
- **Empty/whitespace-only catalog text**: trims to no lines, which the caller reports as
  unreadable rather than opening an empty buffer.
- **Repeated opens**: opening the same object twice produces the same content; the source
  path is a pure read of the current database.
- **Encrypted text (`version is not null`)**: reported through the same notice as
  `sp_hidetext` hidden text.
- **Stray client lines** (e.g. a row count when `set nocount on` did not apply): the hidden
  check compares against the labels `HIDDEN`/`OK`, never a bare number, so a stray count
  cannot be misread as "hidden".

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The adapter MUST read object source from `syscomments` by default, ordered by `number, colid2, colid`, instead of `sp_helptext`.
- **FR-002**: The adapter MUST reassemble the 255-byte catalog rows into the stored source with no mid-line cuts, by appending a two-character row marker that encodes whether the row ended on a real newline (`~ `) or was cut mid-line (`~+`).
- **FR-003**: The adapter MUST strip all client/server framing from the result set: `# Lines of Text` counters, column headings and their separator rows, `---`/`===` rules, row-count trailers, and `Msg <n>, Level <n>` diagnostics.
- **FR-004**: The source buffer MUST contain no banner, heading, count, or diagnostic line; only the object's own lines.
- **FR-005**: The adapter MUST support an opt-in `showsql` mode via `g:db_sybase_source_mode` that issues `exec sp_helptext '<name>', NULL, NULL, 'showsql,noparams'`, and MUST treat any other value (including unset) as `catalog`.
- **FR-006**: The adapter MUST detect hidden or encrypted catalog text before extracting it, and MUST return no lines in that case.
- **FR-007**: The hidden/encrypted check MUST return a labelled result (`HIDDEN`/`OK`) rather than a bare count, so a stray numeric client line cannot be interpreted as "hidden".
- **FR-008**: When no source lines are available for any reason (hidden/encrypted text, missing `select` permission, missing object, missing client, failed query), the picker MUST open no buffer and MUST emit exactly one WARN notice naming the object and the plausible causes.
- **FR-009**: Object names MUST be single-quote-escaped before interpolation into any catalog query; raw input MUST NOT be interpolated.
- **FR-010**: Source extraction MUST be a pure read scoped to the database in the connection URL, with no writes and no credential logging or persistence.
- **FR-011**: The smoke test MUST exercise the reassembly of cut rows, the marker-only row, framing removal, hidden-text detection, the `showsql` dispatch, and the escaping of object names, using canned client output.
- **FR-012**: `nvim/README.md` MUST document the source modes, the reassembly marker, the known limits, and the notice behavior in the same change that alters this behavior (constitution XIV).
- **FR-013**: The change MUST ship on a feature branch through a pull request that links its approved issue (constitution XIII).
- **FR-014**: No new runtime dependency, no configuration file, and no change to the rest of the DB module may be introduced by this feature.

### Key Entities

- **Catalog row**: one `syscomments` slice of an object's text, up to 255 bytes, plus the marker that says whether the slice ended on a real newline.
- **Source line**: one real line of the stored object text, produced by splitting the reassembled stream at newlines.
- **Source mode**: the extraction strategy for one adapter call — `catalog` (default) or `showsql` (opt-in).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For any non-hidden object, the opened buffer contains the byte-exact stored text: 100% of source lines match the catalog, with zero mid-line cuts and zero framing lines.
- **SC-002**: A 255-byte boundary that falls inside an identifier (e.g. `substring(@dat|o, ...)`) is rejoined into one line in 100% of cases.
- **SC-003**: Every unreadable-source condition produces exactly one notice and zero buffers; 0 garbled or empty buffers.
- **SC-004**: Offline validation (`stylua --check`, headless config load, adapter load, `sybase_objects_smoke`) passes with 0 failures, and the existing 8-smoke suite (141 assertions) stays green.

## Assumptions

- The user runs ASE 15.0.2+ / 16.x, so `sp_showtext` exists for the `showsql` mode; the
  default `catalog` mode does not depend on it.
- The client is `sqsh` by default (configurable via `g:db_sybase_client`); it renders a
  row's embedded newlines as output line breaks, which is what the marker scheme relies on.
- `syscomments` is readable by the login for the objects the user can otherwise see;
  permission failures degrade to the single notice.
- The user's own database uses LF line endings inside the catalog; CR-only line endings are
  not treated as breaks.
- Out of scope: the cross-database `%` scan (deferred in spec 001), integrating the team's
  stored procedures, and any change to the picker, save flow, or scope selection.
