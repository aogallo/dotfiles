# Data Model: DBUI Query Result Reopen and Notification Routing

Phase 1 output for `006-dbui-query-results`. Entities are in-memory models — no new storage — derived from
[spec.md](./spec.md) and the plan's Technical Context.

## Entities

### Last Query Result Record

The single per-session slot that tracks the most recent finished query output (spec Key Entity; FR-001).

- Fields:
  - `outfile` (`string | nil`) — absolute path of the finished `.dbout` temp file. Derived from the
    `User */DBExecutePost` match name via `fnamemodify(match, ':h')`.
  - `bufnr` (`integer | nil`) — the result buffer that existed at `DBExecutePost` time
    (`bufnr(outfile)`). Becomes stale when the preview window closes (`bufhidden=delete` wipes it).
  - `running` (`boolean`) — `true` from `DBExecutePre` until `DBExecutePost`. Guards FR-006.
- Lifecycle: `nil` at config load → committed on every `DBExecutePost` (latest wins, overwriting the
  previous `outfile`/`bufnr`) → consumed read-only by the summon action → refreshed on the next
  `DBExecutePost`. Never persisted; replaced, never appended (FR-007).
- Relations: points at the **Query Result Window** (when one exists) and at dadbod's **output temp file** on
  disk (the reopen fallback). Validation: `outfile` is only trusted when `filereadable` at summon time
  (FR-008); `bufnr` is only trusted when `vim.api.nvim_buf_is_valid(bufnr)` (FR-004).

### Query Result Window

The preview window dadbod creates for a query result (`:pedit`, `db.vim:545`; buffer options `nobuflisted
bufhidden=delete`, `db.vim:410`). The summon action either focuses it or recreates it.

- States: `open` (buffer valid, ≥1 window — possibly in another tab), `closed` (buffer wiped, file still on
  disk), `gone` (buffer wiped and file no longer on disk).
- Zero or one of these is the summon target; the drawer's own "Query results (N)" list is a separate
  read-only mirror (FR-007).
- Relations: `open` reaches it via `win_findbuf(bufnr)` (current tab preferred, fallback across tabs);
  `closed` recreates it by `:pedit outfile`; `gone`/`none` produce exactly one notice.

### Notification Routing Flag (US2)

A config-only toggle. Fields: `vim.g.db_ui_use_nvim_notify = true` (Neovim-only, set in dadbod-ui `on_setup`).

- No state transitions beyond the plugin-upstream read at first notification use; severity mapping
  (info/warning/error) is dadbod-ui's own (FR-009/FR-010/FR-011).

## State transitions

```text
config load ─► slot = { nil, nil, running=false }

:DB / drawer query
   │
   ▼
User */DBExecutePre ─────────────────────────────► running=true (nothing recorded yet)
   │ job completes / aborts
   ▼
User */DBExecutePost ──► slot = { outfile, bufnr(outfile), running=false }   (latest wins, FR-001/FR-007)

<leader>qr  (summon)
   │
   ├─ slot == nil ─────────────► one INFO notice "no query result recorded"   (FR-005)
   ├─ running == true ─────────► one INFO notice "query still running" (no-op) (FR-006)
   ├─ bufnr valid & has window ─► focus window (current tab preferred, else tab switch) (FR-003)
   ├─ bufnr invalid & filereadable(outfile) ─► :pedit outfile → result window recreated (FR-004)
   └─ else ────────────────────► one WARN notice "output file no longer exists" (FR-008)
```

Repeated presses converge on the same `open` state (idempotent; no buffers/windows accumulate). Cancel
never applies — the summon path never mutates query state, files, or the drawer (FR-007/FR-009 in the
spec's edge cases).