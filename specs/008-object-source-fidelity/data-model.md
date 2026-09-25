# Data Model: Object Source Fidelity

No persistent data model. This change reads the ASE catalog and reassembles text in memory.
The entities below describe the *in-transit* shapes that the contract and the code must agree
on; they are the reason a change here is not just "swap one query for another".

## E1. Catalog row

One `syscomments` slice for an object: up to 255 bytes of `text` plus a two-character marker
appended by the extraction query.

| Field | Type | Notes |
| --- | --- | --- |
| `text` | `varbinary(255)` | A slice of the stored source, not a line. May end mid-line. |
| marker | `char(2)` | `~ ` when the slice ends with `char(10)`; `~+` when it is cut mid-line. |
| `number` | `int` | Text-block number (definition, then `grant` blocks). |
| `colid2`, `colid` | `int` | Column offsets; with `number` they define the clustered-index order used by `order by number, colid2, colid`. |

**Rule**: rows are never assumed to be lines. The marker is the only carrier of "where this
slice ended" because the client prints embedded newlines as output line breaks and therefore
destroys that information otherwise.

## E2. Client output line

What `sqsh` actually hands back for one row, after the client renders embedded newlines.

| Catalog row ends | Rendered output | Example |
| --- | --- | --- |
| on a real newline | marker alone on the last output line | `~ ` |
| mid-line | marker glued to the partial line | `  select @var = substring(@dat~+` |

## E3. Source line

One real line of the stored object text, produced by concatenating the stream, splitting once
at `"\n"`, stripping a trailing `\r`, and trimming blank edges. This is what the buffer
contains, one list entry per line.

## E4. Source mode

| Mode | Trigger | Result |
| --- | --- | --- |
| `catalog` | default, or any value of `g:db_sybase_source_mode` other than `showsql` | Byte-exact stored text via `syscomments` (E1 → E3). |
| `showsql` | `g:db_sybase_source_mode = 'showsql'` | Regenerated/formatted SQL via `sp_helptext … 'showsql,noparams'`; may differ from the catalog's formatting. |

## E5. Empty result (degraded state)

`[]` is the single sentinel meaning "no readable source" for every cause: hidden/encrypted
text, missing `select` permission, missing object, missing client, failed query. The picker
turns it into one WARN notice. No other shape signals failure, and no partial buffer is ever
opened.

## Invariants

1. A buffer produced from a non-empty result contains only the object's own lines — no banner,
   heading, count, or diagnostic (FR-004).
2. A line in the buffer is never a fragment: any catalog row boundary inside a line is
   rejoined before the split (FR-002, SC-002).
3. The extraction never writes and never leaves the database in the URL (FR-010).
4. The hidden check runs before extraction, so unreadable text is never buffered.
