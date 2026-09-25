# Contract: Sybase Database Scope (005-database-scope)

Defines the adapter surface and the user-facing picker flow for scoping the `:DBObjects` search to a
chosen database. Applies to the Neovim module (`nvim/`). Area: `sybase://` connections only; other
schemes keep the current fallback (FR-012).

## 1. Adapter surface — `nvim/autoload/db/adapter/sybase.vim`

### 1.1 `db#adapter#sybase#with_database(url, database)` — NEW

Returns a connection URL string whose path is `/ <database>`, preserving scheme, user, password,
host, port, and every query param (e.g. `charset=...`).

- Input validation (FR-008): `database` MUST match `^[A-Za-z0-9_$#]+$`. Otherwise returns `''`
  (empty), and the caller surfaces the canonical error (see §3.2).
- URL rebuilt from `db#url#parse()` fields; the database is inserted as the path segment with no
  percent-encoding (accepted charset requires none) and the rest of the URL is re-emitted verbatim.
- Never logs, stores, or prints credentials; the password travels only in the in-memory URL string.

### 1.2 `db#adapter#sybase#objects(url)` — CHANGED

Keeps today's `sysobjects` query against the URL's database, but each returned row now also carries
`database`, set to the database the listing ran in (`s:database(url)`, i.e. the scoped URL's path).

- Row shape: `{ name: string, kind: "table"|"view"|"procedure"|"function", database: string }`.
- `kind` mapping and diagnostic filtering are unchanged.

## 2. Picker flow — `nvim/lua/config/db_objects.lua`

### 2.1 Scope entry

For `sybase://` resolutions, the object picker's first row is:

```text
Database: <connection database, or "login default"> — change…
```

Non-Sybase listings do NOT render this row (FR-012). The value shown is the database of the resolved
URL at invocation start.

### 2.2 Choosing a database

Selecting the scope entry opens a chooser (`vim.ui.select`) over the databases the login can read,
ordered by name, seeded with the current database as the first/default entry:

1. `[use current: <current>]` (default) — keeps the connected database.
2. each readable database from `complete_database()`.
3. ESC / cancel — returns to the previous picker with no state change (FR-009).

### 2.3 Applying the choice

Picking a non-current database:

1. `with_database(url, database)` → scoped URL (validate; see §3.2 on rejection).
2. Re-fetch objects against the scoped URL; reopen the picker with the scope row now reading
   `Database: <chosen> — change…` and the listing showing that database's objects (FR-002/SC-001).
3. The scoped URL is threaded unchanged into every downstream step this invocation:
   - table/view → the list buffer's `b:db` = scoped URL;
   - procedure/function → the source buffer's `b:db` = scoped URL, then the existing save dialog
     (FR-004/FR-010);
   - buffer display name and save file name become `<database>.<object>.sql` (FR-005).

### 2.4 Defaults and scope lifecycle

Scope is per-invocation and stateless. Every fresh `:DBObjects` starts from the connection's
database; it is never persisted across invocations (FR-001/FR-006/SC-005).

## 3. Errors (FR-007)

### 3.1 Unknown or inaccessible database

Choosing a database the login cannot read or that does not exist → exactly one actionable notice:
`DBObjects: cannot access database '<name>'` and the chooser stays open/re-fetch is not attempted;
no empty picker or buffer is opened.

### 3.2 Invalid database name

A name failing `^[A-Za-z0-9_$#]+$` (including `%`) → exactly one actionable notice naming the
offending value and the accepted charset; no query runs (FR-007/FR-008/FR-011).

## 4. Non-goals (explicitly out of contract)

- Cross-database search over all databases (`%`) — owned by `001-multidb-object-search` (FR-011).
- Team stored-procedure enrichment — owned by `001-multidb-object-search`.
- Changes to the `:DBObjects` command grammar or the connection registry — none (FR-010).