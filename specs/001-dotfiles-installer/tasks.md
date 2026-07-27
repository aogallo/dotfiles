# Tasks: Dotfiles Installer TUI

**Input**: Design documents from `specs/001-dotfiles-installer/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/installer-cli.md`, `quickstart.md`

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 900-1400 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 foundation → PR 2 guided menu → PR 3 module planning/execution → PR 4 sync/upgrade/docs |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the Go CLI/TUI project structure without changing existing setup behavior.

- [x] T001 Create installer Go module metadata for Go 1.22+ and Bubble Tea dependencies in `installer/go.mod` and `installer/go.sum`
- [x] T002 [P] Create CLI entrypoint skeleton that starts the TUI program in `installer/cmd/dotfiles-installer/main.go`
- [x] T003 [P] Create installer package files with exported type stubs in `installer/internal/installer/action.go`, `installer/internal/installer/module.go`, `installer/internal/installer/plan.go`, and `installer/internal/installer/report.go`
- [x] T004 [P] Create runner package skeleton for external command boundaries in `installer/internal/runner/runner.go`
- [x] T005 [P] Create TUI package skeleton for Bubble Tea model/update/view separation in `installer/internal/tui/model.go`, `installer/internal/tui/update.go`, and `installer/internal/tui/view.go`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define shared data, planning, reporting, and runner boundaries required by all user stories.

**⚠️ CRITICAL**: No user story implementation can begin until this phase is complete.

- [x] T006 [P] Add action classifications, step kinds, flow constants, and status constants in `installer/internal/installer/action.go`
- [x] T007 [P] Add module definitions for nvim, zsh, ghostty, tmux, keyboard, and macOS source paths in `installer/internal/installer/module.go`
- [x] T008 Add plan builder types that require dry-run/report steps before mutating steps in `installer/internal/installer/plan.go`
- [x] T009 Add report item, totals, backup record, manual next-step, and exit-code types in `installer/internal/installer/report.go`
- [x] T010 [P] Add fakeable command runner interface, command result type, and repository-root path handling in `installer/internal/runner/runner.go`
- [x] T011 [P] Add unit tests for classification, module metadata, and manual-only command rejection in `installer/internal/installer/action_test.go` and `installer/internal/installer/module_test.go`
- [x] T012 [P] Add unit tests for runner fake behavior and path-safe argv execution boundaries in `installer/internal/runner/runner_test.go`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Run Guided Installation (Priority: P1) 🎯 MVP

**Goal**: Show a safe main menu with required actions, Neovim-style navigation, and quit/back behavior without applying unconfirmed changes.

**Independent Test**: Run `cd installer && go run ./cmd/dotfiles-installer` and confirm the first screen shows `start installation`, `sync configs`, `Upgrade tools`, and `quit`; `j`/`k` moves focus; `q` exits safely.

### Tests for User Story 1

- [x] T013 [P] [US1] Add TUI model tests for initial menu items and default dry-run state in `installer/internal/tui/model_test.go`
- [x] T014 [P] [US1] Add TUI update tests for `j`, `k`, `enter`, `q`, and `ctrl+c` key behavior in `installer/internal/tui/update_test.go`
- [x] T015 [P] [US1] Add TUI view tests that assert required menu labels and safe status copy in `installer/internal/tui/view_test.go`

### Implementation for User Story 1

- [x] T016 [US1] Implement initial session state and top-level menu choices in `installer/internal/tui/model.go`
- [x] T017 [US1] Implement Bubble Tea key handling for navigation, selection, quit, and back behavior in `installer/internal/tui/update.go`
- [x] T018 [US1] Implement main menu rendering with required action labels and selected-item styling in `installer/internal/tui/view.go`
- [x] T019 [US1] Wire `installer/cmd/dotfiles-installer/main.go` to run the Bubble Tea program and return the model exit code from `installer/internal/tui/model.go`
- [x] T020 [US1] Validate US1 with `cd installer && go test ./internal/tui ./cmd/dotfiles-installer` and document the command in `specs/001-dotfiles-installer/quickstart.md`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - Install and Validate Modules Safely (Priority: P1)

