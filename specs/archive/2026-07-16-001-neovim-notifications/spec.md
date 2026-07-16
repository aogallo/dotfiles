# Feature Specification: Neovim Notifications

**Feature Branch**: `001-neovim-notifications`

**Created**: 2026-07-16

**Status**: Draft

**Input**: User description: "Explore Neovim notifications. Current notifications appear in the command line, which is hard to notice. The desired behavior is visible editor notifications with a usable history, similar to the referenced LazyVim notification experience, and a solid foundation for resolving notification and LSP progress work in issue #22."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See Important Notifications While Editing (Priority: P1)

As a Neovim user, I want editor messages to appear as visible notifications outside the command line so I can notice important feedback without constantly watching the command line area.

**Why this priority**: This solves the primary usability problem: notifications are easy to miss during normal editing.

**Independent Test**: Can be tested by triggering a normal informational notification during an editing session and confirming it appears in a visible notification surface without requiring the user to inspect the command line.

**Acceptance Scenarios**:

1. **Given** Neovim is open and the user is editing a file, **When** a normal informational message is emitted, **Then** the user sees a visible notification without moving focus to the command line.
2. **Given** multiple notifications occur close together, **When** the user continues editing, **Then** each notification remains readable long enough to understand its source and message.
3. **Given** a notification expires from the visible surface, **When** the user continues editing, **Then** the editor remains focused on the user's current work.

---

### User Story 2 - Review Notification History Clearly (Priority: P2)

As a Neovim user, I want a readable notification history so I can review missed or expired messages without digging through noisy command output and traces.

**Why this priority**: Visibility alone is not enough; users also need recovery when messages disappear or are missed.

**Independent Test**: Can be tested by producing several notifications, opening the notification history, and confirming the messages are readable, ordered, and easier to scan than raw command messages.

**Acceptance Scenarios**:

1. **Given** notifications have occurred during the session, **When** the user opens notification history, **Then** recent notifications are displayed in a readable order with enough context to identify each message.
2. **Given** noisy command output or traces exist in the session, **When** the user opens notification history, **Then** notification review remains focused on notification events rather than raw command-line noise.
3. **Given** no notifications have occurred, **When** the user opens notification history, **Then** the user receives clear empty-state feedback.

---

### User Story 3 - Understand LSP Startup Progress (Priority: P3)

As a Neovim user, I want language tooling startup and progress messages to use the same notification experience so I can understand when language support is loading, ready, delayed, or failed.

**Why this priority**: This prepares the user-facing foundation for issue #22 without making LSP progress a separate notification experience.

**Independent Test**: Can be tested by opening a project that starts language tooling and confirming progress-related events appear consistently with other notifications.

**Acceptance Scenarios**:

1. **Given** language tooling starts after opening a supported project, **When** progress begins, **Then** the user sees a concise progress notification.
2. **Given** language tooling finishes loading successfully, **When** progress completes, **Then** the user sees clear completion feedback or the progress notification resolves cleanly.
3. **Given** language tooling fails, stalls, or emits an error, **When** the event occurs, **Then** the user sees actionable feedback and can review it later in notification history.

---

### Edge Cases

- Notifications emitted before the full editor UI finishes loading should not fail silently; they should either appear later or remain available in history.
- Rapid bursts of notifications should not make the editor unusable or hide the most important message.
- Long messages and traces should remain readable without overwhelming the normal editing view.
- Repeated setup runs must be idempotent and must not duplicate notification behavior.
- Existing user configuration must not be overwritten destructively.
- Missing optional notification capabilities should degrade gracefully to the existing command-line behavior with clear documentation.
- The behavior should be portable across supported local machines used by these dotfiles.
- Notification history should remain session-scoped unless a future requirement explicitly asks for persistence across editor restarts.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Neovim configuration MUST route normal editor notifications to a visible notification surface instead of relying only on the command line.
- **FR-002**: The visible notification surface MUST support informational, warning, error, and progress-style messages with clear visual distinction.
- **FR-003**: Users MUST be able to open a notification history view for the current editor session.
- **FR-004**: Notification history MUST show recent notification messages in a readable order with enough context to identify the message source, severity, and time relationship.
- **FR-005**: The notification experience MUST reduce reliance on raw command messages for routine notification review.
- **FR-006**: LSP startup and progress events MUST be able to use the same user-facing notification flow as ordinary editor notifications.
- **FR-006a**: LSP failure notifications MUST include the language client name, severity, concise failure reason when available, and remain reviewable in notification history.
- **FR-007**: Notification behavior MUST not steal editing focus during normal notification display.
- **FR-008**: Notification behavior MUST remain non-destructive to existing user configuration and safe to apply repeatedly.
- **FR-009**: If the optional visible notification capability is unavailable, the configuration MUST preserve baseline `vim.notify` behavior without startup failure or duplicate handlers.
- **FR-010**: The change MUST include a way to verify visible notifications, notification history, and LSP progress notification readiness manually or through repeatable checks.
- **FR-011**: The active specification relationship MUST be preserved for future planning and closure review before PR creation.

### Key Entities *(include if feature involves data)*

- **Notification**: A user-facing editor event with message content, severity, source, and relative timing.
- **Notification History**: A session-scoped collection of recent notifications that users can reopen and review.
- **Progress Event**: A notification-like event that represents work starting, updating, completing, failing, or stalling.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a normal editing session, 100% of manually triggered informational, warning, and error notifications appear outside the command line.
- **SC-002**: Users can open notification history and find a recent notification in under 10 seconds during manual validation.
- **SC-003**: At least 90% of tested notification messages remain readable without requiring command-line inspection.
- **SC-004**: A burst of 10 notifications does not block editing input and leaves the session usable.
- **SC-005**: LSP startup or progress validation produces user-visible status feedback for start and completion or failure in one supported project scenario.
- **SC-006**: Reapplying the dotfiles configuration does not create duplicate notification handlers or duplicate visible messages.

## Assumptions

- The primary user is the owner of these dotfiles using Neovim interactively.
- The first version focuses on session-scoped notification history, not persistent history across editor restarts.
- Visible notifications should appear outside the command line, avoid stealing focus, remain readable for at least 3 seconds by default, and preserve source/severity context when possible.
- A readable history entry includes message text, severity, source/title when available, and relative ordering.
- The visual experience should be comparable in usefulness to the referenced LazyVim notification screenshot, while preserving this dotfiles setup's existing style and constraints.
- LSP progress support is included as a readiness requirement for issue #22, but broader LSP configuration changes remain outside this feature unless needed for notification validation.
- Existing command-line messages may still exist for compatibility, but routine notification review should move to the visible notification and history experience.
