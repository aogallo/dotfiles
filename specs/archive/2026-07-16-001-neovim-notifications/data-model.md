# Data Model: Neovim Notifications

## Notification

**Purpose**: Represents one user-facing editor message.

**Fields**:

- `message`: Human-readable notification text.
- `level`: Severity such as trace, debug, info, warning, or error.
- `title`: Optional source label, such as a plugin name or LSP client name.
- `id`: Optional stable identity used to update or replace an existing notification.
- `timestamp`: Session-relative creation time.
- `display_state`: Whether the notification is visible, expired, dismissed, or retained in history.

**Validation Rules**:

- `message` must be present and readable.
- `level` must map to a supported severity.
- Reusing the same `id` should update related progress-style notifications rather than creating avoidable duplicates.

## Notification History

**Purpose**: Represents session-scoped review of recent notifications.

**Fields**:

- `items`: Ordered list of notifications captured during the current editor session.
- `order`: Most useful review order for recent events, preserving enough timing context to understand what happened.
- `empty_state`: User-facing feedback when no notifications exist.

**Validation Rules**:

- History must be available without requiring `:messages`.
- History must include notifications that have expired from the visible surface.
- History must remain session-scoped for this feature.

## Progress Event

**Purpose**: Represents language tooling progress that should appear through the same notification experience.

**Fields**:

- `client`: Language tooling source name.
- `token`: Progress token used to group related updates.
- `kind`: Begin, report, or end.
- `percentage`: Optional completion percentage.
- `title`: Optional progress title.
- `message`: Optional progress details.
- `done`: Whether the progress item has completed.

**Validation Rules**:

- Progress events from the same ongoing operation should update a stable notification where possible.
- Completed progress should resolve cleanly and remain reviewable in history.
- Invalid or missing client/progress data should be ignored safely.

## State Transitions

- Notification: created -> visible -> expired -> history.
- Notification: created -> visible -> dismissed -> history.
- Progress Event: begin -> report -> end.
- Progress Event: begin -> error/stall feedback -> history.
