# Phase 1 Data Model: Query Buffer Always Shows Its Tab

**Feature**: [011-query-buffer-tab-visibility](spec.md) · **Plan**: [plan.md](plan.md) ·
**Research**: [research.md](research.md)

The values that cross the buffer-visibility boundary. Names are technology-neutral; the concrete
module surfaces live in [contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md).

Four defects from [research.md](research.md) R-0001, R-0005, R-0006 and R-0007 mean the buffer's own
local state is not a reliable source of truth: a close destroys its listing flag, its text, and its
`b:` variables. So two records exist — a **draft record** (session-local, survives unload) and a
**buffer state** (what the editor currently holds). Every invariant below is stated in terms of those
two.

---

## 1. Draft record

What the developer last opened in a query buffer, kept in memory for the session so it can be
restored after a close destroys the buffer's own state.

| Field | Type | Required | Meaning | Validation |
|-------|------|----------|---------|-----------|
| `display_name` | string | yes | The label the tab and the picker show, e.g. `ventas.dbo_proc.sql` | Non-empty. Must be unique among *live* drafts; collisions get a numeric suffix (§1.1). Never contains credentials. |
| `url` | string | yes | The connection the query acts against | Never displayed, never logged, never written. Carried exactly as `b:db` carries it today (`db_objects.lua:261`). |
| `object` | string | no | The database object the query came from, for the connection warning path | Empty for a hand-written query. |
| `database` | string | no | The owning database label | Empty when the object has no database. |
| `filetype` | string | yes | The buffer's language | `sql` for a database query. Re-applied on restore (FR-014). |
| `lines` | list of strings | no | The buffer text as of the last snapshot | Absent until the first snapshot. Never persisted. |
| `snapshot_taken_at` | tick/counter | no | When `lines` was captured | Used to decide whether a restore is warranted, not shown. |

**Rules**

- The record is keyed by buffer number while the buffer is valid, and by `display_name` as the
  fallback so a wiped-and-recreated buffer is still recognised. Both keys are stored.
- `lines` is a **snapshot of the last known text**, captured when the buffer leaves the editor's
  buffer list. It is a recovery aid, not a live view: a buffer that is still loaded always wins over
  its snapshot (§3).
- A draft record is created only by the module that opens a query buffer. Nothing else writes it.
- A draft record is **session-local and never persisted** (constitution VII, FR-017 as amended by
  A-001). Restarting Neovim discards it, and the developer re-opens the query — today's behaviour for
  anything that was not saved.

### 1.1 Display-name allocation

| Field | Type | Meaning |
|-------|------|---------|
| `base` | string | `<database>.<object>.sql`, or `<object>.sql` when there is no database |
| `sequence` | integer | `0` for the base name, `2`, `3`, … for suffixed names |
| `name` | string | the allocated display name |

**Rules**

1. If no existing buffer owns `base`, allocate `base` (`sequence = 0`).
2. If an **unlisted** buffer owns `base` — the closed-but-alive case of R-0005 — **reuse that buffer
   instead of allocating a new one**. It is reclaimed: lines replaced, language and connection
   re-applied, listing restored, focused. No second tab, no `E95`.
3. If a **listed** buffer owns `base` — a live query the developer still has — allocate the next free
   `<base stem>.<n>.sql` and leave the existing buffer alone (FR-012: two open queries must be
   tellable apart).
4. Allocation MUST NOT loop on a collision and MUST NOT raise: rule 3 is a bounded scan of the
   names already in use.

---

## 2. Buffer state (observed, never authored)

What the editor currently holds for a buffer. Read-only for this feature except for the single
listing write in §4.

| Field | Source | Meaning |
|-------|--------|---------|
| `valid` | buffer validity | The buffer still exists |
| `listed` | `'buflisted'` | Whether it appears in the buffer list — and therefore whether it can have a tab |
| `loaded` | buffer load state | Whether its text is in memory |
| `has_windows` | windows showing it | Whether it is displayed right now |
| `name` | buffer name | The file the buffer belongs to, or the display name |
| `lines_empty` | buffer lines | Whether the buffer currently holds no text |
| `filetype`, `db` | buffer-local options | The binding that an unload destroys (R-0006) |
| `buftype` | `'buftype'` | Non-empty marks a generated/auxiliary buffer |
| `hidden` | buffer info | Loaded-but-not-displayed; drives the picker marker |

**Rules**

- `lines_empty = true` together with an existing draft record is the signal to restore (§3). It is
  never assumed from `loaded = false` alone.
- `listed = false` for a buffer that `has_windows` is precisely the defect state of R-0001.

---

## 3. Reopen transition

The single state machine this feature owns. It runs on every buffer entry; it is a no-op unless a
condition below says otherwise.

