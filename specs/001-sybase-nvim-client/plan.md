# Implementation Plan: Sybase / Neovim Database Client

**Branch**: `001-sybase-nvim-client` | **Date**: 2026-08-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-sybase-nvim-client/spec.md`

## Summary

Turn the existing dadbod stack in the Neovim module into a full database client that replaces
isqlw/Crimson for large Sybase stored procedures, and unifies Sybase ASE, SQL Server, and
MongoDB behind one user-controlled connection registry. vim-dadbod lacks a Sybase adapter, so
this feature adds a small custom adapter (`sybase://` scheme) that shells out to `sqsh` on macOS
and the SAP `isql` client on Windows (auto-selected by OS). Connections are defined in a single
Lua file the user locates via `NVIM_DB_CONNECTIONS` (gitignored, credentials keepable in
env vars), surfaced through dadbod-ui's `g:dbs`, with completion wired into blink.cmp via
vim-dadbod-completion's blink provider. A schema object search (`:DBObjects`, fzf-lua) provides
SSMS-like name filtering across all supported databases, and on Sybase loads a stored
procedure's full source into a buffer for editing (FR-022). Windows client installs are
documented in the Neovim module README.

## Technical Context

**Language/Version**: Vimscript 9 (adapter autoload), Lua 5.1/JIT (Neovim config), Neovim 0.11+
(vim.pack native plugin management).

**Primary Dependencies**: tpope/vim-dadbod, kristijanhusak/vim-dadbod-ui,
kristijanhusak/vim-dadbod-completion (blink provider `vim_dadbod_completion.blink`),
saghen/blink.cmp (already present), ibhagwan/fzf-lua (already present; used by the schema
object search picker). External clients: `sqsh` (macOS), SAP ASE `isql` (Windows),
`sqlcmd`/`go-sqlcmd` (SQL Server), `mongosh` (MongoDB).

**Storage**: No database storage. Config files under `nvim/`; user-owned connection registry
file outside the committed tree (gitignored default in the linked config dir, or any path via
`NVIM_DB_CONNECTIONS`).

**Testing**: Headless nvim startup, `stylua --check nvim`, adapter source/syntax check, an argv
smoke test for the adapter (stubbed `db#url#parse`), an argv smoke test for the
`objects`/`source` hooks, registry-load test, plus documented manual acceptance against live
servers (quickstart).

**Target Platform**: macOS (Apple Silicon + Intel) primary; Windows native documented for client
installs and the same workflow.

**Project Type**: Dotfiles/editor-configuration feature with a small Vimscript adapter.

**Performance Goals**: SC-001 — results for a query that executes in <1s on the server render in
Neovim within 5s of the execution command.

**Constraints**: No committed secrets; no user-specific absolute paths; idempotent and
non-destructive setup; silent truncation of stored-procedure output is unacceptable; nothing in
this feature may require a live DB server at startup or in validation.

**Scale/Scope**: 3 database types (Sybase ASE, SQL Server, MongoDB), a single developer, large
stored procedures (hundreds to thousands of lines) and multi-result-set output.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. No absolute user paths committed; client resolution via `executable()`
  + platform branch; registry location via env var (`NVIM_DB_CONNECTIONS`) with a documented
  default; machine/work values stay in env or the ignored local registry; Apple Silicon and
  Intel covered (`sqsh` is brew-installable on both); Windows documented, not half-configured.
- **Idempotency**: PASS. No installer changes; the loader only assigns `g:dbs` (re-assignable,
  no duplication); example file is a static template; `nvim-pack-lock.json` gains deterministic
  pinned revs for the added plugins.
- **Non-destructive safety**: PASS. Existing dadbod/dadbod-ui config and `g:db_ui_save_location`
  are preserved; the registry loader never overwrites user files; the adapter only reads buffer
  input and writes to OS temp files, never mutating user SQL files.
- **Modularity**: PASS. All changes are inside the nvim module (`nvim/plugin/*.lua`,
  `nvim/autoload/db/adapter/sybase.vim`, `nvim/lua/config/`, `nvim/dependencies.tsv`,
  `nvim/README.md`) plus one `.gitignore` line; other tool modules are untouched and optional.
- **Source of truth**: PASS. Committed repo files = shared portable config + example template;
  user registry file = ignored local state; secrets live only in env or the ignored registry.
