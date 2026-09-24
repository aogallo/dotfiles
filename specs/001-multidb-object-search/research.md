# Research: Multi-Database Sybase Object Search

Phase 0 output. Resolves the unknown design points for the cross-database search and the
byte-exact source extraction. Every decision is grounded in the existing adapter
(`nvim/autoload/db/adapter/sybase.vim`) and verified ASE behavior.

## Decision: Read procedure source from `syscomments` instead of `sp_helptext`

**Rationale**: ASE stores the original definition statements of compiled objects (procedures,
views, triggers, defaults) in the per-database `syscomments` table. The `text` column is
`varchar(255)` and "if the text column is longer than 255 bytes, the entries span rows"; the row
order that reconstructs the definition is the table's unique clustered index
`id, number, colid2, colid, texttype` (ASE Reference Manual — syscomments). This is exactly why
`sp_helptext` wraps long lines and splits variables/conditions mid-token: it prints the 255-byte
chunks as separate rows. Reading the chunks and concatenating them in `colid2/colid` order recovers
the byte-exact definition, satisfying FR-013.

**Source query (single-quote-escaped `name`)**:

```sql
select colid, text from syscomments where id = object_id('<name>') order by number, colid2, colid
```

- Reassembly: collect every `text` chunk in row order, concatenate (no separators — chunks are
  slices of the original DDL), then split the result on the `\n` characters stored inside the text.
  Chunk boundaries that fall in the middle of a line are healed by concatenation-first.
- Hidden/encrypted text: `status & 0x1 = 0x1` = `SYSCOM_TEXT_HIDDEN`; `version` non-null marks
  encrypted hidden text. When the object's rows carry that flag, or reassembly yields an empty
  result for a known `object_id`, return an actionable notice (FR-014) instead of garbage.
- Namespacing: procedures created in the same database with grouped `number > 0` are ordered by
  `number` first, so sub-procedures concatenate in definition order.
- The `use <db>` line for the owning database is injected by the existing `s:run_query` preamble
  (URL path), so extraction inside the correct database is automatic once the URL carries
  `?path=/<owning-db>` (see data model).

**Alternatives considered**:
- `sp_helptext` + heuristic re-join of output rows — fragile: cannot distinguish a real 255-byte
  wrap from a diagnostic line; fails the fidelity requirement. Rejected.
- `bcp out`/server-side DDL export — requires scripting, temp objects, or `bcp` on the client;
  more machinery than a select, contradicts the Simplicity gate. Rejected.

## Decision: Native cross-database search = per-database `sysobjects` scans at isolation level 0

**Rationale** (FR-001/005): the adapter already lists databases via `complete_database(url)`
(`select name from sysdatabases order by name`) and already runs multi-statement batches through
`db#systemlist`. The native scan reuses both:

1. Fetch database names with `complete_database(url)` and filter out system databases in Lua
   (`master`, `model`, `tempdb`, `sybsystemdb`, `sybsystemprocs`, `dbsprocs`). Using the name list
   (not `dbid > n`) stays correct on any ASE layout where user databases don't start at a fixed
   dbid.
2. Build one batch with one section per target database. Each section is
   `use <db>` + `set nocount on` + the filtered select + the batch terminator (`\go` on sqsh,
   `go` on isql), reusing the existing per-client separator logic. sqsh processes multiple
   `\go`-terminated batches from a single `-i` file, so one connection round trip covers all
   databases.
3. Every select embeds the database name as a literal so the parser can label rows without
   juggling result-set boundaries, and status/date columns are emitted token-safe:
   `convert(varchar(10), crdate, 112)` (YYYYMMDD) and `convert(varchar(8), crdate, 108)` (HHMMSS)
   contain no spaces, so rows stay single-token per column (same assumption the adapter already
   uses in `s:first_tokens`).

**Non-blocking guarantee** (FR-005/SC-009): prepend `set transaction isolation level 0` to the
batch. ASE documentation: "Scans at isolation level 0 do not acquire any read locks, so they do not
block other transactions from writing to the same data, and vice versa." This is the user's hard
requirement ("aun siendo dev no me gustaría que se bloqueara") and holds regardless of whether the
team procedure is configured. The scan never issues DDL and never creates temporary objects in a
target database. Catalog rows for a dropped/altered object may read dirty at level 0; harmless for a
search, and the opened object re-verifies on source load. Note ASE allows `0 | 1 | 3`; level 0 is
valid on ASE (revoked on IQ only, out of scope).

