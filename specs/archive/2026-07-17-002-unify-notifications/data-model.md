# Data Model: Unify Neovim Notifications

## Notification

Represents a user-facing event emitted through the unified notification flow.

**Fields**:
- `id`: Optional stable identifier used to replace/update an existing notification, such as an LSP progress notification.
- `message`: Human-readable message body.
- `severity`: One of `info`, `warn`, `error`, `debug`, `trace`, or `progress`.
- `source`: Optional origin label such as `LSP`, a client name, a command name, or a plugin/module name.
- `title`: Optional short title displayed in popup/history surfaces.
- `timestamp`: Session-relative time used for ordering and history display.
- `details`: Optional expanded text for long traces or multi-line messages.
- `visible`: Whether the event should produce a transient popup.

**Validation rules**:
- `message` must be non-empty after trimming whitespace.
- `severity` must map to the same icon/label set in popup and history views.
- Long `details` must remain reviewable without replacing the concise popup summary.
- Reusing the same `id` must update/replace rather than duplicate the visible event.

## Editor Message

Represents a message produced by Neovim or plugins that may otherwise appear only in the command/message area.

**Fields**:
- `message`: Raw or normalized message text.
- `severity`: Best-effort severity, defaulting to `info` when no stronger signal exists.
- `source`: Optional command/plugin/editor context.
- `timestamp`: Session-relative time used for ordering.
- `details`: Optional full message text when a concise summary is shown elsewhere.
- `captured`: Whether the message was added to unified history.

**Validation rules**:
- Messages should be captured in history even when they do not require transient popup display.
- Errors and warnings should be eligible for transient popup display.
- Capturing messages must not suppress baseline `:messages` fallback.

## Message History

Represents the current-session review surface for notifications and editor messages.

**Fields**:
- `entries`: Ordered list of `Notification` and `Editor Message` records.
- `filter`: Optional search/filter text entered by the user.
- `selection`: Current selected entry.
- `preview`: Detail view for the selected entry.

**Validation rules**:
- Entries must be searchable or filterable by message text, source, and severity.
- The selected entry must show enough detail to inspect long messages/traces.
- Opening history must not steal or corrupt the user's editing buffers after closing.

## Command Failure

Represents an error produced by a command or key-triggered action.

**Fields**:
- `action`: User-facing action or command context when available.
- `summary`: Concise failure explanation.
- `details`: Full error or stack trace when available.
- `severity`: Always `error` unless explicitly downgraded by the source.
- `timestamp`: Session-relative time.

**Validation rules**:
- The visible popup must summarize the failed action and high-level reason.
- Full details must be reviewable in history or the fallback message path.
- Failures during redraw/window changes must leave the editor usable.

## LSP Progress Event

Represents language server work starting, updating, completing, or failing.

**Fields**:
- `client`: LSP client/server name such as `tsgo` or `lua_ls`.
- `token`: Progress token for update replacement.
- `kind`: `begin`, `report`, or `end`.
- `title`: Progress title.
- `message`: Optional progress detail.
- `percentage`: Optional numeric progress.
- `state`: `running`, `success`, or `failed`.

**Validation rules**:
- Events with the same client/token should update one visible notification rather than produce unbounded duplicates.
- Completion should resolve the visible progress state cleanly.
- Failures should remain visible and reviewable.

## Diagnostic UI

Related but out of scope for this feature.

**Fields**:
- Not modeled for implementation in this feature.

**Validation rules**:
- Notification/message changes must not intentionally alter inline diagnostics, current-line diagnostics, signs, or diagnostic navigation.
