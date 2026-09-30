# Contract: Sybase Listing Integrity

**Feature**: [010-dbobjects-listing-integrity](../spec.md) · **Plan**: [plan.md](../plan.md) ·
**Data model**: [data-model.md](../data-model.md)

Two boundaries are contractual: the autoload adapter surface consumed by the picker, and the
picker's user-visible behaviour. This file is the reference both implementations and both test
suites are written against.

---

## 1. Adapter surface

All functions live in `nvim/autoload/db/adapter/sybase.vim` and keep their existing names and
argument order unless stated. They are pure: no editor state, no user-visible messages.

### 1.1 `db#adapter#sybase#confirm_database(url)` — NEW

Confirms which database a session actually has in effect after the URL's `use` prologue.

| | |
|---|---|
| **Args** | `url` — string or parsed dict |
| **Returns** | dict `{ requested, confirmed, result, exists }` |
| **`result`** | `'confirmed'` \| `'rejected_absent'` \| `'rejected_forbidden'` \| `'no_database'` |
| **`confirmed`** | the server-reported database name when `result = 'confirmed'`; else `''` |
| **`exists`** | `1` if the requested database exists on the server, `0` if not, `''` when `result = 'no_database'` |
| **SQL** | one batch: `use <db>` (via the existing prologue) then `select 'DDB~' + db_name()` |
| **Side effects** | one client invocation |

**Contract**

- `result = 'confirmed'` **iff** the server-reported name equals the requested name (case-insensitive
  per ASE collation, compared on trimmed values).
- `result = 'no_database'` when the URL carries no database. The adapter MUST NOT invent one.
- When `result` is a rejection, `exists` distinguishes absent from forbidden. It MUST be obtained
  by probing the server-wide database list in the **same batch** — never by matching diagnostic
  text (R-0003, R-0004).
- MUST NOT parse the client's `Changed database context to 'X'.` line. `isql` does not emit it
  (R-0003).
- MUST return a rejection, never an exception, for a missing client — the caller reports it once.

### 1.2 `db#adapter#sybase#objects(url)` — CHANGED

| | |
|---|---|
| **Args** | `url` — string or parsed dict |
| **Returns** | dict `{ rows, reported, excluded, diagnostics }` (**breaking**: was a bare list) |
| **`rows`** | list of Object rows ([data-model.md](../data-model.md) §1) |
| **`reported`** | integer from the count row, `0` when unavailable |
| **`excluded`** | integer — reported objects that did not become rows |
| **`diagnostics`** | list of Diagnostic ([data-model.md](../data-model.md) §6) |

**Contract**

- Query kind set is **exactly** `U`, `V`, `P`, `SF`, `TR`, `XP` (R-0002). `F`, `X` and any other
  single-letter value MUST NOT appear.
- Each data row is emitted as `DOBJ~<name>~<type>`; the count row as `DCNT~<n>`. Both in **one
  batch** with **one** client invocation.
- The parser MUST accept a row **only** if it begins with `DOBJ~` and carries a non-empty name and
  a non-empty type. Every other output line is either a Diagnostic or a Dropped-row record — never
  silently ignored.
- The type MUST be trimmed before mapping: `char(2)` values arrive blank-padded.
- An unmapped type MUST be carried through verbatim as the row's `kind` (FR-011).
- `reported` MUST come from the `DCNT~` row, not from `len(rows)`. If the count row is missing,
  `reported` is `0` and the listing is reported partial rather than claimed complete.
- `row.database` MUST be the confirmed database, never the URL's requested one.
- MUST NOT issue a second client invocation to obtain the count.

### 1.3 `db#adapter#sybase#with_database(url, database)` — UNCHANGED

Retains its current contract, including rejection of names outside `[A-Za-z0-9_$#]+` and
preservation of user, host, port and charset. It remains a **URL rewrite only** and MUST NOT be
mistaken for confirmation — `confirmed` comes solely from §1.1.

### 1.4 `db#adapter#sybase#source(url, name)` — UNCHANGED

Reused verbatim by the direct-open entry (R-0006). Its hidden/encrypted pre-check, single-quote
escaping, chunk reassembly and `g:db_sybase_source_mode` handling are **out of scope** and MUST NOT
change. The only new constraint: callers MUST pass a URL whose database is confirmed (§3).

### 1.5 `s:object_kind(type)` — CHANGED (private)

Maps the trimmed two-character server type to a display kind:

