# Tasks: Installer V2 UI and Install Flow

**Input**: `/Users/allan/dotfiles/specs/002-installer-v2-ui/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`
**Total**: 37 tasks. **Mapping**: Setup=3, Foundation=4, US1=7, US2=8, US3=7, US4=7, Polish=1.

## Review Workload Forecast

Estimated changed lines: 700-1100. Suggested split: PR1 US1 launch/docs -> PR2 US2 confirmation/backup language -> PR3 US3 async progress -> PR4 US4 full-screen/color rendering.

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Downloaded binary visibly starts or gives launch guidance | PR1 | MVP, includes launch docs/tests |
| 2 | Plain-language confirmation and automatic backup summary | PR2 | Builds on PR1 UX copy and report model |
| 3 | Live sequential progress during command execution | PR3 | Converts blocking execution to Bubble Tea messages |
| 4 | Full-screen colored responsive TUI with emoji fallback | PR4 | Visual polish after behavior is stable |

## Phase 1: Setup

**Purpose**: Confirm current entry points and test seams before changing behavior.

- [x] T001 Review release entry flow in `/Users/allan/dotfiles/installer/cmd/dotfiles-installer/main.go`
- [x] T002 [P] Review TUI state fields in `/Users/allan/dotfiles/installer/internal/tui/model.go`
- [x] T003 [P] Review release and bootstrap docs in `/Users/allan/dotfiles/installer/README.md`

## Phase 2: Foundational

**Purpose**: Add shared terminology and accounting primitives required by every story.

- [x] T004 Add user-facing status label mapping in `/Users/allan/dotfiles/installer/internal/installer/action.go`
- [x] T005 Add terminal/progress session fields in `/Users/allan/dotfiles/installer/internal/tui/model.go`
- [x] T006 Add cancelled/incomplete step accounting in `/Users/allan/dotfiles/installer/internal/installer/report.go`
- [x] T007 Ensure stable planned step IDs for UI/report accounting in `/Users/allan/dotfiles/installer/internal/installer/plan.go`

## Phase 3: User Story 1 - Run the Downloaded Installer Successfully (P1) MVP

