# Data Model: Database Completion Never Blocks Editing

**Feature**: `013-db-completion-gate` | **Date**: 2026-10-05 | **Plan**: [plan.md](plan.md)
**Research**: [research.md](research.md) | **Contract**: [contracts/db-completion-gate.md](contracts/db-completion-gate.md)

No database, no file, no persistence. Every entity below is an in-memory Lua table living for one
Neovim session (FR-011, FR-021). Names use camelCase to match the existing `nvim/lua/config/`
modules (`db_context.lua`, `db_results.lua`, `db_objects.lua`).

## 1. Entities

### 1.1 ConnectionState — the per-connection ledger

The central entity. One entry per connection URL observed this session. This is what makes FR-013
and FR-014 ("one attempt", "no retries") enforceable rather than aspirational: the entry is the
memory that the attempt already happened.

| Field | Type | Meaning |
|---|---|---|
| `connectionKey` | `string` | Internal identity. Never rendered. See §2. |
| `state` | `string` | One of `undetermined`, `warming`, `usable`, `unusable`. See §3. |
| `attempted` | `boolean` | `true` once a determination has been completed (success or failure). Enforces FR-013/FR-014. |
| `noticeShown` | `boolean` | `true` once the automatic-disabling notice was emitted, so it is emitted exactly once per connection per session (FR-008). |
| `lastTrigger` | `string`\|`nil` | Which trigger performed the last determination. Diagnostic only; used in the offline test to assert trigger coverage. |
| `databaseName` | `string` | Derived once from `db_context.url_database(connectionKey)`. The **only** form of this entity's connection that may appear in any user-facing string (FR-029). |

Not stored here, deliberately: the URL as a display value, the last client exit status, error text,
or any client argv. A failure is recorded as the state transition plus a notice, and nothing more
— there is no error channel to read back and no retry that could consume it.

### 1.2 BufferBinding — which connection a buffer belongs to

A cache so the gate never has to touch a Vim API (D-0002, R-0011).

| Field | Type | Meaning |
|---|---|---|
| `bufnr` | `integer` | Key. |
| `connectionKey` | `string`\|`nil` | `nil` for a SQL buffer with no connection (the FR-003 / R-0005 case). |
| `kind` | `string` | `"query"` or `"dbui"` — a DBUI buffer's connection comes from `b:dbui_db_key_name`, not `b:db` (`vim_dadbod_completion.vim:380-393`). |

Populated by `FileType`/`BufEnter` autocmds, read by the gate. A buffer with `connectionKey == nil`
is never allowed to reach the provider, which removes the wasted `fetch()` loop of R-0005 as a side
effect.

### 1.3 GateState — the global switch

| Field | Type | Meaning |
|---|---|---|
| `enabled` | `boolean` | The developer-facing switch. Initialized `true` (FR-011, D-0006). |
| `changeCount` | `integer` | Incremented on every change. Asserted by the offline test to prove one notice per change (FR-008). |

### 1.4 Determination — one in-flight or completed attempt

| Field | Type | Meaning |
|---|---|---|
| `inFlight` | `boolean` | Guards against re-entrant determinations: two autocmds firing for one buffer must not produce two attempts. |
| `trigger` | `string` | `"buffer_open"`, `"refresh_command"`, or `"query_pre"` (R-0024). |
| `startedAtTick` | `integer` | `vim.loop.hrtime()` at start. Lets the module notice a determination wedged in a client call instead of blocking later triggers forever (FR-014). |

A `Determination` is transient: it is cleared when the attempt completes, whichever way.

## 2. Identity

`connectionKey` is the raw `b:db` string, exactly as this repository writes it.

Justification for not canonicalizing it: the module must not contain a second parser for connection
URLs, because a second parser is a second thing that can disagree with
`db#connect(db#resolve(db))` — the thing it is trying to predict. Instead the key exploits an
invariant of *this* repository: `b:db` is assigned from exactly one place
(`nvim/lua/config/db_query_buffer.lua:230`), so every buffer pointing at the same connection carries
the identical string, and no parsing is needed for grouping to be correct. R-0007 records the
upstream side of this: `db#resolve` canonicalizes at the point of use, downstream of our key, which
does not affect grouping.

Consequence accepted: two buffers whose `b:db` strings differ only in a `#fragment` or query string
would be tracked as two connections. This repository never produces such a pair, and treating them
as distinct is the safe direction — it fails toward attempting rather than toward suppressing.

`connectionKey` is used as a table key and for equality only. It never reaches a notification, a
`which-key` label, or `vim.notify`. Every user-facing reference to a connection uses the entry's
`databaseName` (FR-029, D-0008, R-0030).

## 3. The state machine

