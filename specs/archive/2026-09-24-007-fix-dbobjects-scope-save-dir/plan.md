# Implementation Plan: Fix DBObjects Scope Feedback and Save Confirmation

**Branch**: `007-fix-dbobjects-scope-save-dir` | **Date**: 2026-09-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-fix-dbobjects-scope-save-dir/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

The `:DBObjects` object-search flow (spec 005) lets the user scope the listing to a chosen database, but the
scope has no stable feedback: when a scope fails (empty result, invalid name, name equal to current scope) the
user is either dropped back to the previous listing or left with nothing visible, and they cannot tell which
database the picker is in. Separately, the procedure-save dialog (spec 002/004) writes the file correctly but
never confirms where it was saved. This feature guarantees **scope-state stability and feedback** (the picker
always shows the active database, and any scope failure produces exactly one actionable message while staying
in the picker — never a silent revert to the unscoped list and never a vanishing picker), adds a
**save-confirmation notification** with the full destination path after every confirmed single write, and folds
in the pending which-key **`<leader>q` = database** keymap group. Approach: keep the flow stateless (scope is
always derived from the connection URL threaded through the picker); centralize failure handling in
`db_objects.lua` so every scope path re-opens the last-good listing with a clear notification; add one notify
call at the single write point; add one which-key group line. No persistence and no behavior change to the
save-dialog defaults (startup-root view is intentional).

## Technical Context

**Language/Version**: Lua (Neovim 0.11+, `nvim/lua/config/db_objects.lua`) + Vimscript adapter
(`nvim/autoload/db/adapter/sybase.vim`) for vim-dadbod.

**Primary Dependencies**: vim-dadbod (pack/core/opt, provides `db#url#parse`, `db#systemlist`, the `use <db>`
selection, and `db#adapter#sybase#with_database`/`objects`/`source`); fzf-lua as the `vim.ui.select` provider
(`nvim/plugin/fzf-lua.lua`). No new dependencies.

**Storage**: none — no new persisted state. The active scope is carried in the connection URL per invocation
(stateless). Saved procedure files on disk keep the existing dialog semantics.

**Testing**: headless smoke tests (`nvim/lua/tests/*_smoke.lua`, run via
`nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'`), `stylua --check nvim`,
headless whole-config startup (`nvim --headless -u nvim/init.lua '+quitall'`). Extend
`db_objects_scope_smoke.lua` (scope feedback) and `db_objects_save_smoke.lua` (save notification); add a
keymap-group check.

**Target Platform**: macOS (Neovim + sqsh) and Windows (Vim + isql), same parity as the existing Sybase
adapter. No Apple Silicon/Intel divergence.

**Project Type**: Neovim configuration module inside the macOS dotfiles repo (`nvim/`).

**Performance Goals**: no new queries or blocking work; scope failure paths only re-render the already-fetched
last-good listing.

**Constraints**: portable scope selection via the in-batch `use <db>` line (no client-specific flags); validated
database names (reject `%`, path separators, unsafe characters — keep current charset `[A-Za-z0-9_$#]`); the save
dialog must keep starting at the startup root with a **single write**; `%` (all databases) stays out of scope;
existing overwrite guard and create-directory prompts are untouched.

**Scale/Scope**: single-user Neovim config; a handful of Sybase servers with a few dozen databases; object
listings of a few thousand rows — far below any performance ceiling.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

How this plan satisfies each applicable dotfiles constitution gate:

- **Portability**: no new user-specific absolute paths; environment/registry-driven connection data; identical
  behavior on macOS and Windows through the existing portable `use <db>` mechanism.
- **Idempotency**: scope state is per-invocation and derived from the URL (stateless); repeated scope attempts and
  repeated saves do not duplicate buffers, notifications, or files; no installer behavior change.
- **Non-destructive safety**: cancelling any scope or save dialog stays a pure no-op; the single-write save flow
  and overwrite guard are preserved; the notification is display-only.
- **Modularity**: change is scoped to the Neovim module (`nvim/`); no other tool module must be installed,
  updated, or removed.
- **Source of truth**: repository-managed Lua/Vimscript and README updated in-repo; no generated files, secrets,
  or local overrides introduced.
- **Dependencies**: no new dependencies; existing vim-dadbod + fzf-lua are already declared in the module README.
- **Security**: no credentials committed; the URL (which may carry a password at runtime) is only reused
  in-memory and never logged; database names remain validated before interpolation.
- **Verification**: headless whole-config startup, `stylua --check`, extended scope/save smoke tests, the keymap
  group check, and the existing database smoke suite gate completion.
- **Installer UX**: not applicable — no installer surface is changed.
- **Recovery**: documented rollback = `git revert` of the Neovim-module changes; no state to unlink or restore.
- **Maintainability**: small additions to three existing files plus smoke-test extensions and one which-key line;
  no new abstractions or frameworks; no new persisted state.
- **Documentation**: `nvim/README.md` updated for scope feedback behavior, save confirmation notification, and the
  keymap group (FR-010), including validation and rollback.
- **Module README**: `nvim/README.md` is the module README and covers purpose, source-of-truth files,
  prerequisites, validation, customization boundaries, and rollback; it will be updated in this change.
- **Spec navigation**: `tasks.md` will include a marker legend and link each user-story phase to its matching
  `spec.md` heading; non-story phases stay unlinked.
- **Branch/PR discipline**: implementation lands on feature branch `007-fix-dbobjects-scope-save-dir`, commits use
  conventional messages targeting the branch, and PR creation verifies whether this active spec should be closed.

No violations require justification; the Complexity Tracking table is left empty.

## Project Structure

### Documentation (this feature)

```text
specs/007-fix-dbobjects-scope-save-dir/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── dbobjects-scope-save-feedback.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── README.md                    # module README — document scope feedback + save confirmation + keymap group
├── plugin/editor.lua            # ~ which-key: add `<leader>q` → group 'database' (US3 / FR-010)
├── plugin/database.lua          # (unchanged) :DBObjects wiring
├── lua/config/db_objects.lua    # ~ scope state/feedback + failure handling (US1); save confirmation
│                                #   notification after single write (US2)
├── autoload/db/adapter/sybase.vim  # (unchanged) with_database/objects/complete_database/source
├── lua/tests/db_objects_scope_smoke.lua  # + scope-feedback assertions (US1)
├── lua/tests/db_objects_save_smoke.lua   # + save-notification assertions (US2)
└── lua/tests/keymap_groups_smoke.lua     # NEW small check for the `<leader>q` group (US3)
```

**Structure Decision**: single Neovim module; all edits stay inside `nvim/`. The scope/flow logic lives in
`nvim/lua/config/db_objects.lua` (no adapter changes needed — the adapter contracts from spec 005 are reused
unchanged), the keymap group in `nvim/plugin/editor.lua`, and verification extends the existing headless smoke
suite under `nvim/lua/tests/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| —        | none       | —                                    |