# Data Model: Multi-Database Sybase Object Search

Phase 1 output. Defines the entities this feature produces and consumes. There is no persistent
storage — everything is derived per invocation from the connection URL, per-user globals, and the
server catalog.

## Entities

### Connection URL (`sybase://[user[:pass]@]host[/database]`)

Source of the client/argv path (server name, credentials, charset). During a cross-database open
action the `path` segment is rewritten to `/<owning-database>` so the adapter's existing `use <db>`
preamble and the buffer's `b:db` both target the object's real database.

- **Validation**: scheme `sybase`; server name resolved from client config (no `:port`); registry
  secrets live in env placeholders (`$VAR`) only.

### Database (native scan target)

One accessible user database, derived at search time from `complete_database(url)`.

- **Attributes**: name.
- **Validation**: excludes the fixed system set `master, model, tempdb, sybsystemdb,
  sybsystemprocs, dbsprocs`. Per-database access failures become diagnostics, never a search abort.

### Search Result (row)

The unit rendered in the picker. Produced in identical shape by both engines.

| Attribute | Native scan | Procedure path | Notes |
|-----------|-------------|----------------|-------|
| `database` | literal `<db>` column | owning-database column | disambiguates same-named objects (FR-004) |
| `name` | `sysobjects.name` | column 1 | like-filtered |
| `owner` | `sysusers.name` (join on `uid`) | column 2 | displayed in picker |
| `date` | `convert(crdate,112)` | column 3 | `YYYYMMDD`, space-free |
| `time` | `convert(crdate,108)` | column 4 | `HHMMSS`, space-free |
| `kind` | mapped from `type` letter | `type` letter | via `s:object_kind()` |
| `id` | `sysobjects.id` | — | native-only; powers direct `syscomments` lookup |

- **Validation**: type letter ∈ `U/V/P/F/X`; rows parse only when the token shape matches; anything
  else is a diagnostic line (surfaced, FR-006).

### Object Source (extracted text)

The byte-exact definition of an opened object.

- **Derivation**: concatenation of all `syscomments.text` rows for the object ordered by
  `number, colid2, colid`, then split on real `\n` characters.
- **Validation**: rows exist for the object's `id`, none carry `status & 1` (hidden) or a non-null
  `version` (encrypted); non-empty after reassembly. Violations → actionable notice; never a
  garbled/empty buffer (FR-014).

### Opened Buffer

A Neovim SQL buffer produced by the open action.

- **Attributes**: `name = <owning-db>.<object>.sql` (database-qualified, FR-008); `filetype = sql`;
  `b:db = <URL path=/owning-db>`; `bufhidden = hide`.
- **Relationship**: bound 1:1 to the Search Result that created it; executing it runs against the
  owning database (FR-011).

## Configuration knobs (per-user, no committed state)

| Knob | Type | Default | Meaning |
|------|------|---------|---------|
| `g:db_sybase_search_proc` | string | unset | OPTIONAL. Two-part name (`db..proc`); set → procedure path, unset → native scan |
| `g:db_sybase_client` | string/list | by platform | unchanged (existing) |
| search type default | `'P'` | procedures | pass-through `U/V/F/X` |
| search db default | `'%'` | all accessible | or a specific database name |

## State transitions

Nothing is persisted; the only lifecycle is per-invocation:

1. `:DBObjects <name>` → resolve connection (existing resolution) → `object_search()`
   → picker shows rows.
2. Row selected → rewrite URL path to owning db → `source()` → new Buffer (bound).
3. Buffer execute → existing run flow against `b:db` (owning database).
4. No name → existing single-DB `objects()` listing (unchanged, FR-011).

Failures branch to notices/errors without creating buffers: empty result (no-match), hidden text,
missing client, missing/renamed configured procedure, inaccessible databases (partial results kept).

## Validation rules by requirement

- FR-001/002/005: engine selection + non-blocking — enforced in the adapter's batch preamble
  (`isolation level 0`) and the Lua system-db filter.
- FR-004: row shape equality (both engines) — contract `sybase-search.md` row table.
- FR-008: escaping — every interpolated string is single-quote-doubled in `object_search`/`source`.
- FR-013/014: fidelity + hidden text — reassembly + status/version checks in `source()`.