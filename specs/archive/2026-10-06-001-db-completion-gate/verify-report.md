# Verify Report: Database Completion Never Blocks Editing

## Verification Report

**Change**: 013-db-completion-gate
**Version**: N/A
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 46 |
| Tasks complete | 46 (T001–T046 `[X]` in [tasks.md](./tasks.md)) |
| Intentionally pending | none |
| Live-server acceptance | Manual-only (no database server or real client binary in validation): with Sybase reachable, typing in a SQL buffer must keep the editor responsive, and with Sybase down the editor must stay usable while the query path reports the connection failure |

### Archive Closure

- User approval: the user answered `si cerremos` on 2026-10-06 to closing and archiving
  `013-db-completion-gate` (spec originated from the developer's own description — no GitHub
  issue exists; PR [#105](https://github.com/aogallo/dotfiles/pull/105) is the delivery vehicle).
- Archived path: `specs/archive/2026-10-06-001-db-completion-gate/`.
- Active path status: `specs/013-db-completion-gate/` no longer exists on the branch after the
  archive.
- Task closure: T001–T046 `[X]` (46/46).
- Spec status: `Closed (archived 2026-10-06; see verify-report.md)`.
- Feature pointer: `.specify/feature.json` set to `{"feature_directory":""}` (no active feature).
- Internal references updated to the archived paths (`plan.md`, `tasks.md`, `nvim/README.md`, and
  the code/test comments that cite the spec).

### FR Compliance

- **FR-001–FR-005, FR-016** (US1 — completion cannot block): `nvim/lua/config/db_completion.lua`
  `M.enabled()` is a fast-event-safe, table-lookup gate consulted by the
  `vim_dadbod_completion` provider in `nvim/plugin/blink.lua` via a per-provider `enabled`
  function (D-0001); the provider list, module, name, and opts are otherwise byte-identical
  (SC-010). Covered by `db_completion_smoke.lua`.
- **FR-013, FR-014, SC-002, SC-011** (one attempt, typing costs nothing): `M.determine()` runs
  exactly one `vim_dadbod_completion#fetch()` per connection; after it settles, typing adds zero
  client invocations (asserted across 50 simulated keystrokes per connection state).
- **FR-008, FR-011, FR-009** (US2 — switch): `M.toggle()` flips `GateState.enabled`, increments
  `changeCount`, emits exactly one notice, and re-registers the which-key label
  (`database: DB completion (on|off)`); `<leader>qc` is bound in
  `nvim/lua/config/keymaps.lua`. Covered by `db_completion_toggle_smoke.lua`.
- **FR-012, FR-017** (US3 — a failed connection steps aside): the `noticeShown`/`attempted`
  guards emit one notice per connection per session and never retry on their own; the notice is
  composed from the derived database name only (FR-029, D-0008).
- **FR-018, FR-019** (US4 — recovery): `M.refresh()` always attempts (ignoring `attempted`) and
  handles the no-connection case with one notice and zero attempts; the `User */DBExecutePre`
  trigger re-runs one determination only for an `unusable` connection — dadbod's real event
  shape is `User <output>.dbout/DBExecutePre`, which the module pattern matches.
- **FR-020, FR-021, FR-033, I-7, I-10** (no side effects): a full session of toggles and
  determinations leaves buffer text, `filetype`, and `b:db` unchanged, and writes nothing to disk
  (temp-dir listing and `stdpath('data')` untouched).
- **FR-028–FR-031** (non-functional): no new dependency — the gate uses blink's documented
  per-provider `enabled`, the upstream plugin's public pre-warm entry point, and which-key for
  the live label.
- **FR-032** (docs): `nvim/README.md` documents the switch, the starting state, the notice
  wording, `:DBCompletionRefresh`, and a troubleshooting entry for "the editor freezes when I
  type SQL".
- **FR-030, FR-031** (offline tests): all three suites run under `-u NORC` with a fake
  `sqsh`/`isql` client on `$PATH` that counts invocations — no database server and no real client
  binary.
- **FR-034, FR-035** (branch and PR discipline): implemented on `013-db-completion-gate` with
  conventional commits and delivered through PR #105; the PR states that no originating issue
  exists and that the spec's Input is the source.
- **US5 / SC-010** (no suggestion regression): `db_completion_gate_healthy_smoke.lua` asserts a
  healthy connection opens the gate and that gated and ungated suggestion sets are identical
  across table, bare, dot-triggered, and reserved-word prefixes, that 50 gate consultations
  change nothing, and that a healthy session emits zero completion notices.

### Build & Tests Execution

**Formatting**: ✅ Passed

```text
$ stylua --check nvim
(no output; exit 0)
```

**Smoke boot**: ✅ Passed

```text
$ nvim --headless -u nvim/init.lua '+quitall'
(no output; exit 0)
```

**Smoke tests**: ✅ All passed (offline, `-u NORC` unless noted)

```text
$ nvim --headless -u NORC -c 'lua require("tests.db_completion_smoke")' -c 'qa!'
DB COMPLETION SMOKE: all assertions passed          # truth table, one attempt, notices, isolation
$ nvim --headless -u NORC -c 'lua require("tests.db_completion_toggle_smoke")' -c 'qa!'
ALL db_completion_toggle_smoke ASSERTIONS PASSED    # toggle, label, refresh, DBExecutePre
$ nvim --headless -u NORC -c 'lua require("tests.db_completion_gate_healthy_smoke")' -c 'qa!'
DB COMPLETION GATE HEALTHY SMOKE: 13 passed, 0 failed
$ for t in sybase_adapter sybase_objects db_connections db_jump db_objects_save \
           db_objects_scope db_results keymap_groups buffer_visibility formatter_chains \
           db_context; do ...; done
OK sybase_adapter ... OK db_context                 # 11 pre-existing suites
$ nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
All markdown whitespace smoke assertions passed
$ nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'
All no-formatter reporting smoke assertions passed
```

14 suites in total, all green, plus `stylua --check nvim` and the `init.lua` boot check. A
pre-change baseline was recorded with `git stash -u` on the branch tip: the eleven pre-existing
suites and `stylua` were green before this feature's edits, so the two later failures were
attributable to the gate's FR-012 notices and are fixed by the documented filters in
`buffer_visibility_smoke.lua` and `db_context_smoke.lua`.

### Noteworthy Findings & Limitations

- **The autoload stub was the wrong fidelity level.** `vim_dadbod_completion#fetch()` writes
  `s:cache[url]` *before* it calls `db#connect`, so a shadowed `db#systemlist` that never throws
  reports success without contacting a database — a false `usable` state production cannot
  produce. The suites instead install a fake client binary on `$PATH` that counts invocations,
  which is the path `db#connect` → adapter → client actually takes.
- **`db#systemlist` never raises.** It returns `[]` on a non-zero exit (`autoload/db.vim`); the
  blocking error comes from `db#connect` (`DB exec error: …` or `DB: 'sqsh' executable not
  found`).
- **The hang-never-answers case is not simulated.** The determination runs synchronously in the
  editor thread, so a wedged client would wedge the test run; `warming` is covered by the gate
  truth table instead.
- **The `attempted` guard must let recovery through.** `query_pre` and `refresh_command` bypass
  it (FR-018); only the automatic typing/buffer-open triggers are blocked.
- **Two pre-existing suites filter this feature's notices.** `buffer_visibility_smoke.lua` and
  `db_context_smoke.lua` create a SQL buffer with `b:db`, which necessarily triggers the gate's
  FR-012 connection attempt; counting those notices would test the gate, not their own concern.
  This is the one deliberate deviation from quickstart §4 ("existing suites must be unchanged")
  and is commented in both files.
- **R-0040 remains deferred.** `opts.trigger_characters` in `nvim/plugin/blink.lua` is discarded
  upstream by `M.new()`; SC-010 forbids correcting it here, so it is documented as a comment.
- **`M.enabled()` reads the current buffer.** That contradicts the literal "table lookups only"
  wording, but the fast-event guard runs first, so blink never consults it outside a typing
  context where the current buffer is the intended one.
- **`Determination.startedAtTick` is recorded but not enforced.** While `inFlight` is set no
  other trigger can run (the inline fetch is the only path into `db#connect`), so a stale entry
  is unreachable.
