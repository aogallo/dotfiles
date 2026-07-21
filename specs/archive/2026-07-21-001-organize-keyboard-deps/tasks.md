# Tasks: Organize Keyboard and Optional Dependencies

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 120-380, depending on rename detection |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Optional dependency clarity | PR 1 | Docs/validation evidence for `nvim/` and `setup/` |
| 2 | Keyboard folder move | PR 1 | `keyboard/` organization plus preservation checks |

## Phase 1: Setup

- [x] T001 Verify implementation branch `001-organize-keyboard-deps` using `.git/HEAD`
- [x] T002 Capture pre-move checksum for `iris_rev__5.json`

## Phase 2: User Story 1 - Resolve Optional Dependency Warnings (P1)

**Independent Test**: `setup/validate-nvim-deps.sh` reports required tools as passing while optional `shfmt`/`shellcheck` remain clear and non-blocking.

- [x] T003 [US1] Review optional entries for `shfmt` and `shellcheck` in `nvim/dependencies.tsv`
- [x] T004 [P] [US1] Update optional dependency resolution guidance in `nvim/README.md`
- [x] T005 [US1] Run and inspect optional warning output from `setup/validate-nvim-deps.sh`
- [x] T006 [US1] Run dry-run optional install preview with `setup/bootstrap-nvim-deps.sh --dry-run --include-optional`

## Phase 3: User Story 2 - Organize Keyboard Configuration (P2)

**Independent Test**: root `iris_rev__5.json` is gone, `keyboard/iris_rev__5.json` exists, parses, and preserves checksum/content.

- [x] T007 [US2] Create keyboard module documentation in `keyboard/README.md`
- [x] T008 [US2] Move `iris_rev__5.json` unchanged to `keyboard/iris_rev__5.json`
- [x] T009 [P] [US2] Update keyboard folder discoverability in `README.md`
- [x] T010 [US2] Validate JSON parsing for `keyboard/iris_rev__5.json`
- [x] T011 [US2] Confirm no active duplicate remains at `iris_rev__5.json`
- [x] T012 [US2] Compare post-move checksum for `keyboard/iris_rev__5.json`

## Phase 4: Polish and Gates

- [x] T013 Run whitespace validation with `git diff --check`
- [x] T014 Verify repository contract coverage in `specs/001-organize-keyboard-deps/contracts/repository-organization.md`
- [x] T015 Verify active spec closure gate before PR using `specs/001-organize-keyboard-deps/spec.md`

## Dependencies

- T001-T002 before file move validation.
- US1 can complete independently after T001.
- US2 depends on T002 for checksum evidence.
- T013-T015 after selected story tasks.

## Parallel Examples

- T004 and T009 can run together because they touch `nvim/README.md` and `README.md`.
- T005 and T006 can run together after T003 if scripts are unchanged.

## Implementation Strategy

MVP scope: complete US1 first, proving optional tools are actionable and non-blocking. Then complete US2 as an independent organization increment. Prefer docs/clarity; update `setup/validate-nvim-deps.sh` or `setup/bootstrap-nvim-deps.sh` only if validation output contradicts the contract.
