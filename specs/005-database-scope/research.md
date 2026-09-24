# Research: Database Scope for Object Search

Phase 0 consolidation for `005-database-scope`. All technical unknowns were resolved from the
existing codebase (adapter, picker flow, dadbod URL helpers) and prior-session findings; no
[NEEDS CLARIFICATION] remained in the spec. Format: Decision / Rationale / Alternatives considered.

## D-1 How to run the search inside a chosen database

- **Decision**: Rebuild the connection URL with the chosen database as its path (a new adapter
  helper `db#adapter#sybase#with_database(url, database)`) and reuse the existing portable
  pipeline already in place: `s:use_lines()` / `s:transform()` emit `use <database>` at the start of
  every batch, so `objects()`, `source()`, and dadbod's own `:DB` run in the scoped database with
  zero client-specific flags.
- **Rationale**: The adapter already derives the working database solely from the URL path
  (`s:database(a:url)`), so a scoped URL flows through every existing call site untouched
  (`fetch_objects`, source loading, `b:db` binding, save naming). One small helper replaces what
  would otherwise be duplicated "run this query in another db" plumbing everywhere. dadbod exposes
  `db#url#parse()` (pack/core/opt/vim-dadbod/autoload/db/url.vim) so parsing/rebuilding is
  dependency-free.
- **Alternatives considered**:
  - *Global runtime override* (e.g., `g:db_sybase_database` consumed by `use_lines`): rejected —
    global mutable state would affect every query in every tab and cannot scope per invocation.
  - *New positional argument* (`:DBObjects <db> <name>`): rejected — collides with the grammar owned
    by `001-multidb-object-search` (`:DBObjects <fragment>`), causing the same ambiguity we are
    avoiding for `001`/`005`.
  - *Per-query `use` prefix in the picker module*: rejected — duplicates the adapter's existing
    batch-prefix logic and would bypass the single source of truth for `use <db>`.

## D-2 Where the database-scope control lives in the UI

- **Decision**: A "Database: \<current\> — change…" entry at the head of the object picker, rendered
  only for `sybase://` connections. Selecting it opens a one-shot chooser of the databases the login
  can read (seeded with the connection's current database); choosing one re-fetches the object list
  against the scoped URL and reopens the picker with the new scope shown. Cancelling the chooser
  returns to the previous picker unchanged.
- **Rationale**: Preserves the no-argument behavior exactly (the object listing of the connected
  database is what the picker shows first, per FR-006/SC-005) while satisfying "the flow offers a
  database-scope choice" (FR-001/FR-002). A dedicated top entry is discoverable, needs no new
  command surface, and avoids an extra unconditional dialog on every invocation. Scope is
  per-invocation and stateless (FR-001 default every time, matching the save dialog's always-ask
  philosophy).
- **Alternatives considered**:
  - *Always-ask chooser before every listing*: rejected — changes the no-argument flow and adds
    friction to the default path.
  - *Dedicated command (`:DBObjectsScope <db>`)*: rejected — more surface than needed; the spec
    scopes this to the search flow, not a new command grammar (FR-011 keeps `%`/cross-DB out).

## D-3 How each picker row is labelled with its owning database

- **Decision**: `objects(url)` gains a `database` field on every row, equal to the database the
  listing ran in (`s:database(url)`). The picker format string shows `kind + database + name` when
  the field is present; non-Sybase fallback rows (dadbod `tables()`) leave it empty and the label
  renders without the database part (FR-012 unchanged).
- **Rationale**: The adapter query knows exactly which database the catalog was read from, so rows
  are labelled at the source with no client-side guesswork. The same field feeds database-qualified
  buffer names and saved file names (FR-005), closing the gap where the current `open_buffer()` names
  buffers by object name only.
- **Alternatives considered**:
  - *Client-side label from the scoped URL*: rejected — the fallback (non-Sybase) path has no scoped
    URL, and duplicating the adapter's `s:database()` logic in Lua splits the truth.

## D-4 Database-name validation and URL rebuilding

- **Decision**: Accept database names matching `[A-Za-z0-9_$#]` (Sybase-safe identifier charset)
  and rebuild the URL path exactly (`path = '/' . database`), preserving scheme, user, password,
  host, port, and query params (`charset=...`). Anything else — including `%` — is rejected with one
  actionable error (FR-007/FR-008/FR-011).
- **Rationale**: A strict grammar makes `%` (out of scope) impossible by construction and keeps the
  interpolated `use <db>` line safe without quoting tricks. It also keeps the URL rebuild trivial
  (no percent-encoding of the path segment needed for the accepted charset).
- **Alternatives considered**:
  - *Allow arbitrary names with quoting*: rejected — Sybase `use` quoting is client-dependent and
    undermines the portable `use <db>` guarantee; the accepted charset covers all realistic Sybase
    database names.

## D-5 Testing strategy

- **Decision**: Add `nvim/lua/tests/db_objects_scope_smoke.lua` that exercises, headlessly and with
  canned output:
  - `with_database()` preserves auth/host/port/params and swaps the path; rejects invalid names;
  - `objects()` rows carry the `database` field;
  - the picker flow, with `vim.ui.select` injected/captured, requests the scope chooser, builds a
    scoped URL from the choice, re-fetches, and labels rows;
  - opening a result binds the buffer to the scoped URL (owning database) and the save name is
    database-qualified.
  Reuse the existing test harness pattern (`cquit` on failure, `PASS/FAIL` prints) from
  `db_objects_save_smoke.lua`.
- **Rationale**: Matches the module's established headless smoke convention (FR-013) and validates
  the scope transitions plus binding without a live server or picker interaction (interactive flows
  go to `quickstart.md`).
- **Alternatives considered**: none — the module already standardizes on this harness.