# Feature Specification: Dotfiles Installer TUI

**Feature Branch**: Not created by spec phase
**Created**: 2026-07-24
**Status**: Draft
**Input**: GitHub issue #37: "feat(installer): add Bubble Tea TUI for dotfiles installation"

## Clarifications

### Session 2026-07-27

- Q: Should clean-machine setup use a shell bootstrap, a prebuilt binary, or keep Go as a prerequisite? → A: Use both a minimal shell bootstrap and an optional prebuilt binary; Go remains a managed required development dependency.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run Guided Installation (Priority: P1)

As the dotfiles owner, I want a terminal installer menu so I can install the repository-managed environment without remembering every setup script and manual step.

**Why this priority**: The issue's minimum value is a safe, guided installer with install-all and per-module paths.

**Independent Test**: Launch the installer on a machine with partial setup and confirm the menu exposes `start installation`, `sync configs`, `Upgrade tools`, and `quit` without changing anything until a user confirms an action.

**Acceptance Scenarios**:

1. **Given** a clean macOS machine has only system-provided tools, **When** the bootstrap entrypoint runs, **Then** it checks or initiates Xcode Command Line Tools, installs Homebrew when missing, installs Go when missing, and then starts the guided installer or reports the remaining manual system prompt.
2. **Given** the installer is launched, **When** the main menu appears, **Then** it shows `start installation`, `sync configs`, `Upgrade tools`, and `quit`.
3. **Given** the main menu is focused, **When** the user presses `j` or `k`, **Then** focus moves like Neovim navigation.
4. **Given** any safe screen is active, **When** the user presses `q`, **Then** the installer exits or returns to the prior screen without applying unconfirmed changes.

---

### User Story 2 - Install and Validate Modules Safely (Priority: P1)

As the dotfiles owner, I want install-all and per-module installation to analyze existing setup surfaces so Neovim, zsh, Ghostty, tmux, keyboard assets, and macOS setup are handled consistently.

**Why this priority**: The repository already has setup scripts, dependency manifests, and module docs; the installer must orchestrate them instead of inventing conflicting behavior.

**Independent Test**: Run installer dry-run/report flows against each supported module and verify detected state, available actions, validation results, and manual-only guidance match repository docs and scripts.

**Acceptance Scenarios**:

1. **Given** module dependencies are missing, **When** installation is reviewed, **Then** required, optional, Mason-backed, and manual-only items are clearly separated.
2. **Given** Neovim or Ghostty config linking is selected, **When** an unmanaged target exists, **Then** the installer refuses overwrite unless backup behavior is explicitly selected.
3. **Given** tmux, keyboard, AWS local setup, or other manual-only items are detected, **When** the report is shown, **Then** the installer provides action guidance instead of unsafe automation.

---

### User Story 3 - Upgrade and Sync Existing Setup (Priority: P2)

As the dotfiles owner, I want upgrade and sync actions so an already-installed machine can refresh tools and repository-managed config without destructive side effects.

**Why this priority**: Dotfiles maintenance is recurring; safe rerun and upgrade behavior prevents the installer from being a one-time bootstrap tool.

**Independent Test**: Run the same upgrade and sync flows twice and confirm the second run converges with no duplicate links, repeated backups, or unclear ownership.

**Acceptance Scenarios**:

1. **Given** supported tools are installed, **When** `Upgrade tools` runs, **Then** the report identifies upgraded, skipped, failed, optional, and manual items.
2. **Given** repository-managed links already exist, **When** `sync configs` runs, **Then** managed config state is refreshed or reported without replacing unmanaged files.
3. **Given** a prior installer run was interrupted, **When** the installer is rerun, **Then** it reports the current state and offers safe next actions.

## Edge Cases

