# Research: Object Source Fidelity

Decisions taken while replacing `sp_helptext` with a `syscomments` read. Each entry records
the alternatives and why the shipped choice won, so a later session does not re-litigate them.

## R1. Why the headings were not a client-flag problem

**Question**: The buffer showed `text` / `--------` / `3 rows affected` before the source.
Could `sqsh` flags (`-h`, `-b`, `set nocount`) remove them?

**Finding**: No. That framing is part of the *result set* `sp_helptext` returns: a counter
result set (`# Lines of Text` + the number), then a column result set (heading `text`,
separator rule, then the 255-byte rows), then the count trailer. There is no flag that makes
`sp_helptext` return only the text rows.

**Decision**: Fix it in the adapter — strip the framing client-side (`s:clean_result()`),
and avoid the framing entirely by reading `syscomments` in the default path.

## R2. Catalog read vs `sp_helptext 'showsql'`

**Options**:

| Option | Fidelity | Availability | Verdict |
| --- | --- | --- | --- |
| `sp_helptext` (legacy) | Broken (255-byte cuts + framing) | Any ASE | Rejected — this is the defect. |
| `sp_helptext … 'showsql'` | Regenerated/formatted SQL | ASE 15.0.2+ | Kept as opt-in mode. |
| `select text from syscomments` | Byte-exact stored text | Any ASE | Chosen as default. |

**Decision**: `catalog` mode is the default because byte-exact stored text is what a user
saving a `.sql` file expects; `showsql` stays available via `g:db_sybase_source_mode`
because it is the only path that returns regenerated SQL, and it is the natural fallback
where the stored text is encrypted in a way the catalog read cannot use.

**Gotcha**: the user originally proposed `sp_helptext 'x', NULL, NULL, 'showsql'` as *the*
fix. It is valid on 15.0.2+, but it reformats the SQL — so it is a mode, not the default.

## R3. How to know a row was cut mid-line (the marker scheme)

**Problem**: `syscomments.text` is `varbinary(255)`. The client prints each row's embedded
newlines as its own line breaks, so a 255-byte slice is emitted as *several* output lines and
the client gives no signal about where the slice ended. A slice that ended mid-line is
indistinguishable from one that ended on a newline — unless the SQL says so.

**First attempt (failed)**: append a bare `~` to each row and treat a standalone `~` line as
"row ended on a newline". Two problems: (1) a bare `~` never matches a Vimscript `=~#` pattern
— `~` is a regex metacharacter, so `t ==# '~'` was used for the exact compare and `t =~# '~+$'`
silently never matched; the fix is `\~+` (`sybase.vim:491`); (2) rows that *did* end on a
newline emit their marker on a line of its own, which is workable, but the mid-line case
needed the marker to be glued to the partial line.

**Shipped decision**: append `'~' + case when text like '%' + char(10) then ' ' else '+' end`
to every row, then reassemble:

- Row ends with `char(10)` → output ends `~ ` alone on its own line → the real newline is
  already inside the text, so skip the marker line and emit `"\n"`.
- Row cut mid-line → output ends `partial~+` → strip the two marker characters and leave the
  line open, continuing on the next output line.

Then `split(text, "\n", 1)` once, strip a trailing `\r` per line, trim blank edges. See
[data-model.md](data-model.md) for the full state table and [contracts/](contracts/object-source-extraction.md)
for the exact queries.

**Accepted limits** (documented in the `s:join_chunks()` header): a source line whose last
characters are exactly `~` at a row boundary is dropped; lone CR endings are not breaks.

## R4. Detecting hidden/encrypted text

**Options**: (a) extract and inspect the bytes; (b) query `syscomments` for
`status & 1 = 1` (SYSCOM_TEXT_HIDDEN) or `version is not null` (encrypted) before extracting.

**Decision**: (b) — one cheap labelled query, and unreadable text is never put in a buffer at
all.

**Gotcha**: the first version used a bare `count(*)` and compared the output to `1`. A stray
numeric line (a row count when `set nocount on` did not apply) would then read as "hidden",
producing a wrong notice for every open. Shipped version returns
`case when count(*) > 0 then 'HIDDEN' else 'OK' end` and compares against the label
(`sybase.vim:517`).

## R5. Framing rules for `s:clean_result()`

A line of only `[-=]{3,}` is treated as client framing. This is safe: such a line cannot
appear in valid SQL. A column heading is detected as an identifier line immediately followed
by a separator rule. `Msg <n>, Level <n>` short-circuits the whole result to `[]` so the
caller shows the single notice instead of a garbled buffer.

## R6. Scope discipline

Deferred deliberately: the cross-database `%` scan (spec 001 FR-002/004/005/006, recorded as
out of scope in that spec's verify report), integrating the team's stored procedures, and any
change to the picker/save/scope flows. This change only touches source extraction.
