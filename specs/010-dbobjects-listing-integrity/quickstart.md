# Quickstart: Validating the Trusted `:DBObjects` Listing

**Feature**: [010-dbobjects-listing-integrity](spec.md) · **Plan**: [plan.md](plan.md) ·
**Contract**: [contracts/sybase-listing-integrity.md](contracts/sybase-listing-integrity.md)

How to prove the feature works. Sections 1–3 are automated and MUST pass before the change is
complete (FR-037, SC-009). Section 4 needs a real ASE server and is **manual-only** — it cannot be
automated here, so it is listed as a known manual-only operation in `nvim/README.md`.

---

## 1. Prerequisites

- Neovim ≥ 0.9 on `PATH` as `nvim`
- No database server, and no `sqsh`/`isql` — the smoke tests stub both. This is deliberate: the
  suites must pass on a clean machine with no ASE access.

No configuration, no connection registry, and no environment variable is needed. Nothing here reads
or writes a real credential.

---

## 2. Run the existing suites first (baseline)

Run before changing anything, so a pre-existing failure is not misattributed.

```sh
cd "$DOTFILES"

nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
```

**Expected**: all four exit `0`. Record the assertion counts — they are the baseline for §3.

---

## 3. Automated validation (required before completion)

### 3.1 Corrected kind set — the bug in issue #92

Extend `tests/sybase_objects_smoke.lua`. Stub the client to echo rows for **two-character** type
values and assert:

| Stubbed output contains | Expected |
|-------------------------|----------|
| `my_proc` / `P` | one `procedure` row |
| `my_func` / `SF` | one `function` row — **previously missing** |
| `my_etrig` / `TR` | one `trigger` row — **previously impossible** |
| `my_view` / `V` | one `view` row |
| `my_table` / `U` | one `table` row |
| `my_esp` / `XP` | one `function` row — **previously missing** (`X` never matched) |

Then assert the emitted query text contains `'SF'`, `'TR'` and `'XP'`, and does **not** contain the
single-letter `'F'` or `'X'` as standalone kind values.

**Expected**: every case passes. A failure here means the root cause was not actually fixed.

### 3.2 Marker parsing and the reconciliation record

With the marker prefix and count row in place, assert:

- A heading line, a dashed separator, a `(N rows affected)` trailer, and a
  `Changed database context to 'X'.` line are each classified as a **diagnostic or dropped row**,
  never as an object (FR-022, FR-012).
- A row with a blank-padded type (`U ` with trailing space) is still classified as a `table`
  (the `char(2)` trimming rule, §1.2).
- `reported` comes from the count row, not from `len(rows)`.
- A `DCNT~` value greater than the number of parsed rows yields `excluded > 0` and
  `shown + excluded == reported` (invariant I5).
- A **missing** count row yields `reported = 0` and marks the listing partial rather than complete.
- An unmapped type such as `SQ` (sequence) is carried through verbatim as the row's `kind`
  (FR-011).
- The whole listing costs exactly **one** client invocation (FR-043).

### 3.3 Scope confirmation

Extend `tests/db_objects_scope_smoke.lua`:

| Stubbed confirmation | Expected |
|----------------------|----------|
| `DDB~<requested>` | scope confirmed; listing opens; label names the confirmed database |
| `DDB~<previous>` + existence `0` | exactly one message naming the database as non-existent; **no listing**; previous scope retained |
| `DDB~<previous>` + existence `1` | exactly one message naming it as not permitted; **no listing**; previous scope retained |
| no database in the URL | label reads `login default`; direct-open entry absent; listing still opens |
| missing client | exactly one message naming the connection; no empty picker |

Assert specifically that **the label is derived from the confirmed value, not the requested one** —
stub a mismatch and confirm the label does not read as the requested database. This is the single
most important assertion in the feature (invariant I3).

Also assert the confirmation issues **one** client invocation and that the invocation count is
identical for a 3-row and a 3,000-row stub (FR-041, SC-010).

### 3.4 Direct-open entry