**Query per database (`type IN (...)`), owner via `sysusers`**:

```sql
use <db>
set nocount on
select '<db>', o.name, u.name, convert(varchar(10), o.crdate, 112),
       convert(varchar(8), o.crdate, 108), o.type, o.id
  from sysobjects o, sysusers u
 where o.uid = u.uid and o.type in (select-config-driven-set)
   and o.name like '<escaped-pattern>'
go
```

- `o.id` is carried in the native row so the follow-up source read can use it
  (`syscomments where id = <id>`) instead of a second `object_id()` lookup — cheaper and immune to
  rename races between search and open.
- Result parsing keeps the existing line-shape discipline: a valid row matches the literal db +
  token sequence with an `o.type` letter in `UVPFX`; anything else is collected as a diagnostic
  line and surfaced (FR-006).

**Alternatives considered**:
- Only the team procedure, no native path — rejected by the user (must work without it).
- `sp_foreachdb` — SQL Server feature, not available on ASE. Rejected.
- A catalog `union all` view across databases — ASE has no cross-database catalog; requires
  per-database sections anyway. Rejected as more complex than the generated multi-batch.

## Decision: Optional procedure override via `g:db_sybase_search_proc`

**Rationale** (FR-002): mirrors the existing `g:db_sybase_client` override pattern. When the global
is empty/unset, `object_search()` uses the native scan. When set to a two-part name (`<db>..<proc>`,
ASE syntax for "default owner in <db>"), the search executes
`exec <db>..<proc> '<escaped-pattern>', '<type>', '<db-scope>'` through the same `s:run_query` path
and parses the 6 output columns (name, owner, date, time, owning database, type) the developer
documented, normalizing to the same `database/name/owner/date/time/kind` row shape as the native
scan. Unset → native (never an error, FR-010); set-but-missing/renamed → one actionable error.

**Alternatives considered**: pcall to detect existence first (`object_id` in `<db>`) — extra round
trip on every search; the single actionable error on failure is sufficient. Rejected.

## Decision: Keep the result row shape identical for native scan and SP path

**Rationale** (FR-004, Simplicity): `db_objects.lua` should not branch on the engine. Both paths
emit rows with the same six attributes — owning database, object name, owner, date, time, kind
(`kind` derived from the type letter using the existing `s:object_kind()`). The picker renders
`database  kind  name  (owner)` regardless of engine, and the open action only needs
`owning database + id/name` (+ the connection URL), which both engines provide.

**Alternatives considered**: two row shapes with engine tagging — more parser and renderer
surface for no user value. Rejected.

## Decision: Opened buffers bind to the owning database; names are database-qualified

**Rationale** (FR-007/011): the picker's open action rewrites the connection URL to
`path=/<owning-db>` before calling `source()`, so the adapter's existing `use <db>` preamble
targets the right database; the new buffer's `b:db` carries that URL and its name is
`<owning-db>.<object-name>.sql`, so same-named objects from different databases coexist and
re-run against the correct database. Sqlite-style have no relevance; only the URL path changes.

**Alternatives considered**: tracking a separate "owning db" buffer variable without URL rewrite —
creates a second source of truth that can drift from the actual dadbod connection. Rejected.

## Key ASE facts verified

- `syscomments`: `text varchar(255)`, spans rows when > 255 bytes, up to 65,025 rows per object;
  unique clustered index on `id, number, colid2, colid, texttype`; `status & 0x1` =
  `SYSCOM_TEXT_HIDDEN`; `version` non-null = encrypted hidden text. (ASE Reference Manual.)
- `set transaction isolation level 0`: level-0 scans acquire no read locks; do not block writers
  and are not blocked by writers; valid on ASE. (ASE docs "Dirty Reads" / "Choose an Isolation
  Level".)
- `sp_helptext` prints catalog chunks as rows → the reported 255-byte wrapping/cutting.
- `convert(varchar, crdate, 112)/(108)` produce space-free date/time strings.