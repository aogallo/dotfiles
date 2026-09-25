# Implementation Plan: Multi-Database Sybase Object Search

**Branch**: `001-multidb-object-search` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/archive/2026-09-25-001-multidb-object-search/spec.md`

## Summary

Extend the Sybase path of `:DBObjects` (schema-object search) so it finds objects across every
database the login can read, opens byte-exact procedure source, and never blocks the databases it
touches. Two pillars:

1. **Native, non-blocking cross-database search** (FR-001/003/005): a read-only catalog scan built
   from what the adapter already does — `complete_database()` lists `sysdatabases`; a generated
   multi-`use` batch queries each accessible user database's `sysobjects` (joined to `sysusers` for
   the owner) at `set transaction isolation level 0`, so no shared locks are taken and writers are
   never blocked (confirmed in ASE docs). The team's stored procedure remains OPTIONAL via a new
   config value; when set, its richer columns (owner, date, time) replace the scan.
2. **Byte-exact source extraction** (FR-013/014): `sp_helptext` is replaced by reading the object's
   definition directly from `syscomments` (`id = object_id('<name>') ORDER BY number, colid2, colid`)
   and concatenating the 255-byte `text` chunks, removing the mid-token line wrapping the developer
   reported. Hidden/encrypted text (`status & 1`/`version`) surfaces an actionable notice.

`db_objects.lua` gains a database column in the picker, triggers cross-database search when a name is
given, and opens procedure buffers bound to the owning database with database-qualified names.

## Technical Context

**Language/Version**: Vimscript 9 (adapter, `autoload/db/adapter/sybase.vim`), Lua 5.1/JIT (picker
`lua/config/db_objects.lua`), Neovim 0.11+ (native `vim.pack` plugin management).

**Primary Dependencies**: tpope/vim-dadbod (adapter dispatch + `db#systemlist`/`db#url#parse`),
existing custom `sybase://` adapter, ibhagwan/fzf-lua (backend for `vim.ui.select` — already wired).
External clients unchanged: `sqsh` (macOS), SAP ASE `isql` (Windows), selected by platform or
`g:db_sybase_client`.

**Storage**: No persistent storage. New config/state is a single user-set global:
`g:db_sybase_search_proc` (OPTIONAL; Sybase two-part name, e.g. `master..mi_procedimiento`) — when
unset the native scan is used. Existing `g:db_sybase_client`/`g:db_sybase_width` unchanged.

**Testing**: Headless nvim startup, `stylua --check nvim`, adapter syntax/source check, extended
argv smoke tests (`lua/tests/sybase_objects_smoke.lua` updated for `syscomments` source; NEW
`lua/tests/sybase_search_smoke.lua` for the native scan + SP path), plus documented manual acceptance
against a live server (quickstart). No test requires a live database.

**Target Platform**: macOS (Apple Silicon + Intel) primary; Windows native (isql) documented and
covered by argv smoke.

**Project Type**: Dotfiles/Neovim-configuration feature with a small Vimscript adapter.

**Performance Goals**: Cross-database scan over the server's user databases reports in a few seconds
(SC-001: found + opened within 3 actions); picker stays responsive on large result sets; the scan
holds zero shared locks so concurrent writes are never delayed (FR-005/SC-009).

**Constraints**: Non-blocking reads (`isolation level 0`), read-only, no DDL and no temporary
objects in any target database; no committed secrets; no user-specific absolute paths; nothing may
require a live server at startup or in automated validation.

**Scale/Scope**: Single developer; ASE 15.x/16.x servers with up to dozens of user databases;
procedures up to thousands of lines (and lines > 255 bytes — the reported bug). SQL Server/MongoDB
schemes keep their current native `tables()` fallback (out of scope).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. No absolute user paths; client resolution stays `executable()` + platform
  branch; the only new knob is `g:db_sybase_search_proc` (two-part name given in the user's own
  Neovim globals, zero filesystem coupling). Apple Silicon/Intel unaffected.
- **Idempotency**: PASS. No installer changes; the adapter and picker are pure functions of the
  connection URL + globals, re-runnable with no accumulated state (search always re-queries;
  opened buffers are fresh).
- **Non-destructive safety**: PASS. The native scan and `syscomments` reads are select-only; no
  user file is written, overwritten, or migrated; no temp files created in target databases.
- **Modularity**: PASS. Everything inside the nvim module (`autoload/db/adapter/sybase.vim`,
  `lua/config/db_objects.lua`, `lua/tests/*`, `README.md`); no other tool module touched.
