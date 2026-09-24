# Contract: Procedure Save Dialog (`db_objects.lua`)

**Owner**: Neovim module (`nvim/lua/config/db_objects.lua`, `nvim/plugin/database.lua`)
**Consumers**: `:DBObjects` command (user-facing) — the save dialog is a leaf addition to the
existing selection flow.
**Related spec**: `002-procedure-save-dialog` FR-001–FR-016.
**Predecessor**: the row shape (`database`, `name`, `kind`) and byte-exact `source()` come from
`001-multidb-object-search` (`contracts/sybase-search.md`).

## Setup contract

| Function | Signature | Contract |
|----------|-----------|----------|
| `setup` | `(startup_root: string) -> nil` | Called once from `plugin/database.lua` at plugin source time with `getcwd()` (the launch cwd, before any `:cd`). The module holds it read-only as the save dialog's default directory on every invocation (FR-002). Defensive: if never called, the first dialog defaults to `getcwd()` at that moment. No other state is stored. |

## Save-flow contract (internal to the module)

Triggered in the procedure branch of the existing selection flow, **always**, after the source
buffer opens (FR-001/FR-010). Tables/views keep their current list-query behavior.

| Function | Signature | Contract |
|----------|-----------|----------|
| `suggest_save_name` | `(database: string\|nil, name: string) -> string` | `database..'.'..name..'.sql'`, else `name..'.sql'` when `database` is nil/empty (FR-006). Purely derived; smoke-tested. |
| `pick_save_target` | `(initial: string) -> string\|nil` | Opens the directory browser via `vim.ui.select` (fzf-lua, the module's existing channel) over `vim.fs.dir` directory entries plus `..`, `use this directory`, `type a path…`. Returns the accepted directory or `nil` on cancel (FR-008). Typed paths are `vim.fs.normalize`d; relative paths resolve against the startup root (FR-004). Non-existent typed path → explicit `create directory` offer before acceptance. |
| `confirm_overwrite` | `(path: string) -> 'overwrite'\|'cancel'` | Shown only when `filereadable(path)` (FR-007). `cancel` = abort save with zero side effects (FR-008/SC-003). |
| `write_source` | `(lines: string[], dir: string, name: string) -> {ok: true, path: string} \| {ok: false, error: string}` | Writes the exact `lines` via `vim.fn.writefile(path)` (FR-005). On failure returns a single actionable error string (FR-009); the caller surfaces it with `vim.notify` and Neovim keeps running. No content transformation, no batch terminator appended. |

Flow within the module:

```
open_row(row: procedure/function with non-empty lines)
  → open source buffer (existing behavior, unchanged)
  → dir = pick_save_target(startup_root); if nil → stop (no-op)
  → name = suggest_save_name(row.database, row.name)
  → path = dir/name
  → if filereadable(path): confirm_overwrite(path); 'cancel' → stop
  → write_source(lines, dir, name) → ok → done; not ok → notify actionable error
```

## Failure paths

- Cancel at any dialog step → no file, no directory change, buffer untouched (FR-008/SC-004).
- Unreadable/empty source → existing notice; the save dialog is not shown; no empty file
  (FR-010/predecessor FR-014).
- Unwritable target / missing permission / failed `writefile` → one actionable `vim.notify` naming
  the problem; Neovim continues (FR-009).
- Existing same-named file → never overwritten without the explicit choice (FR-007/SC-003).

## Security & boundaries

- The feature writes only to paths the user chose; typed input goes through `vim.fs.normalize`
  and relative resolution against the startup root.
- No credentials, secrets, or connection data are written into saved files beyond the procedure
  source text the user already viewed.
- No new configuration surface: behavior is fixed by spec decisions (always-ask, startup-root
  default, database-qualified naming). Removing the save call restores prior behavior exactly.