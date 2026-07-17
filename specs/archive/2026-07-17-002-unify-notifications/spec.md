# Feature Specification: Unify Neovim Notifications

**Feature Branch**: `002-unify-notifications`

**Created**: 2026-07-16

**Status**: Draft

**Input**: User description: "After the notification implementation, all notifications were expected to appear the same way as LSP loading notifications. After changing a file and running <leader>gd, an error appeared in the command line instead. Informational, warning, and error notifications should all use the same visual format."

## Clarifications

### Session 2026-07-16

- Q: Should Neovim messages be included in the unified notification scope? -> A: Include messages, with LazyVim-style visible popup and searchable notification/message history as the UX reference.
- Q: Should diagnostics UI be included in this notification/message spec? -> A: Create a separate issue/spec for diagnostics; keep this spec focused on notifications, messages, and LSP progress.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See Command Errors as Notifications (Priority: P1)

As a Neovim user, I want errors and messages triggered by editor commands to appear in the same visible notification surface as other notifications so I can understand feedback without reading raw command-line stack traces.

**Why this priority**: The reported failure shows that the notification experience is incomplete for command-triggered errors, which keeps the most important messages in the least readable place.

**Independent Test**: Can be tested by triggering command output and a command failure during an editing session and confirming each appears as a visible notification or message entry with readable summary content instead of only as command-line output.

**Acceptance Scenarios**:

1. **Given** Neovim is open and the user runs a command that fails, **When** the failure occurs, **Then** the user sees a visible error notification using the same notification format as other editor notifications.
2. **Given** a command failure includes a long diagnostic trace, **When** the notification appears, **Then** the visible notification shows a concise readable summary and the full detail remains reviewable through an appropriate history or message review path.
3. **Given** the failed command was triggered from a key mapping, **When** the error is reported, **Then** the notification identifies enough context for the user to understand which action failed.
4. **Given** Neovim produces an informational, warning, or error message, **When** the message is emitted, **Then** it is captured in the same user-facing notification and message review experience.

---

### User Story 2 - Get Consistent Severity Formatting (Priority: P2)

As a Neovim user, I want informational, warning, error, progress notifications, and editor messages to share one consistent visual language so I can quickly recognize severity without switching mental models.

**Why this priority**: The user's expectation is not just visibility; the notification system must feel coherent across severities and sources.

**Independent Test**: Can be tested by triggering informational, warning, error, progress, and message output and confirming they use a unified format with clear severity distinctions.

**Acceptance Scenarios**:

1. **Given** an informational message is emitted, **When** it appears, **Then** it uses the same notification layout as LSP loading messages with informational severity styling.
2. **Given** a warning message is emitted, **When** it appears, **Then** it uses the same notification layout with warning severity styling.
3. **Given** an error message is emitted, **When** it appears, **Then** it uses the same notification layout with error severity styling.
4. **Given** an LSP progress message is emitted, **When** it appears, **Then** it remains visually consistent with the other notification severities.
5. **Given** the user opens the notification or message history, **When** previous messages are listed, **Then** the history uses a readable picker-style layout with searchable entries and message detail preview.

---

### User Story 3 - Preserve Editing Flow During Failures (Priority: P3)

As a Neovim user, I want notifications to report problems without stealing focus or breaking the current editing flow so failures remain actionable instead of disruptive.

**Why this priority**: Visible notifications should improve feedback, not interrupt editing or make failures harder to recover from.

**Independent Test**: Can be tested by triggering a notification or failure while editing and confirming focus remains in the editor and the current buffer/window state remains usable.

**Acceptance Scenarios**:

1. **Given** the user is editing a file, **When** a notification appears, **Then** editing focus remains where it was.
2. **Given** a command fails while opening or updating another editor view, **When** the failure is reported, **Then** the current session remains usable and the user receives actionable feedback.
3. **Given** multiple notifications occur close together, **When** the user continues editing, **Then** the notifications remain readable without blocking normal input.

---

### Edge Cases