| Scenario | Expected |
|----------|----------|
| Confirmed scope + valid name | source buffer opens, bound to the confirmed database; exactly one source read |
| Confirmed scope + unknown name | exactly one actionable notice; **no** buffer opened |
| Unconfirmed scope | entry is **not offered** (FR-035) |
| Name supplied, not yet confirmed | **zero** requests issued so far (FR-036) |
| Prompt cancelled | no buffer, no request, no state change |
| Two-part qualified name | rejected with a message pointing at the scope control (FR-039) |

### 3.5 Regression guards

- All four suites from §2 still pass, with the same or a higher assertion count (SC-009).
- The save-flow suite is **unchanged and still passes** — saving is out of scope
  ([contracts](contracts/sybase-listing-integrity.md) §3.5).
- The existing no-op cases still pass: chooser cancel, prompt cancel, re-selecting the active
  database, invalid database name (FR-027, FR-028).

---

## 4. Live-server validation (manual-only)

Needs a real ASE instance and a login with objects in a **non-default** database. This is the
reproduction of issue #92 and cannot be stubbed.

### 4.1 Reproduce the reported bug against the old code

1. Connect with a database that is **not** your working database.
2. `:DBObjects`, choose the other database, search for a **trigger** or a **user-defined
   function** in it.
3. **Before the fix**: the object is absent, the listing is populated, and no message appears.
4. Hand-run the reference path from the issue to confirm the object exists and is readable.

### 4.2 Confirm the fix

| # | Action | Expected |
|---|--------|----------|
| 1 | Choose a database you can use | listing contains only that database's objects; label names it |
| 2 | Choose a database you **cannot** use | one message; **no** listing of the other database |
| 3 | Type a database name that does not exist | one message, distinguishable from #2 |
| 4 | Choose a database with zero objects | "0 objects" for that database — visibly not an error |
| 5 | Search for a **trigger** | **found** (impossible before the fix) |
| 6 | Search for a **user-defined function** | **found** (impossible before the fix) |
| 7 | Pick `Open object by name…`, enter an object of an uncovered kind (e.g. a rule or a sequence) | source opens, from the confirmed database |
| 8 | Pick `Open object by name…`, enter a nonexistent name | one actionable notice, no buffer |
| 9 | With no database in the connection | direct-open entry is absent; `login default` label |
| 10 | Cancel the chooser / the name prompt | pure no-op |

### 4.3 Open questions to settle here

These are the two items [research.md](research.md) marked **[ASSUMED]**. Both are cheap to check
and both would change the implementation if wrong.

1. **Does `TR` also return instead-of triggers (`IT`)?** Run
   `select name, type from sysobjects where type in ('TR','IT')` in a database with an
   instead-of trigger. If `IT` rows appear, decide whether they should be labelled `trigger`
   (current contract) or excluded.
2. **Does `db_id('<name>')` return NULL for a database the login cannot access?** If it does, the
   existence probe must keep reading the server-wide database list explicitly
   ([research.md](research.md) R-0004) and MUST NOT be "simplified" to `db_id()` later.

### 4.4 Server load

The developer's explicit performance condition. Confirm on a database with a non-trivial object
count:

- The number of client invocations for one `:DBObjects` is **2** (confirmation batch + listing
  batch), or **1** when the scope is unchanged — and is the **same** for 50 objects and 50,000
  ([contracts](contracts/sybase-listing-integrity.md) §2).
- Opening the listing without using `Open object by name…` issues **no** extra request.
- No write, DDL, temporary object, or blocking lock appears in any statement sent to the server.

---

## 5. Definition of done

- [ ] §2 baseline recorded, all four suites green before any change
- [ ] §3.1–§3.5 pass — especially the `SF`/`TR`/`XP` cases and the "label is not the requested
      database" assertion
- [ ] §4 run against a real server, with §4.3 answered and recorded in `verify-report.md`
- [ ] `nvim/README.md` updated: covered kind set, the `char(2)` explanation, the direct-open entry,
      the deliberate system-catalogue exclusion, new validation commands
- [ ] The stale in-code kind comment corrected ([contracts](contracts/sybase-listing-integrity.md) §4)
- [ ] Committed on `010-dbobjects-listing-integrity` with conventional commits; PR links issue #92;
      the developer has been asked whether to close this spec as the completed solution
      (constitution XIII)
