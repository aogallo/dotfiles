# Research: Query Errors Are Always Surfaced

**Feature**: [`012-surface-query-errors`](spec.md) · **Date**: 2026-10-01 · **Issue**:
[#98](https://github.com/aogallo/dotfiles/issues/98)

Every finding below was measured against Neovim 0.12.1 and the plugins installed in this
checkout, with headless probes rather than inferred from documentation. The probes are reproduced in
[quickstart.md](quickstart.md) so a reviewer can re-run every number.

**No database server, no client binary, and no credentials were required for any probe.** Every
defect in this feature is local editor state or local text processing, which is why the whole
investigation ran offline.

## Evidence base

| Source | What was used |
|--------|---------------|
| `nvim/lua/config/db_context.lua:114-219` | `strip_noise()` and `M.switches()` — the function the issue's error names |
| `nvim/lua/config/db_context.lua:112` | `TWO_PART`, the cross-database reference pattern |
| `nvim/lua/config/db_context.lua:331-350` | `M.setup()`, the `User */DBExecutePre` listener |
| `nvim/lua/config/db_results.lua:20-73` | the per-session result slot and its two dadbod listeners |
| `nvim/autoload/db/adapter/sybase.vim:355-362` | `s:run_query()`, the only read-only query primitive |
| `nvim/autoload/db/adapter/sybase.vim:375-377` | `s:first_tokens()`, the line filter that drops `Msg` lines |
| `nvim/autoload/db/adapter/sybase.vim:477-537` | `s:parse_listing()`, the **existing** diagnostics vocabulary |
| `nvim/autoload/db/adapter/sybase.vim:586-622` | `confirm_database()` and its result vocabulary |
| `nvim/lua/config/db_objects.lua:799-835` | `start_listing()` — the dispatch whose catch-all `else` infers a cause (R-0006) |
| `nvim/autoload/db/adapter/sybase.vim:655-683` | `s:clean_result()`, returning `[]` for four failure modes |
| `nvim/lua/config/db_objects.lua:775-786` | `surface_diagnostics()` — the precedent for reporting a complaint |
| vim-dadbod (installed) | `autoload/db.vim:307` (Pre event), `:309` (job start), `:316` (writefile), `:329` (Post event) |
| Neovim runtime docs | `autocmd.txt` — an error inside a `User` autocmd aborts the firing command |
| headless probes | `/tmp/h98-probe-ctx.lua`, `/tmp/h98-mech.lua`, `/tmp/h98-abort7.lua`, `/tmp/h98-dadbod.lua`, `/tmp/h98-final3.lua`, `/tmp/h98-verify8.lua`, `/tmp/h98-verify9.lua`, `vimcmp.vim` |

## Findings

### R-0001 — The crash is a sparse table, not a syntax problem

The issue quotes `db_context.lua:186: invalid value (nil) at index 1 in table for 'concat'`. Line
186 is `out[i] = table.concat(kept)`. The cause is that `kept` is **sparse**, and `table.concat`
walks `1..#kept` and refuses to continue at the first `nil`.

`strip_noise()` fills `kept` in exactly two ways: `kept[k] = ' '` for a marker's own characters
(`db_context.lua:165-167`), and `kept[k] = line:sub(k,k)` for the run *after* the last marker
(`:157-159`). The run **before** the first marker is never copied. Measured trace
(`/tmp/h98-mech.lua`), showing the columns actually written and the holes left behind:

```text
"select 'abc' from t"
  kept columns : 8, 13..19
  holes        : 1,2,3,4,5,6,7,9,10,11,12
  trace        : blank 8..8 (string) | fill 13..19
  concat       : FAILS

"'x' = 1"
  kept columns : 1, 4..7
  holes        : 2,3
  trace        : blank 1..1 (string) | fill 4..7
  concat       : FAILS

"select 1"                          <- no noise at all
  kept columns : 1..8
  holes        : none
  trace        : fill 1..8
  concat       : ok -> "select 1"
```

The defect is **positional**: it fires when the first marker is not at column 1. That is why the
existing smoke suite never caught it — every line it exercises has no comment or literal at all
(see Baseline).

**Whether it crashes or silently corrupts is luck.** `table.concat` needs `#kept` to span the
hole. When the trailing `fill` run happens to be long enough that `#kept` reaches past it, the
concat raises; when it is not, Lua's `#` is undefined on a table with holes and returns a shorter
length, so the concat *succeeds* over a prefix and yields a truncated line:

```text
"if not ('T'='F')"
  holes : 1..8,10,11,12,14,15      concat ok -> ""      <- the whole line vanished
"use ventas -- comment"
  holes : 1..11                    concat ok -> ""      <- the whole line vanished
```

Measured against the real module (`/tmp/h98-probe-ctx.lua`):

| Buffer text | `M.switches()` | `M.label()` | Expected switch |
|---|---|---|---|
| `use ventas` | `use:ventas` | `DB main_db ⚠ ventas` | `ventas` |
| `use ventas -- comment` | **`nil`** | **`DB main_db`** | `ventas` |
| `/* c */ use ventas` | **`nil`** | **`DB main_db`** | `ventas` |
| `use ventas /* c */` | **`nil`** | **`DB main_db`** | `ventas` |
| `select * from a..t1 -- c` | **`nil`** | **`DB main_db`** | `a..t1` |
| `select * from a..t1 where c = 'z'` | **`nil`** | **`DB main_db`** | `a..t1` |
| `select 'abc' from t` | **CRASH** | **CRASH** | — |
| `'x' = 1` | **CRASH** | **CRASH** | — |
| `-- only comment` | `nil` | `DB main_db` | `nil` |
| `/* only block */` | `nil` | `DB main_db` | `nil` |

Two distinct user-visible outcomes from one defect: **crash** (literal mid-line) and **silent
loss** (trailing comment). The silent case is the more dangerous one — it disables the
cross-database warning, which exists precisely to stop a query running against the wrong data,
and it produces no message at all.

> **This is the highest-value fix in the feature and it touches no database code.** It is one
> local function.

### R-0002 — The crash aborts the query, which is why the corrected SQL "did not run"

The issue's second half is the striking one: after *fixing* the SQL, the query stopped executing
and an error appeared. The chain is mechanical:

1. `plugin/database.lua:56` calls `db_context.setup()`, which registers a `User */DBExecutePre`
   listener whose callback is **not** wrapped in `pcall` (the call is `db_context.lua:342`, inside
   the callback registered at `:338-347`).
2. dadbod fires that event at `autoload/db.vim:307`, **immediately before** it starts the job at
   `:309`.
3. An error raised inside a `User` autocmd **aborts the command that fired it**.

Measured with the real `doautocmd` mechanism dadbod uses, not the test helper
(`/tmp/h98-abort7.lua`). `reached-job` is a second listener registered *after* `db_context`'s, so
`false` proves the command was aborted mid-firing rather than merely reported an error:

```text
baseline                   ok=true   job-reached=true
literal-midline            ok=false  job-reached=false
literal-first              ok=false  job-reached=false
trailing-comment           ok=true   job-reached=true
block-comment              ok=true   job-reached=true
```

The captured error is the issue's, verbatim, with a traceback that names the whole path:

```text
db_context.lua:186: invalid value (nil) at index 1 in table for 'concat'
  [C]: in function 'concat'
  db_context.lua:186: in function 'strip_noise'
  db_context.lua:205: in function 'switches'
  db_context.lua:234: in function 'conflicting_switch'
  db_context.lua:310: in function 'switch_message'
  db_context.lua:342: in function <db_context.lua:340>
  [C]: in function 'nvim_exec2'
```

Note the event name: the pattern is `*/DBExecutePre` (prefixed by the output path), not
`DBExecutePre`. A probe that fires the unprefixed name matches nothing and appears to pass — worth
knowing before anyone writes a regression test for this.

The crash therefore does not merely print an error — it prevents `s:job_run()` from ever being
reached. The query is never sent to the server. **A cosmetic defect in a text inspection is
blocking query execution**, which is the exact symptom in the report and the reason Q3 in the
spec's Clarifications rejects gating execution on interpretation.

### R-0003 — The issue's own query does *not* crash the text scan

Worth recording because it is counter-intuitive: the query pasted into the issue contains a string
literal, yet both its broken and corrected forms return `nil` rather than a crash (probe section F).

```text
ISSUE broken (no end)       switches true  nil    label true  DB main_db
ISSUE corrected (end added) switches true  nil    label true  DB main_db
```

The reason is R-0001's "luck" branch: `if not ('T'='F')` leaves `kept` with only columns 9, 13, 16,
so `#kept` is 16 but the concat walks a range where the holes dominate and returns `""`. The line
becomes empty, the scan finds nothing, and no error is raised.

So the issue's query exercises the **silent** branch of the same defect, not the crashing one. The
crash the developer hit came from a different line in their real buffer — most likely a query with
a literal followed by code, which is the common shape. This matters for test material: the issue's
pasted query alone would **not** reproduce the reported crash, so FR-013 requires coverage of the
ordinary SQL shapes in FR-008 as well, not only the pasted query.

### R-0004 — Nothing classifies the server's response after a query runs

The reported symptom proper. Two independent gaps:

**Nothing reads the result.** `db_results.lua` records the output file path and buffer on
`DBExecutePost` (`on_post`, `:46-50`) and summoning it later re-opens the file (`:143-153`). The
content is never inspected. Measured: `db_results.lua` contains **zero** calls to `readfile`,
`jobstart`, or `system`. A failed run and a successful run are indistinguishable.

**Some paths throw the complaint away.** `sybase.vim` has three places that discard diagnostics:

| Site | Behavior on a `Msg 156, Level 15...` line |
|---|---|
| `s:first_tokens()` `:375-377` | filters to lines that are exactly **one token**; `Msg 156, Level 15, State 2` is not, so it is dropped with no trace. Its own comment calls multi-word diagnostics "dropped". |
| `s:clean_result()` `:655-683` | `return []` on the first `Msg` line — collapsing syntax error, hidden text, missing object, and missing client into one indistinguishable empty answer |
| `confirm_database()` `:586-622` | looks only for `DDB~`/`DEX~` markers; a syntax error removes both, so it infers a conclusion from absence (see R-0006) |

`s:first_tokens()` is the sharpest illustration: a filter meant to keep result tokens **is** a
filter that removes error messages, and it is exactly the class of filter that
`s:parse_listing()`'s comment (`:473-476`) says it replaced.

### R-0005 — A listener at `DBExecutePost` can read every server complaint

The linchpin the fix depends on. Verifying the *ordering* rather than assuming it: dadbod's
`s:query_callback` writes the output file at `autoload/db.vim:319` and fires `DBExecutePost` at
`:329` — the file is complete before the event. Measured by replaying that exact sequence
(`/tmp/h98-dadbod.lua`):

```text
output file readable at DBExecutePost : true
lines visible to the listener          : { "Msg 156, Level 15, State 2",
                                         "Incorrect syntax near the keyword 'else'.",
                                         "Msg 102, Level 14, State -75",
                                         "Incorrect syntax near 'end'" }
```

So the server's own words are available, complete and in order, with no need to change how queries
are executed, retain anything new, or intercept the client. This is why FR-005/FR-025 are cheap:
the evidence already exists on disk.

Two constraints the fix inherits, both measured at the same sites:

- `db#systemlist()` (`autoload/db.vim:275-288`) returns `[]` whenever the client's **exit status
  is non-zero** — `return exit_status ? [] : lines`. So a client that fails hard yields an empty
  line list even though it wrote its complaint into the file. Any reading of the response must
  prefer the **file**, not the job's line list, or it will re-introduce R-0004 through the back
  door.
- `s:query_callback` distinguishes aborted from finished (`a:status`) and records
  `a:query.canceled`. A cancellation is therefore distinguishable from a server complaint, which
  FR-002 requires and which the exit status alone cannot express.

### R-0006 — A check that could not determine is reported as "database does not exist"

`confirm_database()` ignores `Msg` lines entirely and infers from markers. Its comment states the
intent precisely — *"When the probe itself was unreadable (`''`) we report the weaker, safer claim
(`rejected_forbidden`) rather than assert a database does not exist"* — and the code does the
opposite, for a reason that is subtle enough to have fooled an earlier pass at this document.

**Correction to an earlier reading.** Vimscript *does* coerce here, and the defect is real. The
measure that settles it (`/tmp/h98-settle.vim`), using a variable so no parsing is ambiguous:

```text
let s:empty = ''
let s:empty  == 0    -> TRUE      <- an empty String coerces to Number 0
let s:empty  ==# 0   -> TRUE      <- #= does NOT help: it is case-strict, not type-strict
type(s:empty)        -> 1         <- it really is a String
empty(s:empty) == 0  -> FALSE     <- this is a DIFFERENT expression
```

The last line is the trap. An early probe tested `empty('') == 0` — which is `1 == 0`, i.e.
false — and was read as evidence that the coercion did not happen. It does. **`==#` is
case-strict, not type-strict: any comparison between a Vim String and a Number coerces, in
whichever direction separates them least.**

So an unreadable probe takes the `rejected_absent` branch, and the developer is told a database
does not exist.

#### R-0006a — The field is polymorphic, which makes the obvious fix wrong

`exists` is **not** consistently typed. It starts as the String `''` (`:599`), but a marker sets
it to the **Number** `str2nr(rest)` (`:605-607`). Comparing it against a string literal therefore
does not separate the cases the way it appears to, because the coercion runs in *both*
directions (`/tmp/h98-types.vim`):

```text
exists=0    type=0 (Number)  0 ==# ''  -> TRUE     <- the trap
exists=1    type=0 (Number)  1 ==# ''  -> FALSE
exists=''   type=1 (String)  '' ==# '' -> TRUE
```

So the natural-looking fix `exists ==# '' ? 'indeterminate' : ...` **misclassifies a genuine
absence as indeterminate**, because a real `exists = 0` also satisfies `==# ''`. An intermediate
probe (`/tmp/h98-fixcmp.vim`) missed this because it only ever fed the comparison *strings* —
it never reproduced the Number that the real function passes. **Probe the real types, not
plausible ones.**

Two forms are correct (`/tmp/h98-types2.vim`, `/tmp/h98-types3.vim`), and the plan prefers the
second because it does not change the field's declared type:

```vim
" A — normalize at assignment, then compare strings throughout.
"     Changes exists to a String, so consumers/tests comparing to a Number must follow.
if n >= 0
  let exists = string(n)          " '0' or '1'
endif
" ... then: exists ==# '' ? indeterminate : (exists ==# '0' ? absent : forbidden)

" B — keep the existing types; guard on type() at the branch. PREFERRED.
let result = 'indeterminate'
if type(exists) != v:t_string
  let result = exists == 0 ? 'rejected_absent' : 'rejected_forbidden'
endif
```

Measured against the three values the real function actually produces
(`/tmp/h98-types2.vim`):

```text
exists        type     Form B (type-guard)
0             Number   rejected_absent      <- correct
1             Number   rejected_forbidden    <- correct
''            String   indeterminate         <- correct
```

Form A is verified separately, against the **normalized** values it would receive after
`string(n)` (`/tmp/h98-types3.vim`): `'0'` → `rejected_absent`, `'1'` → `rejected_forbidden`,
`''` → `indeterminate`. It is correct only because every value has been stringified first;
feeding it the raw Number `0` reproduces the misclassification.

Form B is preferred: the existing negative values keep their types and their meanings, so nothing
else that reads `exists` has to change. Form A would silently alter a field that other code and
tests already compare numerically.

A second, compounding defect sits one layer down. `db_objects.lua:824` handles `confirmed`,
`no_database`, `not_attempted`, and `rejected_absent` by name, and every other value lands in a
catch-all that asserts both existence and a permission cause:

```lua
else
    local stayed = previous and scope_label(previous) or 'the login default database'
    report_failure(
        'database ' .. confirmation.requested .. ' exists but this login could not enter it',
        ...
```

Today the unreadable case never reaches that branch — the coercion diverts it to
`rejected_absent` first. But the branch is still inferential, and would misreport any future
`result` value. Both need fixing for the dispatch to be exhaustive (D-0003).

Severity is the same as R-0001's silent case: the developer is sent to fix a problem they do not
have. For `rejected_absent` that is a nonexistent database; for anything reaching the catch-all
it is a nonexistent permission grant — and granting access to a database that was never confirmed
to exist cannot make the message change.

### R-0007 — Three more defects sit in the same function; fixing the crash alone is not enough

`strip_noise()` contains a **third** bug the issue does not report and that a crash-fix would not
touch. The block-comment close search at `db_context.lua:170` passes `true` for the plain-match
flag:

```vim
local _, close_end = line:find('%*/', first[2] + 1, true)
```

With plain matching, `'%*/'` is the literal three-character text `%*/`, not the pattern `*/`.
Measured against `"/* xx */"`:

```text
line:find('%*/', 1)        -> 7  8     (pattern - matches the real '*/')
line:find('%*/', 1, true)  -> nil      (plain - looks for the literal "%*/")
line:find('*/', 1, true)   -> 7  8     (plain, correct literal)
```

A block comment therefore **never closes**: every opening `/*` sets `in_block` and blanks the rest
of the buffer. Confirmed live against the current module, where a `use` that is merely *sitting
next to* a block comment is invisible:

```text
CURRENT /* xx */ use ventas   switches = nil     <- the `use ventas` was swallowed
CURRENT /* multi              switches = nil
CURRENT line */ after open    switches = nil
```

Compare `db_context.lua:135`, which omits the flag and is correct. The asymmetry inside one
function is the tell.

And a **fourth**, in the pattern rather than the function. `TWO_PART` (`db_context.lua:112`) is
anchored with `..'$'` at the call site, `:212`, and has no `%s*` before the anchor. Since
noise-stripping *replaces* text with spaces, a **correct** strip always leaves trailing spaces, so
the anchor can never match a line that had any trailing content. Measured on correctly-stripped
lines (`/tmp/h98-verify9.lua`):

| Source line | current `$` | `%s*$` | unanchored |
|---|---|---|---|
| `select * from a..t1` | `a` | `a` | `a` |
| `select * from a..t1 -- c` | **`nil`** | `a` | `a` |
| `select * from a..t1 /* c */` | **`nil`** | `a` | `a` |
| `/* c */ select * from a..t1` | `a` | `a` | `a` |
| `select * from a..t1 where c = 'z'` | **`nil`** | **`nil`** | `a` |
| `select * from sales..customer` | `sales` | `sales` | `sales` |

The current anchor misses **3 of 6**. `%s*$` still misses the literal-carrying case, because
`where c = 'z'` leaves a *statement* after the reference, not just spaces.

**Consequence for the plan**: fixing only `strip_noise()` would make things *worse* on the
cross-database path — today `a..t1` is lost by the truncation bug; after the crash fix the line
survives intact and the anchor starts rejecting it for a *different* reason. Both must be fixed
together, and **the `%s*$` anchor is rejected in favour of dropping the end anchor**, because it
still misses the literal case FR-021 explicitly requires. Decision D-0004 records this.

## Candidate fix, validated against the defect matrix

The fix for R-0001 is structural: walk each line **left to right** and emit every column exactly
once — copy the code *before* a marker, blank the marker, continue after it. Sparseness becomes
impossible by construction rather than by care.

**But "emit every column" has to mean every column on *every* exit path, and that is the trap.**
Two intermediate versions of this fix were written and measured, and **both still had holes**:

- Copying the run before the first marker, but not the run inside an open block comment — a line
  beginning inside a block (`/* multi` on line 1, `line */ after open` on line 2) left columns
  `1..ce` unwritten.
- Fixing that, but not blanking the *remainder* of a line on the branches that consume to
  end-of-line. An unclosed block (`/* multi`) and an unterminated literal (`select 1 -- 'x`) both
  set `j = n + 1` after blanking only the marker, leaving the rest of the line unwritten. These
  did not always crash — `table.concat` returned a **truncated** line of the right prefix length —
  which is the same silent corruption as R-0001, just at a smaller scale.

The version that passes blanks explicitly on all four exits: the block body, the marker, the
unterminated literal tail, and the comment tail. The invariant to assert, on every shape, is
`#out[i] == #line` — length equality, not just "no error". A shape matrix that only checks for a
crash will pass a truncated implementation.

Validated (`/tmp/h98-verify9.lua`), 19 shapes, asserting **no crash AND byte-length preserved**:

```text
use ventas                           OK   len=10/10        /* a */ select 1 /* b */      OK   len=24/24
use ventas -- c                      OK   len=15/15        select 1                        OK   len=8/8
/* c */ use ventas                   OK   len=18/18        select 'it''s' from t           OK   len=21/21
use ventas /* c */                   OK   len=18/18        select '/* not a comment */'    OK   len=35/35
/* multi                             OK   len=8/8          -- has /* inside                OK   len=16/16
line 2 still block                   OK   len=18/18        select 1 -- tail                OK   len=16/16
line */ after open                   OK   len=18/18        (empty string)                 OK   len=0/0
use ventas -- 'x'                    OK   len=17/17        select 'abc' from t             OK   len=19/19
                                    ...                    'x' = 1                         OK   len=7/7
select 1 -- 'unterminated            OK   len=25/25        /* never closed                 OK   len=15/15
select 1 from t -- cafe 中文         OK   len=30/30   <- multibyte
TOTAL FAILURES: 0
```

Multi-line block state, which R-0007's bug corrupts:

```text
[1] "        "                    <- /* multi           : fully blanked
[2] "                  "           <- line 2 still block: fully blanked
[3] "        after open"           <- line */ after open: closes, code survives
[4] "select 1"                     <- state reset
```

**The defect count is the plan's shape**: one function with four coupled bugs (R-0001, R-0007),
one inferential consumer (R-0006), and one reporting gap (R-0004/R-0005). The crash fix and the
silent-loss fix are the same edit — which is why US2 and US4 in the spec share a phase.

## Baseline

All nine existing smoke suites pass today, so the plan's regression gate is meaningful:

```text
sybase_objects  PASS   sybase_adapter   PASS   db_results      PASS
db_context      PASS   db_objects_scope PASS   db_objects_save PASS
db_jump         PASS   db_connections   PASS   buffer_visibility PASS
```

All 267 existing assertions pass, and **not one of them exercises a buffer line containing a
comment or a string literal** — which is precisely why R-0001 and R-0007 are undetected. FR-032
therefore requires coverage for each shape in FR-008, not only for the issue's pasted query
(R-0003).

## Decisions

### D-0001 — Read the result file at `DBExecutePost`, not the job's line list

**Decision**: classify the server's response by reading the completed output file inside a
`User */DBExecutePost` listener.

**Rationale**: R-0005 measured that the file is complete and readable at that event, and R-0005
also measured that `db#systemlist()` collapses to `[]` on a non-zero exit — so the line list is
the *one* source that is guaranteed to have lost the complaint.

**Alternatives considered**: reading the job's stdout lines (rejected: R-0005, empty on failure);
wrapping the client invocation (rejected: changes how queries execute, which the spec's Out of
Scope forbids, and couples the module to the client binary); parsing during `DBExecutePre`
(rejected: the query has not run yet, so there is nothing to read).

### D-0002 — Report through the existing notification path, reuse the existing severity vocabulary

**Decision**: emit one notice per failed run via the repo's notification helper, and classify
complaints with the `Msg N, Level N` shape already used at `sybase.vim:510` and the
`severity`/`reason` vocabulary already defined in `s:parse_listing()`.

**Rationale**: the module already has both — `surface_diagnostics()` at `db_objects.lua:775-786`
reports server complaints to the developer today, and `notifications.notify()` is what
`db_context.lua:346` already uses. Reusing them means no new presentation concept and no new
dependency (FR-030, constitution VI).

**Alternatives considered**: a new dedicated error UI (rejected: constitution XI, and the spec's
Clarifications Q2 forbids reshaping the response); writing failures to the message history only
(rejected: FR-001 requires the developer to actually see it).

### D-0003 — Add a third check outcome, selected by the field's type

**Decision**: extend `confirm_database()`'s result vocabulary with an explicit "could not
determine" value, and give `db_objects.lua` an explicit branch for it. Select the outcome by
guarding on the **type** of `exists` (Form B), leaving its existing Number/String representation
untouched.

**Rationale**: R-0006 measured the coercion (`'' == 0` is true) and showed the current code
therefore reports `rejected_absent` for a probe that established nothing. FR-015 forbids
asserting a conclusion, and FR-017 requires the message to say the check could not determine. A
third state satisfies both. Form B is chosen over the superficially cleaner "compare as a string"
because `exists` is **polymorphic** — Number when a marker sets it, String when not — so
`exists ==# ''` is true for a genuine `exists = 0` as well. R-0006 measured that trap: the
string-comparison form misclassifies a real absence as indeterminate. Guarding on `type()` is
correct for all three real inputs and changes no field's type. Making the dispatch **exhaustive**
also removes the inferential catch-all as a failure mode for any future value.

**Alternatives considered**: `exists ==# 0` (rejected: **measured still true** — changes
nothing); `exists ==# ''` / `exists ==# '0'` on the raw field (rejected: **measured wrong** —
`0 ==# ''` is true, so a real absence becomes indeterminate); normalizing `exists` to a String at
assignment (rejected: it works, but silently changes a field other code and tests compare
numerically); `str2nr(exists) == 0` (rejected: encodes "unknown" as a magic number and leaves
FR-017 unmeetable, since the label would have to mean two things); suppressing database messages
when the probe fails (rejected: FR-018 requires genuine findings to keep working); fixing only the
message text (rejected: the coercion would still divert the case to `rejected_absent`, so the
message would never be reached).

**Scope note**: this decision touches two files, not one — `sybase.vim` (add the value and fix
the comparison) and `db_objects.lua` (dispatch it explicitly). The plan's Phase 3 covers both.

### D-0004 — Drop the end anchor from the cross-database reference pattern

**Decision**: remove the `..'$'` anchor from `TWO_PART` rather than adding `%s*` before it.

**Rationale**: R-0007 measured both options on correctly-stripped lines. `%s*$` recovers 5 of 6
cases but still misses `select * from a..t1 where c = 'z'`, which FR-021 names explicitly. An
unanchored match catches 6 of 6. The `IDENT` character class already prevents a false positive on
`schema.object`, because two dots are required — the anchor was guarding against something the
pattern does not actually admit.

**Alternatives considered**: `%s*$` (rejected: measured, still fails FR-021's case); keeping the
anchor and stripping trailing whitespace before matching (rejected: adds a pass over every line to
work around a pattern defect).

### D-0005 — Fix `strip_noise` and `TWO_PART` in one change, with one shared test file

**Rationale**: R-0007 established they are coupled — fixing the strip alone makes the cross-database
path *worse* before the pattern is fixed. Splitting them across changes would ship a regression
window. One test file owns both because a test that only exercises the strip would pass while the
anchor still silently rejects valid references.

**Alternatives considered**: two separate changes (rejected: creates the regression window above);
fixing only the crash and deferring the silent-loss case (rejected: FR-019/FR-020/FR-021 are in the
same spec and the silent case is the more dangerous one).

## Resolved clarifications

All NEEDS CLARIFICATION items from Technical Context are resolved by the findings above. No
blocking question remained; the three defaults the spec recorded as Clarifications are upheld by
measurement:

- **Report, don't gate** (spec Q3) — confirmed by R-0002: the ungated inspection is already
  blocking execution, which is the reported bug. Gating would reproduce it deliberately.
- **Don't trim the server's response** (spec Q2) — confirmed by R-0005: the full response is
  already on disk and complete at the Post event, so preserving it costs nothing.
- **Fold the false diagnosis into scope** (spec Q1) — confirmed by R-0006: it is a two-line
  change in the same reporting layer being repaired — one new result value plus one explicit
  dispatch — and shipping the query-reporting fix without it would leave a message that
  sends the developer after a permission problem they do not have.

## Out of scope for research

Client-side SQL validation or linting, changing how queries are executed, and cancellation redesign
are excluded by the spec's Out of Scope and were not investigated. Whether ASE `isql` and `sqsh`
format their complaints identically is **not** assumed anywhere: the plan classifies by the
`Msg N, Level N` shape already in use at `sybase.vim:510`, and treats any unrecognised output as
"unreadable" rather than as "fine" (FR-012) — so a client that words things differently degrades
to a warning rather than to silence.
