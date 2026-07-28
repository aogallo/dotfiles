# Tasks: Installer Release v1

**Input**: Design documents from `specs/001-installer-release-v1/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/installer-release.md](./contracts/installer-release.md), [quickstart.md](./quickstart.md)

## Review Workload Forecast

| Field                   | Value                                                  |
| ----------------------- | ------------------------------------------------------ |
| Estimated changed lines | 250-400                                                |
| 400-line budget risk    | Medium                                                 |
| Chained PRs recommended | No                                                     |
| Suggested split         | Single PR; split bootstrap download only if diff grows |
| Delivery strategy       | ask-on-risk                                            |
| Chain strategy          | pending                                                |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal                                 | Likely PR | Notes                                |
| ---- | ------------------------------------ | --------- | ------------------------------------ |
| 1    | Release workflow and manual playbook | PR 1      | Creates release path and docs        |
| 2    | Bootstrap binary preference          | PR 1      | May split only if tests become large |

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable task touching different files or not depending on incomplete work.
- **[US#]**: User story marker. The phase `Story Link` points to the matching `spec.md` heading.

## Phase 1: Setup

- [x] T001 Verify branch is `feat/installer-release-v1` and repo has no unrelated staged changes.
- [x] T002 [P] Create `.github/workflows/` for the first repository workflow.

---

## Phase 2: User Story 1 - Follow a Manual v1 Release Playbook (Priority: P1) MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---follow-a-manual-v1-release-playbook-priority-p1)

**Goal**: Maintainer can publish `v1.0.0` manually with safe checkpoints.

**Independent Test**: Follow `quickstart.md#manual-v1-release-validation` without unstated release decisions.

- [x] T003 [US1] Add manual release playbook section to `installer/README.md` with pre-checks, build assets, checksum, publish, and post-publish verification.
- [x] T004 [US1] Add root `README.md` release summary linking to the installer playbook.
- [x] T005 [US1] Document `v1.0.0` scope and explicitly exclude future installer UX/UI redesign in `installer/README.md`.

---

## Phase 3: User Story 2 - Define an Automated Release Path (Priority: P2)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---define-an-automated-release-path-priority-p2)

**Goal**: GitHub Actions can publish versioned installer assets repeatably.

**Independent Test**: Review workflow against [contracts/installer-release.md](./contracts/installer-release.md#release-workflow-behavior).

- [x] T006 [US2] Create `.github/workflows/release-installer.yml` triggered by semantic version tags `v*`.
- [x] T007 [US2] Add workflow validation steps for `cd installer && go test ./...`, bootstrap shell tests, and shell syntax checks.
- [x] T008 [US2] Add workflow build steps for `dotfiles-installer-darwin-arm64` and `dotfiles-installer-darwin-amd64`.
- [x] T009 [US2] Add workflow checksum generation producing `checksums.txt` with one entry per binary.
- [x] T010 [US2] Add release publication with minimal `contents: write` permissions and failure-safe ordering.

---

## Phase 4: User Story 3 - Consume Released Installer Binaries Safely (Priority: P3)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---consume-released-installer-binaries-safely-priority-p3)

**Goal**: `--prefer-binary` can use verified released binaries while preserving source fallback.

**Independent Test**: Run `quickstart.md#bootstrap-validation` scenarios.

- [x] T011 [US3] Update `setup/bootstrap-dotfiles-installer.sh` to model release asset lookup for detected macOS architecture.
- [x] T012 [US3] Add checksum verification before executing any downloaded release binary.
- [x] T013 [US3] Preserve `--no-binary`, local binary candidates, dry-run behavior, and `go run` fallback.
- [x] T014 [US3] Extend `setup/bootstrap-dotfiles-installer_test.sh` for release hit, missing release, checksum mismatch, dry-run, and fallback paths.
- [x] T015 [US3] Update `README.md` and `installer/README.md` with binary-preferred release behavior and recovery path.

---

## Phase 5: Verification & Release Readiness

- [x] T016 Run `(cd installer && go test ./...)` from repository root.
- [x] T017 Run `setup/bootstrap-dotfiles-installer_test.sh`.
- [x] T018 Run `bash -n setup/bootstrap-dotfiles-installer.sh setup/bootstrap-dotfiles-installer_test.sh`.
- [x] T019 Run `setup/bootstrap-dotfiles-installer.sh --dry-run --prefer-binary` and `setup/bootstrap-dotfiles-installer.sh --dry-run --no-binary`.
- [x] T020 Run `git diff --check`.
- [x] T021 Verify expected release assets match `contracts/installer-release.md`.
- [x] T022 Verify PR creation reviews active spec closure and links required issue if applicable.

## Dependencies & Execution Order

- Phase 1 must finish before workflow or bootstrap changes.
- US1 can be delivered first as documentation-only MVP.
- US2 and US3 can proceed after Phase 1; US3 tests may depend on asset names from US2.
- Phase 5 must pass before tagging `v1.0.0`.

## PR Readiness Notes

- Active spec is related to this release infrastructure change and should be reviewed for closure when the PR is prepared.
- No open `status:approved` issue was found during implementation; link an approved issue if repository policy requires one before PR creation.