| # | From | Condition | To | Requirement |
|---|------|-----------|----|-------------|
| T1 | any | buffer is not valid | unchanged, no action | — |
| T2 | any | buffer is generated output (§5) | unchanged, **not** listed | FR-018 |
| T3 | any | `listed = true` | unchanged | common case, cost is one read |
| T4 | listed + not generated output | `has_windows` and `listed = false` | **listed**, tab appears on next redraw | FR-001, FR-002 |
| T5 | T4 applied | draft record exists | listing + `filetype` + `db` + `lines` restored | FR-013, FR-014 |
| T6 | T4 applied | no draft record | listing only | FR-001 holds for any developer-opened buffer, not just queries |
| T7 | listed | buffer gains a window (split, preview, tab) | T3/T4 re-evaluated | FR-002 |
| T8 | any | session start with command-line buffers | T3/T4 evaluated once | FR-001 |
| T9 | any | buffer leaves the buffer list (close) | `lines` snapshotted into its draft record; **listing not restored** | FR-013 recovery, FR-022 |

**Rules — the invariants of the machine**

1. **T4 is the only mutation of listing, and it only ever sets it.** No transition removes a buffer
   from the buffer list (FR-021, FR-022, R-0002).
2. **T9 never restores listing by itself.** Only an explicit developer action moves the buffer
   through T4 (FR-017 as amended by A-001).
3. **T5 restores only what the close destroyed.** A buffer whose text is present is never
   overwritten by its snapshot; a buffer with no draft record is never given text (FR-013).
4. **The machine is idempotent.** Re-entering the same buffer repeatedly converges on the same state
   and performs no further writes after the first (constitution II).
5. **A buffer with no draft record still gets a tab** (T6): the tab requirement is about what the
   developer opened, not about databases.

---

## 4. The listing write

The only state change the feature performs on a buffer.

| Field | Value | Constraint |
|-------|-------|------------|
| target | buffer number | must be valid |
| option | `'buflisted'` | `false → true` only |
| guard | current value is `false` | never `true → false` |
| preconditions | T2 does not apply; the buffer has a window | |
| observable effect | `BufAdd` fires; the tab appears on the next redraw | R-0003 |

**Rules**: the write is idempotent, fires no recursive work (no transition listens for the event it
produces), and costs one option write. Nothing else in the editor's buffer options is touched by
this feature.

---

## 5. Generated-output class

Buffers that must never gain a tab, whatever else happens (FR-018).

| Field | Meaning | Source |
|-------|---------|--------|
| `dbout` | A query result over a `.dbout` file | name ends in `.dbout` (R-0008) |
| `auxiliary` | Any buffer with a non-empty `'buftype'` | DBUI drawer, quickfix, help, prompt (R-0009) |
| `opted_out` | A buffer that opts out explicitly | buffer-local flag; the extension point for a generated buffer matching neither rule |

**Rules**

1. Membership is decided **before** the listing write (T2 precedes T4). A generated buffer is never
   re-listed by this feature.
2. Membership is about *intent*, not about the current listing state. A generated buffer that is
   already listed — the `<leader>qr` summon path today — is a defect to fix at its source, not
   something the guard should compensate for (R-0008).
3. The `opted_out` rule exists so a future generated buffer can join the class without changing the
   predicate. It is documented in the module README (FR-011, FR-027).
4. A developer-opened read-only file is **not** in this class. Only the three rules above are.

---

## 6. Relationship map

```text
                opens (db_query_buffer.open)
   object + database ─────────────────────────────► Draft record ──keyed by──► Buffer
                                                            │                     │
                        snapshot on close (T9)  ◄──────────┘                     │
                                                                            │
                    Reopen transition (T1–T8) ───► is_generated_output? ──yes──► untouched
                                          │                      └─no──► listing write (§4)
                                          └────────────────────────────────► T5 restore
                                                                            (text, language, connection)
```

**Cross-entity constraints**

- One `Draft record` per live query buffer; a display name is unique among live drafts (§1.1).
- One `Buffer` may be re-entered any number of times; the transition converges (invariant 4).
- A `Draft record` with no matching `Buffer` (wiped) is discarded when its name is allocated by a new
  query, so a stale record can never restore text into an unrelated buffer.

---

## 7. Requirement coverage

| Requirement | Entity / transition |
|-------------|---------------------|
| FR-001, FR-002 | T4, T7, T8; invariant 1 |
| FR-003 | T4 precedes any save; the write does not depend on disk state |
| FR-004 | T3/T4 convergence: one buffer, one listing write |
| FR-005 | T9 → T4 → T5 return the buffer to its pre-close state |
| FR-006 | a wiped buffer has no draft record → T6, a fresh buffer is listed at creation |
| FR-008, FR-011, FR-012 | §1.1 allocation; §5 vocabulary |
| FR-013 | T9 snapshot, T5 restore; invariant 3 |
| FR-014 | T5 re-applies `filetype` and the connection |
| FR-016 | T5 re-applies the recorded URL, never a newly resolved one |
| FR-017 (as amended) | invariant 2: no self-restoration, no write |
| FR-018 | T2, §5 |
| FR-021, FR-022 | invariant 1 |