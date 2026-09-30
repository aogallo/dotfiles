# Phase 1 Data Model: Trusted `:DBObjects` Listing

**Feature**: [010-dbobjects-listing-integrity](spec.md) · **Plan**: [plan.md](plan.md)

Entities are the values that cross the adapter/picker boundary. Names are technology-neutral;
the concrete encodings live in [contracts/sybase-listing-integrity.md](contracts/sybase-listing-integrity.md).

---

## 1. Object row

One database object as the developer sees it in the picker.

| Field | Type | Required | Meaning | Validation |
|-------|------|----------|---------|-----------|
| `name` | string | yes | The object's name, exactly as the server reports it | Non-empty after trimming. No pattern restriction — ASE permits spaces and punctuation. Never re-quoted or escaped for display. |
| `kind` | string | yes | Plain-language kind for display | One of `table`, `view`, `procedure`, `function`, `trigger`; **or** the raw server-reported type value when unmapped (FR-011) |
| `database` | string | yes | The **confirmed** database that owns this row | Must equal the session's confirmed scope. A row whose database differs from the confirmed scope is a defect, not a variant. Empty only when no scope is confirmed. |

**Rules**

- `kind` is derived from a closed mapping over the six covered type values
  ([research.md](research.md) R-0002). An unmapped value is passed through verbatim rather than
  discarded.
- Two rows may share a `name` within one listing only if the server reports them as distinct
  objects; duplicates are preserved, not merged (no dedup by name).
- A row is never constructed from a line that lacks the client's row marker. An unparseable line
  becomes a **dropped-row record** (§5), never a partial row.

---

## 2. Scope selection

What the developer asked for, before the server has agreed.

| Field | Type | Required | Meaning | Validation |
|-------|------|----------|---------|-----------|
| `requested` | string | yes | The database name the developer chose | Rejected before any server round trip unless it matches `[A-Za-z0-9_$#]+` (FR-028, existing behaviour) |
| `origin` | enum | yes | How it was chosen | `connected` (from the connection), `chosen` (from the chooser list), `typed` (from the name prompt) |
| `result` | enum | yes | The outcome of confirmation | `confirmed`, `rejected_absent`, `rejected_forbidden`, `not_attempted` |

**Rules**

- A `requested` name outside the accepted character set never becomes a scope selection at all —
  it is rejected locally with the existing message (FR-028). No request is issued.
- `result` is assigned only by the confirmation step (§3), never optimistically.
- `origin` is retained so the failure message can distinguish a typo (`typed`) from a chooser pick
  (`chosen`) — a different hint for each.

---

## 3. Confirmed scope

The database the server reports as being in effect for the catalog read that produced the current
listing.

| Field | Type | Required | Meaning | Validation |
|-------|------|----------|---------|-----------|
| `database` | string | no | The server-confirmed database name | Absent means *unconfirmed* — never guessed, never defaulted to the requested name |
| `source` | enum | no | How it was established | `verified` (the server reported this name after the switch), `none` (no database in the connection) |

**Rules — the central invariant of this feature**

1. A listing is only ever labelled with a `Confirmed scope` whose `source` is `verified`.
2. A scope selection that is not `confirmed` never produces one (FR-002). There is exactly one
   `Confirmed scope` per session and a failure leaves the previous one in place (FR-004).
3. `source = 'none'` means the connection carried no database and the listing covers the login
   default. The indicator states that rather than naming a database (FR-006) — and, per FR-035,
   the direct-open entry is not offered in this state.
4. **Nothing infers a confirmed scope from a URL.** The URL carries the *request*; only the
   server's answer carries the *fact*. This is the precise break with current behaviour, where the
   label comes from the URL and is therefore a claim rather than an observation.

---

## 4. Reconciliation record

The counts that make a listing self-describing (FR-029).

| Field | Type | Meaning |
|-------|------|---------|
| `reported` | integer | Objects the server reported for the covered kinds |
| `shown` | integer | Rows present in the listing |
| `excluded` | integer | Reported objects that did not become rows |
| `hidden_by_limit` | integer | Rows not displayed because of a display limit (FR-031) |

**Rules**

- `reported` comes from the count row in the same batch as the listing (R-0005) — **not** from a
  second request.
- Invariant: `shown + excluded = reported`. A violation is itself a defect to report, not a
  number to round.
