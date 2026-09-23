# Implementation Plan: Procedure Save Dialog

**Branch**: `002-procedure-save-dialog` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-procedure-save-dialog/spec.md`

## Summary

Extend the `:DBObjects` procedure flow so that after a procedure's source loads into a buffer, the
user is asked where to save its text to disk — every time (never skipped, never defaulting to a
previously chosen folder). Default target is the directory where Neovim was started (startup root,
captured once at plugin source time). The user can pick an available subdirectory by browsing or type an
arbitrary path; saved files are named `<owning-database>.<object-name>.sql` so same-named
procedures from different databases never collide, and an existing same-named file requires an
explicit confirm before overwriting (non-destructive, constitution-aligned).

The save dialog reuses the plumbing `db_objects.lua` already has (`vim.ui.select` → fzf-lua as its
handler, `vim.api`/`vim.fs` native APIs, `vim.fn.writefile`): zero new dependencies, zero new
configuration knobs, macOS/Windows agnostic (no database client involved).

## Technical Context

**Language/Version**: Lua 5.1/JIT (Neovim config), Vimscript 9 (user command unchanged), Neovim
0.11+ (`vim.fs.dir`, `vim.fs.parents`, `vim.ui.input`, `vim.fn.writefile` all native).

**Primary Dependencies**: Already present and unchanged — fzf-lua (already wired as the
`vim.ui.select` handler used by `db_objects.lua`), vim-dadbod (url/connection, unchanged). Native
`vim.fs`/`vim.ui`/`writefile` for the new logic; no new plugin, no database client.

**Storage**: No feature-owned persistent state. Startup root captured once at plugin source time
(`plugin/database.lua` reads `getcwd()` while sourcing, before any `:cd`), read by
`db_objects.lua`. Saved procedure files are **user-owned files in user-chosen directories** —
never repo-managed, never gitignored on the user's behalf; clearly separated from
repository-managed configuration (constitution V).

**Testing**: Headless nvim startup, `stylua --check nvim`, existing smoke tests (unchanged, still
pass), plus a NEW `lua/tests/db_objects_save_smoke.lua` covering file-name derivation, default-dir
resolution, overwrite detection, and a write-roundtrip in a throwaway temp dir (no server, no
fzf-lua UI required — the pure functions are tested directly). Manual acceptance in quickstart.

**Target Platform**: macOS (Apple Silicon + Intel) primary; the save dialog is pure Neovim Lua and
works identically on Windows — documented, no client involved.

**Project Type**: Dotfiles/Neovim-configuration feature (additive change inside one existing Lua
module).

**Performance Goals**: The dialog appears immediately after source load (no network, no server);
saving a file of any size completes in the current session (local write) — SC-001: one extra action
beyond today's flow.

**Constraints**: Non-destructive (no silent overwrite, FR-007), always-ask (default never a
previously chosen directory, FR-003), byte-exact file content (FR-005), the existing buffer-opening
flow must remain (FR-010), no new dependencies, no committed user-specific paths.

**Scale/Scope**: Single developer; procedures up to thousands of lines; dozens of saved files;
leaf-only saving (one procedure per save, FR-016 scope boundary in spec Assumptions); bulk export
out of scope.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. Startup root is discovered (`getcwd()`), not hardcoded; relative typed
  paths resolve against the startup root; the feature is pure Neovim Lua with no OS path
  assumptions beyond what Neovim already provides; Apple Silicon/Intel and Windows behave the same
  (no client executable involved).
- **Idempotency**: PASS. No installer; repeated saves are independent (FR-003 re-asks every time);
  no accumulated state, caches, or generated files; the only in-memory value (startup root) is
  read-only after capture.
- **Non-destructive safety**: PASS. Existing-file conflict → explicit confirm/alter before write
  (FR-007/SC-003); cancel produces zero writes and zero directory changes (FR-008/SC-004); the
  buffer-opening flow is preserved untouched (FR-010).
- **Modularity**: PASS. All changes are inside the nvim module
  (`nvim/lua/config/db_objects.lua`, `nvim/lua/tests/db_objects_save_smoke.lua`,
  `nvim/README.md`); no other tool module touched.
- **Source of truth**: PASS. Saved procedure files are user-owned runtime artifacts in
  user-chosen directories — explicitly out of repository governance; the only repo-managed change
  is the module source + docs. No new generated files inside the repo.
- **Dependencies**: PASS. No new dependency; all APIs used (`vim.fs`, `vim.ui`, `writefile`,
  fzf-lua) are already present in the module's runtime; nothing to declare in `dependencies.tsv`.
- **Security**: PASS. No credentials involved (procedure source is what the user already viewed);
  interaction is local file paths; no secrets created, logged, or committed.
- **Verification**: PASS. Headless startup, stylua, existing smoke tests, and the new save smoke
  test (name derivation, default resolution, overwrite detection, write roundtrip) cover success
  and failure paths (unwritable target, existing file, cancel, missing source).
- **Installer UX**: PASS. No installer surface changes; failed saves surface one actionable error
  naming the problem and Neovim keeps running (FR-009).
- **Recovery**: PASS. No destructive operation is automatic — overwrites are user-confirmed; a
  saved file is removed by the user (documented); reverting the module restores prior behavior
  with zero residual state.
- **Maintainability**: PASS. One small Lua module gains a small, pure-function block (naming,
  default-dir, overwrite check) plus a thin UI helper reusing `vim.ui.select`/`vim.fs`; no new
  abstractions or frameworks.
- **Documentation**: PASS. `nvim/README.md` DB section updated: save dialog flow, startup-root
  default, always-ask, naming/collision handling, customization boundary (none needed), validation,
  rollback (user deletes saved files).
- **Module README**: PASS. `nvim/README.md` updated in the same change covering purpose,
  source-of-truth files, prerequisites, activation, validation, customization boundaries,
  rollback/recovery, and manual-only operations (live acceptance).
- **Spec navigation**: PASS. `tasks.md` will include a marker legend and link each user-story phase
  ([US1]/[US2]/[US3]) to the matching `spec.md` heading; foundational/polish tasks stay unlinked.
- **Branch/PR discipline**: PASS. Work planned for branch `002-procedure-save-dialog` with
  conventional commits; PR will link the required approved issue and PR creation will verify the
  active-spec relationship — notably the **predecessor spec `001-multidb-object-search`**, since
  this feature consumes its row shape (`database`, `source()`) and will be asked whether that spec
  should be closed.

No MUST-level violations; no constitutional exception required.

*Post-design re-check (Phase 1):* Re-evaluated after data model, contract, and quickstart.
**Simplicity** PASS — the design adds pure functions (naming, overwrite check) and reuses existing
`vim.ui.select`/`vim.fs`/`writefile`; no new knob because the always-ask behavior and startup-root
default are fixed spec decisions. **Security** PASS — no new IO surface beyond the user's own
chosen path; **Verification** PASS — save smoke covers derivation + roundtrip headlessly;
**Recovery** PASS — every write is either fresh (new file) or explicitly confirmed (overwrite);
cancel is a total no-op. No new violations.

## Project Structure

### Documentation (this feature)

```text
specs/002-procedure-save-dialog/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output: dialog interaction, naming, default-dir decisions
├── data-model.md        # Phase 1 output: entities, validation, state transitions
├── quickstart.md        # Phase 1 output: automated + manual acceptance
├── contracts/           # Phase 1 output: db_objects-save interaction + function contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── lua/config/db_objects.lua             # EDIT: startup root via setup(); after procedure source
│                                          #       loads, run save dialog (always); name/overwrite
│                                          #       helpers; typed-path + directory-browse target picker
├── plugin/database.lua                   # EDIT: capture launch cwd (before any :cd) and hand it
│                                          #       to db_objects.setup(root)
├── lua/tests/db_objects_save_smoke.lua   # NEW:  pure-function smoke (filename, default dir,
│                                          #       overwrite, write roundtrip in temp dir)
├── README.md                             # EDIT: save dialog, startup-root default, always-ask,
│                                          #       naming, validation, rollback (constitution XIV)
└── (dependencies.tsv, pack-lock)          # UNCHANGED: no new dependency
```

**Structure Decision**: Everything lives in the existing `db_objects.lua` module and its tests; the
save dialog is deliberately a leaf addition to the procedure branch of the already-present
selection flow, so there is no new module, no new command, and no config surface.

## Complexity Tracking

> No constitutional violations to justify; this section is intentionally empty.