- **Source of truth**: PASS. Committed files = portable shared config; machine/work specifics stay
  in env vars or per-user globals; no new generated/local files introduced by the feature.
- **Dependencies**: PASS. No new dependency; `sqsh`/`isql` already declared in
  `nvim/dependencies.tsv`; the SP is optional and NOT a declared dependency (native path works
  without it) — documented so.
- **Security**: PASS. `syscomments.text` select is escaped (single quotes doubled) for every
  interpolated object name; credentials continue to flow only through the existing argv path; no
  secrets in the adapter, docs, or specs. Note: restricted/encrypted `syscomments.text` (evaluated
  configuration) yields an actionable notice, never a crash (FR-014).
- **Verification**: PASS. Headless startup, stylua, adapter source check, argv smoke tests for
  search + source (stubbed `db#systemlist` with canned multi-DB and multi-chunk output), and
  documented manual acceptance cover success and failure paths (missing client, empty result,
  hidden text, partial DB access).
- **Installer UX**: PASS. No installer surface; startup/runtime degrade with single actionable
  messages (unconfigured SP → native scan silently; `%`/no matches → no-match state).
- **Recovery**: PASS. Reverting the adapter/picker restores prior single-DB `sp_helptext` behavior;
  no destructive operations introduced; no backups required.
- **Maintainability**: PASS. Reuses `s:run_query`'s client/argv path and the existing parser
  conventions; the SP knob mirrors the existing `g:db_sybase_client` pattern; no new abstractions.
- **Documentation**: PASS. `nvim/README.md` DB section updated: native scan, optional
  `g:db_sybase_search_proc`, `syscomments` extraction, picker database column, validation, rollback.
- **Module README**: PASS. `nvim/README.md` is updated in the same change (purpose, source files,
  prerequisites, activation, validation commands, customization boundaries, rollback).
- **Spec navigation**: PASS. `tasks.md` will include a marker legend and link every user-story
  phase ([US1]/[US2]/[US3]) to the matching `spec.md` heading; setup/foundational/polish phases stay
  unlinked.
- **Branch/PR discipline**: PASS. Work is planned for `001-multidb-object-search` with conventional
  commits; PR creation will link the required approved issue and verify the active-spec relationship
  and closure of the related completed spec.

No MUST-level violations; no constitutional exception required.

*Post-design re-check (Phase 1):* Re-evaluated after the data model, contracts, and quickstart were
produced. **Simplicity** PASS — no new dependency, both pillars reuse functions already in the
adapter (`run_query`, `complete_database`, `first_tokens`). **Security** PASS — every interpolated
value is single-quote-escaped; hidden-text detection is read-only. **Verification** PASS — smoke
tests assert both the multi-DB scan argv and the `syscomments` source argv headlessly. **Recovery**
PASS — revert restores `sp_helptext`/single-DB behavior. No new violations.

## Project Structure

### Documentation (this feature)

```text
specs/archive/2026-09-25-001-multidb-object-search/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output: ASE catalog + isolation-0 facts, decisions
├── data-model.md        # Phase 1 output: result rows + config knobs + validation
├── quickstart.md        # Phase 1 output: automated + manual acceptance
├── contracts/           # Phase 1 output: sybase-search contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── autoload/db/adapter/sybase.vim        # EDIT: add object_search() (native scan + optional SP),
│                                          #       rewrite source() to syscomments extraction
├── lua/config/db_objects.lua             # EDIT: name → cross-db search(); db column in picker;
│                                          #       db-qualified buffers bound to owning db
├── lua/tests/sybase_objects_smoke.lua    # EDIT: source() now asserts syscomments query + reassembly
├── lua/tests/sybase_search_smoke.lua     # NEW:  argv smoke for native scan (isolation 0, multi-DB
│                                          #       batch) and optional SP path
├── README.md                             # EDIT: DB section — scan, g:db_sybase_search_proc,
│                                          #       syscomments fidelity, picker db column, validation
└── fetch-manifest? (nvim-pack-lock.json) # UNCHANGED: no new plugins
```

**Structure Decision**: Everything is scoped to the existing Neovim module, extending the adapter
convention dadbod already discovers (`autoload/db/adapter/sybase.vim`) and the existing
`db_objects.lua` picker. No new files outside `lua/tests/`.

## Complexity Tracking

> No constitutional violations to justify; this section is intentionally empty.