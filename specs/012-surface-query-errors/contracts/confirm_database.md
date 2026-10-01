# Contract: Check Outcome

**Feature**: [`012-surface-query-errors`](spec.md) · **Phase**: 1 · **Date**: 2026-10-01

The interface behind User Story 3 and the `indeterminate` state in
[data-model.md](../data-model.md). This contract spans **two** files, because
R-0006 found a coercion in the producer and an inference in the consumer, so both
change:

| File | Role | Change |
|---|---|---|
| `nvim/autoload/db/adapter/sybase.vim:586-622` | producer — `confirm_database()` | add one `result` value; compare `exists` as a string |
| `nvim/lua/config/db_objects.lua:799-835` | consumer — `start_listing()` | dispatch it explicitly; stop inferring |

## Current behavior

### The producer coerces, and misreports absence

`confirm_database()` selects between "does not exist" and "exists but cannot
enter" with a numeric comparison:

```vim
return {'requested': requested, 'confirmed': '',
      \ 'result': exists == 0 ? 'rejected_absent' : 'rejected_forbidden',
      \ 'exists': exists}
```

`exists` is a String (`''` until a marker sets it to a number at `:607`). Vimscript
coerces a string to a number, so `'' == 0` is **true** and an unreadable probe is
reported as `rejected_absent`. The function's own comment says it should not be:

> *"When the probe itself was unreadable (`''`) we report the weaker, safer claim
> (`rejected_forbidden`) rather than assert a database does not exist"*

Measured (`/tmp/h98-settle.vim`):

```text
let s:empty = ''
let s:empty == 0     -> TRUE      <- coerces; this is the bug
let s:empty ==# 0    -> TRUE      <- #= is case-strict, NOT type-strict
type(s:empty)        -> 1         <- it really is a String
empty(s:empty) == 0  -> FALSE     <- a DIFFERENT expression
```

The last line is the trap that makes this easy to misdiagnose: an early probe tested
`empty('') == 0`, which is `1 == 0`, and was read as evidence the coercion did not
happen.

And the coercion has a mirror image that catches the *fix*: because `exists` is a
**Number** once a marker sets it, `0 ==# ''` is also true. A fix written as a string
comparison therefore cannot tell a genuine absence from an unreadable probe. Select
the outcome by `type()`.

### The consumer's catch-all is also inferential

`start_listing()` handles `confirmed`, `no_database`, `not_attempted`, and
`rejected_absent` by name. Everything else lands at `db_objects.lua:824`:

```lua
else
    report_failure(
        'database ' .. confirmation.requested .. ' exists but this login could not enter it',
        ...
```

Today the unreadable case never reaches it — the coercion diverts it to
`rejected_absent` first — but the branch would still misreport any future `result`
value. Both are fixed, so the dispatch becomes exhaustive.

## Target behavior

`exists` is **polymorphic** — the String `''` while no marker has been seen, then the
**Number** `str2nr(rest)` once one sets it. That makes the obvious fix wrong: measured,
`0 ==# ''` is **true**, so `exists ==# '' ? 'indeterminate' : ...` would report a
genuine absence as indeterminate. Guard on the **type** instead, leaving the field's
representation untouched:

```vim
let result = 'indeterminate'
if type(exists) != v:t_string
  let result = exists == 0 ? 'rejected_absent' : 'rejected_forbidden'
endif
```

```lua
-- db_objects.lua: an explicit branch, before the catch-all
elseif confirmation.result == 'indeterminate' then
    report_failure(
        'could not determine whether ' .. confirmation.requested .. ' exists',
        'the check did not complete, so nothing was confirmed about it'
    )
    return
```

Verified against all three values the real function produces (`/tmp/h98-types2.vim`):

| `exists` | type | current | fixed | meaning |
|---|---|---|---|---|
| `''` | String | `rejected_absent` | `indeterminate` | probe established nothing |
| `0` | Number | `rejected_absent` | `rejected_absent` | server said absent |
| `1` | Number | `rejected_forbidden` | `rejected_forbidden` | exists, cannot enter |

Only the first row changes, which is the point: the two genuine outcomes keep their
current values, types, and messages.

## Return shape

| Key | Type | `confirmed` | `rejected_absent` | `rejected_forbidden` | `indeterminate` |
|---|---|---|---|---|---|
| `requested` | `string` | database asked about | database asked about | database asked about | database asked about |
| `confirmed` | `string` | marker found | `''` | `''` | `''` |
| `result` | `string` | `confirmed` | `rejected_absent` | `rejected_forbidden` | `indeterminate` |
| `exists` | `string` | `'1'` | `'0'` | `'1'` | `''` |
| `reason` | `string` | `''` | server's own complaint | the server's own refusal | the request's own failure |

`reason` is **new**. Today it is absent entirely, which is why a failure is
unactionable: the developer is told what happened but never why (FR-016).

### Compatibility

The four existing `result` values keep their meanings and their messages, so
existing consumers and the fixtures in `db_objects_scope_smoke.lua:151-157` and
`sybase_objects_smoke.lua:306-318` are unaffected. One value is added, and one
case that previously fell through now has a message of its own.

Both existing negative values become *more* accurate. `rejected_absent` is no
longer reachable by a probe that established nothing, and `rejected_forbidden` is
returned only when `exists == '1'` — the server confirmed the database exists and
the login could not enter it.

## Invariants

- `result == 'rejected_absent'` only when the probe **completed** and the server
  reported absence. A true absence is still reported (FR-018).
- `result == 'rejected_forbidden'` only when `exists == '1'`, i.e. existence is
  established and only the entry failed.
- The outcome selection MUST handle the polymorphic `exists`. Comparing it against
  a string literal is **not sufficient**: `0 ==# ''` is true, so a real `exists = 0`
  is indistinguishable from an unreadable probe. Guard on `type()`, or normalize
  `exists` to a String at assignment.
- `result == 'indeterminate'` when `exists == ''`. The message MUST say the check
  could not determine, and MUST NOT name a cause (FR-015, FR-017).
- The consumer MUST NOT infer a cause from an unhandled `result`. The catch-all
  remains only as a defensive branch, and reports the outcome as undetermined.
- `reason` is non-empty for every non-`confirmed` outcome (FR-016).
- The function MUST NOT return a conclusion derived from the **absence** of a
  marker alone. R-0004 measured that a syntax error removes the `DDB~`/`DEX~`
  markers, so absence is ambiguous between "absent" and "probe failed".

## Interaction with buffer context

This contract and `db_context.lua` are independent, but a *failure* here used to
present exactly like a *finding* there. With `indeterminate` distinct, the
cross-database check can report "could not determine" (FR-022) without claiming a
conflict that was never established.

## Verification

Callable with no server: the decision depends only on the text
`confirm_database()` already read, so a fixture response with no marker exercises
the `indeterminate` branch directly. Assert all four outcomes, and assert the
`exists == ''` case produces a message that does **not** contain "could not enter"
or "does not exist". Add a regression assertion that feeds the branch each of the three **real** types
(`''`, Number `0`, Number `1`): a probe that only passes strings misses the
polymorphism and will accept the wrong fix. Covered in
`nvim/lua/tests/sybase_adapter_smoke.lua` and
`nvim/lua/tests/db_objects_scope_smoke.lua`; see [quickstart.md](../quickstart.md).
