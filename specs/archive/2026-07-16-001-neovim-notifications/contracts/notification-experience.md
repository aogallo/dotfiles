# Contract: Notification Experience

## User-Facing Commands And Actions

### Trigger Visible Notification

**Actor**: User or Neovim subsystem.

**Input**: A notification message with optional severity and title.

**Expected Outcome**: The message appears in a visible editor notification surface and is captured in session history.

**Failure Behavior**: If the notification surface is unavailable, the message falls back to baseline editor notification behavior.

### Open Notification History

**Actor**: User.

**Input**: A configured command or keymap for notification history.

**Expected Outcome**: Recent session notifications open in a readable history view.

**Failure Behavior**: If no notifications exist, the user receives a clear empty-state response.

### Report LSP Progress

**Actor**: Neovim LSP subsystem.

**Input**: Progress begin, report, and end events from a language client.

**Expected Outcome**: The user sees concise progress feedback through the same notification surface used by ordinary notifications.

**Failure Behavior**: Malformed or missing progress data is ignored without interrupting editing.

## Acceptance Contract

- Normal notifications are visible outside the command line.
- Notification history is accessible without using `:messages`.
- LSP progress uses the same visual and historical notification path.
- Editing focus is preserved while notifications appear.
- Repeated configuration loads do not create duplicate visible notifications for a single event.