**Goal**: Build install-all and per-module dry-run/report flows that inventory existing setup sources, classify work safely, invoke only approved scripts, and report manual-only guidance.

**Independent Test**: Run dry-run/report flows for nvim, zsh, ghostty, tmux, keyboard, and macOS setup and verify classifications, unmanaged overwrite refusal, and manual-only guidance.

### Tests for User Story 2

- [x] T021 [P] [US2] Add plan tests for inventorying manifests and docs from `nvim/dependencies.tsv`, `zsh/dependencies.tsv`, `ghostty/dependencies.tsv`, and `setup/` in `installer/internal/installer/plan_test.go`
- [x] T022 [P] [US2] Add action tests for approved script argv and explicit exclusion of `setup/macos.sh` in `installer/internal/installer/action_test.go`
- [x] T023 [P] [US2] Add report tests for required, optional, Mason-backed, AWS, manual-only, unmanaged, and backed-up statuses in `installer/internal/installer/report_test.go`
- [x] T024 [P] [US2] Add runner tests for streaming/fake command results and failure propagation in `installer/internal/runner/runner_test.go`

### Implementation for User Story 2

- [x] T025 [US2] Implement module inventory from setup scripts, dependency manifests, and module docs in `installer/internal/installer/module.go`
- [x] T026 [US2] Implement install-all and per-module action plan construction with automatic, confirmation-required, dry-run/report-only, and manual-only classifications in `installer/internal/installer/plan.go`
- [x] T027 [US2] Implement approved command argv generation for validators, bootstrap dry-run/install, and nvim/ghostty link dry-run/apply/backup/remove in `installer/internal/installer/action.go`
- [x] T028 [US2] Implement normalized report totals, raw logs, backup paths, manual next steps, and non-zero failure exit codes in `installer/internal/installer/report.go`
- [x] T029 [US2] Implement runner execution with context, working directory, stdout/stderr capture, and no shell interpolation in `installer/internal/runner/runner.go`
- [x] T030 [US2] Integrate install flow screens for module list, action plan, confirmation, running, and report in `installer/internal/tui/model.go`, `installer/internal/tui/update.go`, and `installer/internal/tui/view.go`
- [x] T031 [US2] Validate US2 with `cd installer && go test ./...`, `setup/validate-nvim-deps.sh`, `setup/bootstrap-nvim-deps.sh --dry-run`, `setup/link-nvim-config.sh --dry-run`, `setup/validate-zsh-config.sh`, `setup/validate-ghostty-config.sh`, and `setup/link-ghostty-config.sh --dry-run` from `specs/001-dotfiles-installer/quickstart.md`

**Checkpoint**: User Stories 1 and 2 work independently and together.

---

## Phase 5: User Story 3 - Upgrade and Sync Existing Setup (Priority: P2)

**Goal**: Support safe `sync configs` and `Upgrade tools` flows for repeated runs without duplicate links, backup loops, or unclear ownership.

**Independent Test**: Run sync and upgrade flows twice in a sandbox and confirm the second run converges with managed/unchanged/skipped/manual statuses.

### Tests for User Story 3

- [x] T032 [P] [US3] Add sync plan tests for managed, unmanaged, missing, broken symlink, backed-up, removed, skipped, and failed config targets in `installer/internal/installer/plan_test.go`
- [x] T033 [P] [US3] Add upgrade report tests for changed, skipped, failed, optional, Mason-backed, AWS/external, and manual items in `installer/internal/installer/report_test.go`
- [x] T034 [P] [US3] Add repeated-run tests that prevent duplicate links and backup loops in `installer/internal/installer/plan_test.go`

### Implementation for User Story 3

- [x] T035 [US3] Implement sync config planning with unmanaged overwrite refusal and explicit backup confirmation requirements in `installer/internal/installer/plan.go`
- [x] T036 [US3] Implement upgrade planning and result normalization for supported, optional, external, and manual-only tools in `installer/internal/installer/action.go` and `installer/internal/installer/report.go`
- [x] T037 [US3] Integrate sync and upgrade screens with confirmation gates and rerun-safe report rendering in `installer/internal/tui/model.go`, `installer/internal/tui/update.go`, and `installer/internal/tui/view.go`
- [x] T038 [US3] Validate US3 by running repeated sync/upgrade sandbox scenarios and recording the command sequence in `specs/001-dotfiles-installer/quickstart.md`

