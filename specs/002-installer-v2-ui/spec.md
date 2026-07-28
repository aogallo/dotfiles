# Feature Specification: Installer V2 UI and Install Flow

**Feature Branch**: `[not-created-by-specify]`

**Created**: 2026-07-27

**Status**: Draft

**Input**: User description: "Create a second version of the dotfiles installer with better UI/UX, colors, full-screen terminal experience, clearer confirmation language, automatic backups during install, visible progress while tools install, and expected behavior when executing the downloaded release binary. User provided terminal UI reference images and `/Users/allan/Desktop/DESIGN.md`."

## Clarifications

### Session 2026-07-27

- Q: Should emojis be allowed as installer UI status indicators? -> A: Emojis are allowed as secondary visual cues, but every status must also have a text label and/or color indicator.
- Q: When should installer TUI images or screenshots be added? -> A: Do not add visual mockups or screenshots now; add final screenshots only after the real TUI is implemented and approved.

### Session 2026-07-28

- Q: Which visual theme should the installer use? → A: Bubble Tea-inspired dark palette.
- Q: What status concepts must installer help explain? → A: Help always includes all status concepts: preview, automatic, confirmation, manual action, skipped, failed, backed up, and completed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run the Downloaded Installer Successfully (Priority: P1)

As a user who downloads the `dotfiles-installer-darwin-arm64` release artifact, I want executing that file to visibly launch the installer experience or give me an unmistakable next step, so I do not think the installer did nothing.

**Why this priority**: If the downloaded installer appears to do nothing, every other improvement is unreachable. The first-run experience must prove that the installer is alive and ready to guide the user.

**Independent Test**: Can be tested by downloading the release artifact on a supported Mac, executing it from the expected user entry points, and confirming the installer visibly starts or displays a clear actionable message.

**Acceptance Scenarios**:

1. **Given** a user has downloaded the installer artifact, **When** they execute it from a terminal, **Then** the installer opens an interactive full-screen experience or prints clear instructions explaining how to start it.
2. **Given** a user launches the installer from a non-terminal context where interaction cannot continue safely, **When** execution starts, **Then** the user sees a clear explanation that the installer must be run from a terminal and includes the exact command to run.
3. **Given** the installer cannot start because of platform, permission, or quarantine restrictions, **When** execution fails, **Then** the user sees a plain-language error with the next action required.

---

### User Story 2 - Understand and Confirm Installation Safely (Priority: P2)

As a user installing dotfiles, I want the installer to clearly explain what will change and ask for one understandable confirmation before making changes, so I can proceed confidently without decoding terms like "confirmation required", "manual only", or "report only".

**Why this priority**: The current safety language blocks trust because it describes internal modes instead of user decisions. The user expects that choosing install means the installer will protect existing files automatically.

**Independent Test**: Can be tested by starting an install with existing local configuration files and confirming the UI explains planned changes, backup behavior, and the single action needed to proceed.

**Acceptance Scenarios**:

1. **Given** the installer detects changes that will modify local files, **When** the user chooses install, **Then** the installer summarizes affected files, automatic backup behavior, and asks for explicit confirmation using plain language.
2. **Given** the installer is in preview mode, **When** a report-only or dry-run step is shown, **Then** the UI explains that no files will be changed and labels the mode in user-facing language.
3. **Given** a step requires manual user action, **When** it appears in the UI, **Then** the installer explains why automation is not safe and what the user must do next.
4. **Given** a user confirms installation, **When** local files already exist, **Then** the installer creates backups automatically using the established backup naming format before changing those files.

---

### User Story 3 - Track Install Progress by Tool and File (Priority: P3)

As a user watching the installer run, I want visible progress for the overall install and for the current tool or configuration step, so I know whether the installer is working, waiting, failed, or complete.

**Why this priority**: Installing developer tools can take time. Without progress, users assume the process is frozen and may cancel or rerun it unsafely.

**Independent Test**: Can be tested by running an install that includes multiple tools and configuration files, then verifying that each active, completed, skipped, failed, and manual step is visible in the UI.

**Acceptance Scenarios**:

