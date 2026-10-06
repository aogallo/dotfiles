# Contract: Database Completion Gate

**Feature**: `013-db-completion-gate` | **Date**: 2026-10-05
**Model**: [../data-model.md](../data-model.md) | **Research**: [../research.md](../research.md)

The observable surface of `nvim/lua/config/db_completion.lua` plus the three things the developer can
see or press. Everything else in the module is private. Nothing here is versioned or negotiated;
these are the guarantees the rest of the configuration — and the offline test — may rely on.

---

## 1. Module API

Called only by `nvim/plugin/blink.lua` and `nvim/plugin/database.lua`.

### `M.setup() -> nil`

Registers the buffer→connection autocmds, the `:DBCompletionToggle` command and the
`DBExecutePre` listener. Idempotent: guarded exactly as `db_context.setup()` is
(`nvim/lua/config/db_context.lua:349`), so re-sourcing `plugin/database.lua` produces no duplicate
commands, autocmds or listeners. Calling it twice is the same as calling it once.

### `M.enabled() -> boolean`

The gate. Called by `blink.cmp` on every completion request through the provider's `enabled`
option (R-0010).

- **Must** be a pure function of the module's own Lua tables.
- **Must not** call any Vim or LuaJIT API that touches buffer or window state, because it is
  evaluated in fast-event contexts where the engine has documented that such calls fail (R-0011).
- **Must not** perform I/O, spawn a process, or call into `vim-dadbod` under any circumstance. If
  this function can block, the defect is unfixed.
- **Must not** itself emit a notice. It runs many times per second; notices are emitted only by the
  determination that follows an actual attempt.

Guarantee: `M.enabled() == true` implies the current buffer's connection is `usable`. This is the
whole contract; everything else is implementation (FR-001, FR-002).

### `M.determine(connection, trigger) -> nil`

Runs at most one determination for `connection`, guarded by `Determination.inFlight` and by
`Ledger[connection].attempted`. Invokes the upstream pre-warm
(`vim_dadbod_completion#fetch(bufnr)`) and records the outcome. `trigger` ∈ `"buffer_open"`,
`"refresh_command"`, `"query_pre"`; it is recorded for diagnostics and asserted by the test.

Callers: `buffer_open`, `:DBCompletionRefresh`, `DBExecutePre` (R-0024). **Not** reachable from
`M.enabled()` or from the provider.

### `M.refresh() -> nil`

Developer-facing re-attempt. `vim.api.nvim_cmd({ 'DBCompletionRefresh' }, {})`. Always attempts,
even for a connection whose `attempted` is already `true` — this is the explicit override of
FR-013's default, which is what FR-017 requires.

---

## 2. Gate truth table

The complete specification of `M.enabled()`. "Connection" is the current buffer's
`BufferBinding.connectionKey`; `—` means none.

| Switch | Connection | State | `M.enabled()` | Provider consulted? |
|---|---|---|---|---|
| `false` | — | — | `false` | no |
| `true` | `nil` (FR-003) | — | `false` | no |
| `true` | set | `undetermined` | `false` | no |
| `true` | set | `warming` | `false` | no |
| `true` | set | `unusable` | `false` | no |
| `true` | set | `usable` | `true` | yes — behavior identical to today (SC-010) |
| any | — | — | `false` | no — `vim.in_fast_event()`, R-0011 |

**Closed means closed.** In every `false` row, no client invocation, no network round trip, and no
buffer mutation occurs — not as a consequence, but because the guarded code path is never entered
(SC-002, SC-011).

**Global and per-connection independence.** The switch closes the gate for every connection at once
(FR-005); one connection being `unusable` does not close the gate for a different one.

---

## 3. Editor-visible surfaces

### 3.1 `:DBCompletionToggle`

Toggles `GateState.enabled`. Emits exactly one notice per invocation and re-registers the keymap
label. Does not alter any connection state, does not cancel an in-flight determination, and does not
trigger a determination (D-0006).

| Aspect | Guarantee |
|---|---|
| Starting state | enabled (FR-011) |
| Persistence | none — session only, never written (FR-011, FR-021) |
| Idempotence of repetition | two invocations restore the starting state (I-8) |
| Notice count | exactly one per invocation (FR-008) |
| Message content | "Database completion enabled" / "Database completion disabled" — no URL (FR-029) |

### 3.2 `:DBCompletionRefresh`

Re-runs one determination for the current buffer's connection. If the buffer has no connection, the
notice says so and nothing is attempted. On success the connection becomes `usable` and the gate may
open; on failure it stays `unusable`, at most one attempt is made, and the database's own failure is
reported once (FR-016, FR-017, FR-019).

### 3.3 `<leader>qc`

Toggles, identical to §3.1. Placed in the existing `database` which-key group
(`nvim/plugin/editor.lua:185`) next to the other `<leader>q…` bindings
(`nvim/lua/config/keymaps.lua:36-40`).

The `which-key` label **tracks the live state**: after toggling, the registered description reads
`database: DB completion (on)` or `(off)`. This requires re-registering the binding on each change
rather than setting it once (R-0031, FR-009).

### 3.4 Notices

All notices go through `require('notifications').notify(msg, vim.log.levels.WARN, { source = 'DB' })`
(`nvim/lua/notifications.lua:129`, matching `nvim/lua/config/db_context.lua:372`).

| Event | Notice | Count |
|---|---|---|
| Switch toggled | enabled/disabled | one per toggle |
| Determination failed | schema completion disabled for `<databaseName>`; use `:DBCompletionRefresh` to retry | **one per connection per session** (FR-012, FR-008) |
| Determination failed again (`:DBCompletionRefresh`) | the database's failure, reported | one per explicit attempt (FR-019) |
| `:DBCompletionRefresh` with no connection | no connection bound to this buffer | one per invocation |
| Turned on, everything healthy | none | zero — silence is the success signal |

Every message names a **database**, never a URL, because a `sybase://` URL can carry a password
(R-0030, D-0008, FR-029). The contract test asserts this by scanning generated strings for the
connection key (invariant I-6).

---

## 4. What the gate must not do

Explicit negative guarantees, so a future change cannot quietly reintroduce the defect:

1. **No timeout, no retry, no backoff on the typing path.** The gate is closed or open; there is no
   middle state in which the provider runs and the module waits.
2. **No monkey-patching `vim_dadbod_completion#omni` or any other autoload function.** The upstream
   plugin file stays unmodified (FR-027).
3. **No reimplementation of the provider.** The gate reuses the plugin's own cache-fill path
   (D-0003), so suggestion behavior cannot drift.
4. **No second connection-URL parser.** §2 of [../data-model.md](../data-model.md) explains why:
   a second parser is a second thing that can disagree with `db#resolve`.
5. **No writes.** No settings file, no cache file, no state persistence of any kind (FR-020,
   FR-021, FR-033).
6. **No effect on other sources.** The switch is scoped to this provider; `lsp`, `path`, `snippets`
   and `buffer` in `nvim/plugin/blink.lua:107` are untouched (FR-005).
7. **No new dependency.** `blink.cmp`, `vim-dadbod-completion`, `vim-dadbod` and `which-key` are
   all already declared (FR-028).