- **Dependencies**: PASS. `nvim/dependencies.tsv` declares `sqsh` (homebrew), `mongosh`
  (homebrew), `sqlcmd` (homebrew/go) as optional; isql is documented for Windows; `nvim/README.md`
  gains prerequisites; missing-client errors are surfaced by dadbod's `executable()` check.
- **Security**: PASS. `nvim/db-connections.lua` is gitignored; `db-connections.example.lua` has
  no real credentials; URLs may embed `$VAR` placeholders resolved from the environment by
  dadbod; no credentials in the adapter, docs, or lockfile.
- **Verification**: PASS. Headless startup, stylua, adapter source check, argv smoke test,
  registry-load test, and a documented manual acceptance run (quickstart) cover success and
  failure paths (missing client, missing registry, connection refused).
- **Installer UX**: PASS. No installer surface changes; startup behavior with a missing registry
  or missing client degrades with clear, single actionable errors.
- **Recovery**: PASS. Removing the ignored registry file or reverting the config restores prior
  behavior (existing `g:db_ui_save_location` data untouched); adapter temp files are OS-managed;
  no destructive operations introduced.
- **Maintainability**: PASS. Adapter is one small Vimscript file mirroring dadbod's own adapter
  pattern (sqlserver.vim as reference); registry loader is ~20 lines of Lua; no new abstractions
  or frameworks beyond what dadbod already defines.
- **Documentation**: PASS. `nvim/README.md` updated with connection registry usage, client
  prerequisites (macOS + Windows), validation, customization/override boundaries, and rollback;
  `docs/windows-tooling-audit.md` is referenced for Neovim-on-Windows.
- **Module README**: PASS. `nvim/README.md` is updated in the same change, covering purpose,
  source-of-truth files, prerequisites, install/activation, validation, customization
  boundaries, rollback/recovery, and manual-only operations (live-server acceptance).
- **Spec navigation**: PASS. `tasks.md` will include a marker legend and link every user-story
  phase to the matching `spec.md` heading; setup/foundational/polish phases stay unlinked unless
  they have a clear story owner.
- **Branch/PR discipline**: PASS. Implementation will be developed on `001-sybase-nvim-client`
  (feature branch) with conventional commits; the PR will link the required approved issue and
  PR creation will verify the active-spec relationship and whether a related completed spec
  should be closed.

No MUST-level violations; no constitutional exception required.

*Post-design re-check (Phase 1):* Re-evaluated after adding `:DBObjects` (object search +
procedure source loading, FR-022). **Simplicity** PASS — reuses the already-present fzf-lua
picker, no new dependency; **Verification** PASS — the `objects`/`source` argv smoke test
covers the new hooks headlessly; **Security** PASS — `source()` only reads server-side object
text and never interpolates raw user input into SQL; **Documentation** PASS — `nvim/README.md`
documents `:DBObjects` usage and the Sybase-only source-load limitation; **Portability** PASS —
Lua module + adapter are OS-agnostic, ISQL vs sqsh handling unchanged. No new violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-sybase-nvim-client/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── autoload/db/adapter/sybase.vim        # NEW: sybase:// adapter (sqsh macOS / isql Windows)
├── lua/config/db_connections.lua         # NEW: registry loader → g:dbs (NVIM_DB_CONNECTIONS)
├── lua/config/db_objects.lua             # NEW: :DBObjects fzf-lua picker + procedure source load
├── plugin/database.lua                   # EDIT: add vim-dadbod-completion, wire loader + sybase table helper
├── plugin/blink.lua                      # EDIT: add dadbod provider + per_filetype sql
├── dependencies.tsv                      # EDIT: add sqsh, mongosh, sqlcmd (optional)
├── README.md                             # EDIT: registry, prerequisites (macOS+Windows), validation, rollback
├── db-connections.example.lua            # NEW: committed template, no secrets
└── nvim-pack-lock.json                   # EDIT: pinned revs for new plugins

.gitignore                                # EDIT: ignore nvim/db-connections.lua
docs/windows-tooling-audit.md             # REFERENCE (no change): Neovim-on-Windows install
```

**Structure Decision**: Everything is scoped to the existing Neovim module, extending its current
dadbod/dadbod-ui configuration. The adapter follows dadbod's own convention (`autoload/db/adapter/
<scheme>.vim`) so it is discovered from the runtimepath with zero custom wiring.

## Complexity Tracking

> No constitutional violations to justify; this section is intentionally empty.
