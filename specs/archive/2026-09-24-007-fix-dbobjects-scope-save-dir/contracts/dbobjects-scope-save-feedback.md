# Contract: Database-Scope Feedback and Save Confirmation

**Spec**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md) | **Data model**: [data-model.md](../data-model.md)
**Date**: 2026-09-24

This contract governs the user-visible behavior of the `:DBObjects` scope flow and the procedure-save
confirmation in `nvim/lua/config/db_objects.lua` and the which-key registration in `nvim/plugin/editor.lua`.
Adapter (`nvim/autoload/db/adapter/sybase.vim`) contracts from spec 005 are reused unchanged.

## §1 Scope display contract

- The object-search picker MUST always render the active database scope in its header:
  - no database in the connection URL → `login default`;
  - otherwise → the database name read from the URL path (`url_database`).
- The scope row keeps the existing format `Database: <x> — change…` using the same label rule.
- Re-rendering the header MUST happen on every `pick(...)` call — successful re-list, scope-cancel, and
  scope-failure re-opens alike. (FR-001/FR-002)

## §2 Scope failure-handling contract

Every attempt to apply a database scope MUST end in one of exactly two outcomes, never a third:

1. **Success**: the picker re-opens listing the scoped database with the header showing the scoped name, and the
   scope row reflects the new label. (FR-002)
2. **Failure**: the user sees **exactly one** actionable notification naming the typed/picked name and the
   reason detected (invalid characters, name equals current scope, or no readable objects returned), and the
   picker re-opens on the **last-good** listing with the previous scope unchanged. (FR-003)

- Explicit prohibition: the flow MUST NOT silently return to the unscoped listing without an explanation, MUST
  NOT leave the user with no picker after a failed scope, and MUST NOT clear or reset the previous scope state
  on a failed attempt. (FR-003)
- Cancelling the scope chooser or the typed-name prompt MUST return to the last-good listing with zero side
  effects. (FR-005)
- Typed names accept `[A-Za-z0-9_$#]` (letters, digits, `_`, `$`, `#`); an underscore-only deviation such as
  `my_schema_db` is valid and MUST scope correctly. (FR-004)

## §3 Save-notification contract

- A confirmed save MUST write exactly **one** file, in the directory the user confirmed. Files MUST NOT be
  written to earlier browse locations or the startup root when the user navigated elsewhere. (FR-007/FR-008)
- After a successful write, the user MUST receive exactly **one** informational notification containing the full
  resolved path and filename of the written file. (FR-006)
- The notification fires from the single write point so the fresh-save and the overwrite paths each notify
  exactly once per confirmed save.
- The overwrite guard (explicit choice before replacing an existing file) and the create-directory prompt for
  missing typed paths MUST behave unchanged. (FR-009)

## §4 Keymap-group contract

- `<leader>q` MUST be registered as the `database` group in the which-key prefix registry; pressing `<leader>q`
  alone shows a `database` group containing `<leader>qj`, `<leader>qu`, `<leader>qo`, and `<leader>qr`,
  without changing the action mappings themselves. (FR-010)

## §5 Verification contract

- Behavior is verified headlessly with the smoke suite in `nvim/lua/tests/`:
  - scope success/failure/cancel outcomes against stubbed adapter + `vim.ui.select`/`vim.ui.input`
    (`db_objects_scope_smoke.lua`);
  - save confirmation + single-write assertions (`db_objects_save_smoke.lua`);
  - which-key group registry check (`keymap_groups_smoke.lua`).
- Whole-config startup and `stylua --check nvim` must pass before completion.