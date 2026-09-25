# Phase 1 Data Model: Trailing Whitespace Cleanup + Database Context Indicator

**Branch**: `009-trim-trailing-whitespace` | **Date**: 2026-09-25 | **Spec**: [spec.md](spec.md)

This is editor configuration, so the "data model" is the set of values the two features compute, the
rules that constrain them, and the states they move between. No persistence is involved: nothing here
is written to disk, and every value is derived from the buffer and the connection on demand.

## Entity: Document line outcome

The cleanup does not store anything. It maps a saved line to one of three outcomes.

| Input | Outcome | Rule |
| --- | --- | --- |
| Line with 1+ trailing whitespace that carries no meaning | whitespace removed | FR-001, FR-002 |
| Line consisting only of whitespace | becomes an empty line, never removed | FR-003 |
| Markdown prose line ending in exactly two spaces inside a paragraph | preserved | FR-004 |
| Any line inside a fenced code block or indented example | untouched | FR-005 |

Derived rules: leading indentation and tabs are never touched (FR-006); line-ending style is
preserved (FR-011); nothing runs when the user disabled auto-formatting (FR-012).

**Qualification on FR-004**: the hard-break exception holds while the main formatter is available.
When it is absent, the whitespace-only fallback trims every trailing space, including the two-space
hard breaks. This is the pre-existing behavior of the non-project markdown chain; the plan makes the
project chain behave the same way rather than adding a new exception. See
[research.md](research.md) Decision 1.

## Entity: Formatter chain

| Field | Values | Source |
| --- | --- | --- |
| Document kind | `markdown`, any other filetype with an explicit chain, any other filetype | buffer filetype |
| Project signal | present, absent | presence of a formatter configuration file in an ancestor directory |
| Selected chain | main formatter, or whitespace-only fallback | first available entry of the configured chain |
| Available formatter | available, unavailable | resolvable executable and valid configuration |

**States**

```text
                 main formatter available
   [configured chain] ─────────────────────────────▶ [main formatter runs]
        │  unavailable                                        │
        ▼                                                     ▼
   [whitespace fallback runs] ◀──── unavailable ───── [cleanup guaranteed]
        │
        │ no formatter at all available
        ▼
   [message naming the filetype, on every save]
```

Invariants: exactly one formatter runs per save (FR-009, SC-005); the whitespace fallback is always
reachable for Markdown (FR-007); a save with nothing available produces a visible message every
time, not only the first (FR-008, SC-003).

## Entity: Connection database

| Field | Type | Source | Notes |
| --- | --- | --- | --- |
| `url` | string or nil | `b:db` as string, or `b:db.conn`, or `b:db.db_url` | nil when the buffer has no connection |
| `database` | string or nil | path segment of the URL | nil for a non-Sybase URL, no path, or an empty path |

Relationship: the same two functions serve the query path and the status line (FR-025). The
executing database is the URL path, because the adapter prepends `use <database>` to every call;
the status line must not compute it any other way.

Edge values: a database name containing `$` or `#` is a normal name and is displayed intact; an
explicit `master` is displayed like any other name; a URL with no path yields no database.

## Entity: Context switch

| Field | Type | Notes |
| --- | --- | --- |
| `kind` | `use` or `object` | `use <db>` statement, or `<db>..<object>` reference |
| `name` | string | database name, for `object` the `<db>` part |
| `position` | line number | not displayed; recorded so the message can point at it if needed later |

**Selection rule**: when the buffer contains at least one `use`, the switch that decides the
effective database is the **last** one, because statements execute in order. Otherwise the first
`<db>..<object>` name is reported. The result is at most one reported switch per buffer, which keeps
the status line and the message short.

**Validation rules** (FR-021, FR-023): text inside comments and string literals is not a switch; the
name character class allows letters, digits, `_`, `$`, `#`.

## Entity: Conflict mark

| Field | Type | Notes |
| --- | --- | --- |
| `shown` | boolean | true when a context switch was detected |
| `label` | string | the connection database, always present when the buffer has a connection |
| `switch` | string or nil | the reported switch name, shown next to the label |
| `color` | highlight group | a distinct highlight when `shown` is true |

**States**

```text
   buffer is not sql filetype ─────────────────────────▶ [component renders nothing]

   sql buffer
        │
        ├── no connection ──────────────────────────▶ [ "no database" marker ]
        │
        └── connection with no switch in the text ──▶ [ database name ]
        │
        └── connection with a switch in the text ───▶ [ database name + conflict mark ]
```

Invariants: the connection database stays visible when a mark is shown (FR-017); the absence of a
connection is visible rather than silent (FR-018); the component never renders for result buffers
(FR-024); computing it performs no server call (SC-009).

## Entity: Execution-time message

| Field | Type | Notes |
| --- | --- | --- |
| `fired` | boolean | at most one per execution |
| `severity` | warning | an advisory, never a block |
| `content` | string | the connection's database and the reported switch |

Invariants: emitted only when a context switch exists (FR-019); never alters, delays or blocks the
query (FR-020); contains no URL, so no credential can leak into a notification (see
[research.md](research.md) Decision 7).

## Entity: Filetype-unavailable message

| Field | Type | Notes |
| --- | --- | --- |
| `filetype` | string | the file type the user was saving |
| `repeats` | every save | not only the first failure of the session |

Invariant: reported once per failing save, and never alongside a cleanup pass, because the cleanup
only fails when nothing was available to trim (FR-008, SC-003).

## Validation rules summary

1. A save produces exactly one formatting outcome and at most one message.
2. Cleanup never deletes a line, never changes content, and never runs when formatting is off.
3. A buffer's effective database is the URL path unless the text's last `use` says otherwise.
4. The status line and the query path never disagree about the database, because they share one
   source of truth.
5. Neither the status line nor any message exposes a connection URL.