The gate's value is a pure function of `(GateState.enabled, BufferBinding.connectionKey,
ConnectionState.state)`. There is no fourth input and no ambient lookup.

```text
                      ┌──────────────────────────────────────────┐
                      │                                          │
   buffer acquires    │                                          │  developer
   a connection       ▼                                          │  toggles the
   (R-0007)      ┌───────────┐                                   │  switch off
     ───────────► │ undetermined│ ◄──────────────────────┐        │
                  └─────┬─────┘                        │        │
                        │ trigger: buffer_open,        │        │
                        │   refresh_command,           │        │
                        │   query_pre (only if         │        │
                        │   state == unusable)         │        │
                        ▼                             │        │
                  ┌───────────┐  attempt in progress  │        │
                  │  warming  │ ──────────────────────┼────────┤
                  └─────┬─────┘                         │        │
        db#connect     │                               │        │
        returns        │                               │        │
        ┌───────────────┴───────────────┐               │        │
        │                               │               │        │
        ▼                               ▼               │        │
  ┌───────────┐                   ┌───────────┐         │        │
  │  usable   │                   │ unusable  │         │        │
  └─────┬─────┘                   └─────┬─────┘         │        │
        │                               │               │        │
        │        connection ceases      │  next trigger  │        │
        │        to exist              │  attempts again │        │
        ▼                               │  (FR-018/019)  │        │
   BufferBinding.connectionKey          ▼               │        │
   set to nil ──────────────────► undetermined ────────┘        │
                                                                │
   gate value:                                                   │
     usable ──────────────────────────────────► OPEN (if switch on)
     undetermined / warming / unusable ──────────► CLOSED
     connectionKey == nil ──────────────────────► CLOSED
                                                                ▼
                                                  switch flip is orthogonal:
                                                  it never resets state,
                                                  only opens/closes the gate
```

### 3.1 Transition rules

| From | Trigger | Guard | To | Side effect |
|---|---|---|---|---|
| — | `setup()` | — | `undetermined` (absent entry) | none; switch initialized `true` |
| `undetermined` | buffer acquires connection | entry absent | `warming` | schedule determination |
| `undetermined` | buffer acquires connection | entry `usable` | `usable` | **no determination** — reuse cached verdict |
| `undetermined` | buffer acquires connection | entry `unusable` | `unusable` | **no determination** — `attempted` is `true` (FR-013) |
| `warming` | any trigger | `inFlight` | `warming` | ignored; prevents a second attempt |
| `warming` | `db#connect` returns | — | `usable` | `attempted = true`; gate may open |
| `warming` | `db#connect` throws | — | `unusable` | `attempted = true`; `noticeShown = true`; one notice (FR-008, FR-012) |
| `usable` | buffer's connection becomes `nil` | — | entry retained | `BufferBinding.connectionKey = nil`; gate closes on §4 |
| `usable` | connection string differs for the buffer | — | new entry `undetermined` | old entry retained; per-connection independence (FR-005) |
| `unusable` | `:DBCompletionRefresh` | entry exists | `warming` | explicit re-attempt (FR-017) |
| `unusable` | `DBExecutePre` for that connection | — | `warming` | deliberate re-attempt; its `db#connect` is the verdict (R-0024, D-0007) |
| any | switch toggle | — | state unchanged | one notice + label re-registration (FR-008, FR-009) |

Note the third and fourth rows: a connection that has already been judged usable or unusable is
**never re-probed merely because a buffer was opened**. That is what makes "at most one attempt per
connection" true regardless of how many buffers or keystrokes occur (FR-013).

### 3.2 The state that makes the guarantee hold

`warming` exists solely so the gate is closed while a determination is outstanding. Without it, a
buffer that acquires `b:db` at `FileType` would be `undetermined`, and if `undetermined` were
treated as "not known to be bad" the gate would open and the very next keystroke would reproduce
R-0003. Treating `undetermined` as **not usable** — FR-016 — is the entire reason the loop cannot
recur, and it is why D-0005 makes the gate a conjunction rather than a lookup.

## 4. Gate evaluation

```text
gate(ctx):
  if fast_event:            return false        -- R-0011
  if not GateState.enabled: return false        -- FR-002, FR-005
  if Binding[key].connectionKey == nil: return false   -- FR-003
  return Ledger[connectionKey].state == "usable"        -- FR-001, FR-004, FR-016
```

`fast_event` is checked first and unconditionally returns `false`. This matches the engine's own
precedence at `blink.cmp …/provider/init.lua:52-53` and means the gate is safe even if a future
call site reaches it from a context where the buffer→URL cache is not guaranteed current: the
worst case is a closed gate, never a connect.

The function performs one table lookup and no Vim API call (D-0002). This matters for performance
independently of safety — it is evaluated per keystroke in three places
(`sources/lib/init.lua:101`, `sources/lib/tree.lua:29`, and the trigger-character path), so it must
be O(1) and allocation-free.

## 5. Invariants

Asserted by the offline test in [quickstart.md](quickstart.md) §3:

| # | Invariant | Source |
|---|---|---|
| I-1 | The gate returns `true` at most when the connection state is `usable` | FR-001, FR-004 |
| I-2 | From the gate returning `true`, a stubbed client invocation is unreachable | FR-001, SC-002 |
| I-3 | No `db#connect` call is ever made from the gate function | R-0011 |
| I-4 | A failed determination performs exactly one client invocation, total, for that connection | FR-013, FR-014 |
| I-5 | Exactly one notice is emitted per automatic disabling, per connection per session | FR-008 |
| I-6 | No user-facing string produced by the module contains the connection key | FR-029 |
| I-7 | Buffer text, filetype and `b:db` are unmodified by the module | FR-020, FR-033 |
| I-8 | Toggling the switch twice restores the starting state, with no change to any connection state | FR-011, D-0006 |
| I-9 | Two different connection keys are gated independently | FR-005 |
| I-10 | The module writes no file | FR-021 |