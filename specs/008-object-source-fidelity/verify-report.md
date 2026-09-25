# Verify Report: Object Source Fidelity (`:DBObjects`)

**Change**: 008-object-source-fidelity · **Version**: N/A · **Mode**: Standard
**Verified**: 2026-09-25 · **Branch**: `fix/nvim-db-source-and-docs` (PR #89, issue #88)
**Report type**: retroactive — this specification was formalized after the implementation; see
[Provenance](spec.md#provenance).

## Verification Report

### Completeness

| Metric | Value |
| --- | --- |
| Tasks total | 31 |
| Tasks complete | 28 (`[X]`, present in the PR #89 diff) |
| Tasks incomplete | 3 (`T101`–`T103`, live-server acceptance + report update) |
| Functional requirements | 14 (FR-001–FR-014) |
| User stories | 3 (P1, P2, P3) |
| Constitution principles evaluated | 15 (I–XV) → PASS, one documented deviation |

### Governance Notes

- **Branch-name deviation (constitution XIII)**: the implementation is on
  `fix/nvim-db-source-and-docs`, not `008-object-source-fidelity`, because the contributor asked
  for the source fix and the archival of specs 001/003/004/005 to ship in a single PR. The
  spec directory follows the spec-kit convention; the branch does not. All artifacts are
  committed to that branch and reviewed in PR #89, so the branch/PR discipline itself
  (no direct commits to `main`, conventional commits, linked issue) is intact.
- **Issue linkage (FR-013)**: PR #89 links approved issue #88, which remains open until the
  live acceptance passes.
- **Spec status**: active, not closed. The spec is not archived until T101–T102 pass; the
  offline gates below cannot prove byte-exactness against a real ASE catalog.

### Build & Tests Execution

Re-run for this report on 2026-09-25 (all commands from the repository root):

**Build**: ✅ Passed

```text
$ stylua --check nvim
exit=0

$ nvim --headless -u nvim/init.lua '+quitall'
exit=0

$ nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'
exit=0
```

**Tests**: ✅ Passed — 141 assertions across 8 smokes, all exit 0

```text
$ nvim --headless -u NORC -c 'lua require("tests.<smoke>")' -c 'qa!'
sybase_adapter_smoke       exit=0  11 asserts
sybase_objects_smoke       exit=0  28 asserts   ← source extraction (this change)
db_connections_smoke       exit=0   4 asserts
db_jump_smoke              exit=0   7 asserts
db_objects_save_smoke      exit=0  26 asserts
db_objects_scope_smoke     exit=0  41 asserts
db_results_smoke           exit=0  18 asserts
keymap_groups_smoke        exit=0   6 asserts
```

`sybase_objects_smoke` last lines:

```text
PASS tables returns [] for missing client
PASS missing client never spawns a job
PASS source returns [] for missing client
All objects/source smoke assertions passed
```

**Dependency validation**: ✅ Passed

```text
$ setup/validate-nvim-deps.sh
Summary: 26 checked, 0 required missing, 5 optional missing
exit=0
```

(The 5 optional gaps — mongosh and similar — are unrelated to this change; no dependency was
added, per FR-014.)

**Live-server acceptance**: ⏳ Not run — requires a real ASE 15.0.2+/16.x instance and a
procedure whose body crosses a 255-byte boundary inside an identifier. Procedure:
[quickstart.md](quickstart.md#manual-acceptance-live-server-required). Tasks T101–T102.

### Requirements Traceability

| Requirement | Evidence | Status |
| --- | --- | --- |
| FR-001 catalog read, index order | `s:source_catalog()` (`sybase.vim:538`); smoke asserts the exact query line | ✅ |
| FR-002 marker-based reassembly, no mid-line cuts | `s:join_chunks()` (`sybase.vim:484`); smoke: `substring(@dat~+` + `o, @poscicion, 1)` → one line | ✅ (offline) |
| FR-003 framing removal | `s:clean_result()` (`sybase.vim:416`); smoke covers `# Lines of Text`, heading + rule, `Msg 2812` → `[]` | ✅ |
| FR-004 no framing in buffer | smoke: reassembled result equals 3 whole lines exactly | ✅ (offline) |
| FR-005 opt-in `showsql`, `catalog` default | `s:source_mode()`/`s:source_showsql()` (`sybase.vim:402`,`559`); smoke asserts `exec sp_helptext 'usp_calc', NULL, NULL, 'showsql,noparams'` and that an unset mode uses the catalog SQL | ✅ |
| FR-006 hidden/encrypted detected pre-extraction | `s:text_is_hidden()` called from `s:source_catalog()` before the extraction query | ✅ (offline) |
| FR-007 labelled `HIDDEN`/`OK`, not a bare count | `sybase.vim:518`; header documents the stray-count failure mode | ✅ |
| FR-008 one notice, no buffer | `open_procedure_source()` (`db_objects.lua:408-421`) | ✅ (offline) |
| FR-009 name escaping | `source()` escapes `'` → `''` (`sybase.vim:582`); smoke asserts the interpolated name | ✅ |
| FR-010 pure read, scoped to the URL database | no DDL/DML in the contract; only catalog selects | ✅ |
| FR-011 smoke coverage | `nvim/lua/tests/sybase_objects_smoke.lua`, 28 asserts, all batches asserted | ✅ |
| FR-012 README + uniform headers | `nvim/README.md` (`:DBObjects`, module map, traceability, documenting a function); 67 production functions carry the header block | ✅ |
| FR-013 feature branch + PR + linked issue | `fix/nvim-db-source-and-docs` → PR #89 → issue #88 (branch-name deviation noted above) | ✅ |
| FR-014 no new dependency / no scope creep | `validate-nvim-deps.sh` 0 required missing; diff limited to source extraction + docs | ✅ |

### Noteworthy Findings & Limitations

1. **The client cannot express row boundaries.** `syscomments.text` is `varbinary(255)` and the
   client renders embedded newlines as its own line breaks, so a slice that ended mid-line is
   indistinguishable from one that ended on a newline. The `~ `/`~+` marker in the extraction
   query is the only place that information can exist; the reassembler depends on it exactly.
   If the client is changed to `isql` with different rendering, the marker scheme must be
   re-verified (research R3, [data-model.md](data-model.md#e2-client-output-line)).
2. **A bare `~` never matches in a Vimscript pattern.** The mid-line branch is `\~+$`
   (`sybase.vim:491`). This cost a debug cycle during implementation; it is recorded in
   [research.md](research.md#r3-how-to-know-a-row-was-cut-mid-line-the-marker-scheme) so it is
   not reintroduced.
3. **A bare `count(*)` is unsafe for the hidden check.** A stray numeric client line (a row
   count when `set nocount on` did not apply) reads as "hidden" and would produce a wrong notice
   on every open. Hence the labelled `HIDDEN`/`OK` result.
4. **Accepted limits** (documented in code headers and [quickstart.md](quickstart.md#known-limitations-accepted)):
   a source line ending in exactly `~` at a row boundary is dropped; CR-only endings are not
   breaks; a line of only `[-=]{3,}` is always treated as framing.
5. **`showsql` reformatting is by design.** It is not the byte-exact path, which is why it is
   opt-in and why `catalog` is the default.
6. **What the offline gates cannot prove**: the exact behavior of
   `text like '%' + char(10)` on a real ASE build, and the `sqsh` rendering of a real
   255-byte binary slice. T101 is the gate for that; until it passes, this report is honest
   about SC-001/SC-002 being verified only against canned output.
