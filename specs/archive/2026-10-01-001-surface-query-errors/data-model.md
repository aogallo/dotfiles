# Data Model: Surface Query Errors

**Feature**: [`012-surface-query-errors`](spec.md) · **Phase**: 1 · **Date**: 2026-10-01

This feature stores nothing and creates no new persistent structures. It is
documented because the change introduces two new *value shapes* and one new
*state*, and because the spec's correctness argument depends on keeping four
outcomes distinguishable. Every shape below is derived from
[research.md](research.md) measurements; no field is speculative.

## Value: Server complaint

The server's own words about a statement. The only authoritative evidence of why
a run failed (FR-011). Extracted from the completed output file at
`User */DBExecutePost` (D-0001).

| Field | Type | Source | Notes |
|---|---|---|---|
| `code` | `integer \| nil` | `Msg <N>, Level <N>...` | `nil` when the text is a bare message |
| `level` | `integer \| nil` | same line | ASE severity; `nil` when absent |
| `text` | `string` | the complaint line, whitespace-trimmed | never rewritten or abbreviated |
| `line_no` | `integer` | position in the response | 1-based, for pointing at the complaint |

`code` and `level` are `nil`-able because a client that does not emit the ASE
header must still be classified (see Unrecognized output). `text` is
**unmodified** server text: FR-014 and FR-025 require the full text to remain
readable, and surfacing is additive, never a rewrite.

**Invariant**: at least one of `code`/`level`/`text` is present. A complaint is
never synthesized — a run with no complaint has no complaint object.

## Value: Run outcome

The classification of one run. This is the type the reporting path produces and
the presentation path consumes.

```text
RunOutcome
├── success   : zero or more rows, no complaint    -> current presentation (FR-003, FR-007)
├── failed    : one or more complaints             -> complaint-shaped notice (FR-001, FR-004)
├── cancelled : the run was stopped by the user    -> not a failure, not a success
└── unreadable: output that could not be classified -> warning, never silent (FR-012)
```

- `success` with `row_count == 0` is the legitimate zero-row case. FR-007 forbids
  reporting it as a failure, and SC-003 forbids showing it as "no rows" for a run
  that actually failed. The two are distinguished by the variant, not by row
  count.
- `failed` carries **all** complaints, not the first (FR-004), and may also carry
  partial rows (FR-026). Both are retained.
- `cancelled` is distinguishable because dadbod records `query.canceled`
  separately from the exit status (R-0005). A cancellation must not be reported
  as a server complaint.
- `unreadable` is the fail-closed default. Any response the classifier does not
  recognize becomes `unreadable`, never `success`. This is what keeps FR-012
  ("MUST NOT silently discard") true for a client whose wording differs from
  ASE's — it degrades to a visible warning rather than to silence.

**Invariants**:
- Exactly one variant per run. A run is never both `success` and `failed`; that
  combination is SC-003's central failure mode.
- `failed` implies at least one `Server complaint`.
- `cancelled` implies zero complaints are reported as failures.
- The full response text is retained for every variant (FR-025), and is
  independent of the variant — reading the outcome never consumes or truncates it.

## State: Check outcome (replaces a two-value return)

`confirm_database()` returns two shapes for "not confirmed": `rejected_absent`
(the server said the database is not there) and `rejected_forbidden` (it is there,
this login cannot enter). It selects between them with a numeric comparison:

```vim
'result': exists == 0 ? 'rejected_absent' : 'rejected_forbidden'
```

R-0006 measured that this is wrong: Vimscript coerces a string to a number, so
`'' == 0` is **true**, and an unreadable probe (`exists == ''`) is reported as
`rejected_absent` — a database asserted not to exist because the check never ran.

The fix is a **third** state (D-0003) selected by type — the field is polymorphic,
so a string comparison is not enough — plus an explicit branch in `db_objects.lua`
so the dispatch becomes **exhaustive** rather than falling through to an inference.

```text
CheckOutcome
├── established  : the probe returned the expected marker
├── not_established : the probe completed and reported absence   (FR-018)
└── indeterminate : the probe could not complete                 (FR-015, FR-017)
```

| Field | `established` | `not_established` | `indeterminate` |
|---|---|---|---|
| `requested` | database asked about | database asked about | database asked about |
| `confirmed` | marker found | `''` | `''` |
| `result` | `established` | `rejected_absent` | `indeterminate` |
| `exists` | Number `1` | Number `0` | String `''` |
| `reason` | `''` | server's own complaint | the request's own failure |

**Invariants**:
- `result == 'rejected_absent'` is only ever returned when the probe **completed**
  and the server said the database is absent. FR-018: a database that truly does
  not exist must still be reported, so `not_established` keeps its current
  behavior and its current message.
- `result == 'indeterminate'` is returned when `exists == ''`, i.e. the probe
  produced no usable marker. FR-015 forbids asserting a conclusion, and FR-017
  requires the message to say it could not determine.
- `exists` is **polymorphic**: a Number once a marker sets it, the String `''`
  otherwise. The outcome selection MUST account for that. Comparing it to a string
  literal is not sufficient — R-0006 measured `0 ==# ''` as true, so a genuine
  absence (`exists == 0`) would be reported as indeterminate. Guard on `type()`.
