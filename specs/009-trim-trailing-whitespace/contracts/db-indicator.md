# Contract: Database Context Status-Line Component

**Branch**: `009-trim-trailing-whitespace` | **Date**: 2026-09-25
**Spec**: [spec.md](../spec.md) (US4) | **Data model**: [data-model.md](../data-model.md)

The user-visible contract of the status-line element. It is stable for the lifetime of the feature:
changing any string or visibility rule below is a change to the contract.

## 1. Where it renders

| Condition | Rendering |
| --- | --- |
| `filetype = sql`, buffer has a connection, no switch in the text | database name |
| `filetype = sql`, buffer has a connection, switch in the text | database name + conflict mark naming the switch |
| `filetype = sql`, buffer has no connection | visible "no database" marker |
| any other filetype | nothing |

The component occupies the right-hand section of the status line, in both the active and the
inactive section definitions, so a database is identifiable in a window that is not focused.

## 2. Label shapes

```text
DB ventas                     connection database, no switch
DB ventas ⚠ base-a            text switches the database with `use base-a`
DB ventas ⚠ base-b..t2        text targets another database with a two-part name
DB —                          sql buffer with no connection
```

Contract rules:

1. The database name is always the name the connection declares, never the one found in the text.
2. The mark never replaces the database name; it is added beside it.
3. The mark names the switch that decides the effective database: the last `use` in the buffer if
   any, otherwise the first two-part name.
4. With a conflict, the element uses a highlight that differs from the clean state.
5. No part of the element ever contains the connection URL.

## 3. Execution-time message

Fires once per execution of a buffer whose text switches context.

```text
DB query runs on "ventas", but the text switches to "base-a". Check the statement before executing.
```

Contract rules:

1. Warning severity, never an error, and never blocking.
2. Absent when the text does not switch context.
3. Contains the connection database, the reported switch, and nothing else — no URL, no credentials.
4. Appears at most once per execution.

## 4. Buffer-scope boundary

Result buffers and the object explorer use a different filetype from query buffers and are excluded
by rule, not by a name check. A buffer that merely has a connection variable set is not enough to
make the element appear.
