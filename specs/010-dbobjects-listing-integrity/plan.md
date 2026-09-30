# Implementation Plan: Trusted `:DBObjects` Listing

**Branch**: `010-dbobjects-listing-integrity` | **Date**: 2026-09-25 | **Spec**: [spec.md](spec.md)
**Issue**: [#92](https://github.com/aogallo/dotfiles/issues/92)

**Input**: Feature specification from [`specs/010-dbobjects-listing-integrity/spec.md`](spec.md)

**Phase 0 artifacts**: [research.md](research.md) · **Phase 1 artifacts**: [data-model.md](data-model.md) ·
[contracts/sybase-listing-integrity.md](contracts/sybase-listing-integrity.md) ·
[quickstart.md](quickstart.md)

## Summary

Fix issue #92: `:DBObjects` silently returns the **wrong database's** objects under a label naming
the database the developer chose, and silently omits whole object kinds. Two independent defects,
one reported symptom.

**Root cause found** ([research.md](research.md) R-0001): ASE stores `sysobjects.type` as
**`char(2)`**, and several kinds are two characters — triggers are `TR`, user-defined functions are
`SF`, extended procedures are `XP`. The listing queries `type in ('U','V','P','F','X')` and parses
each row with a single-character regex `^[UVPFX]$`. Consequences: `X` never matches `XP`, `F`
matches only rare SQLJ functions so ordinary functions were never listed, and `TR` is not queried
at all — **no trigger has ever been listable**. Separately, the selected database is applied with a
`use` line whose acceptance is never checked, so a rejected switch leaves the session on the login
default and that database's objects get labelled with the requested name.

**Technical approach**: (1) verify the database by state — `select db_name()` compared against the
request — instead of trusting the absence of errors; (2) query the correct two-character type
values and drop the single-character parser; (3) give every emitted row a marker prefix so
headings, trailers and wrapped names can no longer be silently mistaken for, or dropped as, data;
(4) add a direct-open entry so any object is reachable by name from the confirmed database, reusing
the source reader that already exists. All of it inside a **two-request budget per invocation**
(R-0008) that does not grow with database size.

## Technical Context

**Language/Version**: Lua 5.1-compatible (Neovim LuaJIT) and VimScript; Neovim ≥ 0.9 (module
already uses `vim.api.nvim_create_user_command`, `vim.ui.select`, `vim.fn`)

**Primary Dependencies**: `vim-dadbod` + `vim-dadbod-ui` (lazy-loaded, `setup = false`);
`fzf-lua` (deferred, provides the `vim.ui.select` implementation). Server side: an ASE command-line
client — `sqsh` (preferred) or `isql` (fallback), chosen at runtime. **No new dependency is
introduced.**

**Storage**: N/A — the feature is read-only. It issues catalog `select`s and nothing else: no
writes, no DDL, no temporary objects (FR-033).

**Testing**: headless Neovim Lua smoke tests, one file per concern, following the existing stub
pattern (a fake `sqsh`/`isql` on `PATH` plus a temporary `autoload/db.vim` overriding
`db#systemlist`). Run with `nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'`.
No test framework, no runner script — the README documents each command.

**Target Platform**: macOS (Apple Silicon and Intel), driven from Neovim against a remote ASE server

**Project Type**: dotfiles module (Neovim configuration) inside a larger dotfiles repository

**Performance Goals**: ≤ 2 client invocations per `:DBObjects` invocation, and the *same* count for
a 50-object and a 50,000-object database. Wall clock within 2× today's listing. No per-database or
per-object request anywhere in the flow.

**Constraints**:
- Read-only against the server; must not take locks that block other work (FR-033)
- The request count MUST NOT scale with database size (FR-041) — the developer's explicit
  performance condition
- Must work on both supported clients (`sqsh` and `isql`) with no extra round trips for either
- Must degrade to a clear message, never a wrong or empty listing
- `g:db_sybase_source_mode` (`catalog` | `showsql`) must keep working unchanged

**Scale/Scope**: one command (`:DBObjects`), one picker, six covered object kinds, one new picker
entry. Three source files plus tests and documentation. No new module, no installer change.

## Constitution Check

*GATE: evaluated before Phase 0 and re-evaluated after Phase 1. No unresolved MUST-level violation.*

| Principle | Assessment | Evidence |
|-----------|-----------|----------|
| **I. Portable by Default** | PASS | No new paths. Detection uses the client already on `PATH` via the existing `executable()` check. Nothing architecture-specific; the module is pure Lua/VimScript. FR-032. |
| **II. Idempotent Installation** | PASS (N/A) | No installer, dotfile link, or generated state is touched. Repeated `:DBObjects` invocations are idempotent by construction: each re-derives its own confirmed scope. |
| **III. Non-destructive** | PASS | Strictly read-only `select`s. The fix *removes* a silent-failure mode that could mislead a developer into editing or running against the wrong database. FR-033. |
| **IV. Modular Tool Boundaries** | PASS | Confined to the Neovim database module (three files, R-0007). No other module changes; Neovim remains installable without a database server. FR-034. |
| **V. Repository Source of Truth** | PASS | No generated file, no local state, no work-setting. Connection details continue to come from the untracked local registry; no new configuration surface. |
| **VI. Reproducible Dependencies** | PASS | **No new dependency.** The `sqsh`/`isql` prerequisite is already declared in `nvim/README.md` and already detected via `executable()`; this change upgrades the missing-client case from silent-empty to an actionable message. FR-035. |
| **VII. Security & Secret Hygiene** | PASS | Credentials keep flowing through the existing URL, unchanged. The existence probe reads only `master..sysdatabases.name`. No secret is logged, echoed into a message, or written. FR-036. |
| **VIII. Verification Before Completion** | PASS | All three existing smoke suites must still pass; new coverage for confirmation, each rejection path, the corrected kind set, the marker parse, the direct-open entry and its two guards. FR-037, SC-009. |
| **IX. Clear Installer Experience** | PASS (analogous) | The installer is untouched, but the UX principle carries over and is the point of User Story 4: exactly one actionable message per failure, naming the subject and the causes. FR-003, FR-023, FR-024. |
| **X. Recovery and Rollback** | PASS | Rollback is `git revert` on the feature branch; no migration, no persisted state, nothing to restore. Source loading and saving are unchanged, so the existing save-flow recovery is untouched. |
| **XI. Simplicity & Maintainability** | PASS | The marker query is a few lines. The confirmation is one extra `select` in an existing batch. The direct-open entry reuses the existing source reader rather than adding a path (R-0006). No new abstraction, no framework. The main *simplification* is deleting the single-character type assumption that caused the bug. |
| **XII. Documentation & Governance** | PASS | FR-038 requires `nvim/README.md` updated in the same change and requires the **stale documented kind set corrected** — `db_objects.lua:137-139` currently documents a third set (`'P','FN','IF','TF','V','U'`) matching neither the code nor the vendor table. |
| **XIII. Feature Branch & PR Discipline** | PASS | Work on `010-dbobjects-listing-integrity`, not `main`. Conventional commits, PR linking issue #92. Before opening the PR, verify scope fit against this spec and **ask the developer whether to close it as the completed solution**. FR-039. |
| **XIV. Module README Contract** | PASS | `nvim/README.md` carries purpose, source-of-truth, prerequisites, validation commands, customization boundaries and manual-only operations. Updated in the same change. FR-038. |
| **XV. Spec Artifact Navigation** | PASS | `tasks.md` will carry a marker legend and link each user-story phase to its `spec.md` heading; artifacts cross-link relatively. FR-040. |

**Complexity Tracking**: no violations to justify — the table is intentionally empty.

## Project Structure

### Documentation (this feature)

```text
specs/010-dbobjects-listing-integrity/
├── spec.md                                    # the specification
├── plan.md                                    # this file
├── research.md                                # Phase 0 — root cause + decisions R-0001..R-0008
├── data-model.md                              # Phase 1 — entities, states, transitions
├── quickstart.md                              # Phase 1 — validation guide (incl. live-server checks)
├── contracts/
│   └── sybase-listing-integrity.md            # Phase 1 — adapter & picker contracts
├── checklists/
│   └── requirements.md                        # spec quality checklist
├── tasks.md                                   # Phase 2 (/speckit.tasks — not created here)
└── verify-report.md                           # after implementation
```

### Source Code (repository root)

```text
nvim/
├── autoload/db/adapter/sybase.vim             # MODIFIED — SQL: kind filter, marker query,
│                                              #   count row, db_name() confirmation,
│                                              #   existence probe, diagnostic surfacing,
│                                              #   two-letter kind mapping
├── lua/config/db_objects.lua                  # MODIFIED — confirmed-scope state, scope label,
│                                              #   direct-open entry, failure messages,
│                                              #   reconciliation display
├── lua/config/db_context.lua                  # unchanged — url_database() already supplies
│                                              #   the requested name; no change needed
├── plugin/database.lua                        # unchanged — :DBObjects already accepts the
│                                              #   optional connection argument
├── README.md                                  # MODIFIED — corrected kind set, new entry,
│                                              #   updated validation commands
└── lua/tests/
    ├── sybase_objects_smoke.lua               # EXTENDED — corrected type values, marker parse,
    │                                          #   count row, confirmation, existence probe,
    │                                          #   diagnostics no longer discarded
    ├── db_objects_scope_smoke.lua             # EXTENDED — confirmed-scope label, failure paths,
    │                                          #   direct-open entry + its two guards
    ├── db_objects_save_smoke.lua              # unchanged — save flow is out of scope
    └── keymap_groups_smoke.lua                # unchanged
```

**Structure Decision**: the repository is a single-project dotfiles tree, not a multi-package
workspace, so only the relevant subtree is shown. The existing convention — SQL in
`autoload/db/adapter/<backend>.vim` behind a `db#adapter#<backend>#*` autoload surface, flow and
UI in `lua/config/*.lua`, one `lua/tests/*_smoke.lua` per concern — is followed exactly. The
backend boundary means the Sybase-only scope logic never leaks into the picker module, and the
picker module never emits SQL. No new directory, no new module.

## Phase 0 → Phase 1 handoff

All Phase 0 unknowns are resolved in [research.md](research.md); Technical Context above has no
`NEEDS CLARIFICATION`. The two items that cannot be settled from documentation and need a live ASE
server are carried into [quickstart.md](quickstart.md) as named confirmations rather than being
assumed away: whether `IT` rows are returned alongside `TR`, and whether `db_id()` conflates
"absent" with "not permitted" (which is why the existence probe reads `master..sysdatabases`
explicitly).
