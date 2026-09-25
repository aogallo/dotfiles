# Data Model: Database Scope for Object Search

Phase 1 output for `005-database-scope`. Entities are view/render-time models — no new storage —
derived from [spec.md](./spec.md) and the plan's Technical Context.

## Entities

### Connection URL

The resolved connection used by vim-dadbod: `sybase://[user[:password]@]host[:port]/[database]
[?charset=...]`.

- Fields (from `db#url#parse`): `scheme`, `user` (optional), `password` (optional, in-memory only),
  `host`, `port` (optional), `path` (→ `database` when not `/`), `params` (optional, e.g. `charset`).
- **Scoped variant**: a copy whose `path` is `/ <chosen-database>`; produced by
  `with_database(url, database)` per invocation. All other fields are carried over untouched.
- Relations: the scoped variant is the URL used for the scoped listing, for `b:db` on opened object
  buffers, and for the save flow's owning-database identity.
- Validation: `database` MUST match `[A-Za-z0-9_$#]`, else rejected with one actionable error
  (FR-007/FR-008). `%` is rejected by construction (FR-011).

### Database Scope Selection

The in-memory choice of which database a single `:DBObjects` invocation searches.

- Fields: `default` (the connection's current database, or the login default when the URL has no
  path), `chosen` (the pick the developer made, or the default when none).
- Lifecycle: created at the start of the invocation from the resolved URL; per-invocation and
  stateless — every fresh `:DBObjects` starts from the connection default again (FR-001/FR-006).
- States: `unset` (default used) → `chosen` → (scoped listing) → `cleared` on cancel (no-op).
- Relations: drives the scoped Connection URL; derived list shown by the chooser (from
  `complete_database()`, ordered by name).

### Object Search Result

One row of the object picker.

- Fields: `name` (object name, from `sysobjects`), `kind` (label mapped from type letter:
  procedure/function/view/table), `database` (owning database label, from the scoped URL path via the
  adapter — FR-003).
- Relations: `database` is present for Sybase listings and empty for the dadbod fallback rows
  (non-Sybase schemes keep current behavior, FR-012); carried into buffer naming and save naming.

### Owning Database

The database reported on an Object Search Result; the "single source of truth" for downstream
binding.

- Relations: open-buffer binding (`b:db` = scoped Connection URL so execution runs in the owning
  database, FR-004), source loading, database-qualified buffer names and saved file names
  (`<database>.<object>.sql`, FR-005). READ-ONLY identity, never mutated by downstream steps.

### Open Source Buffer

The SQL buffer that displays an opened object.

- Fields: `b:db` (scoped Connection URL ⇒ owning database), display name =
  `<database>.<object>.sql` when `database` is present (FR-005), `filetype=sql`, `bufhidden=hide`.
- Relations: feeds the existing execute-and-re-run flow (running against the owning database) and the
  existing save dialog (database-qualified file names).

## State transitions

```text
:DBObjects
   │  resolve URL (connection arg > current buffer b:db > registry picker)
   ▼
[Sybase?] ──no──► current fallback listing (unchanged, FR-012)
   │yes
   ▼
object picker = [Database: <current> — change…] + object rows (connected db)
   │
   ├─ "change…"
   │     │  chooser = [current(default)] + sysdatabases list  │  ESC ──► return to picker (no-op)
   │     ▼  pick B
   │  scoped URL = with_database(url, B)   (validate; error if invalid)
   │     ▼
   │  re-fetch objects against scoped URL → reopen picker with scope = B
   │
   └─ any object row
         ├─ table/view ──► list buffer (b:db = scoped URL)
         └─ proc/func ──► source buffer (b:db = scoped URL) ──► existing save dialog
```

Cancel at any point leaves files, buffers, and directory unchanged (FR-009).