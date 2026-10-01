# Quickstart: Surface Query Errors

**Feature**: [`012-surface-query-errors`](spec.md) · **Date**: 2026-10-01 ·
**Issue**: [#98](https://github.com/aogallo/dotfiles/issues/98)

Two parts: how to reproduce the reported defects before the fix, and how to
validate the fix after it. Everything here runs **offline** — no database server,
no client binary, no credentials. That is deliberate: every defect in this feature
is local editor state or local text processing.

## Prerequisites

- Neovim 0.12.1 on `PATH` (`nvim --version`)
- The Sybase adapter and vim-dadbod in the active config (`~/.local/share/nvim/site/pack/core/opt/vim-dadbod`)
- `stylua` on `PATH` for the formatting gate

## Part 1 — Reproduce the defects

### 1.1 The crash (FR-008, R-0001)

A buffer line whose first comment marker or string literal is **not at column 1**
leaves `table.concat()` meeting a hole. `M.switches(buf)` takes a **buffer
number**, not a line, so each shape goes into its own scratch buffer:

```sh
cat > /tmp/h98-repro.lua <<'LUA'
local c = require("config.db_context")
local shapes = {
  "use ventas", "use ventas -- c", "/* c */ use ventas", "use ventas /* c */",
  "select * from a..t1 -- c", "select * from a..t1 where c = 'z'",
  "select 'abc' from t", "'x' = 1",
}
for i, l in ipairs(shapes) do
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { l })
  vim.api.nvim_buf_set_name(b, "repro" .. i .. ".sql")
  local ok, sw = pcall(c.switches, b)
  print(string.format("%-36s %s", l, ok and (vim.inspect(sw):gsub("%s+", " ")) or "CRASH"))
  vim.api.nvim_buf_delete(b, { force = true })
end
LUA
nvim --headless -u NORC -c 'lua dofile("/tmp/h98-repro.lua")' -c 'qa!'
```

Expected **before** the fix:

```text
use ventas                         { kind = "use", name = "ventas", owner = "ventas" }
use ventas -- c                    nil
/* c */ use ventas                 nil
use ventas /* c */                 nil
select * from a..t1 -- c           nil
select * from a..t1 where c = 'z'  nil
select 'abc' from t                CRASH   <- invalid value (nil) at index 1 ...
'x' = 1                            CRASH
```

Two outcomes from one defect: **crash** (a literal mid-line) and **silent loss**
(a trailing comment or a cross-database reference). The crash wording is the
issue's. Note the first shape succeeds — the defect is **positional** (R-0001),
which is why the existing smoke suite never caught it.

### 1.2 The silent case (FR-012, R-0001)

The same command against cross-database lines shows the more dangerous variant —
no crash, but the reference is lost, so the cross-database warning silently
disappears:

```text
select * from a..t1 -- c        -> switches = nil   (expected a..t1)
select * from a..t1 where c='z'  -> switches = nil   (expected a..t1)
select 'abc' from t             -> switches = nil   (no crash, no message at all)
```

### 1.3 The crash blocks execution (FR-010, R-0002)

This is the counter-intuitive one: the crash is not cosmetic. An error inside a
`User` autocmd **aborts the command that fired it**, and dadbod fires the event at
`autoload/db.vim:307`, immediately before starting the job at `:309`.

The event is prefixed with the output path, so the pattern is `*/DBExecutePre` —
**not** `DBExecutePre`. Firing the unprefixed name matches nothing and appears to
pass, which is a trap when writing this test:

```sh
cat > /tmp/h98-abort.lua <<'LUA'
local function run(lines, label)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(b, "repro.sql")
  vim.bo[b].filetype = "sql"
  vim.api.nvim_set_current_buf(b)
  require("config.db_context").setup()
  _G.reached = false
  -- registered AFTER db_context's, so false proves the command aborted mid-firing
  vim.api.nvim_create_autocmd("User", { pattern = "*/DBExecutePre",
    callback = function() _G.reached = true end })
  local ok = pcall(vim.cmd, "doautocmd User */DBExecutePre")
  print(string.format("%-24s doautocmd-ok=%-5s later-listener-reached=%s",
    label, tostring(ok), tostring(_G.reached)))
  vim.api.nvim_buf_delete(b, { force = true })
end
run({ "use ventas" }, "baseline (no noise)")
run({ "select 'abc' from t" }, "literal mid-line")
run({ "/* xx */ use ventas" }, "block comment")
LUA
nvim --headless -u NORC -c 'lua dofile("/tmp/h98-abort.lua")' -c 'qa!'
```

Expected **before** the fix — `later-listener-reached=false` for the literal, meaning
`s:job_run()` was never reached and the query was never sent:

```text
baseline (no noise)      doautocmd-ok=true   later-listener-reached=true
literal mid-line         doautocmd-ok=false  later-listener-reached=false
block comment            doautocmd-ok=true   later-listener-reached=true
```

That is the mechanism behind the issue's "after I fixed the SQL, the query did not
run". The captured error is the issue's, verbatim, with a traceback naming the
whole path from `concat` up through `switch_message`.

### 1.4 A server complaint is never shown (FR-001, R-0004)

Run any syntactically invalid query in a Sybase connection buffer:

```sql
if not ('T'='F') else print 'x'
```

Expected **before** the fix: the result buffer is empty and no message reaches the
developer. `s:first_tokens()` (`sybase.vim:375-377`) keeps only single-token
lines, and `Msg 156, Level 15, State 2` is not one. `s:clean_result()`
(`:655-683`) returns `[]` at the first `Msg` line, collapsing four distinct
failure modes into one indistinguishable empty answer.

### 1.5 A check that could not determine is reported as "does not exist" (FR-015, R-0006)

Against a database the connection cannot read — a probe that errors, or a request
that never completed — the message says *"database X does not exist on this
server"*, because `confirm_database()` compares a Vim **string** to a number and
Vimscript coerces `''` to `0`.

```sh
cat > /tmp/h98-settle.vim <<'VIM'
let s:empty = ''
let s:out = []
call add(s:out, 'let s:empty == 0      -> ' . (s:empty == 0  ? 'TRUE' : 'FALSE'))
call add(s:out, 'let s:empty ==# 0     -> ' . (s:empty ==# 0 ? 'TRUE' : 'FALSE'))
call add(s:out, 'type(s:empty)         -> ' . type(s:empty))
call add(s:out, 'empty(s:empty) == 0   -> ' . (empty(s:empty) == 0 ? 'TRUE' : 'FALSE'))
call add(s:out, '--- the branch at sybase.vim:620 ---')
for s:v in ['', '0', '1']
  call add(s:out, printf('exists=%-4s -> %s', string(s:v),
        \ s:v == 0 ? 'rejected_absent' : 'rejected_forbidden'))
endfor
call writefile(s:out, '/tmp/h98-settle.out')
qa!
VIM
nvim --headless -u NORC -c 'source /tmp/h98-settle.vim'
```

```text
let s:empty == 0      -> TRUE     <- the coercion, and the bug
let s:empty ==# 0     -> TRUE     <- #= is case-strict, NOT type-strict
type(s:empty)         -> 1        <- it really is a String
empty(s:empty) == 0   -> FALSE    <- a DIFFERENT expression
--- the branch at sybase.vim:620 ---
exists=''   -> rejected_absent     <- the unreadable probe, misreported
exists='0'  -> rejected_absent
exists='1'  -> rejected_forbidden
```

**Read the fourth line before concluding anything.** `empty('') == 0` is `1 == 0`,
so it is false — and mistaking it for the coercion test makes this bug look absent.
The last three lines are the branch at `sybase.vim:620` verbatim.

One more pitfall, and it is the one that catches the *fix*: `exists` is polymorphic.
After a marker sets it, `exists` is a **Number** — so `exists ==# ''` is also true for
a genuine `exists = 0`, and a fix written as a string comparison would report a real
absence as indeterminate. Select the outcome by `type()`, not by comparing to a
string. See 2.6.

Also check `db_objects.lua:824`, whose catch-all handles every `result` value not
named explicitly and reports *"database X exists but this login could not enter it"*.
Today the unreadable case never reaches it — the coercion diverts first — but the
branch would misreport any future value.

## Part 2 — Validate the fix

### 2.1 Regression gate: all existing suites (FR-032)

```sh
for t in sybase_objects sybase_adapter db_results db_context db_objects_scope \
         db_objects_save db_jump db_connections buffer_visibility; do
  nvim --headless -u NORC -c "lua require('tests.${t}_smoke')" -c 'qa!' \
    && echo "PASS ${t}" || echo "FAIL ${t}"
done
```

All nine must pass. They pass today, so this is a meaningful gate — and none of
the 267 existing assertions exercises a buffer line containing a comment or a
literal, which is exactly why the defects are undetected.

### 2.2 New coverage: the shape matrix (FR-008, FR-032)

```sh
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
```

Must assert, for **every** shape below: no internal error, correct detection, and
**output byte length equal to input** (FR-012). Length equality is the assertion
that matters — a rewrite can stop crashing and still silently truncate, because
`table.concat` over a table with holes returns whatever prefix `#kept` happens to
report:

```text
use ventas                        use ventas -- comment
use ventas -- c                   use ventas /* c */
/* c */ use ventas                /* multi
                                    line 2 still block
use ventas /* c */                 line */ after open
select 1                          select 'it''s' from t
select 1 -- tail                  select '/* not a comment */'
select 'abc' from t               -- has /* inside
'x' = 1                           (empty string)
```

Plus the multibyte assertion (FR-012): `select 1 from t -- cafe 中文` is 30 bytes
in and 30 bytes out, so surviving columns do not shift. And the multi-line block
state, since R-0007's bug corrupts it:

```text
input : { "/* multi", "line 2 still block", "line */ after open", "select 1" }
output: { "        ", "                  ", "        after open", "select 1" }
```

The opening line and the still-commented line must be **fully** blank, the closing
line must keep its code, and the state must reset for line 4. A block comment that
opens and never closes must blank the rest of the buffer (`/* never closed`).

And the cross-database cases (FR-019…FR-023), which is why D-0004 dropped the
end anchor:

| Input | Expected `declared` |
|---|---|
| `select * from a..t1` | `a..t1` |
| `select * from a..t1 -- c` | `a..t1` |
| `select * from a..t1 /* c */` | `a..t1` |
| `/* c */ select * from a..t1` | `a..t1` |
| `select * from a..t1 where c = 'z'` | `a..t1` |

### 2.3 The crash no longer blocks execution (FR-010)

Re-run 1.3. Expected **after** the fix: `AFTER-EVENT: reached` is printed in every
case, because the inspection can no longer raise.

### 2.4 Complaints are surfaced (FR-001, FR-004, SC-001)

```sh
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
```

Must assert, on fixture responses and with no server:

| Scenario | Expected |
|---|---|
| `Msg 156, Level 15, ...` + `Incorrect syntax...` | one notice naming the server's own text |
| two `Msg` lines | **both** appear (FR-004) |
| complaint plus partial rows | complaint **and** rows both available (FR-026) |
| zero rows, no `Msg` line | success, **no** notice (FR-007) |
| 10 distinct zero-row queries | 0 reported as failures (SC-004) |
| same run observed twice | 1 notice, not 2 (FR-027) |
| unrecognized format | warning, never silence (FR-012) |
| full response text | still readable in full afterward (FR-005, FR-025) |
| cancelled run | no failure notice (FR-002) |

### 2.5 Every route reports (FR-006, SC-002)

The classifier sits at `User */DBExecutePost`, which is the single point every
route passes through. SC-002 requires 100% of routes; assert the listener is
reached for the interactive `:DB` path and the list-query path, and that neither
`sybase.vim`'s `s:clean_result()` nor `s:first_tokens()` can report a failed run as
a success.

### 2.6 The third check outcome (FR-015…FR-018)

```sh
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
```

| Probe response | `exists` | Expected `result` | Expected message |
|---|---|---|---|
| `DDB~` marker present | `'1'` | `confirmed` | none |
| clean absence, server says so | `'0'` | `rejected_absent` | "does not exist" (FR-018) |
| server confirms it, login refused | `'1'` | `rejected_forbidden` | "could not enter" |
| no marker, request failed | `''` | `indeterminate` | "could not determine" + reason (FR-016, FR-017) |

The `indeterminate` case must **not** contain "does not exist" or "could not
enter" — that is precisely the false diagnosis in R-0006. Assert on the message
text, not only the `result` value, and assert `reason` is non-empty for all three
non-`confirmed` outcomes.

Feed the branch each of the three **real** types, not three strings. `exists` is
polymorphic — a Number once a marker sets it, the String `''` otherwise — and
`0 ==# ''` is **true**, so a suite that only passes strings will happily accept a
fix that misreports a genuine absence:

```text
exists      type     expected result
''          String   indeterminate       (current code: rejected_absent)
0           Number   rejected_absent     (unchanged)
1           Number   rejected_forbidden  (unchanged)
```

### 2.7 Failure is never success-shaped (FR-002, SC-003)

Assert on the outcome variant, not on row count: a failed run and a zero-row
success must render differently, and a failure must not be summarized with a
success-shaped summary (SC-003).

### 2.8 Formatting and docs

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
```

`nvim/README.md` must document the new behavior and how to validate it (FR-033).

### 2.9 Manual verification on Windows (FR-028)

The developer's own plan requires manual verification on Windows. No platform
branch is introduced, so this is a confirmation that behavior is identical, not a
portability fix. Exercise: a query with a string literal (should not break the
status line), an invalid query (should name the server's complaint), a valid query
returning zero rows (should not warn), and a `a..t1` reference with a trailing
comment (should warn).

## Full gate

```sh
for t in sybase_objects sybase_adapter db_results db_context db_objects_scope \
         db_objects_save db_jump db_connections buffer_visibility; do
  nvim --headless -u NORC -c "lua require('tests.${t}_smoke')" -c 'qa!' || exit 1
done
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
```

## Probe sources

The measurements behind [research.md](research.md) came from headless probes
kept outside the repository, since they are diagnostic rather than regression
material — the assertions that matter are now permanent in
`nvim/lua/tests/*_smoke.lua`. Reproduction of each is described above:

| Claim | Probe | Reproduced in |
|---|---|---|
| sparse `kept` mechanics | `/tmp/h98-mech.lua` | 1.1 |
| crash and silent loss in real `db_context` | `/tmp/h98-probe-ctx.lua` | 1.1, 1.2 |
| autocmd aborts the firing command | `/tmp/h98-abort7.lua` | 1.3 |
| `.dbout` complete at Post | `/tmp/h98-dadbod.lua` | 2.4 |
| pattern alternatives | `/tmp/h98-verify9.lua` | 2.2 |
| corrected scanner, multibyte, block state | `/tmp/h98-verify9.lua` | 2.2 |
| an earlier scanner that still truncated | `/tmp/h98-verify8.lua` | 2.2 (rationale) |
| `'' == 0` coerces in Vimscript | `/tmp/h98-settle.vim` | 1.5 |
| the polymorphic-type trap, all 3 real inputs | `/tmp/h98-types.vim`, `/tmp/h98-types2.vim` | 2.6 |
| the two candidate fix forms | `/tmp/h98-types2.vim`, `/tmp/h98-types3.vim` | 2.6 |

The two scanner probes matter for the test design, not just the record: an
intermediate rewrite of the fix (`verify8`) still had holes and produced
truncated-but-not-crashing output. A shape matrix that only asserts "no error"
would have passed it. Assert length.
