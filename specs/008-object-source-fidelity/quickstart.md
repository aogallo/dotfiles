# Quickstart: Object Source Fidelity (`:DBObjects`)

**Created**: 2026-09-25 · **Spec**: [spec.md](spec.md) · **Contract**: [contracts/object-source-extraction.md](contracts/object-source-extraction.md)

## Prerequisites

- Neovim with this config (`nvim/init.lua`).
- `sqsh` available (or `g:db_sybase_client` set) for any live check.
- A Sybase ASE login with `select` on `sysobjects` and `syscomments`.
- For the live section: an ASE 15.0.2+ / 16.x instance and a procedure longer than 255 bytes
  whose body crosses a 255-byte boundary inside an identifier.

## Automated validation (no server required)

Run from the repository root:

```bash
# 1. Lua formatting check
stylua --check nvim

# 2. Headless startup of the whole config
nvim --headless -u nvim/init.lua '+quitall'

# 3. Adapter loads standalone (no plugin/config side effects)
nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'

# 4. Source-extraction smoke (canned sqsh output; 28 assertions)
nvim --headless -u NORC \
  -c 'lua vim.g.db_sybase_client = "sqsh" require("tests.sybase_objects_smoke")' -c 'qa!'

# 5. Dependency validation
setup/validate-nvim-deps.sh
```

What the smoke proves: the 255-byte rows are rejoined into whole lines
(`substring(@dat` + `o, @poscicion, 1)` → one line), the `~ ` marker row is consumed, framing
and `Msg` diagnostics are stripped, the hidden check labels are compared as `HIDDEN`/`OK`, the
`showsql` dispatch issues `exec sp_helptext 'usp_calc', NULL, NULL, 'showsql,noparams'`, and
an unset mode still uses the catalog query.

## Manual acceptance (live server required)

Open [tasks.md](tasks.md) tasks T101–T102 after these pass.

1. `:DBObjects` on a connection, pick a **procedure** whose body exceeds 255 bytes.
2. Read the buffer:
   - no `# Lines of Text`, no `text` heading, no `--------`, no `N rows affected`;
   - every line is complete — check the line that spans a 255-byte boundary;
   - blank lines, comments, and `go` are preserved.
3. Save through the save flow; confirm the destination dialog names the object and the database.
4. Re-run `:DBObjects` for the same object: the content must be identical.
5. Optional: `let g:db_sybase_source_mode = 'showsql'`, reopen the object, and confirm the
   buffer is regenerated SQL without the parameter block. Note that the formatting may differ
   from the catalog's — that is the documented trade-off, and a reason `catalog` is the default.
6. Degraded paths (pick one you can reproduce safely):
   - `sp_hidetext on` an object you own, reopen it → no buffer, one WARN notice naming the object;
   - a login without `select` on `syscomments.text` → same single notice.

## Known limitations (accepted)

- A source line whose last characters are exactly `~` at a 255-byte row boundary is dropped by
  the marker scheme (`s:join_chunks()` header).
- A lone CR line ending is not treated as a line break; a trailing CR is stripped per line.
- A line made only of `[-=]{3,}` is always treated as client framing — it cannot occur in valid SQL.
- `showsql` mode regenerates the SQL, so a saved file can differ from the stored formatting;
  it also needs ASE 15.0.2+ (`sp_showtext`). On older servers it degrades to the single notice.
- No pagination: a very large object is fetched in one query.
- Out of scope here: the cross-database `%` scan (deferred in spec 001) and integrating the
  team's stored procedures.

## Rollback / recovery

Read-only change, nothing persisted. Revert the commit (or the PR) to restore the previous
`sp_helptext` behavior; the optional `g:db_sybase_source_mode` variable is ignored by the
older code, so it can be left in place or removed.