1. **Given** installation is running, **When** a tool is being installed or upgraded, **Then** the UI shows the current tool name, current action, and progress state.
2. **Given** multiple install steps exist, **When** each step completes, **Then** the UI updates the overall completed count and status without requiring the user to infer it from logs.
3. **Given** a step takes longer than expected, **When** the installer is still running, **Then** the UI continues to show activity or elapsed status so the user does not assume the app is frozen.
4. **Given** a step fails, **When** the installer continues or stops, **Then** the UI shows the failed step, the reason, and the recovery action.

---

### User Story 4 - Use a Full-Screen Colored Terminal UI (Priority: P4)

As a user running the installer, I want a full-screen terminal UI with meaningful colors, readable layout, keyboard guidance, and status semantics, so the experience feels intentional instead of like raw logs.

**Why this priority**: The improved UI reduces confusion and makes safety states visible, but it should not block the core ability to run and confirm installation.

**Independent Test**: Can be tested by opening the installer in common terminal sizes and confirming it occupies the available terminal area, uses color-coded states, and remains readable on desktop and smaller terminal windows.

**Acceptance Scenarios**:

1. **Given** the user opens the installer in a supported terminal, **When** the UI starts, **Then** it uses the available terminal viewport with a header, main content area, progress/status area, and navigation footer.
2. **Given** files or tools have different states, **When** they are listed, **Then** synced, changed, skipped, failed, manual, and selected states are visually distinct through labels, color, and optional secondary emoji cues.
3. **Given** the terminal is narrow or short, **When** the installer renders, **Then** critical actions and statuses remain visible without corrupting the layout.
4. **Given** keyboard navigation is available, **When** the user moves through choices, **Then** the current selection is clearly highlighted and the footer explains available keys.
5. **Given** the user opens help from any installer screen, **When** status terminology is shown, **Then** the help explains preview, automatic, confirmation, manual action, skipped, failed, backed up, and completed states.

### Edge Cases

- The installer is run outside a terminal or from a file manager that closes immediately after execution.
- The downloaded artifact lacks execute permission or is blocked by operating system security/quarantine controls.
- The installer is run repeatedly after a previous successful install; it must not create unnecessary duplicate changes.
- Existing user configuration files differ from repository files and require backup before replacement or linking.
- A backup target already exists for the same file and timestamp/window; the installer must avoid overwriting previous backups.
- A tool installation is slow, prompts externally, loses network access, or fails halfway through.
- Optional tools are missing or unavailable while core dotfile sync can still continue.
- Apple Silicon and Intel Macs require different release artifacts or support messages.
- The terminal does not support colors, alternate-screen full-screen behavior, or required dimensions.
- The user cancels before confirmation, during a long-running step, or after partial completion.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The installer MUST visibly launch an interactive experience when executed from a supported terminal.
- **FR-002**: If the installer cannot run interactively, it MUST display a clear reason and the exact next command or action the user should take.
- **FR-003**: The installer MUST use a full-terminal layout with persistent header, main content, progress/status area, and keyboard-help footer.
- **FR-004**: The installer MUST use color and labels to distinguish safe preview, pending change, active work, success, skipped, manual action, warning, and failure states.
- **FR-004a**: The installer MUST use a Bubble Tea-inspired dark palette: dark background, bright cyan/mint primary accents, purple/magenta secondary accents, pink failure accents, and readable muted text for secondary guidance.
- **FR-005**: The installer MUST provide readable output when color or full-screen terminal capabilities are unavailable.
- **FR-005a**: The installer MAY use emojis as secondary visual cues, but MUST NOT rely on emojis as the only way to communicate status, progress, warnings, errors, or required user action.
- **FR-006**: The installer MUST replace unclear internal labels such as "confirmation required", "manual only", and "report only" with plain-language user-facing explanations.
- **FR-007**: The installer MUST explain preview/dry-run mode as a safe review where no files are changed.
- **FR-008**: The installer MUST ask for explicit confirmation before mutating files, installing tools, linking files, backing up files, removing files, syncing files, or upgrading tools.
- **FR-009**: The confirmation prompt MUST summarize what will change, what will be backed up, what will be skipped, and what requires manual action before the user confirms.
- **FR-010**: When the user confirms installation, the installer MUST automatically back up existing local files that would be modified, using the established backup format.
- **FR-011**: The installer MUST never overwrite an existing backup without creating a distinct backup path or warning the user before proceeding.
- **FR-012**: The installer MUST be idempotent: repeated successful runs should report already-correct files and tools without unnecessary changes.
- **FR-013**: The installer MUST show overall progress as completed steps out of total steps and a percentage or equivalent completion indicator.
- **FR-014**: The installer MUST show current step progress for long-running tool installs, upgrades, syncs, backups, and links.
- **FR-015**: The installer MUST show a final report with completed, changed, backed up, skipped, manual, and failed items.
- **FR-016**: The installer MUST preserve user secrets and must not display secret values in UI, logs, reports, or error messages.
- **FR-017**: The installer MUST validate required dependencies before starting mutating actions and explain missing dependency impact.
- **FR-018**: The installer MUST support cancellation before confirmation without changing files.
- **FR-019**: If cancellation or failure occurs after changes begin, the installer MUST show what completed, what did not complete, and what recovery actions are available.
- **FR-020**: The installer MUST document the active release artifact names and expected user launch flow in release-facing instructions.
- **FR-021**: The installer MUST clearly differentiate automatic actions from manual user actions in the UI and final report.
- **FR-022**: Generated task artifacts for this feature MUST link each implementation phase back to the matching user-story heading in this specification.
- **FR-023**: Installer help MUST include a complete status legend explaining preview, automatic, confirmation, manual action, skipped, failed, backed up, and completed states, regardless of the current screen.

