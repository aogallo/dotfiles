# Quickstart: Validating the Database Completion Gate

**Feature**: `013-db-completion-gate` | **Date**: 2026-10-05
**Plan**: [plan.md](plan.md) | **Contract**: [contracts/db-completion-gate.md](contracts/db-completion-gate.md)

Every command is run from the repository root. §1–§3 need no database server and no real client
binary — the client is stubbed, following `nvim/lua/tests/sybase_objects_smoke.lua`. §5 is the only
manual section and it is optional; §1–§4 are what the PR must show.

## 1. The gate holds: zero client invocations while typing

This is the requirement the whole feature exists for (FR-001, SC-001, SC-002, SC-011). The new
`nvim/lua/tests/db_completion_smoke.lua` replaces `db#systemlist` with a counting stub — the same
seam every Sybase client call goes through — and then drives a typing burst while the connection is
unusable.

```bash
nvim --headless -u NORC -c 'lua require("tests.db_completion_smoke")' -c 'qa!'
```

The test asserts, in order:

| Assertion | What it proves |
|---|---|
| `M.enabled() == false` for `undetermined`, `warming` and `unusable` | the gate's truth table, [contract §2](contracts/db-completion-gate.md) |
| `M.enabled() == false` in a fast event | the gate never reaches buffer/window state (R-0011) |
| a failed determination issues **exactly one** stub invocation, total | FR-013, FR-014, invariant I-4 |
| after the failure, 50 simulated keystrokes add **zero** further invocations | FR-001, SC-002 — the reported freeze, reproduced and gone |
| a fresh connection's failure does not close the gate for a second, `usable` connection | FR-005, invariant I-9 |
| toggling twice restores the starting state and leaves connection states untouched | FR-011, I-8 |
| every generated notice is free of the connection key | FR-029, invariant I-6 |
| buffer text, `filetype` and `b:db` are byte-identical afterwards | FR-020, FR-033, invariant I-7 |

To watch the counter itself, run the same file with tracing on:

```bash
nvim --headless -u NORC -c 'lua vim.g.gate_trace = true' \
  -c 'lua require("tests.db_completion_smoke")' -c 'qa!'
```

Expected: one line per attempt, then silence. **Any invocation logged after a failure is a
regression** — it means a path from the suggestion layer to `db#connect` reopened.

## 2. Behavior on a healthy connection is unchanged

The risk in this feature is not failing to fix the freeze; it is changing what suggestions appear.
SC-010 forbids that, so the test must compare against the unmodified provider rather than against a
recorded snapshot.

```bash
nvim --headless -u NORC -c 'lua require("tests.db_completion_gate_healthy_smoke")' -c 'qa!'
```

It runs the same buffer twice — once with the gate installed and once with it removed from the
provider options — and asserts the suggestion lists are identical for a seeded cache. This is what
"byte-identical" means in practice, and it is why D-0001 gates the provider's `enabled` option
rather than substituting a replacement provider (R-0012, R-0022).

## 3. Recovery and the toggle

```bash
nvim --headless -u NORC -c 'lua require("tests.db_completion_toggle_smoke")' -c 'qa!'
```

| Case | Expectation |
|---|---|
| `:DBCompletionToggle` twice | state restored; `changeCount == 2`; two notices (FR-008, I-8) |
| `:DBCompletionToggle` with a `usable` connection | gate closes; suggestion content unchanged when reopened (FR-005) |
| `:DBCompletionRefresh` on an `unusable` connection | one new attempt; on success → `usable`, gate opens (FR-017, FR-018) |
| `:DBCompletionRefresh` on a still-dead connection | state stays `unusable`; at most one attempt (FR-019) |
| `:DBCompletionRefresh` with no bound connection | one notice; zero attempts |
| `DBExecutePre` on an `unusable` connection | one re-determination; its `db#connect` is the verdict (R-0024) |
| keymap `<leader>qc` | label reads `database: DB completion (on)` / `(off)` after each change (FR-009, R-0031) |

## 4. Regression: nothing else moved

```bash
# 1. every existing offline suite
for t in sybase_adapter sybase_objects db_connections db_jump \
         db_objects_save db_objects_scope db_results keymap_groups \
         buffer_visibility formatter_chains db_context; do
  nvim --headless -u NORC -c "lua require(\"tests.${t}_smoke\")" -c 'qa!' || echo "FAIL: ${t}"
done

# 2. suites that need the real configuration
nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'

# 3. formatting and a clean startup
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
```

A new gate must not change any existing suite's result, and the startup probe in step 3 must print
no error — in particular nothing about `vim_dadbod_completion` or a duplicated command.

## 5. Manual check with a real database (optional)

Only needed to confirm the human-visible behavior; §1–§4 are the gating evidence.

```vim
" healthy database
:DBCompletionToggle   " notice: Database completion enabled
                      " <leader>qc label now reads (on)
" open a query buffer with :DBQuery → suggestions appear as before (SC-010)

" unreachable database — the reported symptom
:DBCompletionRefresh  " one attempt, one notice naming the database
                      " gate closed: type freely, no freeze, no redraw,
                      " no '[dadbod completion] Connecting to db…' per keystroke (SC-011)
:DBCompletionRefresh  " at most one further attempt; still closed
```

Then, for the recovery path: bring the database back, run a query in the buffer, and confirm the
gate reopens on its own (FR-018) — or `:DBCompletionRefresh` for an explicit re-attempt (FR-017).

## 6. Troubleshooting

| Symptom | Most likely cause | Where to look |
|---|---|---|
| Freeze on the first keystroke in a `.sql` buffer is still there | the gate is being consulted but the connection is `usable` while the server is unreachable — i.e. the buffer reused a stale `usable` verdict | `Ledger[connection].state`; check whether `b:db` differs between buffers (R-0007, [data-model §2](data-model.md)) |
| No suggestions at all, with a working database | the state is stuck in `warming` — a determination errored outside `db#connect` and never resolved the entry | `Determination.inFlight`; `pcall` around the pre-warm in `M.determine` |
| `[dadbod completion] Connecting to db…` still repeats per keystroke | the gate is open, so the provider is running unguarded | `M.enabled()` truth table, [contract §2](contracts/db-completion-gate.md) |
| `:DBCompletionToggle` does nothing visible | the notice is suppressed by the developer's Snacks config | confirm the command ran: `:DBCompletionToggle` returns to the prior state |
| Notifications show a `sybase://…` URL | a message was composed from the connection key instead of `databaseName` | invariant I-6; the assertion in §1 catches this |
| Everything fails only in headless mode | a gate call reached a Vim API from a fast event | R-0011; `M.enabled()` must call nothing but table lookups |