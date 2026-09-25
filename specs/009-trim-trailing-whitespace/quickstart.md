# Quickstart: Validation Guide

**Branch**: `009-trim-trailing-whitespace` | **Date**: 2026-09-25
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Contracts**: [db-indicator](contracts/db-indicator.md), [whitespace-fallback](contracts/whitespace-fallback.md)

How to check that this feature works, from cheapest to most complete. No database server and no
interactive session is required for anything in sections 1–4.

## 1. Prerequisites

| Tool | Why | If missing |
| --- | --- | --- |
| `nvim` 0.10+ | runs every check | stop; the feature targets that version |
| `stylua` | formats the Lua sources | the formatting gate cannot be evaluated |
| `prettier` | the main Markdown formatter | sections 3 and 5 change meaning; read the note in section 5 |

The offline checks run with `-u NORC`, so they load this repository's `lua/` directory but no
plugins. A check that needs a plugin states so explicitly.

## 2. Static validation

```sh
stylua --check nvim
```

Expected: no output, exit code 0. A diff here means the sources were not formatted; fix it before
continuing, because the repository's own gate requires it.

## 3. Offline smoke tests

Run every one of them; the feature adds two to the existing eight.

```sh
nvim --headless -u NORC -c 'lua require("tests.formatter_chains_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
```

Expected: each prints `PASS <case>` per assertion and a final confirmation line, then exits 0. A
failure prints `FAIL`, the got and want values, and exits 1 via `cquit`.

What the two new tests must cover, in the spirit of [data-model.md](data-model.md):

| Test | Cases |
| --- | --- |
| `formatter_chains_smoke` | chain with a project configuration, chain without one, both contain the whitespace fallback, both stop after the first available formatter, a second call returns the same chain |
| `db_context_smoke` | database from a string connection, from both table connection forms, absent connection, `use` detected, last `use` wins, two-part name detected, `use` in a comment ignored, `db..object` in a string ignored, block comment spanning lines ignored, `$`/`#` names intact, non-sql filetype renders nothing, non-connection buffer renders the marker, execution message fires once on conflict and not at all without one |

## 4. Boot with the real configuration

```sh
nvim --headless -u nvim/init.lua '+quitall'
```

Expected: exits 0 with no error output. This loads conform, lualine and the database modules, which
the offline tests deliberately do not.

## 5. Fallback and reporting behavior (requires `prettier`)

The fallback is only observable when the main formatter cannot be resolved, so this section runs the
same save twice: once with the formatter reachable, once with a `PATH` that excludes it. Only Neovim
and a system `printf` stay on that `PATH`.

Prepare a file whose lines carry both kinds of trailing space:

```sh
printf '# ws-check\n\nprose with 3 spaces...   \nprose with a hard break.  \n' > /tmp/ws-check.md
```

### 5.1 Formatter reachable

```sh
nvim --headless -u nvim/init.lua -c 'edit /tmp/ws-check.md' -c 'write' -c 'qa!'
cat -A /tmp/ws-check.md
```

Expected: the three-space line comes back without them, and the line that ended in exactly two
spaces inside the paragraph keeps both spaces (`$` at end of line in `cat -A` output, preceded by
two spaces on the prose line).

### 5.2 Formatter unreachable

```sh
NVIM_BIN="$(dirname "$(command -v nvim)")"
env PATH="$NVIM_BIN:/usr/bin:/bin" nvim --headless -u nvim/init.lua \
  -c 'edit /tmp/ws-check.md' -c 'write' -c 'quitall'
cat -A /tmp/ws-check.md
```

Expected: the accidental trailing spaces are still removed, and the two-space hard break is now
flattened. That flattening is the accepted degradation recorded in
[contracts/whitespace-fallback.md](contracts/whitespace-fallback.md) section 2 rule 3, not a defect.

### 5.3 A file type with nothing available, saved twice

```sh
env PATH="$NVIM_BIN:/usr/bin:/bin" nvim --headless -u nvim/init.lua \
  -c 'lua _G.seen = {}; vim.notify = function(m) table.insert(_G.seen, tostring(m)) end' \
  -c 'lua vim.bo.filetype = "yaml"' -c 'edit /tmp/ws-check.md' -c 'write' -c 'write' \
  -c 'lua print("messages: " .. #_G.seen); for _, m in ipairs(_G.seen) do print(m) end' -c 'qa!'
```

Expected: `messages: 2`. One warning naming the file type per save, on both saves, and no duplicate
for a single save. Repeating the check in a second session must produce the same result.

## 6. Manual scenarios (live database)

These need a reachable Sybase server and an interactive session. They are the only part of the
validation that cannot be automated, and they are the reason the spec keeps the indicator free of
server round trips: the status line must be correct with the server unreachable.

| # | Steps | Expected |
| --- | --- | --- |
| 6.1 | open a `sql` buffer whose connection points at one database | the status line shows that database, no mark |
| 6.2 | add `use <other>` to the buffer | the same database stays visible and a mark naming `<other>` appears |
| 6.3 | execute the buffer from 6.2 | one warning naming both databases, and the query runs unchanged |
| 6.4 | execute a buffer with no switch | no warning, no mark |
| 6.5 | open a `.sql` file with no connection | the "no database" marker is visible |
| 6.6 | open the object explorer, then a result buffer | no indicator in either |
| 6.7 | open a procedure's source from the object browser | the owning database is shown, with no mark |
| 6.8 | change the scope of an open buffer | the indicator follows the new database without reloading |
| 6.9 | disconnect the server, then look at the indicator | unchanged: the indicator is local and keeps working |

## 7. Documentation gate

```sh
rg -n 'DBObjects|qr|db_ui_use_nvim_notify' nvim/README.md
rg -n 'tests\.' nvim/README.md
```

Expected: the behavior table, the validation block, and the customization notes in
`nvim/README.md` mention both features, and the validation block lists the two new smoke tests, so a
clean-machine session can reproduce every check above without reading this file.
