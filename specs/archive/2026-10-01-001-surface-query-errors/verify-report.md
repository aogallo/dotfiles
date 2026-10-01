# Verify Report: Query Errors Are Always Surfaced

## Verification Report

**Change**: 012-surface-query-errors
**Version**: N/A
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 29 |
| Tasks complete | 28 (T001–T027 and T029 `[X]` in `tasks.md`) |
| Intentionally pending | T028 — manual verification on Windows by the developer (FR-028). No Windows runner exists in validation and the change introduces no platform branch, so this is a behavioral confirmation on the developer's machine, not a portability fix |
| Live-server acceptance | Manual-only (no database servers in validation): an invalid query against a real ASE connection must show the server's own complaint (`incorrect syntax near the keyword 'else'`), and a valid zero-row query must not warn |

### Archive Closure

- User approval: the user answered `Commit + PR y cerrar spec 012` on 2026-10-01 to closing and
  archiving `012-surface-query-errors` in this change (PR for issue #98).
- Archived path: `specs/archive/2026-10-01-001-surface-query-errors/`.
- Active path status: `specs/012-surface-query-errors/` no longer exists on the branch after the
  archive.
- Task closure: T001–T027 and T029 `[X]` (28/29); T028 remains `[ ]` pending the developer's
  Windows pass.
- Spec status: `Closed (archived 2026-10-01; see verify-report.md)`.
- Feature pointer: `.specify/feature.json` set to `{"feature_directory":""}` (no active feature).
- Internal references updated to the archived paths (`plan.md`, `tasks.md`, and the two smoke tests
  that cite the spec from their comments).

### FR Compliance

- **FR-001–FR-007, FR-011–FR-014, FR-025–FR-027** (US1 — surface the server's complaint):
  `db_results.lua` classifies the completed `.dbout` response at `User */DBExecutePost`, notifies at
  WARN through the existing `notifications` path, keeps **every** `Msg` complaint (FR-004), retains
  partial rows **beside** a complaint (FR-026), treats a zero-row response as success, never a warning
  (FR-007), and keeps `slot.lines` byte-for-byte (FR-005/014/025). Covered by `db_results_smoke.lua`.
- **FR-008–FR-010, FR-012, FR-019–FR-023** (US2+US4 — inspection never blocks or corrupts):
  `db_context.lua`'s `strip_noise()` was rewritten as a single left-to-right column walk (no sparse
  `table.concat`, so no crash and no silent loss; output byte length equals input for every shape,
  including a 30-byte multibyte line), the `*/DBExecutePre` callback is `pcall`-wrapped so an editor
  fault is reported as an editor error while the query still runs (FR-010), and the cross-database
  pattern is unanchored so a reference carrying a trailing comment or a literal is still detected
  (FR-019–FR-023). Covered by `db_context_smoke.lua`.
- **FR-015–FR-018** (US3 — the third check outcome): `confirm_database()` selects the outcome by
  `type(exists)` — String `''` → `indeterminate`, Number `0` → `rejected_absent`, Number `1` →
  `rejected_forbidden` — and every outcome carries a `reason` (FR-016/017); a genuine absence keeps
  its "does not exist" message (FR-018). `db_objects.lua` dispatches `indeterminate` explicitly and
  reports the undetermined state rather than inferring a cause. Covered by `sybase_adapter_smoke.lua`
  (the three **real** types, through a fake client) and `db_objects_scope_smoke.lua`.
- **FR-006, SC-002** (every route): the classifier sits at the single `*/DBExecutePost` point that
  every run route passes through; `db_results_smoke.lua` drives the listener end to end.
- **FR-028–FR-031** (non-functional): no user-specific absolute paths, confined to the Neovim module,
  no new dependency, no credential — `origin_label()` reduces a URL to a basename, so no URL, host,
  or secret is ever rendered (FR-031).
- **FR-032–FR-034** (tests, docs, non-regression): see *Build & Tests Execution*.
- **FR-035**: implemented on branch `012-surface-query-errors`, committed with conventional messages,
  and submitted through a pull request that links issue #98.
- **FR-036**: spec artifacts remain navigable; relative links updated to the archived paths.

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
$ nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
All db_results smoke assertions passed          # classify/notice/dedup/retention
$ nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
All db_context smoke assertions passed          # shape matrix + byte length + abort + editor-fault guard
$ nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
All sybase adapter smoke assertions passed      # confirm_database() three real types via a fake client
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
All db_objects scope smoke assertions passed    # indeterminate dispatch + four existing results
$ for t in sybase_objects db_objects_save db_jump db_connections buffer_visibility; do ...; done
PASS sybase_objects
PASS db_objects_save
PASS db_jump
PASS db_connections
PASS buffer_visibility
$ for t in markdown_whitespace no_formatter_warning formatter_chains keymap_groups (init.lua); do ...; done
PASS markdown_whitespace
PASS no_formatter_warning
PASS formatter_chains
PASS keymap_groups
```

13 suites in total, all green, plus `stylua --check nvim` and the `init.lua` boot check.

### Noteworthy Findings & Limitations

- **T028 is pending by design.** The change has no platform branch; the Windows pass is the
  developer's confirmation that behavior is identical, not a code path under test.
- **The `vim.fn` stub trap.** `vim.fn['name'] = fn` is Lua-side only; a Vimscript caller
  (`s:run_query()` → `db#systemlist()`) does not see it, and an autoload function cannot be
  redefined from the command line (`E746`). `confirm_database()` is therefore exercised end to end by
  pointing `g:db_sybase_client` at a tiny executable that drains stdin and prints the canned probe.
- **`db#systemlist` hides hard failures.** It returns `[]` when the process exits non-zero
  (`db.vim:275-289`), so classification must read the completed `.dbout` **file**, which
  `M.setup_diagnostics()` does.
- **The visible notification is a summary.** `notifications.lua` shows only the first line in the
  snack; the full complaint text lives in the notification history, and the complete server response
  always remains in the query's result buffer.
- **`'' == 0` and `'' ==# 0` are both true in Vimscript** (R-0006); `type()` is the only reliable
  discriminator, which is why the fix selects the outcome by `type(exists)`.
