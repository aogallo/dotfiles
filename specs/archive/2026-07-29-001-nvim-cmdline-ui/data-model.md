# Data Model: Neovim Command-Line UI

## Command-Line Interaction

Represents one user command-entry session.

**Fields**:

- `mode`: command, search, filter, Lua, help, or input prompt.
- `prompt`: visible command/input prompt label.
- `input_text`: current text entered by the user.
- `visible`: whether the floating command input is currently shown.
- `width`: intended command input width in editor columns.
- `position`: editor-relative placement of the floating input.
- `statusline_mode`: current statusline mode label during command entry.

**Validation rules**:

- Command entry must be keyboard usable for submit, cancel, history, and option navigation.
- Floating input must close after submit or cancel.
- Bottom command-line area must not be the normal visible command-entry surface.

## Command Option List

Represents command completion/options shown while command entry is active.

**Fields**:

- `items`: visible command options.
- `selected_index`: currently highlighted option.
- `width`: visual menu width.
- `anchor`: relationship to the floating command input.
- `height`: maximum visible item count before scrolling.

**Validation rules**:

- Width must align with the command input and use at least 90% of intended input width in tested scenarios.
- Short option labels must not shrink the menu to label-only width.
- Menu must remain readable at 80, 120, and 160 terminal columns.

## Notification Event

Represents a visible message outside the bottom command-line area.

**Fields**:

- `severity`: trace, debug, info, progress, warning, or error.
- `title`: short source or category label.
- `summary`: first-line user-visible message.
- `details`: optional expanded text.
- `source`: origin such as LSP, formatter, package manager, command, or editor.
- `visible`: whether the notification should be shown immediately.
- `timestamp`: capture/display time.

**Validation rules**:

- Warnings and errors must be prominent.
- Informational notifications must not block normal editing unnecessarily.
- Notifications must not duplicate across active providers.

## Notification History

Represents discoverable recent notifications and messages.

**Fields**:

- `entries`: ordered notification events.
- `limit`: maximum retained entries.
- `open_action`: user action or command that displays history.

**Validation rules**:

- At least the most recent 20 notification/message events must be inspectable.
- History must include enough detail to debug warnings/errors.
- History must remain available if the visible notification provider changes.

## LSP Progress Event

Represents language-server progress reported during startup, indexing, or work execution.

**Fields**:

- `client`: language server name.
- `title`: progress title.
- `message`: current progress detail.
- `percentage`: optional completion percentage.
- `state`: started, running, done, or failed.
- `visible_until`: when completed progress should clear.

**Validation rules**:

- Progress must appear within 1 second of tested startup/progress events.
- Completed progress must clear within 5 seconds unless the message is an error.
- No stale progress UI may remain visible while idle.

## UI Provider Decision

Represents the approved ownership model for command-line, messages, notifications, and LSP progress.

**Fields**:

- `command_line_provider`: selected owner for command entry.
- `popupmenu_provider`: selected owner for command options.
- `notification_provider`: selected owner for visible notifications.
- `history_provider`: selected owner for notification history.
- `lsp_progress_provider`: selected owner for LSP progress.
- `disabled_behaviors`: superseded tools or behaviors to disable.
- `approval_status`: pending, approved, or rejected.

**Validation rules**:

- Approval status must be approved before implementation begins.
- Only one provider should own each visible notification/progress surface unless the plan documents conflict prevention.
- Superseded behavior must be removed or disabled in the same implementation work unit.