- `excluded > 0` sets the listing partial, which the UI must state (FR-030).
- `reported = 0` on a confirmed scope is an **empty result**, visually distinct from a failure
  (FR-008).

---

## 5. Dropped-row record

One output line the client could not interpret as a data row.

| Field | Type | Meaning |
|-------|------|---------|
| `line` | string | The raw line, retained for the diagnostic message |
| `reason` | enum | `no_marker`, `malformed_marker`, `missing_type` |

**Rules**

- Dropped-row records are the mechanism that makes FR-012 and FR-022 enforceable: nothing is
  discarded without becoming one.
- They are counted into `excluded` and summarized once. The raw text is shown only when the count
  is non-zero, and is trimmed — the UI never dumps an unbounded block of client output.
- A line carrying a server diagnostic is a **diagnostic** (§6), not a dropped row.

---

## 6. Diagnostic

A message from the server or the client accompanying a result.

| Field | Type | Meaning |
|-------|------|---------|
| `text` | string | The message as received |
| `severity` | enum | `info`, `error` |

**Rules**

- A diagnostic is never silently discarded (FR-022). Today every `Msg …` line is dropped by the
  row parser; that is the mechanism behind the reported silence.
- `severity = 'error'` on a listing that would otherwise be presented is what converts that
  listing into a failure — the confirmation step is the primary defence, but this is the backstop.
- A diagnostic is reported once, not once per line, even if the server repeats it.

---

## 7. Direct-open request

The developer's typed object name (User Story 3).

| Field | Type | Required | Meaning | Validation |
|-------|------|----------|---------|-----------|
| `name` | string | yes | The object to open | Non-empty after trimming. Single-quote-escaped before interpolation, per the existing source-reader contract |
| `scope` | Confirmed scope | yes | The database to read from | Must be `verified`; the request is refused otherwise (FR-035) |
| `qualified` | boolean | yes | Whether the name was given in two-part form | Must be `false`; a qualified name is rejected to keep the closed cross-database search closed (FR-039) |

**Rules**

- Constructing a request issues **no** server request (FR-036). The request is issued only on
  confirmation, and then it reuses the existing source read.
- Cancellation before confirmation is a pure no-op (FR-038).
- A name that does not resolve produces one actionable notice and no buffer (FR-019) — the same
  outcome as an unreadable source, because from the developer's position they are the same
  situation.

---

## State transitions

```
                 ┌──────────────────────────────────────────┐
                 │  no confirmed scope                      │
                 │  (connection carried no database)         │
                 └───────────────┬──────────────────────────┘
                                 │ developer chooses a database
                                 ▼
                        ┌─────────────────┐
                        │ scope selection │  requested validated locally
                        │  result = ?     │  (rejected → local message, no request)
                        └────────┬────────┘
                                 │ confirmation batch
              ┌──────────────────┼───────────────────┐
              ▼                  ▼                   ▼
      db_name() matches   mismatch + 0 rows   mismatch + 1 row
              │                  │                   │
              ▼                  ▼                   ▼
     ┌─────────────────┐  rejected_absent   rejected_forbidden
     │ CONFIRMED       │        │                  │
     │ source=verified │        │                  │
     └────────┬────────┘        └────────┬─────────┘
              │                         │
              │ listing batch            │ one actionable message
              ▼                         │ previous confirmed scope
     ┌─────────────────┐                │ RETAINED unchanged
     │ listing built   │                └──────────► back to
     │ reconciliation  │                           no confirmed scope
     │ computed        │                           or previous CONFIRMED
     └────────┬────────┘
              │
     ┌────────┴─────────┐
     ▼                  ▼
 rows shown        excluded > 0
     │                  │
     ▼                  ▼
 picker opens     picker opens AND
                 states the count (partial)
```

**Invariants across every transition**

| # | Invariant | Requirement |
|---|-----------|-------------|
| I1 | No listing is presented under a label whose scope is not `verified` | FR-002 |
| I2 | A failed confirmation never mutates the confirmed scope | FR-004 |
| I3 | The label is derived from the server's answer, never from the request | FR-005 |
| I4 | A failed selection never re-presents another listing as its answer | FR-025 |
| I5 | `shown + excluded = reported` for every built listing | FR-029 |
| I6 | The direct-open entry exists only when a scope is `verified` | FR-035 |
| I7 | A direct-open request issues nothing until confirmed | FR-036 |
| I8 | The number of server requests does not depend on database size | FR-041 |