**Checkpoint**: All user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, regression validation, branch discipline, and final quality gates.

- [x] T039 [P] Update installer usage, rollback, troubleshooting, manual-only boundaries, and validation commands in `README.md`
- [x] T040 [P] Update module documentation for installer behavior and manual-only guidance in `nvim/README.md`, `zsh/README.md`, `ghostty/README.md`, `Tmux/README.md`, and `keyboard/README.md`
- [x] T041 Run full Go validation and shell smoke checks from `specs/001-dotfiles-installer/quickstart.md` using `cd installer && go test ./...` and the listed `setup/` commands
- [x] T042 Verify constitution gates for portability, idempotency, non-destructive behavior, verification, recovery, documentation, and branch/PR discipline in `specs/001-dotfiles-installer/plan.md`
- [x] T043 Verify implementation work is on branch `001-dotfiles-installer`, PR scope links GitHub issue #37, and active spec closure is reviewed before PR creation in `.specify/feature.json`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies.
- **Phase 2 Foundational**: Depends on Phase 1 and blocks all user stories.
- **Phase 3 US1**: Depends on Phase 2; first MVP because the TUI shell enables visible safe operation.
- **Phase 4 US2**: Depends on Phase 2 and can use US1 screens for integration, but planner/report tests remain independently executable.
- **Phase 5 US3**: Depends on Phase 2 and benefits from US2 report normalization.
- **Phase 6 Polish**: Depends on selected story completion and final validation.

### User Story Dependencies

- **US1 Run Guided Installation (P1)**: No dependency on US2 or US3 after foundation.
- **US2 Install and Validate Modules Safely (P1)**: No dependency on US3; integrates with US1 TUI if available.
- **US3 Upgrade and Sync Existing Setup (P2)**: Depends conceptually on shared planner/report safety rules from Phase 2 and may reuse US2 normalization.

### Within Each User Story

- Write the story's tests first and confirm they fail before implementing the matching code.
- Implement data/planning/report types before TUI integration.
- Run the story-specific validation command before moving to the next story.

## Parallel Execution Examples

### User Story 1

```bash
Task: "T013 [P] [US1] Add TUI model tests in installer/internal/tui/model_test.go"
Task: "T014 [P] [US1] Add TUI update tests in installer/internal/tui/update_test.go"
Task: "T015 [P] [US1] Add TUI view tests in installer/internal/tui/view_test.go"
```

### User Story 2

```bash
Task: "T021 [P] [US2] Add inventory plan tests in installer/internal/installer/plan_test.go"
Task: "T022 [P] [US2] Add script argv tests in installer/internal/installer/action_test.go"
Task: "T023 [P] [US2] Add report normalization tests in installer/internal/installer/report_test.go"
Task: "T024 [P] [US2] Add runner failure tests in installer/internal/runner/runner_test.go"
```

### User Story 3

```bash
Task: "T032 [P] [US3] Add sync target tests in installer/internal/installer/plan_test.go"
Task: "T033 [P] [US3] Add upgrade report tests in installer/internal/installer/report_test.go"
Task: "T034 [P] [US3] Add repeated-run tests in installer/internal/installer/plan_test.go"
```

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1) and validate the safe main menu.
3. Stop and demo before adding mutating execution paths.

### Incremental Delivery

1. Deliver US1 for the guided menu shell.
2. Deliver US2 for safe install planning, dry-run/report, confirmation gates, and approved script orchestration.
3. Deliver US3 for rerun-safe sync and upgrade maintenance flows.
4. Finish Phase 6 with docs, smoke checks, constitution gates, and PR/spec linkage.

### Review Strategy

Use chained PRs because the implementation is likely above the 400-line review budget: foundation first, menu MVP second, module planning/execution third, sync/upgrade/docs last.

---

## Phase 7: Convergence

- [x] T044 Correct tmux source-path casing to `Tmux/` in `installer/internal/installer/module.go`, `installer/internal/installer/module_test.go`, and installer documentation references per FR-008 (partial)
