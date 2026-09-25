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
# real configuration, see section 5
nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'
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
| `db_context_smoke` | database from a string connection, from both table connection forms, absent connection, and agreement with the adapter's own derivation for every URL shape; then, once US4 lands: `use` detected, last `use` wins, two-part name detected, `use` in a comment ignored, `db..object` in a string ignored, block comment spanning lines ignored, `$`/`#` names intact, non-sql filetype renders nothing, non-connection buffer renders the marker, execution message fires once on conflict and not at all without one |

## 4. Boot with the real configuration

```sh
nvim --headless -u nvim/init.lua '+quitall'
```

Expected: exits 0 with no error output. This loads conform, lualine and the database modules, which
the offline tests deliberately do not.

## 5. Fallback and reporting behavior (requires the real configuration)

Two checks need the real configuration, because the claim is about what a real save does. Both are
run the same way, and both skip with exit 0 when the formatting toolchain is not loadable:

```sh
nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'
```

### 5.1 Markdown rules, from the formatter itself

`markdown_whitespace_smoke` writes a canned file and asserts the rules in
[contracts/whitespace-fallback.md](contracts/whitespace-fallback.md) section 2 against what the
formatter actually produced.

Expected: a two-space break followed by more text is preserved, three spaces become two, a two-space
break on the last line of a paragraph is removed, and heading and fenced-block spaces are removed.

**Correction found while running this**: FR-003 and FR-006 were written as guarantees about "the
cleanup", and the first run showed they only hold for the whitespace-only fallback. With the main
formatter, a line of only whitespace between two blank lines is collapsed, and a source formatter
reindents code. Both requirements now say so, and the check asserts the two cases separately.

### 5.2 A file type with nothing available, saved repeatedly

`no_formatter_warning_smoke` uses `sh`, which maps to `shfmt` — a binary this configuration does not
install, so the empty formatter list is genuine rather than staged.

Expected: the first save reports one warning naming `sh`, a second save in quick succession raises
that entry's repeat count to 2, a third save after the aggregation window is a new message, and
neither the toolchain's own notice nor a message naming the file appears.

**Correction found while running this**: an earlier draft of this section shortened `PATH` to make
the main formatter unreachable. That cannot work here — the configuration prepends the formatter
directory to `PATH` during startup — and the toolchain also memoizes which formatters are available,
so `PATH` cannot be changed inside a live session either. The recipe would have passed without
exercising anything.

### 5.3 The accepted degradation, by hand

Only reachable on a machine where the main formatter is genuinely missing, which is why it is not a
check:

```sh
printf '# ws-check\n\nprose with 3 spaces...   \nprose with a hard break.  \n' > /tmp/ws-check.md
nvim --headless -u nvim/init.lua -c 'edit /tmp/ws-check.md' -c 'write' -c 'qa!'
sed -n 'l' /tmp/ws-check.md
```

Expected with the formatter present: the three-space line keeps exactly two spaces and the
paragraph's last line loses its two. Expected without it: both lose every trailing space, which is
the flattening recorded in the contract, section 2 rule 3. `sed -n 'l'` rather than `cat -A`, which
macOS does not have.

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