- The consumer MUST NOT infer a cause from an unhandled `result`. Every value in
  the vocabulary has an explicit branch, and the catch-all reports the outcome as
  undetermined rather than naming a cause (FR-015).
- `reason` is populated for every non-`established` outcome. FR-016 requires the
  reason the request failed to be included; today it is absent, which is why the
  failure is unactionable.

## Value: Declared database context

The buffer-text side of the cross-database comparison. Its shape is **unchanged**
by this feature — the change is that it becomes reliably populated.

| Field | Type | Notes |
|---|---|---|
| `declared` | `string` | database the buffer's text says it will run against; `''` when absent |
| `reference` | `string \| nil` | the cross-database reference, e.g. `a..t1` |
| `switch` | `boolean` | `true` when `declared ~= connection.database` |
| `reason` | `string \| nil` | conflict vocabulary, existing |

**Invariants**:
- Parsing MUST NOT raise for any buffer text (FR-008). After the Phase 1 rewrite
  this holds structurally rather than by care: the single left-to-right pass
  writes every column, so `table.concat` can never meet a hole.
- Parsing MUST NOT silently discard text (FR-012). The invariant that was
  violated is now: the output string has the **same byte length** as the input
  line, with comment and literal regions blanked. Measured at 30 bytes for
  `select 1 from t -- cafe 中文`, so multibyte content does not shift columns.
- A reference carrying a trailing comment, a block comment, or a string literal
  MUST be found (FR-020, FR-021). This is the requirement that rejects the `%s*$`
  anchor (D-0004).
- A block comment MUST close on the line that closes it (R-0007); today
  `line:find('%*/', ..., true)` looks for the literal text `%*/` and never
  matches.

## Value: Client invocation result

The shape the read-only query primitive must expose so a complaint cannot be lost
on a non-zero exit. Documented because R-0005 measured
`db#systemlist()` returning `[]` whenever the exit status is non-zero.

| Field | Type | Notes |
|---|---|---|
| `lines` | `string[]` | stdout lines; may be empty on failure |
| `exit_status` | `integer` | the client's own status; non-zero does **not** imply an empty response |
| `output_path` | `string` | the completed file; the authoritative source for classification |

**Invariant**: an empty `lines` array is not evidence of an empty response. Any
consumer must consult `output_path`, not infer from `lines` (D-0001). Without
this, a hard client failure re-creates R-0004 through the synchronous path.

## Relationships

```text
buffer text
    |  strip_noise()  (single left-to-right pass, FR-008, FR-012)
    v
DeclaredDatabaseContext --compare--> connection.database
    |                                        |
    | non-empty and different                 | fixed side, never changes
    v                                        v
  SwitchInfo  (FR-019..FR-023)          CheckOutcome  (FR-015..FR-018)
                                            |
                                            | indeterminate -> reason
                                            v
                                    CheckOutcome  (FR-015..FR-018)
                                       dispatched EXHAUSTIVELY in db_objects.lua;
                                       no value may fall into an inferred branch

query run
    |
    | DBExecutePre  -> DeclaredDatabaseContext check (may abort on internal error; FR-010)
    v
  client invocation -> ClientInvocationResult
    |
    | DBExecutePost -> read output_path -> Server complaint list
    v
  RunOutcome
    |
    | notice (deduplicated, FR-027)
    | full text retained (FR-005, FR-014, FR-025)
    v
  developer
```

## State transitions for a run

```text
                    +-- user stopped it --> cancelled --> done
                    |
submitted --> running --+-- no complaint, rows      --> success(0+ rows) --> done
                    |     |
                    |     +-- no complaint, 0 rows   --> success(0 rows)   --> done
                    |     |                                    (NOT a failure, FR-007)
                    |     +-- complaint(s)           --> failed             --> done
                    |     |                            (all kept, FR-004;
                    |     |                             partial rows kept, FR-026)
                    |     +-- unclassifiable output   --> unreadable          --> done
                    |                                   (warning, FR-012)
                    |
                    +-- editor check raised
                          internal error --> reported as internal error, NOT as a
                                           server complaint (FR-011), and it must
                                           not be able to prevent execution (FR-010)
```

The last branch is R-0002 and is the reason Phase 1 exists: today an internal error
in the Pre listener aborts dadbod's command before the job starts, so a
text-inspection bug becomes a query that never runs.

## Validation summary

| Rule | Enforced by | Verifiable without a server |
|---|---|---|
| parsing never raises | structural single pass | yes — shape matrix, FR-008 |
| output preserves byte length | per-column emit | yes — multibyte assertion |
| complaint keeps full text | no truncation on the read path | yes — fixture `.dbout` |
| zero rows is not a failure | `RunOutcome` variant split | yes — 10 zero-row fixtures, SC-004 |
| failure is not success-shaped | `RunOutcome` variant split | yes — presentation assertion, SC-003 |
| every route surfaces | shared classifier at Post | yes — 9-route matrix, SC-002 |
| unknown is not absent, and not a permission failure | third `CheckOutcome` state, selected by type, dispatched explicitly | yes — feed `''`, Number `0`, Number `1` |
| no duplicate notices | per-run dedup key | yes — repeat same run, FR-027 |
