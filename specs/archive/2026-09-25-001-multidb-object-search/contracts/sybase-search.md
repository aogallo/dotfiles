# Contract: Sybase cross-database object search (`sybase://`)

**Owner**: Neovim module (`nvim/autoload/db/adapter/sybase.vim`, `nvim/lua/config/db_objects.lua`)
**Consumers**: `db_objects.lua` `:DBObjects [name]` picker
**Related spec**: FR-001–014, US1/US2/US3
**Predecessor**: `contracts/sybase-adapter.md` (archived feature) — unchanged functions remain valid.

## New adapter functions (dadbod extension, not dispatched by dadbod)

Called directly by `db_objects.lua` like the existing `objects()`/`source()`. All string parameters
MUST be single-quote-escaped before interpolation (the adapter doubles every `'`), never raw input.

| Function | Signature | Contract |
|----------|-----------|----------|
| `object_search` | `(url, pattern, type, db) → {rows=…, diagnostics=…}[]` | Cross-database search. `pattern` is a `LIKE` pattern; `type` is an ASE type letter or a quoted set like `'P'`/`('U','P')`; `db` is `%` (all) or `dbname`. Runs the configured procedure when `g:db_sybase_search_proc` is set, otherwise the native scan. Returns `rows` (see row shape) plus `diagnostics` lines for inaccessible databases (FR-006). |
| `source` | `(url, name, id) → string[]` | **Behavior change**: no longer `sp_helptext`. Reads `syscomments` for the object (`id` from `object_id(name)`, or the caller-supplied native id), ordered by `number, colid2, colid`, concatenates chunks, splits on real line breaks. Empty/hidden result → `[]` with an actionable notice expectation in the caller (FR-014). |

## Result row shape (native scan AND procedure path — identical)

```
{database, name, owner, date, time, kind, id?}
```

- `kind` ∈ table | view | procedure | function (from ASE letter `U/V/P/F/X` via the existing
  `s:object_kind()`).
- `date` = `YYYYMMDD`, `time` = `HHMMSS` (space-free). Native scan derives from `crdate`
  (`convert(…,112)/(108)`); the procedure supplies its own when configured.
- `id` (ASE `sysobjects.id`, native path only) is carried through so `source()` can read
  `syscomments where id = <id>` without a second lookup.
- Parsing discipline: a valid row line matches the literal db label + token sequence with a final
  `UVPFX` letter; any other line is a diagnostic and is surfaced, never dropped silently.

## Native scan batch (no `g:db_sybase_search_proc` configured)

1. Databases: `complete_database(url)` minus system databases `master, model, tempdb, sybsystemdb,
   sybsystemprocs, dbsprocs` (filtered in Lua by name — no fixed-dbid assumption).
2. One batch section per database, terminator per client (`\go` sqsh / `go` isql):

   ```sql
   set transaction isolation level 0
   use <db>
   set nocount on
   select '<db>', o.name, u.name, convert(varchar(10), o.crdate, 112),
          convert(varchar(8), o.crdate, 108), o.type, o.id
     from sysobjects o, sysusers u
    where o.uid = u.uid and o.type in (<type-set>) and o.name like '<pattern>'
   go
   ```

3. Non-blocking guarantee (FR-005): `set transaction isolation level 0` heads the batch — level-0
   scans take no read locks, so writers in the scanned databases are never blocked and the scan is
   never blocked by them. The batch contains only selects and `use`/`set` statements; no DDL, no
   temp objects in the target databases.

## Procedure path (when `g:db_sybase_search_proc` is set)

- Value semantics: Sybase two-part name (`db..proc`, default owner in that database), e.g.
  `master..mi_procedimiento`.
- Batch: `set transaction isolation level 0` + `exec <db>..<proc> '<pattern>', '<type>', '<db'>`
  + terminator, through the same `s:run_query` path. The procedure's richer columns
  (name, owner, date, time, owning database, type) are normalized to the same row shape.
- Unset → native scan, no error (FR-010). Set-but-missing/renamed → exactly one actionable error
  naming the configured procedure.

## Consumption (`db_objects.lua`)

- `:DBObjects` (no name) → unchanged: `objects(url)` listing of the connected database.
- `:DBObjects <name>` (sybase:// only) → `object_search(url, '%<name>%', 'P' | configured type,
  '%' | configured db)`: picker rows render `database  kind  name  (owner)`.
- Selecting a row → URL rewritten to `path=/<owning database>`; `source(url, name, id)`; new buffer
  named `<owning-db>.<name>.sql`, `filetype=sql`, `b:db = <rewritten url>`, ready for the US1
  execute flow (FR-011).
- Non-sybase schemes → unchanged fallback (dadbod `tables()`).

## Security

- Every interpolated `pattern`/`type`/`db`/`name`/procedure name is single-quote-escaped (doubled
  `'` → `''`) before being placed in SQL.
- Hidden/encrypted `syscomments` text produces a notice, never partial bytes.
- Credentials flow only through the existing argv path; nothing new is logged or stored.
- Committed files contain no real procedure names, credentials, or user-specific paths.