- Xcode Command Line Tools are absent and macOS requires user interaction to complete `xcode-select --install`.
- Homebrew, Go, or Git are absent before the TUI can be compiled locally.
- A prebuilt installer binary is unavailable for the current architecture, so bootstrap must fall back to installing Go and running from source.
- Homebrew, Node, Git, Neovim, Ghostty, tmux, zsh, or platform assumptions are absent.
- Dependency manifests include tools the installer cannot safely install automatically.
- Backups already exist under `~/.dotfiles_backup`.
- The target config path is a real file, broken symlink, managed symlink, or missing path.
- macOS setup requires user consent, security approval, or app installation.
- AWS CloudFormation/SAM tooling requires local-only downloads or manual repair.
- Keyboard VIA import must remain manual/report-only.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The installer MUST provide a terminal main menu with `start installation`, `sync configs`, `Upgrade tools`, and `quit`.
- **FR-002**: The installer MUST support Neovim-style `j`/`k` navigation and `q` quit/back behavior.
- **FR-003**: The installer MUST provide install-all and per-module flows.
- **FR-004**: The installer MUST inventory existing setup scripts, manifests, and module docs before deciding available actions.
- **FR-005**: The installer MUST classify each action as automatic, confirmation-required, dry-run/report-only, or manual-only.
- **FR-006**: The installer MUST preserve existing safe behavior from Neovim and Ghostty link scripts, including dry-run defaults, backups, removal boundaries, and unmanaged overwrite refusal.
- **FR-007**: The installer MUST report Neovim tools, LSPs, Mason-backed entries, AWS tooling, and optional dependencies separately.
- **FR-008**: The installer MUST report zsh, Ghostty, tmux, keyboard, and macOS setup readiness using existing repository sources.
- **FR-009**: The installer MUST support safe rerun and interrupted-run recovery without duplicate links, backup loops, or destructive cleanup.
- **FR-010**: The installer MUST provide `Upgrade tools` results for changed, skipped, failed, optional, and manual items.
- **FR-011**: The installer MUST provide `sync configs` results for managed, unmanaged, missing, backed-up, removed, and failed config targets.
- **FR-012**: The installer MUST generate a final report summarizing actions, validation status, backups, skipped items, failures, and manual next steps.
- **FR-013**: The installer MUST NOT automate manual-only or unsafe actions such as AWS local bundle repair, macOS security approval, VIA import, or TPM keypress installation unless a later spec explicitly makes them safe.
- **FR-014**: The feature MUST provide a minimal shell bootstrap entrypoint that can run on a clean macOS machine, check or initiate Xcode Command Line Tools installation, install Homebrew when missing, install Go when missing, and then launch the guided installer.
- **FR-015**: The feature SHOULD support a prebuilt installer binary path for first-run convenience, but the bootstrap MUST still ensure Go is installed because Go is a required development dependency for this dotfiles environment.

### Key Entities

- **Installer Session**: One interactive run, including selected action, confirmations, results, and exit state.
- **Bootstrap Entrypoint**: A minimal shell-based first-run path that prepares prerequisites required to launch the TUI on a clean macOS machine.
- **Module**: A repository area with setup or validation behavior, including Neovim, zsh, Ghostty, tmux, keyboard, and macOS setup.
- **Action Plan**: The classified set of install, upgrade, sync, backup, validation, and manual guidance steps.
- **Managed Config Target**: A local file or symlink owned by this repository's setup flow.
- **Backup Record**: A recoverable copy created before replacing user-owned config.
- **Installation Report**: The user-facing summary of current state, changes, skipped items, failures, and next steps.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can identify the correct main action from the first screen in under 30 seconds.
- **SC-002**: The installer reports readiness for all documented modules in one run.
- **SC-003**: Re-running install, upgrade, and sync flows twice produces no duplicate managed links or backup loops.
- **SC-004**: Existing unmanaged Neovim and Ghostty configs are never overwritten without explicit backup confirmation.
- **SC-005**: Manual-only items are reported with actionable guidance and are not silently skipped.
- **SC-006**: The final report distinguishes changed, unchanged, skipped, failed, backup, and manual-next-step items.
- **SC-007**: On a clean supported macOS machine, the bootstrap path reaches the guided installer after prerequisites are installed, or stops with a clear message when macOS requires manual completion of Xcode Command Line Tools installation.

## Assumptions

- The initial target platform is macOS because existing setup paths and scripts are macOS-oriented.
- Existing setup scripts and dependency manifests remain the source of truth for installable tools and config targets.
- Bubble Tea is the intended TUI framework from issue #37, but this specification defines behavior rather than implementation structure.
- Go is not a prerequisite the user must install manually; it is a managed required development dependency installed by the bootstrap when absent.
- Manual AWS setup already documented in issue comments remains report/action-guidance unless safe automation is designed later.
