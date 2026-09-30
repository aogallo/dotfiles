# 010 — Verification Report: `:DBObjects` Listing Integrity

Spec: `specs/010-dbobjects-listing-integrity/`
Branch: `010-dbobjects-listing-integrity` · Issue: #92

## Status

78 of 82 tasks done. The implementation, the documentation, and the static validation are
complete. The four open tasks need a real ASE server, so they are not code:

| Task | What it needs | Why it is open |
| --- | --- | --- |
| T075 | an ASE instance with a login that has objects in a non-default database | the reproduction of #92 and the ten-scenario confirmation; no server is reachable from this machine |
| T076 | the same instance | the two `[ASSUMED]` items from `research.md` (does `TR` return `IT`; does `db_id()` conflate absent with not-permitted) |
| T077 | the same instance | the client-invocation count has to be observed, not inferred — the code shape is verified below, the observed count is not |
| T082 | a human decision | whether `spec.md` is closed as the completed solution (asked at PR time, constitution XIII) |

T074 is **written** below. The spec is not closed: T075, T076, T077 and T082 are open, so this
report records a partial acceptance on purpose.

## Gate

```
TOTAL 339 pass / 0 fail
stylua: clean
boot:   clean
```

Twelve smokes. Ten with `-u NORC` (no plugin state), two with the real configuration, because they
depend on Prettier, Stylua and a real save.

| Smoke | Configuration | Assertions | Was |
| --- | --- | --- | --- |
| `db_objects_scope_smoke.lua` | offline | 87 | 20 |
| `db_context_smoke.lua` | offline | 72 | 72 |
| `sybase_objects_smoke.lua` | offline | 53 | 20 |
| `formatter_chains_smoke.lua` | offline | 27 | 27 |
| `db_objects_save_smoke.lua` | offline | 26 | 19 |
| `db_results_smoke.lua` | offline | 18 | 18 |
| `sybase_adapter_smoke.lua` | offline | 11 | 11 |
| `db_jump_smoke.lua` | offline | 7 | 7 |
| `keymap_groups_smoke.lua` | offline | 6 | 6 |
| `db_connections_smoke.lua` | offline | 4 | 4 |
| `markdown_whitespace_smoke.lua` | real | 18 | 18 |
| `no_formatter_warning_smoke.lua` | real | 10 | 10 |

Total before: 268. Total now: 339. The whole increase is in the two smokes this feature owns;
every other count is unchanged, which is the regression evidence the framework asks for.

### One flake, ruled out

`markdown_whitespace_smoke.lua` failed once (`trailing spaces after a heading are removed`) during
a run that started two Neovim instances back to back in a single shell. It then passed 5/5 in
isolation, and it passes on a clean `HEAD` worktree. Two Neovim processes in one shell were
fighting over the same temporary Markdown fixture. It is not related to this feature — that smoke
touches `db_objects.lua` nowhere — and it is recorded here rather than quietly dropped.

## The root cause, confirmed

`sysobjects.type` is `char(2)`, space-padded, so a kind is two characters:

| Row in the catalog | Correct predicate | The old one-letter predicate | Result |
| --- | --- | --- | --- |
| `U ` table | `'U'` | `'U'` | matched |
| `V ` view | `'V'` | `'V'` | matched |
| `P ` stored procedure | `'P'` | `'P'` | matched |
| `SF` function | `'SF'` | `'F'` | **never matched** |
| `XP` extended procedure | `'XP'` | `'X'` | **never matched** |
| `TR` trigger | `'TR'` | absent from the query | **never selected** |

Three of the five advertised kinds were unreachable, and because the query returned no rows and no
count, nothing contradicted the result: a populated listing with a trigger simply missing from it,
no message. That is exactly the report in #92.

## What the tests actually pin

The failure modes below are asserted, not described. `sybase_objects_smoke.lua` drives the parser
and the count reconciliation; `db_objects_scope_smoke.lua` drives the picker and its messages.

- **The `char(2)` codes** — `U`, `V`, `P`, `SF`, `TR`, `XP` all yield the right label, and the kind
  set is closed: `D ` (default), `PK`, `C`, `UQ`, `F` (foreign key), `IT`, `SY`, `D1`, `D2` and the
  gate row are all rejected, so an `SF` row can no longer be read as an `F` row.
- **A complete listing reconciles** — 2 rows with a server count of 2 gives `2 of 2 objects shown`.
  The count row is what makes the header falsifiable; it was absent before.
- **A listing that excludes objects says so** — a server count of 4 against 0 shown rows gives
  `partial: 0 of 4 objects shown, 4 not shown`, and the client's `Msg` line (5 rows, 4 covered) is
  reported as a server note rather than as a row.