- Command failures that occur during redraw, window changes, or view opening should still surface through the unified notification experience when possible.
- Long stack traces should not overwhelm the normal editing view; the visible notification should summarize while preserving access to full details.
- Existing editor messages should be captured in notification history even when they are not severe enough to require a transient popup.
- Diagnostic presentation improvements should be tracked separately so notification changes do not unintentionally alter inline diagnostic behavior.
- Notifications emitted before the notification UI is fully ready should not cause startup failure or disappear silently.
- Rapid bursts of mixed informational, warning, error, and progress notifications should remain readable and should not block editing input.
- Repeated dotfiles application must not register duplicate notification behavior or duplicate visible messages.
- Existing user configuration must not be overwritten destructively.
- Missing optional notification capabilities should degrade gracefully while preserving baseline message visibility.
- The behavior should remain portable across supported local machines used by these dotfiles.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Neovim configuration MUST present informational, warning, error, and progress notifications through one consistent visible notification experience.
- **FR-002**: Errors produced by editor commands and key-triggered actions MUST be visible as error notifications instead of appearing only as raw command-line output.
- **FR-003**: Error notifications MUST include a concise summary that helps the user identify the failed action and the high-level reason for failure.
- **FR-004**: Long diagnostic details MUST remain accessible through a review path without forcing the full trace into the primary visible notification.
- **FR-005**: LSP loading and progress notifications MUST remain visually consistent with other notification severities.
- **FR-006**: Severity levels MUST be visually distinguishable while preserving a shared layout and interaction model.
- **FR-007**: Notifications MUST not steal editing focus during normal display.
- **FR-008**: Notification behavior MUST keep the editor session usable when a notification source fails, emits malformed data, or lacks optional metadata.
- **FR-009**: The configuration MUST be safe to apply repeatedly without duplicate notification handlers or duplicate notification output.
- **FR-010**: The change MUST avoid destructive changes to existing user configuration and preserve a safe fallback for baseline message visibility.
- **FR-011**: Editor messages MUST be included in the unified review experience and MUST be searchable or filterable in a readable picker-style history with detail preview.
- **FR-012**: The transient visible notification and the message history MUST use the same severity labels and source context so entries can be correlated across both surfaces.
- **FR-013**: The change MUST include a repeatable validation path for informational, warning, error, progress, editor-message, command-failure, history-search, and burst-notification scenarios.
- **FR-014**: The active specification relationship MUST be preserved for future planning and closure review before PR creation.
- **FR-015**: Diagnostic UI changes, including inline diagnostic presentation and current-line diagnostic styling, MUST remain outside this feature except where needed to avoid regressions from notification changes.

### Key Entities *(include if feature involves data)*

- **Notification**: A user-facing editor event with message content, severity, source context, and relative timing.
- **Editor Message**: A message produced by the editor or plugins that may appear transiently, in history, or both depending on severity and relevance.
- **Message History**: A searchable, picker-style review surface that lists recent notifications and editor messages with a detail preview.
- **Severity**: The classification of a notification as informational, warning, error, or progress.
- **Command Failure**: A failed editor action triggered directly or through a key mapping that should be reported in a readable user-facing way.
- **Diagnostic Detail**: Extended error content, such as traces or raw messages, that should remain reviewable without dominating the primary notification display.
- **Diagnostic UI**: Inline or current-line diagnostic presentation for code issues; this is related UX but belongs to a separate follow-up scope.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: During manual validation, 100% of tested informational, warning, error, and progress notifications appear in the unified visible notification format.
- **SC-002**: A command failure triggered from a key mapping appears as a visible error notification within 2 seconds in manual validation.
- **SC-003**: Users can identify the failed action and high-level reason from the visible error notification in under 10 seconds.
- **SC-004**: Full diagnostic detail for a long failure remains reviewable after the visible notification appears.
- **SC-005**: A burst of 10 mixed-severity notifications leaves editing input usable and keeps the latest important message readable.
- **SC-006**: Reapplying the dotfiles configuration does not create duplicate notification handlers or duplicate visible notifications.
- **SC-007**: The reported `<leader>gd` failure scenario no longer appears only as command-line output during validation.
- **SC-008**: Users can open notification/message history, search for a recent message, and view its detail preview in under 10 seconds.
- **SC-009**: The transient popup and history view visually match the referenced LazyVim-style experience closely enough that severity, source, message text, and selected detail are immediately recognizable.

## Assumptions

- The primary user is the owner of these dotfiles using Neovim interactively.
- The expected experience is consistent with the existing LSP loading notification style introduced by the prior notification work.
- Command-line output may still exist as a fallback or detailed record, but routine user-facing notification feedback should appear in the visible notification surface.
- The first version focuses on session-scoped notification review, not persistent notification history across editor restarts.
- The reported statusline failure is treated as a representative command-failure notification scenario; fixing the underlying statusline defect may be part of implementation planning but the user-facing requirement is unified notification display.
- The attached LazyVim screenshots are the UX reference for transient notification shape and notification/message history layout, not a requirement to clone every color or pixel exactly.
- The attached diagnostic screenshots establish a desired future LazyVim-like diagnostic experience, but diagnostics will be planned as a separate issue/spec rather than included in this notification/message feature.
