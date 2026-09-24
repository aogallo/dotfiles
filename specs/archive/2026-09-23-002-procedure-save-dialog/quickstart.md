# Quickstart: Procedure Save Dialog

Validation guide for `002-procedure-save-dialog`. Two layers: **automated checks** (no live
server, no picker interaction) and **manual acceptance** (interactive, on any machine with the
config).
Contract: [contracts/db_objects-save.md](./contracts/db_objects-save.md).
Data model: [data-model.md](./data-model.md). Research: [research.md](./research.md).

## Prerequisites

- Neovim 0.11+ with this repo's config (see `nvim/README.md`).
- The `:DBObjects` flow already working (parent feature `001-multidb-object-search`: a `sybase://`
  connection and readable procedure source).
- No additional tools: the save dialog is pure Neovim Lua (no database client involved).

## Automated validation (no server required)

Run from the repo root:

```sh
# 1. Headless startup of the whole config
nvim --headless -u nvim/init.lua '+quitall'

# 2. Lua formatting check
stylua --check nvim

# 3. Wiring check: module loads headlessly and the startup-root capture exists
nvim --headless -u nvim/init.lua '+lua require("config.db_objects")' '+qa!'

# 4. Save-flow smoke test (pure functions, no UI):
#    - suggest_save_name("db","proc") → "db.proc.sql"; no database → "proc.sql"
#    - startup-root default = the path handed to setup()
#    - overwrite detection: writing over an existing file requires confirm_overwrite
#    - write roundtrip in a temp dir: content on disk == source lines
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'

# 5. Existing suite still green (predecessor features)
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
```

Expected: all commands exit 0; test 4 prints its assertions (all pass); test 3 degrades to the
existing "no registered connections" notice without crashing.

## Manual acceptance (interactive)

### US1 — Save a selected procedure to a chosen directory (P1)

1. **Given** a readable procedure selected through `:DBObjects`, **When** its source opens, **Then**
   a save dialog appears immediately with the directory where Nvim was started as the default.
   → FR-001/FR-002, SC-001.
2. **Given** the dialog at the default, **When** the user confirms, **Then** one file
   `<database>.<name>.sql` containing the exact source appears in that directory. → FR-005/006.
3. **Given** the dialog, **When** the user browses (or types) another directory and confirms,
   **Then** the file is created there, not in the default. → FR-004.

### US2 — Is asked where to save on every save (P1)

1. **Given** a procedure was just saved to a non-default folder, **When** another procedure is
   selected, **Then** the dialog opens again — never skipped — and defaults to the startup
   directory, not the previous folder. → FR-003, SC-002.
2. **Given** any number of consecutive saves, **When** each selection is made, **Then** the dialog
   always appears. → FR-001.

### US3 — Save without collisions or data loss (P2)

1. **Given** the chosen folder already contains `<name>.sql`, **When** the user confirms the save,
   **Then** the user is informed and must explicitly choose overwrite or cancel; nothing is
   overwritten silently. → FR-007, SC-003.
2. **Given** two same-named procedures from different databases, **When** both are saved to the
   same folder, **Then** two distinct `<database>.<name>.sql` files exist. → FR-006, SC-005.
3. **Given** the dialog (any step), **When** the user presses ESC, **Then** no file is created, no
   directory is changed, and the opened procedure buffer is untouched. → FR-008, SC-004.
4. **Given** an unreadable/encrypted procedure, **When** selected, **Then** the existing unreadable
   notice appears and no save dialog/empty file is produced. → FR-010.
5. **Given** a target directory that is not writable, **When** the save is confirmed, **Then** one
   actionable error appears and Nvim keeps running. → FR-009.

## Known limitations (accepted)

- The save dialog is triggered automatically after every procedure selection (per the user's
  request); there is intentionally no "don't ask" config knob in this feature.
- Saving writes a fresh copy to disk; it does not move or overwrite the opened buffer, and the
  buffer's execute flow keeps talking to the owning database (the file is a static snapshot).
- Bulk export of many procedures at once is out of scope.