- **A missing count row is not claimed as whole** — with no `DCNT~` row the header says the server
  sent no object count, so the listing may be incomplete.
- **The scope label follows the server, not the request** — the picker is opened for `sybase://…/main_db`
  while the buffer's `b:db` says `mismatch_db` and the server confirms `other_db`: the header reads
  `other_db`, and the change is not silently accepted as a scope.
- **One message per failure, and no picker** — an absent database, a denied database, and a catalog
  the login cannot read each raise exactly one notice, open no picker at all, leave the previous
  scope in force, and issue **zero** listing requests.
- **The three rejections are distinguishable** — absent, denied and catalog-unreadable each get
  their own wording and their own fix, and a typed name gets the "check the spelling" hint because
  it never appeared in the readable list.
- **An empty confirmed database is not a failure** — `0 of 0 objects shown` plus one INFO notice,
  and the picker still opens so scope can be changed.
- **The direct-open entry is conditional** — present with a confirmed database, absent with no
  database in the connection, present again as soon as a database is confirmed.
- **Direct-open is safe** — a bad name raises one notice and opens no buffer; no request is issued
  when the prompt is cancelled.
- **Server notes are deduplicated and capped** — a `Changed database context` message repeated
  three times appears once, and a client that frames every row as a dropped line still yields
  three samples, not an unbounded block.

## T077 — the request budget, verified statically

The live count still has to be observed (T075). What the code guarantees, checked by reading the
call sites rather than by counting a run:

| Flow | Client invocations | Where |
| --- | --- | --- |
| Open listing, no scope change | 1 | `confirm_database()` + `objects()` |
| Change scope, accepted | 1 | same two, for the rewritten URL |
| Change scope, rejected | 1 | `confirm_database()` only; `objects()` is never reached |
| Open a listed object | 1 | the existing `source()` read |
| Direct-open by name, confirmed | 1 | the existing `source()` read; no re-confirmation |
| Direct-open offered but not used | **0** | the entry is a `vim.ui.select` item, not a request |

The count is **structurally independent of the row count**: `objects()` issues exactly one
statement no matter how many rows come back, and no code path asks per database, per object or per
row. Confirmation, the `master..sysdatabases` existence probe, the listing and the count all share
one batch (one client invocation each), which is why a scope change costs 2 and not 4.

A grep of `autoload/db/adapter/sybase.vim` for `insert`/`update`/`delete`/`create`/`drop`/`alter`/
`grant`/`revoke`/`begin tran`/`waitfor`/`select … into` returns no SQL statement — the only hit is
Vim's `insert()` built-in building a `use <db>` session line. There is no write, no DDL, no
temporary object and no blocking lock in anything this feature sends to the server.

## What was corrected while implementing

- **`prompt_for()` first hid the count** when the listing was complete, so the header showed no
  numbers at all in the common case. FR-029 requires the reconciliation whenever it is known, so
  the header now always carries `N of M objects shown`, and `partial: … K not shown` when objects
  are excluded.
- **`apply_database_scope()` had two copies of the rejection wording**, one for a typed name and one
  for a chosen one, and neither was shared with `M.open()`. Both now call `start_listing()`, which
  owns every rejection message in one place — that is what makes "exactly one message" checkable
  rather than aspirational.
- **`no_database` produced a raw-URL message.** The scope now reads `login default` and a 0-object
  login-default listing reports `0 objects in the login default database`, so no path prints a
  `sybase://` URL back at the developer.

## Documentation

`nvim/README.md` §`:DBObjects` now carries the covered-kind set in plain language, the `char(2)`
explanation with the specific rows that were being missed, why the system catalogue is deliberately
not enumerated, the conditional `Open object by name…` entry and its confirmed-database rule, and
the manual-only live-server checklist from `quickstart.md` §4 as a documented table. The
[Function traceability](nvim/README.md#function-traceability) table gained rows for the kind
codes, the marker protocol, server-confirmed scope, the single-message rule and direct-open.

## Not verified here

- The reported bug reproduced against the old code on a live server (T075).
- The ten live scenarios, including "a trigger is found" and "a user-defined function is found"
  (T075) — these are the two that a stub cannot fake, because the stub proves the predicate, not
  the catalog's contents.
- Whether `TR` also returns instead-of triggers `IT`, and whether `db_id()` conflates absent with
  not-permitted (T076). Both are `[ASSUMED]` in `research.md`; the first would change a label, the
  second would change the existence probe.
- The observed client-invocation count (T077), verified statically above only.