| Server type | Display kind |
|-------------|--------------|
| `U` | `table` |
| `V` | `view` |
| `P` | `procedure` |
| `SF` | `function` |
| `XP` | `function` |
| `TR`, `IT` | `trigger` |
| anything else | returned verbatim |

**Contract**: MUST NOT drop an unmapped type; MUST NOT match on a single character.

### 1.6 Removed: silent diagnostic discarding

The current `s:first_tokens()`-style filtering, which kept only single-token lines and dropped
everything else, MUST NOT be used on listing output. Its diagnostic-dropping behaviour is the
direct cause of the reported silence.

---

## 2. Request budget

Per [research.md](../research.md) R-0008 and FR-041–FR-044:

| Flow | Client invocations |
|------|--------------------|
| Open listing, no scope change | 1 |
| Change scope (accepted or rejected) | 1 |
| Open a listed object | 1 (the existing source read) |
| Direct-open by name, confirmed | 1 (the existing source read) |
| Direct-open offered but not used | **0 additional** |

**Contract**: the count MUST be identical for a 50-object and a 50,000-object database. No code
path may issue one request per database, per object, or per row. The confirmation, existence probe,
listing and count MUST share a single batch wherever they are all needed.

---

## 3. Picker surface

`nvim/lua/config/db_objects.lua`. Behaviour, not signatures — this is the user-visible contract.

### 3.1 Picker composition

In order, for a confirmed scope:

1. `Database: <confirmed> — change…` (existing entry, now labelled from the **confirmed** value)
2. Object rows, rendered `kind \t database name` (existing format, unchanged)
3. **NEW** `Open object by name…` — the direct-open entry (FR-033)

For an unconfirmed scope (`source = 'none'`), entries 1–2 render with the `login default` label and
entry 3 is **not offered** (FR-035).

### 3.2 Direct-open entry

- Selecting it prompts for a name. It MUST NOT issue a request until the name is confirmed
  (FR-036).
- On confirmation it calls §1.4 with the confirmed scope's URL and opens the source in a new `sql`
  buffer, bound to that database exactly as a listed object is (FR-016).
- A name containing a two-part qualifier MUST be rejected with a message pointing at the scope
  control (FR-039).
- A name that does not resolve produces **exactly one** actionable notice naming the object and the
  causes, and opens no buffer (FR-019).
- Cancellation is a pure no-op (FR-038).

### 3.3 Failure messages

Exactly one message per failure, naming the subject and the causes (FR-003, FR-023, FR-024).
Required distinctions:

| Case | Must say |
|------|----------|
| Database does not exist | the name, and that no such database exists on the server |
| Login not permitted | the name, that it exists, and that the login could not enter it |
| Catalog read denied | the database, and that the login may lack read access to its catalog |
| No confirmed scope yet | that the operation needs a confirmed database first |

**Contract**: a failure MUST NOT re-present a previously obtained listing as if it answered the new
request (FR-025). Note this **changes** current behaviour, which reopens the last-good listing —
permitted by the spec's Assumptions only where it does not present a wrong listing as the answer.

### 3.4 Reconciliation display

Per [data-model.md](../data-model.md) §4. When `excluded > 0` the picker states the listing is
partial with the number excluded (FR-030). When rows are withheld for display it states how many
(FR-031). When `reported = 0` on a confirmed scope it states an empty result, which must be
visually distinct from a failure (FR-008).

### 3.5 Preserved behaviours

Unchanged and required to keep passing their existing tests (FR-027):

- Cancelling the database chooser or the typed-name prompt — pure no-op
- Re-selecting the already-active database — one warning, no re-query
- A syntactically invalid database name — rejected locally, no request, current message
- The save flow (destination, overwrite confirmation, naming) — untouched
- `[use current: <db>]` as the chooser's seeded entry

---

## 4. Documentation contract

`nvim/README.md` MUST state, after this change:

- the covered kind set as **`U`/`V`/`P`/`SF`/`TR`/`XP`** in plain language, matching §1.2 exactly
- that `sysobjects.type` is `char(2)` and why the earlier single-letter set was wrong
- the direct-open entry, and that it requires a confirmed database
- that the system catalogue is deliberately not enumerated, with the reason
- the updated smoke-test commands for any new or renamed test file

The in-code comment at `db_objects.lua:137-139`, which documents a third kind set
(`'P','FN','IF','TF','V','U'`) matching neither the old code nor the server, MUST be corrected
(FR-038).