**Story Link**: [`spec.md` US1](./spec.md#user-story-1---run-the-downloaded-installer-successfully-priority-p1)
**Goal**: Executing the downloaded installer visibly starts the app or gives exact next steps.
**Independent Test**: Build/run a local darwin binary and verify terminal and startup-error paths are visible and actionable.

- [x] T008 [P] [US1] Add startup error tests in `/Users/allan/dotfiles/installer/internal/tui/update_test.go`
- [x] T009 [P] [US1] Add launch guidance report tests in `/Users/allan/dotfiles/installer/internal/installer/report_test.go`
- [x] T010 [US1] Detect non-interactive startup failures in `/Users/allan/dotfiles/installer/cmd/dotfiles-installer/main.go`
- [x] T011 [US1] Render actionable startup guidance in `/Users/allan/dotfiles/installer/internal/tui/view.go`
- [x] T012 [US1] Document direct binary execution and troubleshooting in `/Users/allan/dotfiles/installer/README.md`
- [x] T013 [US1] Align prefer-binary guidance with release behavior in `/Users/allan/dotfiles/setup/bootstrap-dotfiles-installer.sh`
- [x] T014 [US1] Validate local release-like binary startup in `/Users/allan/dotfiles/installer/cmd/dotfiles-installer/main.go`

## Phase 4: User Story 2 - Understand and Confirm Installation Safely (P2)

**Story Link**: [`spec.md` US2](./spec.md#user-story-2---understand-and-confirm-installation-safely-priority-p2)
**Goal**: Replace internal safety terms with clear confirmation, backup, skipped, and manual-action language.
**Independent Test**: Build a plan with unmanaged config targets and verify confirmation explains changes/backups before mutation.

- [x] T015 [P] [US2] Add confirmation copy tests in `/Users/allan/dotfiles/installer/internal/tui/view_test.go`
- [x] T016 [P] [US2] Add backup uniqueness tests in `/Users/allan/dotfiles/installer/internal/installer/plan_test.go`
- [x] T017 [US2] Replace internal classification display labels in `/Users/allan/dotfiles/installer/internal/installer/action.go`
- [x] T018 [US2] Render confirmation summary sections in `/Users/allan/dotfiles/installer/internal/tui/view.go`
- [x] T019 [US2] Keep pre-confirm cancellation non-mutating in `/Users/allan/dotfiles/installer/internal/tui/update.go`
- [x] T020 [US2] Plan automatic backup steps after install confirmation in `/Users/allan/dotfiles/installer/internal/installer/plan.go`
- [x] T021 [US2] Add backup restore guidance to reports in `/Users/allan/dotfiles/installer/internal/installer/report.go`
- [x] T022 [US2] Add pre-confirm cancel regression test in `/Users/allan/dotfiles/installer/internal/tui/update_test.go`

## Phase 5: User Story 3 - Track Install Progress by Tool and File (P3)

**Story Link**: [`spec.md` US3](./spec.md#user-story-3---track-install-progress-by-tool-and-file-priority-p3)
**Goal**: Show current step, overall count, and failure/recovery status while commands run.
**Independent Test**: Use `FakeRunner` to verify running state renders before final report and each step is accounted for.

- [x] T023 [P] [US3] Add runner progress message tests in `/Users/allan/dotfiles/installer/internal/runner/runner_test.go`
- [x] T024 [P] [US3] Add running-screen transition tests in `/Users/allan/dotfiles/installer/internal/tui/update_test.go`
- [x] T025 [US3] Add progress result message types in `/Users/allan/dotfiles/installer/internal/runner/runner.go`
- [x] T026 [US3] Execute plan steps sequentially via Bubble Tea commands in `/Users/allan/dotfiles/installer/internal/tui/update.go`
- [x] T027 [US3] Store active step and totals in `/Users/allan/dotfiles/installer/internal/tui/model.go`
- [x] T028 [US3] Render running progress and recent results in `/Users/allan/dotfiles/installer/internal/tui/view.go`
- [x] T029 [US3] Account failed and skipped step outcomes in `/Users/allan/dotfiles/installer/internal/installer/report.go`

## Phase 6: User Story 4 - Use a Full-Screen Colored Terminal UI (P4)

**Story Link**: [`spec.md` US4](./spec.md#user-story-4---use-a-full-screen-colored-terminal-ui-priority-p4)
**Goal**: Provide full-screen, color-coded, keyboard-driven layout with text fallback for emojis/color.
**Independent Test**: Render 80x24 and larger views and verify status labels remain understandable without emojis.

- [ ] T030 [P] [US4] Add viewport rendering tests in `/Users/allan/dotfiles/installer/internal/tui/view_test.go`
- [ ] T031 [P] [US4] Add resize state tests in `/Users/allan/dotfiles/installer/internal/tui/model_test.go`
- [ ] T032 [US4] Enable alternate screen program mode in `/Users/allan/dotfiles/installer/cmd/dotfiles-installer/main.go`
- [ ] T033 [US4] Handle `tea.WindowSizeMsg` in `/Users/allan/dotfiles/installer/internal/tui/update.go`
- [ ] T034 [US4] Add semantic color styles in `/Users/allan/dotfiles/installer/internal/tui/view.go`
- [ ] T035 [US4] Add optional emoji cues with text fallback in `/Users/allan/dotfiles/installer/internal/tui/view.go`
- [ ] T036 [US4] Verify 80x24 readability in `/Users/allan/dotfiles/installer/internal/tui/view_test.go`

## Final Phase: Polish and Validation

- [ ] T037 Run `go test ./...` from `/Users/allan/dotfiles/installer`

## Dependencies

Setup -> Foundation -> US1 MVP -> US2 -> US3 -> US4 -> Polish. US2, US3, and US4 may branch after T004-T007, but recommended review order is sequential because later UI polish depends on stable behavior.

## Parallel Execution Examples

- `T002` and `T003` can run together after `T001` starts.
- `T015` and `T016` can run together for US2 tests.
- `T023` and `T024` can run together for US3 tests.
- `T030` and `T031` can run together for US4 tests.

## Implementation Strategy

MVP first: complete T001-T014, then validate US1 independently. Before implementation, choose a chain strategy because the forecast is above the 400-line review budget. Continue with US2, US3, and US4 as separate chained work units.
