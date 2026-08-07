# Feature Specification: Neovim Command-Line UI

**Feature Branch**: `001-nvim-cmdline-ui`

**Created**: 2026-07-28

**Status**: Closed - Deferred

**Input**: User description: "Improve the Neovim command-line experience. The user reviewed dressing.nvim, noted it is archived, and is considering noice.nvim. The current disliked behavior is that command-line option lists do not span the expected input width. The user wants floating notifications because the goal is to remove the visible command-line area; the statusline already shows the current mode. The current configuration still shows the command line and notifications in the same bottom area. If Noice is selected, its UI must be adjusted so the option list does not look like the disliked reference. Before choosing between extending Noice, using Noice, combining Snacks and Noice, creating a custom command-line UI, or other options, the implementation must present pros and cons for approval. Also review fidget.nvim because its LSP progress notification style matches the user's expectation, while the current LSP notification setup is functional."

**Related Issue**: [#62](https://github.com/aogallo/dotfiles/issues/62)

## Clarifications

### Session 2026-07-29

- Q: Should the Noice-based command-line UI be accepted after manual validation? -> A: No. Both eager/custom and LazyVim-like Noice attempts duplicated the native bottom command line in the real UI; the floating command-line requirement remains deferred until another provider can satisfy it.

### Session 2026-07-28

- Q: Should issues #48 and #27 be included in this command-line UI spec or handled separately? -> A: Keep this spec focused on command-line UI; handle #48 and #27 as separate specs coordinated in the same session and final delivery flow.
- Q: How should the separate Neovim specs be delivered to main? -> A: Use separate specs with one integration branch and one final PR to main.
- Q: What should happen to custom code when a plugin replaces its behavior? -> A: Remove or disable replaced custom code in the same work unit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use a Floating Command Line (Priority: P1)

As a Neovim user, I want command entry to appear in a centered floating interface so the bottom command-line area no longer duplicates information already shown in the statusline.

**Why this priority**: This is the primary user-visible change and removes the current source of visual duplication.

**Independent Test**: Can be tested by opening command mode and confirming command entry appears in a floating interface while the bottom command-line area remains unused for normal command entry.

**Acceptance Scenarios**:

1. **Given** Neovim is open in a normal editing buffer, **When** the user starts command entry, **Then** a centered floating command input appears instead of relying on the bottom command-line area.
2. **Given** the user is entering a command, **When** the editor indicates the current mode, **Then** the statusline remains the visible source of truth for command mode.
3. **Given** the floating command input is visible, **When** the user cancels or submits the command, **Then** the floating interface closes without leaving stale UI elements.

---

### User Story 2 - See Full-Width Command Options (Priority: P1)

As a Neovim user, I want command options and completions to align with the command input width so the option list feels intentionally attached to the input instead of appearing as a narrow detached menu.

**Why this priority**: The user's main objection to existing approaches is the narrow option list. A floating command line without correct option sizing would fail the feature goal.

**Independent Test**: Can be tested by opening command completion for commands with multiple options and verifying the option list uses the intended input width and alignment.

**Acceptance Scenarios**:

1. **Given** the floating command input is open, **When** command options are shown, **Then** the options appear aligned with the command input and occupy the expected width.
2. **Given** the command options contain short labels, **When** the option list appears, **Then** the menu still uses the designed command-line width instead of shrinking to only the label text.
3. **Given** the editor width changes, **When** command options are shown again, **Then** the command input and options remain readable and aligned.

---

### User Story 3 - Receive Floating Notifications (Priority: P2)

As a Neovim user, I want notifications and messages to appear outside the bottom command-line area so command output does not compete with the statusline or command entry.

**Why this priority**: Removing the command-line area requires another clear place for notifications, warnings, and progress messages.

**Independent Test**: Can be tested by triggering informational, warning, error, and progress messages and confirming they appear in floating UI with discoverable history.

**Acceptance Scenarios**:

1. **Given** a normal notification is emitted, **When** it appears, **Then** it is shown in a floating notification area rather than the bottom command-line area.
2. **Given** a warning or error is emitted, **When** it appears, **Then** it remains noticeable and readable without blocking normal editing unnecessarily.
3. **Given** previous notifications exist, **When** the user opens notification history, **Then** recent notifications are discoverable without relying on the command-line area.

---

### User Story 4 - Review LSP Progress Feedback (Priority: P3)

As a Neovim user, I want LSP startup and progress feedback to feel like unobtrusive floating progress notifications so language server activity is visible without noisy command-line output.

**Why this priority**: The existing LSP notification behavior is functional, but the user specifically wants the visual style reviewed against a better progress-notification expectation.

**Independent Test**: Can be tested by opening a file that starts an LSP server and verifying progress appears as unobtrusive floating feedback while normal notifications still behave correctly.

**Acceptance Scenarios**:

1. **Given** an LSP server starts or reports progress, **When** progress events occur, **Then** progress feedback appears as unobtrusive floating UI.
2. **Given** LSP progress completes, **When** the completion state is shown, **Then** the message expires or settles without lingering indefinitely.
3. **Given** no LSP progress is active, **When** the editor is idle, **Then** no empty or stale progress UI remains visible.

---

### User Story 5 - Approve the UI Provider Decision (Priority: P1)

As the repository owner, I want to review pros and cons before a UI provider is selected so the final implementation does not add overlapping tools or duplicate notification systems without a clear reason.

**Why this priority**: The user explicitly requested approval before choosing whether to use, combine, extend, or replace candidate UI approaches.

**Independent Test**: Can be tested by reviewing the planning artifacts and confirming they compare viable approaches before implementation begins.

**Acceptance Scenarios**:

1. **Given** planning has started, **When** candidate approaches are evaluated, **Then** the plan documents benefits, risks, overlap, and removal implications for each viable approach.
2. **Given** a candidate approach would introduce a notification provider, **When** the decision is presented, **Then** the plan identifies whether existing notification behavior must be kept, disabled, replaced, or removed.
3. **Given** the comparison is complete, **When** implementation is about to begin, **Then** the user approves the selected direction before code changes are made.

### Edge Cases

- Repeated Neovim starts must not register duplicate notification handlers, duplicate command-line UI handlers, or conflicting message routes.
- Existing custom notification history must remain accessible or be replaced by an equivalent discoverable history.
- Error and warning messages must remain visible even if the floating notification provider fails or is unavailable.
- Command entry must remain usable in small terminal windows and large split layouts.
- Search prompts, command history, command completion, and command cancellation must remain usable after the bottom command-line area is removed from normal use.
- LSP progress must not spam persistent notifications during server startup, workspace indexing, or repeated file opens.
- The change must not introduce user-specific paths, secrets, machine-local assumptions, or config that only works on one Mac architecture.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide command entry through a floating interface during normal command use.
- **FR-002**: The system MUST avoid showing normal command entry in the bottom command-line area.
- **FR-003**: The system MUST keep the statusline as the visible command-mode indicator during command entry.
- **FR-004**: The system MUST show command options and completions aligned to the floating command input.
- **FR-005**: The system MUST ensure command option lists use the intended command input width rather than shrinking to a narrow label-only menu.
- **FR-006**: The system MUST keep command entry, completion navigation, submission, and cancellation usable from keyboard-only workflows.
- **FR-007**: The system MUST route normal notifications and messages away from the bottom command-line area.
- **FR-008**: The system MUST provide a discoverable way to inspect recent notification and message history.
- **FR-009**: The system MUST show warnings and errors prominently enough for the user to notice without requiring command-line output.
- **FR-010**: The system MUST provide unobtrusive floating feedback for LSP progress events.
- **FR-011**: The system MUST prevent stale progress or notification UI from remaining visible after work completes.
- **FR-012**: The system MUST evaluate viable command-line, input, notification, and LSP progress approaches before implementation.
- **FR-013**: The system MUST document pros, cons, overlap, maintenance risk, and removal implications for each viable approach before selecting one.
- **FR-014**: The system MUST obtain user approval for the selected approach before implementation begins.
- **FR-015**: The system MUST avoid overlapping active notification providers unless the plan justifies the overlap and documents how conflicts are prevented.
- **FR-016**: The system MUST remove or disable superseded notification, input, or command-line behavior when a replacement is selected.
- **FR-017**: The system MUST preserve existing insert-mode completion behavior.
- **FR-018**: The system MUST remain portable across supported macOS environments and avoid user-specific absolute paths.
- **FR-019**: The system MUST be safe to load repeatedly without duplicate handlers, duplicate messages, or accumulated UI side effects.
- **FR-020**: The system MUST include validation steps that prove command entry, command options, notifications, history, LSP progress, and fallback behavior.
- **FR-021**: The system MUST update affected Neovim module documentation with usage, customization, validation, troubleshooting, and rollback guidance.
- **FR-022**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification.
- **FR-023**: Before pull request creation, the active specification relationship and closure/archival decision MUST be reviewed with the user.
- **FR-024**: This specification MUST remain scoped to command-line UI, command option layout, notification routing, LSP progress display, and replacement cleanup directly caused by those UI provider choices.
- **FR-025**: Delivery MUST preserve separate specification artifacts for command-line UI, Treesitter textobjects, and plugin cleanup while coordinating their implementation through one integration branch and one final pull request to `main`.
- **FR-026**: If an approved plugin replaces existing custom command-line, notification, message, or LSP progress behavior, the implementation MUST remove or disable the replaced custom code in the same work unit.

### Key Entities

- **Command-Line Interaction**: A command-entry session, including prompt state, typed command, completion/options state, submission, cancellation, and visual placement.
- **Command Option List**: The visible set of command suggestions or completions associated with command entry, including alignment and width behavior.
- **Notification Event**: An informational, warning, error, or progress message that should be visible outside the bottom command-line area.
- **Notification History**: A discoverable record of recent notifications and messages.
- **LSP Progress Event**: A language-server startup, indexing, or work-progress update that should be shown unobtrusively and cleared when complete.
- **UI Provider Decision**: The approved selection of command-line, notification, and progress UI responsibilities, including what existing behavior is kept, disabled, replaced, or removed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In normal command-entry workflows, 100% of tested command prompts appear in the floating interface rather than the bottom command-line area.
- **SC-002**: In tested command-completion workflows, option lists align with the floating input and use at least 90% of the intended input width.
- **SC-003**: 100% of tested informational, warning, and error notifications appear outside the bottom command-line area.
- **SC-004**: Notification history can be opened and used to inspect at least the most recent 20 notification or message events.
- **SC-005**: LSP progress appears within 1 second of a progress event in tested language-server startup scenarios and clears within 5 seconds after completion.
- **SC-006**: Reopening Neovim 5 times in a row does not produce duplicate handlers, duplicate startup notifications, or stale UI artifacts.
- **SC-007**: Command entry and command completion remain usable at terminal widths of 80, 120, and 160 columns.
- **SC-008**: Planning artifacts include a user-approved decision comparing viable UI approaches before implementation begins.

## Assumptions

- The bottom command-line area should be avoided for normal command entry and notifications, but emergency fallback behavior may still use native editor mechanisms if the floating UI cannot start.
- The statusline already communicates command mode and should not be replaced as part of this feature.
- The current notification setup is functional and should not be removed unless the selected approach replaces it with equivalent or better behavior.
- The planning phase will compare named candidate tools and custom approaches, but this specification intentionally does not select the implementation provider.
- This feature is limited to repository-managed Neovim configuration and documentation; installer behavior changes are out of scope unless needed to validate or document the Neovim module.
- Treesitter textobjects/incremental selection from issue #48 and plugin removal UI from issue #27 are separate Neovim specs, coordinated in the same working session and final delivery flow rather than merged into this command-line UI specification.
- The final delivery flow for this Neovim work is one integration branch and one final pull request to `main`, while keeping each spec independently reviewable.
- Replaced custom UI or notification code should not remain active as an undocumented fallback; fallback behavior must be explicit and justified if retained.

## Closure Decision

- Noice was rejected after manual validation because it duplicated native command entry in the bottom command-line area and the LazyVim-like retry introduced a statusline integration error.
- Noice and Nui were removed from Neovim config, local `vim.pack` state, and `nvim/nvim-pack-lock.json`.
- The current repository state keeps native command-line behavior plus Snacks/custom notification history.
- Issue #62 remains a future enhancement candidate if a provider can satisfy the no-duplicate-cmdline requirement without breaking message/history behavior.
