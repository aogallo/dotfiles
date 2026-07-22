# Tasks: Ghostty Configuration Module

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

Estimated changed lines: 250-380. Suggested work unit: single focused PR for issue #40 with config, scripts, docs, and validation together.

## Phase 1: Setup

- [x] T001 Confirm implementation branch is not `main` and record issue #40 linkage in `/Users/allan/dotfiles/ghostty/README.md`.
- [x] T002 Create the Ghostty module directory at `/Users/allan/dotfiles/ghostty/`.
- [x] T003 Create script placeholders with executable intent at `/Users/allan/dotfiles/setup/validate-ghostty-config.sh` and `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.

## Phase 2: Foundational

- [x] T004 Create `/Users/allan/dotfiles/ghostty/dependencies.tsv` listing Ghostty.app and IosevkaTerm NF dependency expectations.
- [x] T005 Create `/Users/allan/dotfiles/ghostty/local.example.ghostty` with safe local override examples only.
- [x] T006 Add required-file and path constants to `/Users/allan/dotfiles/setup/validate-ghostty-config.sh`.
- [x] T007 Add dry-run default, argument parsing, and path constants to `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.

## Phase 3: US1 Capture Portable Ghostty Configuration (MVP)

- [x] T008 [US1] Create `/Users/allan/dotfiles/ghostty/config.ghostty` from the current portable Ghostty settings inventory.
- [x] T009 [US1] Document excluded and local-only Ghostty values in `/Users/allan/dotfiles/ghostty/README.md`.
- [x] T010 [P] [US1] Add optional local override include guidance to `/Users/allan/dotfiles/ghostty/config.ghostty`.
- [x] T011 [P] [US1] Validate setting coverage against the inventory in `/Users/allan/dotfiles/specs/001-ghostty-config-module/data-model.md`.
- [x] T012 [US1] Validate no secrets, private identifiers, generated `auto/`, or user-specific paths appear in `/Users/allan/dotfiles/ghostty/config.ghostty`.

## Phase 4: US2 Safely Adopt Repository-Managed Ghostty Config

- [x] T013 [US2] Implement state detection for missing, unmanaged, and repo-managed active config in `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T014 [US2] Implement dry-run reporting with source, destination, conflicts, and required backup status in `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T015 [US2] Implement `--apply --backup` backup creation before replacement in `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T016 [US2] Implement idempotent activation of `/Users/allan/dotfiles/ghostty/config.ghostty` in `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T017 [US2] Implement managed-only `--remove` behavior in `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T018 [US2] Add final changed, skipped, failed, and backup summary output to `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T019 [P] [US2] Validate repeated dry-run/apply behavior does not create duplicate links or backups using `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T020 [P] [US2] Validate unmanaged conflict and rollback safety behavior using `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.

## Phase 5: US3 Document Ghostty Usage and Validation

- [x] T021 [US3] Write managed files, baseline paths, dependencies, and issue #40 context in `/Users/allan/dotfiles/ghostty/README.md`.
- [x] T022 [US3] Write validation, linking, backup, rollback, customization, and troubleshooting sections in `/Users/allan/dotfiles/ghostty/README.md`.
- [x] T023 [US3] Implement repository file, dependency, Ghostty presence, and hygiene checks in `/Users/allan/dotfiles/setup/validate-ghostty-config.sh`.
- [x] T024 [US3] Implement Ghostty config smoke-check reporting when the local Ghostty command supports it in `/Users/allan/dotfiles/setup/validate-ghostty-config.sh`.
- [x] T025 [P] [US3] Validate quickstart steps against `/Users/allan/dotfiles/specs/001-ghostty-config-module/quickstart.md`.
- [x] T026 [P] [US3] Validate documentation answers ownership and next-action questions in `/Users/allan/dotfiles/ghostty/README.md` within five minutes.

## Final Phase: Polish & Cross-Cutting Concerns

- [x] T027 Run shell syntax validation for `/Users/allan/dotfiles/setup/validate-ghostty-config.sh` and `/Users/allan/dotfiles/setup/link-ghostty-config.sh`.
- [x] T028 Run repository hygiene checks to ensure `/Users/allan/dotfiles/ghostty/` contains no generated `auto/` state or real local overrides.
- [x] T029 Verify `/Users/allan/dotfiles/ghostty/dependencies.tsv` matches dependency guidance in `/Users/allan/dotfiles/ghostty/README.md`.
- [x] T030 Before PR creation, verify branch discipline and ask whether the PR should close issue #40 in `/Users/allan/dotfiles/ghostty/README.md` notes.

## Dependencies

Phase 1 before all other phases. Phase 2 before US1-US3. US1 is the MVP and must complete before adoption. US2 depends on US1 config files. US3 can start after Phase 2 but final docs depend on US1 and US2 behavior.

## Parallel Examples

After T007, T010 and T011 can run in parallel. In US2, T019 and T020 can run after T018. In US3, T025 and T026 can run after T024.

## Independent Test Criteria

US1 passes when every current setting is captured or documented as excluded/local-only. US2 passes when dry-run, backup-safe apply, repeated runs, and managed-only removal are recoverable. US3 passes when quickstart validation and README review explain install, ownership, customization, validation, backup, rollback, and troubleshooting.

## Implementation Strategy

Implement MVP first: T001-T012. Then add safe adoption: T013-T020. Finish documentation and validation: T021-T030. Keep all generated Ghostty state and real local overrides outside git.
