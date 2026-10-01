# Contract: Query Diagnostics

**Feature**: [`012-surface-query-errors`](spec.md) · **Phase**: 1 · **Date**: 2026-10-01

The interface that closes the reporting gap (R-0004, R-0005). It is a **local**
interface inside `nvim/lua/config/db_results.lua` — not a new module — because
that file already owns per-run result state and already receives the same
dadbod events (Constitution Maintainability, D-0002).

## Public surface

One function and one listener registration. Nothing else is added to the module's
namespace.

```lua
--- Classify the text the server returned for one completed run.
--- @param lines string[]  the full response, in server order, unmodified
--- @return outcome table  one of: success | failed | cancelled | unreadable
function M.classify(lines) end
```

```lua
--- Register the per-run listener. Called from the existing on_post path;
--- idempotent, so a re-source is harmless.
function M.setup_diagnostics() end
```

## `M.classify(lines) -> outcome`

### Input

`lines` is the **complete** response, read from the output file at
`User */DBExecutePost` (D-0001). The caller must not filter, trim, or reorder it.
The classifier must not mutate it.

### Output shape

```lua
{
  kind      = 'success' | 'failed' | 'cancelled' | 'unreadable',
  complaints = { { code = 156, level = 15, text = "Incorrect syntax near ...", line_no = 1 }, ... },
  rows      = { 'a', 'b', ... },   -- retained partial rows when present (FR-026)
  row_count = 0,
}
```

`complaints` is `{}` for `success` and `unreadable`, and has **one entry per
complaint**, never just the first (FR-004).

### Recognition rules

Deterministic and ordered. Each rule is measured, not assumed.

| # | Condition | Outcome | Requirement |
|---|---|---|---|
| 1 | dadbod recorded `query.canceled` for the run | `cancelled` | FR-002 |
| 2 | any line matches `^Msg%s+(%d+),%s*Level%s+(%d+)` | `failed`, with all such lines captured | FR-001, FR-004 |
| 3 | client exit status is non-zero and no `Msg` line exists | `unreadable` | FR-012 |
| 4 | otherwise, no `Msg` line and no failure signal | `success` | FR-003, FR-007 |

Rule 2 is the ASE shape already used at `sybase.vim:510`, which is why no new
error vocabulary is introduced (D-0002). Rule 3 is the fail-closed default: an
unrecognized failure becomes a visible warning rather than silence. Rule 4's
zero rows is a **success** with `row_count == 0`, never a failure (FR-007,
SC-004).

**Not assumed**: that `isql` and `sqsh` word complaints identically. A client that
words things differently hits rule 3, so it degrades to a warning. The classifier
does not depend on any particular client's phrasing.

## Listener behavior

Fires on `User */DBExecutePost`, which dadbod raises at `autoload/db.vim:329`
**after** the output file is written at `:319` (measured, R-0005).

```lua
function on_post()
  local slot   = M._current_slot()      -- existing per-session state
  local lines  = readfile(slot.path)    -- authoritative source, not job lines (D-0001)
  local out    = M.classify(lines)
  if out.kind == 'failed' or out.kind == 'unreadable' then
    M._notify_once(slot, out)           -- dedup per run (FR-027)
  end
  M._store(slot, out)                   -- slot keeps the full lines (FR-025)
end
```

### Rules the listener must honor

- **Read the file, not the job's line list.** `db#systemlist()` returns `[]` on a
  non-zero exit (`autoload/db.vim:275-288`), so the line list is the one source
  guaranteed to have lost the complaint (R-0005, D-0001).
- **One notice per run.** A repeated identical failure must not accumulate
  duplicate notices (FR-027). The dedup key is the run's output path plus the
  complaint text; a new run has a new path.
- **Notice names the complaint.** The text includes the server's own words, so
  SC-001 is met by construction (FR-024, FR-028).
- **Never trim.** `slot` keeps `lines` in full, and the classifier does not
  rewrite them. Summoning the result later re-opens the same file and must show
  the same text (FR-005, FR-014, FR-025).
- **Never block execution.** The listener runs at Post, after the run. It cannot
  prevent a query from having been sent.
- **Internal errors are not server complaints.** An error raised inside this
  listener is reported as an internal error and must not be converted into a
  complaint about the statement (FR-011). The listener body is wrapped so a
  failure in reporting cannot be mistaken for a failed query.

## Error handling

| Condition | Behavior | Requirement |
|---|---|---|
| output file missing or unreadable at Post | `unreadable`, notice issued | FR-012, FR-017 |
| `readfile` raises | caught; `unreadable`, never `success` | FR-012, FR-011 |
| unrecognizable response format | `unreadable`, notice issued | FR-012 |
| zero rows, no complaint | `success`, no notice | FR-007, SC-004 |
| run cancelled by the user | `cancelled`, no failure notice | FR-002 |

## Observability

The notice text is the only new user-visible output. It is built from the
server's own complaint text and names the statement's buffer, so the developer can
locate the query (FR-024, FR-028). No log file, no telemetry, no persistence.

## Verification

Every rule above is testable with no server and no client binary, by calling
`M.classify()` on a fixture array and by writing a fixture file then raising
`doautocmd User DBExecutePost` through the same mechanism dadbod uses. See
[quickstart.md](../quickstart.md) and `nvim/lua/tests/db_results_smoke.lua`.
