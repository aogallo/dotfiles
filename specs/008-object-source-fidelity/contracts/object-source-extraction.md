# Contract: Object Source Extraction (Sybase)

Public contract of `db#adapter#sybase#source(url, name)` in
`nvim/autoload/db/adapter/sybase.vim`, plus the two internal steps it orchestrates. The
consumer is `open_procedure_source()` in `nvim/lua/config/db_objects.lua`.

## `db#adapter#sybase#source(url, name)`

**Args**

| Arg | Type | Notes |
| --- | --- | --- |
| `url` | string | `sybase://` URL. Its path selects the database the object must live in. Credentials are passed to the client and never logged or persisted. |
| `name` | string | Object name. Single quotes are escaped (`'` → `''`) before interpolation; raw input is never interpolated. |

**Returns**: `string[]`

- Non-empty → the object's source, one entry per real line, no client framing, no mid-line
  cuts.
- `[]` → no readable source, for any of: client binary not executable, hidden/encrypted text,
  no `select` on `syscomments.text`, object absent, or query failure.

**Side effects**: none. Pure read of the current database's catalog.

**Precedence**

1. Client binary not executable → `[]` (no query issued).
2. `g:db_sybase_source_mode ==# 'showsql'` → `showsql` mode.
3. Otherwise (unset or any other value) → `catalog` mode.

## Step 1 — hidden/encrypted check (catalog mode only)

```sql
select case when count(*) > 0 then 'HIDDEN' else 'OK' end
from syscomments
where id = object_id('<name>')
  and (status & 1 = 1 or version is not null)
```

- `status & 1 = 1` → `SYSCOM_TEXT_HIDDEN` (`sp_hidetext`).
- `version is not null` → encrypted.
- Result MUST be compared against the label `HIDDEN`, never a bare number.
- `HIDDEN` → return `[]` without attempting extraction.
- No rows (`OK`, or object absent) → continue; an absent object yields `[]` at extraction.

## Step 2 — extraction (catalog mode)

```sql
select convert(varchar(255), text) + '~'
       + case when text like '%' + char(10) then ' ' else '+' end
from syscomments
where id = object_id('<name>')
order by number, colid2, colid
```

- `convert(varchar(255), …)` keeps the slice as text (the stored value is binary), and
  preserves the embedded newlines the client will render as line breaks.
- The suffix encodes row-boundary semantics — see [data-model.md](../data-model.md#e2-client-output-line).
- `order by number, colid2, colid` is the clustered-index order, so grouped procedures
  (definition, then `grant`) concatenate in definition order.

**Client-side reassembly**

1. Strip framing (`s:clean_result()`); `Msg <n>, Level <n>` → `[]`.
2. Per output line, right-trim whitespace:
   - `~` (the `~ ` marker rendered alone) → skip (the real newline is already in the text).
   - ends with `\~+` → drop the two marker characters, keep the line open.
   - otherwise → append the line plus `"\n"`.
3. `split(text, "\n", 1)` once, strip a trailing `\r` per line, trim blank edges.

**Accepted limits**: a source line ending in exactly `~` at a row boundary is dropped; CR-only
line endings are not treated as breaks; a line of only `[-=]{3,}` is always treated as client
framing (cannot occur in valid SQL).

## Step 2' — extraction (showsql mode, opt-in)

```sql
exec sp_helptext '<name>', NULL, NULL, 'showsql,noparams'
```

- `showsql` delegates to `sp_showtext`, so the `# Lines of Text` counter is never emitted.
- `noparams` drops the generated parameter block.
- Requires ASE 15.0.2+; on older servers this fails into `[]` → the single notice.
- Output is regenerated/formatted SQL, not the stored text: the saved file can differ from the
  catalog's original formatting. Prefer `catalog` for byte-exact source.

## Consumer behavior (`open_procedure_source`)

| Source result | Action |
| --- | --- |
| non-empty | open the buffer, then always start the save flow |
| `[]` | open **no** buffer; emit exactly one WARN notice naming the object and the plausible causes (hidden text, missing `select` on `syscomments.text`, missing object, unavailable client) |

## Constraints

- No new dependency, no configuration file, no other module change (FR-014).
- The Lua layer must not parse, re-join, or otherwise post-process source lines; reassembly is
  the adapter's job (constitution IV).
