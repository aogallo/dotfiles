# Implementation Plan: Database Scope for Object Search

**Branch**: `005-database-scope` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-database-scope/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

The developer cannot choose which database the `:DBObjects` search runs in: today the arg is a
*connection* name and the listing always uses the connection's database. This feature adds a
**database-scope control** to the object-search flow: a "Database: \<current\> — change…" entry on the
Sybase object picker opens a chooser of the databases the login can read (seeded with the
connection's current database); choosing one re-runs the search inside that database and threads the
scoped URL through source loading, buffer binding, and save naming so everything executes in the
owning database. Approach: reuse the adapter's portable `use <db>` selection by **rebuilding the URL
with the chosen database as its path** (new `with_database()` adapter contract); `objects()` gains a
`database` field per row so the picker can label owners and names become database-qualified. The
cross-database `%` scan and the team procedure stay out of scope (owned by `001-multidb-object-search`).

## Technical Context

**Language/Version**: Lua (Neovim 0.11+, `nvim/lua/config/db_objects.lua`) + Vimscript adapter
(`nvim/autoload/db/adapter/sybase.vim`) for vim-dadbod.

**Primary Dependencies**: vim-dadbod (pack/core/opt, provides `db#url#parse`, `db#systemlist`, and the
job engine consumed by `objects()`/`source()`); fzf-lua as the `vim.ui.select` provider
(`nvim/plugin/fzf-lua.lua`). No new dependencies.

**Storage**: none — no new persisted state. Connection registry `vim.g.dbs` (nvim/lua/config/
db_connections.lua) untouched. Saved procedure files on disk follow the existing save dialog.

**Testing**: headless smoke tests (`nvim/lua/tests/*_smoke.lua`, run via
`nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'`), `stylua --check nvim`,
headless whole-config startup (`nvim --headless -u nvim/init.lua '+quitall'`). New
`nvim/lua/tests/db_objects_scope_smoke.lua`.

**Target Platform**: macOS (Neovim + sqsh) and Windows (Vim + isql), same parity as the existing
Sybase adapter. No Apple Silicon/Intel divergence for this change.

**Project Type**: Neovim configuration module inside the macOS dotfiles repo (`nvim/`).

**Performance Goals**: listing a single database must stay responsive (same order of magnitude as
today's `sysobjects` query); no long blocking operations added. The scope toggling path performs one
additional catalog query (`sysdatabases`).

**Constraints**: portable DB selection via the in-batch `use <db>` line (no client-specific flags);
database names validated (reject `%`, path separators, and unsafe characters); owning-database binding
for buffers and saved files; no-argument behavior preserved; the existing save dialog must keep
working unchanged; `%` (all databases) is out of scope per FR-011.

**Scale/Scope**: single-user Neovim config; connections to a handful of Sybase servers, a few dozen
databases each; object listings of a few thousand rows at most — far below any performance ceiling.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

How this plan satisfies each applicable dotfiles constitution gate:

- **Portability**: no new user-specific absolute paths; environment/registry-driven connection data;
  identical behavior on macOS and Windows through the existing portable `use <db>` mechanism.
- **Idempotency**: scope selection is per-invocation and stateless; repeated runs do not duplicate
  buffers or accumulate state; no installer behavior change.
- **Non-destructive safety**: cancelling the scope chooser or the picker is a pure no-op (no files,
  no directory changes, no buffer changes); the existing save dialog's overwrite guard is untouched.
- **Modularity**: change is scoped to the Neovim module (`nvim/`); no other tool module must be
  installed, updated, or removed (FR-015).
- **Source of truth**: repository-managed Lua/Vimscript and README updated in-repo; no generated
  files, secrets, or local overrides introduced.
- **Dependencies**: no new dependencies; existing vim-dadbod + fzf-lua are already declared in the
  module's manifest/README.
- **Security**: no credentials committed; the URL may carry a password at runtime and is only
  rebuilt/reused in-memory (never logged or stored); database names are validated before
  interpolation (FR-008).
- **Verification**: headless whole-config startup, `stylua --check`, new scope smoke test, and the
  existing database smoke suite all gate completion (FR-013).
- **Installer UX**: not applicable — no installer surface is changed.
- **Recovery**: documented rollback = `git revert` of the Neovim-module changes; no state to unlink
  or restore (FR-014).
- **Maintainability**: small additions to two existing files plus one new smoke test; no new
  abstractions or frameworks; rejects `%` explicitly to avoid dragging in the multi-DB scan.
- **Documentation**: `nvim/README.md` updated for the scope control, default behavior, binding, and
  out-of-scope cross-DB search (FR-014), including quickstart/validation and rollback.
- **Module README**: `nvim/README.md` is the module README and covers purpose, source-of-truth
  files, prerequisites, validation, customization boundaries, and rollback; it will be updated in
  this change.
- **Spec navigation**: `tasks.md` will include a marker legend and link each user-story phase to its
  matching `spec.md` heading; non-story phases stay unlinked.
- **Branch/PR discipline**: implementation lands on feature branch `005-database-scope`, commits use
  conventional messages targeting the branch, the PR links the approved issue, and PR creation
  verifies the active-spec relationship (this spec vs. `001-multidb-object-search` vs. the
  save-dialog spec) and asks whether a related completed spec should be closed.

No violations require justification; the Complexity Tracking table is left empty.

## Project Structure

### Documentation (this feature)

```text
specs/005-database-scope/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── sybase-db-scope.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── README.md                    # module README — document scope control + rollback (FR-014)
├── autoload/db/adapter/sybase.vim
│   ├── + db#adapter#sybase#with_database(url, database)   # NEW contract
│   └── ~ db#adapter#sybase#objects(url)                   # rows gain `database` field
├── lua/config/db_objects.lua
│   └── ~ object-picker flow: scope entry, scoped-url threading, db-qualified names
├── lua/tests/db_objects_scope_smoke.lua                    # NEW smoke suite (FR-013)
└── plugin/database.lua                                     # unchanged (command surface)
```

**Structure Decision**: the feature is a set of small, targeted changes to two existing Neovim-module
files (adapter + picker flow) plus a new smoke test. No new directories, entry points, or plugins are
introduced; this matches the modular-tool-boundary and simplicity principles. The picker flow change
follows the existing single-file module style of `db_objects.lua`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

None. The plan introduces no constitutional exceptions.