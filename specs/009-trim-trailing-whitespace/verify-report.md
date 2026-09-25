# 009 — Verification Report: Trailing Whitespace and Database Context

Spec: `specs/009-trim-trailing-whitespace/`
Branch: `009-trim-trailing-whitespace` · PR: #91 · Issue: #90

## Status

36 of 40 tasks done. The implementation, the documentation, and the static validation are complete.
Four tasks remain, and none of them is code:

| Task | What it needs | Why it is open |
| --- | --- | --- |
| T102 | a machine where Prettier is genuinely absent | this configuration prepends Mason's bin directory back onto `PATH`, so the documented recipe cannot produce that state here |
| T101 | recorded manual scenarios | **recorded below, 12/12** |
| T103 | a confirmed unreachable server | **confirmed below, host does not resolve** |
| T104 | this report | **written** |

The spec is not closed: T102 is still open, so the report records a partial acceptance on purpose.

## Gate

```
TOTAL 268 pass / 0 fail
stylua: clean
boot:   clean
```

Twelve smokes. Ten with `-u NORC` (no plugin state), two with the real configuration, because they
depend on Prettier, Stylua, and a real save:

| Smoke | Configuration | Assertions |
| --- | --- | --- |
| `db_objects_scope_smoke.lua` | offline | 41 |
| `db_context_smoke.lua` | offline | 72 |
| `sybase_objects_smoke.lua` | offline | 28 |
| `formatter_chains_smoke.lua` | offline | 27 |
| `db_objects_save_smoke.lua` | offline | 26 |
| `db_results_smoke.lua` | offline | 18 |
| `sybase_adapter_smoke.lua` | offline | 11 |
| `db_jump_smoke.lua` | offline | 7 |
| `keymap_groups_smoke.lua` | offline | 6 |
| `db_connections_smoke.lua` | offline | 4 |
| `markdown_whitespace_smoke.lua` | real | 18 |
| `no_formatter_warning_smoke.lua` | real | 10 |

## Manual scenarios (quickstart §6) — T101, T103

Run against the real configuration, driving `lualine.statusline()` so the rendered string is what
was checked, and `nvim_exec_autocmds('User', { pattern = '*/DBExecutePre' })` for the execution
path. No server was involved, which is the point of 6.9.

| # | Expected | Got | |
| --- | --- | --- | --- |
| 6.1 | `DB ventas` | `DB ventas` | pass |
| 6.2 | `DB ventas ⚠ base-a` | `DB ventas ⚠ base-a` | pass |
| 6.3 | one warning, buffer unchanged | 1 warning, lines identical | pass |
| 6.3 | the warning names both databases | `…on "ventas"… switches to "base-a"…` | pass |
| 6.4 | no warning, no mark | 0 warnings | pass |
| 6.5 | the no-database marker | `DB —` | pass |
| 6.6 | nothing in the drawer | `''` | pass |
| 6.6 | nothing in a result buffer | `''` | pass |
| 6.7 | owning database of a procedure source | `DB base-a` | pass |
| 6.8 | the indicator follows a scope change | `DB base-a` | pass |
| 6.9 | unchanged with the server unreachable | `DB ventas` | pass |
| 6.9 | no round trip | 0.085 ms per render, host does not resolve | pass |

12 scenarios, 0 failures.

### 6.8 found a real bug

The first run of 6.8 answered `DB base-a ⚠ base-a`. The buffer still read `use base-a` while the
scope had just changed the connection to `base-a`, so the mark was reporting a conflict that no
longer existed — on exactly the buffer shape a scope change produces.

A switch is now a conflict only when it names a database other than the one the connection points
at, decided on the owner half (`ventas..t1` on a `ventas` connection stays put) and folded for case
while the label still shows both names as written. Fixed in `853c134`, with five assertions added
for the same-name, folded-case, same-owner, and post-scope-change cases.

## T102 — the accepted degradation, not reproducible here

The check wants Prettier genuinely absent, to confirm a Markdown save is still trimmed and its hard
breaks are flattened as documented. Two things stand in the way on this machine:

1. `nvim/plugin/conform.lua` (or the pack setup) prepends `$HOME/.local/share/nvim/mason/bin` to
   `PATH` at startup, so exporting a reduced `PATH` before launching Neovim does not remove
   Prettier — the configuration puts it back.
2. Mason's own tool availability is re-evaluated at runtime, not pinned at startup.

The closest honest substitute already runs in the suite: `no_formatter_warning_smoke.lua` saves a
`sh` buffer, whose filetype really resolves to zero formatters on this machine, twice in a row, and
asserts two reported failures with no silent save and no duplicate notice. That exercises the
fallback path and the reporting; what it does not exercise is Markdown with Prettier specifically
missing.

To close T102, either run it on a machine without Prettier installed, or move Mason's Prettier
shim aside for one session — the latter is a change to the user's toolchain, so it was not done
unilaterally.

## What was corrected against what was written

- **FR-003 and FR-006** described the fallback as preserving bytes exactly. Measured against
  Prettier and Stylua, a whitespace-only line between blank lines is collapsed and a run of spaces
  is reindented, so both now describe the main formatter's real behavior and leave the exact
  guarantee to the fallback, which is where it holds.
- The quickstart's "hide Prettier from `PATH`" recipe was replaced with a file type that really
  resolves to nothing, for the reasons above.
- The counts in the PR body were recorded at 263; the suite is now 268 after the 6.8 fix.
