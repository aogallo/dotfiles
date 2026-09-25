# Implementation Plan: Object Source Fidelity (`:DBObjects`)

**Input**: [spec.md](spec.md) (formalized after implementation — see [Provenance](spec.md#provenance))
**Branch**: `fix/nvim-db-source-and-docs` (PR #89)
**Created**: 2026-09-25

## Summary

Replace `sp_helptext` as the source of truth for `:DBObjects` object source with a direct read
of the `syscomments` catalog, plus a client-side reassembler that restores the byte-exact
stored text from the 255-byte catalog rows. Keep `sp_helptext … 'showsql,noparams'` as an
opt-in mode for ASE 15.0.2+ when regenerated SQL is preferred. Degrade every unreadable case
to one actionable notice.

Technical context: Vimscript adapter + Lua picker, `sqsh` as the default client, no new
runtime dependency, no config file.

## Technical Context

| Dimension | Value |
| --- | --- |
| Language | Vimscript (adapter) + Lua (picker) |
| Primary files | `nvim/autoload/db/adapter/sybase.vim`, `nvim/lua/config/db_objects.lua` |
| Tests | `nvim/lua/tests/sybase_objects_smoke.lua` (canned client output) |
| Docs | `nvim/README.md` |
| Client | `sqsh` (`g:db_sybase_client`), overridable |
| Target server | Sybase ASE 15.0.2+ / 16.x (`showsql` mode only) |
| Performance | 1 extra catalog query per open (hidden check), 1 extraction query |
| Constraints | No new dependency; pure read; never interpolate raw names |

## Constitution Check

| Principle | Applicable | Compliance |
| --- | --- | --- |
| I. Portable by Default | Yes | No new tooling; behavior is server-side SQL over the existing client. Degrades to a notice on older ASE. |
| II. Idempotent Installation | No | No installer surface. |
| III. Non-Destructive Operations | Yes | Pure reads of `syscomments`; no DDL/DML, no catalog writes (FR-010). |
| IV. Modular Tool Boundaries | Yes | All extraction logic stays in the Sybase adapter; the Lua picker only consumes `db#adapter#sybase#source()`. |
| V. Repository as Source of Truth | Yes | Change lands in the repo, not in user config; `g:db_sybase_source_mode` is optional. |
| VI. Reproducible Dependencies | Yes | No dependency added (FR-014). |
| VII. Security and Secret Hygiene | Yes | Names escaped before interpolation (FR-009); credentials neither logged nor persisted. |
| VIII. Verification Before Completion | Yes | stylua, headless load, adapter load, smoke; live-server acceptance tracked in [verify-report.md](verify-report.md). |
| IX. Clear Installer Experience | Partial | No installer; the "feedback" surface is the single actionable notice (FR-008). |
| X. Recovery and Rollback | Partial | Read-only change: reverting the commit restores `sp_helptext`; documented in [quickstart.md](quickstart.md). |
| XI. Simplicity and Maintainability | Yes | ~40 lines of adapter logic, no framework, no abstraction layer. |
| XII. Documentation and Governance | Yes | `nvim/README.md` updated in the same change (FR-012). |
| XIII. Feature Branch and PR Discipline | Yes | Branch + PR #89 + linked issue #88. Deviation: branch is not `008-…`; documented in [verify-report.md](verify-report.md). |
| XIV. Module README Contract | Yes | `nvim/README.md` gains source-mode docs, traceability, and the marker scheme (FR-012). |
| XV. Spec Artifact Navigation | Yes | Every user-story phase in [tasks.md](tasks.md) links its `spec.md` heading; marker legend included. |

**Gate result**: PASS with one documented deviation (branch name; constitution XIII allows
emergency/recovery exceptions only, so the deviation is a governance note, not an exception
claim — the contributor explicitly asked for a single PR).

## Project Structure

```
nvim/
  autoload/db/adapter/sybase.vim   # source_mode, clean_result, trim_edges,
                                   # join_chunks, text_is_hidden,
                                   # source_catalog, source_showsql, source
  lua/config/db_objects.lua        # open_procedure_source(): one actionable notice
  lua/tests/sybase_objects_smoke.lua
  README.md                        # source modes, marker scheme, limits
specs/008-object-source-fidelity/
  spec.md  plan.md  research.md  data-model.md  quickstart.md  tasks.md
  contracts/object-source-extraction.md
  checklists/requirements.md
  verify-report.md
```

## Implementation Phases

1. **Framing removal** — `s:clean_result()`: drop `# Lines of Text` blocks, headings +
  separator rows, rules, row counts; return `[]` on `Msg <n>, Level <n>` (FR-003).
2. **Row marker** — the extraction query appends `~ ` / `~+` per row; `s:join_chunks()`
  rebuilds the stream and splits once (FR-001, FR-002, [data-model.md](data-model.md)).
3. **Hidden detection** — `s:text_is_hidden()` with labelled `HIDDEN`/`OK` (FR-006, FR-007).
4. **Modes** — `s:source_mode()`, `s:source_catalog()` (default), `s:source_showsql()`
   (opt-in), dispatch in `db#adapter#sybase#source()` (FR-005).
5. **Notice** — `open_procedure_source()` emits one WARN notice and opens no buffer when
   lines are empty (FR-008).
6. **Tests + docs** — smoke coverage (FR-011) and README contract (FR-012).
7. **Acceptance** — live-server check per [quickstart.md](quickstart.md).

## Complexity Tracking

| Item | Complexity | Justification |
| --- | --- | --- |
| Marker scheme (`~ `/`~+`) | Medium | The one non-obvious piece: the client cannot express "this row was cut", so the SQL has to carry that bit. Documented in [research.md](research.md). |
| `HIDDEN`/`OK` labels | Low | Chosen over a bare `count(*)` after a stray numeric client line nearly produced a false "hidden". |
| Extra hidden-check query | Low | One extra round trip per open; avoids extracting unreadable text at all. |