### Key Entities

- **Install Session**: A single user run of the installer, including selected mode, confirmation state, progress, cancellation state, and final outcome.
- **Install Step**: A unit of work shown to the user, such as preview, backup, link, sync, install, upgrade, remove, skip, or manual action.
- **Configuration Item**: A dotfile, directory, or configuration group that may be synced, linked, skipped, backed up, or marked for manual resolution.
- **Tool Item**: A developer tool that may be missing, already installed, installing, upgraded, skipped, failed, or complete.
- **Backup Record**: A user-protective record describing the original path, backup path, backup time, and reason the backup was created.
- **Final Report**: The end-of-run summary that lists what changed, what was backed up, what failed, what was skipped, and what remains manual.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of first-time users can start the downloaded installer or identify the exact command needed to start it within 60 seconds.
- **SC-002**: 90% of users can correctly identify whether the installer will change files before confirming installation.
- **SC-003**: 100% of modified existing local configuration files are backed up before being changed during confirmed installation.
- **SC-004**: Users can see either active progress or a current waiting state within 2 seconds during every long-running install step.
- **SC-005**: The final report accounts for 100% of planned steps as completed, changed, backed up, skipped, manual, cancelled, or failed.
- **SC-006**: Re-running the installer after a successful install completes without unintended duplicate backups or repeated changes for already-correct items.
- **SC-007**: Confusion-related issue reports about "confirmation required", "manual only", "report only", and downloaded binary launch behavior decrease by at least 75% after release.
- **SC-008**: The UI remains usable at common terminal sizes, including 80x24 and larger desktop full-screen sessions.
- **SC-009**: 100% of UI states remain understandable when emojis are not rendered or are visually ambiguous.
- **SC-010**: Visual review for UI-changing PRs includes a dark-mode preview that demonstrates the approved Bubble Tea-inspired palette across at least menu, status, warning/manual, and failure states.
- **SC-011**: A user can find a plain-language explanation for every installer status concept from help without needing to visit the specific screen where that status appears.

## Assumptions

- The target user is a developer or power user installing personal dotfiles on macOS.
- The V2 installer should improve the existing installer experience rather than introduce a separate graphical desktop app.
- The release artifact is expected to be launched primarily from a terminal, but failures from non-terminal launch paths must be understandable.
- The existing backup naming format is already defined elsewhere in the project and should be reused.
- The visual direction should use a Bubble Tea-inspired dark theme: dark terminal surface, monospaced typography, cyan/mint primary accents, purple/magenta secondary accents, pink failure accents, meaningful semantic colors, and keyboard-driven interaction.
- Bubble Tea-style examples are valid inspiration for progress bars, compact status lists, color accents, and tasteful emoji usage, but emoji usage must remain supplemental and never replace text labels.
- TUI images/screenshots are deferred until the implemented UI is approved; draft mockup images are not required before US4 is complete.
- Preview/dry-run behavior remains available, but must be explained in user language.
- Manual-only actions are allowed only when automation would be unsafe or unreliable, and each manual action must explain its reason.
