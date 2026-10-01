# Implementation Plan: Query Buffer Always Shows Its Tab

**Branch**: `011-query-buffer-tab-visibility` | **Date**: 2026-09-30 | **Spec**: [spec.md](spec.md)
**Issue**: [#96](https://github.com/aogallo/dotfiles/issues/96)

**Input**: Feature specification from [`specs/011-query-buffer-tab-visibility/spec.md`](spec.md)

**Phase 0 artifacts**: [research.md](research.md) · **Phase 1 artifacts**: [data-model.md](data-model.md) ·
[contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md) ·
[quickstart.md](quickstart.md)

## Summary

Fix issue #96: a query buffer that the developer closes and then brings back has no tab in the
buffer row, while the buffer is in front of them. Investigation found **four** defects, not one,
and they compound into the reported symptom:

1. **The close unregisters the buffer.** `:bdelete` clears `'buflisted'`; `:buffer N` does not set it
   back — only `:edit <name>` and fzf-lua's explicit workaround do. That is the "for some reason"
   ([research.md](research.md) R-0001). bufferline only renders buffers with `listed == 1`
   (`utils/init.lua:150`) and exposes no option to relax it.
2. **Reopening the same query raises `E95`.** The closed buffer still owns the display name, so
   `nvim_buf_set_name` at `db_objects.lua:258` throws, and the rest of `open_buffer` — filetype,
   `b:db`, focus — never runs. The developer gets a tab labelled `[No Name]` next to stale content
   (R-0005).
3. **The close destroys the query's database binding.** `bdelete` unloads the buffer and `b:`
   variables do not survive an unload, so a reopened query has no connection (R-0006).
4. **The close destroys the query text.** The buffer's file does not exist until saved, so reopening
   shows an *empty* buffer with the right name (R-007).

**Technical approach** — one guard, one registry, three deletions:

- a small **buffer-visibility guard** that re-lists any displayed, developer-opened buffer on entry
  (`BufEnter`/`BufWinEnter`/`TabEnter`/`VimEnter`). It only ever *adds* listing, never removes it, so
  close semantics cannot change (R-0002, R-0003);
- a **generated-output exclusion predicate** (`*.dbout`, non-empty `'buftype'`, explicit opt-out) so
  the guard never promotes a result buffer or the DBUI drawer (R-0009), plus a correction to the
  `<leader>qr` summon path, which today leaks a `.dbout` buffer into the tab row (R-0008);
- a **session-local query draft registry** in the database module that owns the display name, the
  connection URL and the buffer text, and re-applies all three on re-entry (R-0005, R-0006, R-0007);
- `open_buffer` stops creating a second buffer for a name that is already taken, so the `E95` class
  disappears instead of being caught and hidden.

No new dependency, no new keymap, no disk writes, no bufferline option change.

## Technical Context

**Language/Version**: Lua 5.1-compatible (Neovim LuaJIT) and VimScript; Neovim ≥ 0.9, developed and
verified against **0.12.1** (Homebrew). The module already uses `vim.api.nvim_create_autocmd`,
`vim.api.nvim_buf_set_option`, `vim.bo[]`, `vim.fs.*`.

**Primary Dependencies**: `akinsho/bufferline.nvim` (the tab row under repair),
`tpope/vim-dadbod` + `kristijanhusak/vim-dadbod-ui` (query and result buffers),
`junegunn/fzf-lua` (`<leader>bb` buffer picker), `folke/snacks.nvim` (`<leader>bo` delete others,
notifications). **No new dependency is introduced.**

**Storage**: none. Draft records are session-local in-memory tables; nothing is written to disk by
this change (FR-017, amended by A-001 — see Spec amendments).

**Testing**: headless Neovim Lua smoke tests, one file per concern, following the existing pattern
(plain `check()` helpers, `vim.print('PASS'/'FAIL')`, `:cquit` on failure). Run with
`nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'` for tests that must not load
plugins, and `-u nvim/init.lua` for tests that need the real configuration. `stylua --check nvim`
for formatting. No test framework, no runner — `nvim/README.md` documents each command.

**Target Platform**: macOS (Apple Silicon and Intel), inside Neovim; no server involvement — every
change in this feature is local editor state, so no live database is needed to validate it (unlike
[010](archive/../010-dbobjects-listing-integrity/spec.md)).

**Project Type**: dotfiles module (Neovim configuration) inside a larger dotfiles repository.

**Performance Goals**: the guard costs one `vim.bo[bufnr].buflisted` read per buffer entry in the
common case (already listed → return). No timer, no polling, no redraw request: the tabline is a
redraw-time expression (`bufferline.lua:205`), so the tab appears on the next redraw for free.
Open/reopen of a query must stay interactive (< 50 ms of added work; a Lua table read plus at most
two option writes).

**Constraints**:
- The guard MUST be additive-only; it must never unlist a buffer (FR-021, FR-022)
- Generated output MUST keep taking no tab (FR-018) — including on the `<leader>qr` summon path
- Force-close semantics MUST NOT change: no prompt, no write, no re-insert (FR-017 as amended)
- No credentials may enter a buffer name, a draft record that can be displayed, or a message
  (constitution VII)
- The change must not depend on which route brought a buffer back (FR-002)
- No user-specific absolute paths (FR-025)

**Scale/Scope**: one Neovim module; **two new Lua modules** (~90 lines each including the required
function-header comments), one modified module, one corrected summon path, one new smoke test, one
extended smoke test, one README. No installer, no generated files, no other tool module.

## Spec amendments

| ID | Requirement | Change | Status |
|----|-------------|--------|--------|
| **A-001** | FR-017 / US3-4 vs FR-013 / US1-4 / SC-006 | FR-017 as written ("force-close MUST continue to discard its unsaved content") contradicts FR-013 ("a query buffer that has been closed and brought back MUST retain its content") because `bdelete` unloads the buffer and the text is gone at close time (measured, R-0007). Reword FR-017/US3-4 to: force-close MUST NOT write the content anywhere, MUST NOT create a file, MUST NOT prompt, MUST leave the buffer closed and unlisted, and MUST NOT restore anything by itself; within the same session the text MAY remain retrievable in memory so a later **explicit** reopen shows the query again, per FR-013. SC-006 scoped to a session. | **Approved by the developer 2026-09-30** — applied to [spec.md](spec.md) §Clarifications, FR-017, US3-4, SC-006 and "Out of Scope" |

Nothing else in the approved spec changes. The recommended path was chosen, so the fallback (narrow
FR-013 to saved content and document the empty-buffer-on-reopen behavior) is not taken.

## Constitution Check

*GATE: evaluated before Phase 0 and re-evaluated after Phase 1. No unresolved MUST-level violation.*

| Principle | Assessment | Evidence |
|-----------|-----------|----------|
| **I. Portable by Default** | PASS | No path handling at all: the guard reads buffer options; the registry is in-memory. The only path-shaped value is the `.dbout` suffix match, which is the module's own existing vocabulary (`db_results.lua:4`). FR-025. |
| **II. Idempotent Installation** | PASS (N/A) | No installer, symlink, or generated state is touched. Repeated buffer entries are idempotent: the guard returns immediately when the buffer is already listed; `setup()` follows the repo's existing `setup_done` guard pattern. |
| **III. Non-destructive** | PASS | The guard's only mutation is `buflisted: false → true` — it can never discard content. Draft records hold text in memory only; nothing is written (FR-017 as amended, A-001). Reclaiming a stale buffer clears a buffer whose content is catalog-generated and reproducible, and only when it is unlisted. |
| **IV. Modular Tool Boundaries** | PASS | Confined to the Neovim module: two new files under `nvim/lua/config/`, one edited module, one summon path, tests and README. No other tool module changes; Neovim stays usable with no database. FR-026. |
| **V. Repository Source of Truth** | PASS | No generated file, no local override, no work setting. Draft records are runtime session state, exactly like the existing `db_results` per-session slot (`db_results.lua:20`). |
| **VI. Reproducible Dependencies** | PASS | **No new dependency.** Everything reuses plugins the module already declares and loads (`plugin/database.lua`). The only new *configuration surface* is one optional buffer-local opt-out flag, documented in the module README (FR-027). |
| **VII. Security & Secret Hygiene** | PASS | The connection URL already lives in `b:db` in this module (`db_objects.lua:261`) and is never displayed; the draft record stores the same value, is never printed, and never reaches a name or message. No credential enters disk. FR-028. |
| **VIII. Verification Before Completion** | PASS | New smoke test covers the guard, the exclusion predicate, the `E95` reclaim, binding/content restore, and the `.dbout` exclusion; existing `db_objects_save_smoke`, `db_objects_scope_smoke`, and `db_results_smoke` must still pass unchanged. FR-029, SC-012. |
| **IX. Clear Installer Experience** | PASS (analogous) | No installer. The analogous obligation lands in User Story 2: no buffer the developer is looking at is presented as absent or unloadable, and the marker vocabulary is documented (FR-009, FR-011). |
| **X. Recovery and Rollback** | PASS | `git revert` on the feature branch. No migration, no persisted state, nothing to restore. No database state is touched, so the server-side recovery story is unchanged. |
| **XI. Simplicity & Maintainability** | PASS | Two small modules with the repo's required function headers; no framework, no new abstraction layer, no monkey-patching. Three *deletions* are part of the fix: the duplicate-buffer path in `open_buffer`, the reliance on buffer-local state that an unload destroys, and the inaccurate README claim. Each guard callback short-circuits on a single boolean. |
| **XII. Documentation & Governance** | PASS | FR-024/FR-030 require `nvim/README.md` updated in the same change, including the false auto-hide claim at `README.md:83` (measured, R-0011) and a troubleshooting entry for "my query buffer has no tab". |
| **XIII. Feature Branch & PR Discipline** | PASS | Work on `011-query-buffer-tab-visibility`, never directly on `main`. Conventional commits; the PR links issue #96; before opening it, verify scope fit against this spec and **ask the developer whether to close the spec and the issue as the completed solution**. FR-031. **Open question for the developer: the working tree already carries an unrelated uncommitted change to `nvim/lua/config/options.lua` (`vim.o.showmode = false`) that must not be swept into this branch's commits.** |
| **XIV. Module README Contract** | PASS | `nvim/README.md` is updated with the visibility contract, the draft-registry behavior, the picker-marker vocabulary (FR-011), the new validation command, and the rollback path. FR-030. |
| **XV. Spec Artifact Navigation** | PASS | `tasks.md` will carry a marker legend and link each user-story phase to its `spec.md` heading; research, data model, contract and quickstart cross-link relatively. FR-032. |

**Complexity Tracking**: no violations to justify — the table is intentionally empty.

**Pre-Phase-1 risk**: the spec contradiction in A-001 is a governance item, not a complexity item; it
is surfaced above and repeated in the completion report rather than resolved unilaterally.

## Project Structure

### Documentation (this feature)

```text
specs/011-query-buffer-tab-visibility/
├── spec.md                                    # the specification
├── plan.md                                    # this file
├── research.md                                # Phase 0 — four defects, R-0001..R-0012,
│                                              #   every claim measured with headless probes
├── data-model.md                              # Phase 1 — draft record, guard, exclusion
│                                              #   classes, state transitions
├── quickstart.md                              # Phase 1 — re-runnable probes, smoke commands,
│                                              #   manual reproduction of issue #96
├── contracts/
│   └── query-buffer-visibility.md             # Phase 1 — module contracts + invariants
├── checklists/
│   └── requirements.md                        # spec quality checklist (all pass)
├── tasks.md                                   # Phase 2 (/speckit.tasks — not created here)
└── verify-report.md                           # after implementation
```

### Source Code (repository root)

```text
nvim/
├── lua/config/
│   ├── buffers.lua                            # NEW — buffer-visibility guard
│   │                                          #   M.setup() augroup aogallo/buffer_visibility
│   │                                          #   M.is_generated_output(bufnr)
│   │                                          #   M.register_reopen_handler(fn)
│   │                                          #   additive-only; never unlists
│   ├── db_query_buffer.lua                    # NEW — query draft registry
│   │                                          #   M.setup(), M.open(url,name,lines,database),
│   │                                          #   M.reopen(bufnr): re-list + restore lines,
│   │                                          #   filetype and b:db from the draft record;
│   │                                          #   E95-safe name allocation
│   ├── db_objects.lua                         # MODIFIED — open_buffer() delegates to
│   │                                          #   db_query_buffer.open(); the duplicate-buffer
│   │                                          #   and unhandled-E95 paths are deleted
│   ├── db_results.lua                         # MODIFIED — after :pedit on a dismissed result,
│   │                                          #   re-apply dadbod's buffer-local settings
│   │                                          #   (nobuflisted bufhidden=delete readonly
│   │                                          #   nomodifiable) so the summon path matches the
│   │                                          #   original path (R-0008)
│   ├── autocmds.lua                           # unchanged — the guard owns its own augroup
│   └── options.lua                            # unchanged — note: an unrelated uncommitted
│                                              #   change lives here; do not touch or commit it
├── plugin/
│   ├── database.lua                           # MODIFIED — call db_query_buffer.setup() next to
│   │                                          #   the existing db_*.setup() calls
│   └── editor.lua                             # MODIFIED — additive: one require plus
│                                              #   buffers.setup() at plugin source time.
│                                              #   bufferline's own options stay byte-for-byte
│                                              #   as they were (R-0004, R-0011); this file was
│                                              #   marked "unchanged" in the first draft of this
│                                              #   plan, which was wrong: contract §3.3 requires
│                                              #   exactly one wiring point, and the guard is
│                                              #   editor-level, so it belongs here.
├── README.md                                  # MODIFIED — false auto-hide claim corrected,
│                                              #   visibility contract, picker-marker vocabulary,
│                                              #   troubleshooting entry, new validation command
└── lua/tests/
    ├── buffer_visibility_smoke.lua            # NEW — guard, exclusion predicate, E95 reclaim,
    │                                          #   binding/content restore, .dbout exclusion,
    │                                          #   generated-output regression
    ├── db_results_smoke.lua                   # EXTENDED — summon path keeps output tab-less
    ├── db_objects_save_smoke.lua              # unchanged — save flow untouched by this change
    ├── db_objects_scope_smoke.lua             # unchanged
    └── keymap_groups_smoke.lua                # unchanged — no keymap added or removed
```

**Structure Decision**: the repository is a single-project dotfiles tree, not a multi-package
workspace, so only the relevant subtree is shown. The existing convention — one Lua module per
concern under `nvim/lua/config/`, each exporting `setup()`, each function carrying a
Purpose/Called by/SQL/Args/Returns/Side-effects header (`nvim/README.md`, "Documenting a function"),
one `lua/tests/*_smoke.lua` per concern — is followed exactly. The split into two new modules is
forced by scope, not by taste: `buffers.lua` is editor-level and knows nothing about databases
(FR-001 is about *any* developer-opened buffer), while `db_query_buffer.lua` owns the database
binding and the draft text (FR-013/FR-014) and registers itself with the guard as a reopen handler.
Keeping the guard generic is what makes FR-002 route-independent without this module depending on
any database plugin. No new directory, no new top-level module.

## Phase 0 → Phase 1 handoff

All Phase 0 unknowns are resolved in [research.md](research.md); Technical Context above contains no
`NEEDS CLARIFICATION`. Two items could not be settled from the repository alone and are carried
into [quickstart.md](quickstart.md) as named manual confirmations rather than assumed away:

1. **The exact wording of "a name shows up but it hides"** ([research.md](research.md) R-0004,
   R-0008). The phrase admits two readings — a tab that appears then disappears, or a picker entry
   that carries the `h` marker. The probes ruled out `bufhidden` as the cause and found the real
   leak (a `.dbout` buffer listed by the summon path), which covers the second reading; the first
   reading is covered by re-listing before any save. The quickstart records which reading the
   developer actually sees so the requirement is measured, not assumed.
2. **Which key the developer pressed** ([research.md](research.md) R-0012). `<leader>j` is not mapped
   in this repository; the quickstart reproduces the report with `<leader>bb` / `<leader>bo` and asks
   the developer to confirm. The implementation does not depend on the answer (FR-002).

Amendment **A-001** was approved by the developer on 2026-09-30 and is applied to
[spec.md](spec.md) (FR-017, US3-4, SC-006, the "Out of Scope" entry, and a new
[Clarifications](spec.md#clarifications) entry). The design in Phase 1 already implements the amended
reading — [data-model.md](data-model.md) §3 T9/invariant 2 and
[contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md) §2.2/§2.3 — so no
design work changes with the amendment.