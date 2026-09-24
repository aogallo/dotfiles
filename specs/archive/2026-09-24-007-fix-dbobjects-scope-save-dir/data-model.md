# Data Model: Fix DBObjects Scope Feedback and Save Confirmation

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-24

## Overview

The feature is stateless by design: every entity is derived at invocation time from the connection URL threaded
through the picker, or from a confirmed save destination. No persistence, caches, or on-disk state are added.

## Entities

### Database Scope

The database the object search runs in during one picker session.

- **Attributes**: `active` — display label: `login default` when no path in the URL, else the database name
  (from `url_database`); `source` — the connection URL carrying the scope.
- **Rules**: scope comes only from the threaded URL; no module-global mutable scope (idempotent/stateless).
  Display label rule is shared with the scope-row format and the picker header (D-2).
- **Transitions**:
  - `choose from list` → scoped URL rebuilt via `with_database` → new object listing fetched.
  - `typed name` → trimmed, validated (`[A-Za-z0-9_$#]`) → scoped URL rebuilt → new listing fetched.
  - `scope fails` (invalid name, equal to current, unreadable, empty listing) → notify once + picker re-opens on
    the last-good scope/listing; scope value unchanged.
  - `cancel in chooser` → picker returns to the last-good listing untouched (zero side effects).

### Connection URL

The resolved `sybase://[user[:password]@]host[:port]/[database][?charset=...]` carrying host, auth, current
database (path), and params.

- **Rules**: never logged or stored; reused/threaded as-is; rebuilt only by the 005 `with_database` adapter
  contract. No adapter changes in this feature.

### Object Listing Entry

One row shown by the picker: `{ name, kind, database }`.

- **Attributes**: `name`, `kind` (`table`/`view`/`procedure`/`function`), `database` (owning database from the
  scoped listing).
- **Rules**: unchanged from spec 005; rows come from `fetch_objects(url)` and are only re-rendered, never mutated
  on scope failure.

### Save Destination

The directory confirmed in the save dialog for one write.

- **Attributes**: selected via `[save here: <current>]`, subfolder navigation (`..`/dirs), or `[type a path…]`;
  relative typed paths resolve against `default_save_dir()` (the startup root).
- **Rules**: default is **always** the directory where Neovim was opened (no memory of previous choices — matches
  the user's intent: general overview). Zero writes until confirmed; a non-existent typed path triggers the
  create-directory prompt first.

### Saved Procedure File

The on-disk file produced by a confirmed save.

- **Attributes**: filename `<owning-database>.<object>.sql` (fallback `<object>.sql` for no-database rows);
  full path = `joinpath(save_destination, filename)`.
- **Rules**: exactly one file per confirmed save (single write at the write point); existing file requires the
  explicit overwrite confirmation. After a successful write the user receives one informational notification with
  the full path (D-3).

### Keymap Group (transient registry, not data)

- **Attributes**: `<leader>q` → label `database`, listing `<leader>qj`, `<leader>qu`, `<leader>qo`, `<leader>qr`
  (the four actions are unchanged, defined in `keymaps.lua`).
- **Rules**: declared once in the which-key prefix registry in `nvim/plugin/editor.lua`; display-only.

## Relationships

- **Database Scope** *owns* the **Object Listing**: the listing rows carry the scoped database name and the
  header shows the scope label.
- **Connection URL** *carries* the **Database Scope**: the active scope is read from the URL path; failure
  paths keep the last-good URL+rows pair.
- **Save Destination** *produces* **Saved Procedure File**: one destination → one write → one path in the
  confirmation notification.

## Validation rules (from spec)

| Rule | FR | Testable check |
|------|----|----------------|
| Picker header always shows active scope label | FR-001 | `login default` vs chosen name rendered in header |
| Scope choice re-lists in that database and updates header | FR-002 | header + rows change to scoped name |
| Scope failure → one actionable message + picker stays on last-good list | FR-003 | exactly 1 notify; picker re-opened; scope unchanged |
| Typed names accept `[A-Za-z0-9_$#]` incl. `_` | FR-004 | `my_schema_db` scopes correctly |
| Cancel leaves list/scope/buffers untouched | FR-005 | no side effects on cancel |
| Successful save → notification with full path+filename | FR-006 | notify carries result.path |
| One write per confirmed save | FR-007 | no file in earlier browse locations or startup root |
| Save dialog always starts at startup root | FR-008 | every invocation `pick_save_target(default_save_dir())` |
| Overwrite only after explicit confirmation | FR-009 | existing guard unchanged |
| `<leader>q` registered as `database` group | FR-010 | registry contains group; actions unchanged |