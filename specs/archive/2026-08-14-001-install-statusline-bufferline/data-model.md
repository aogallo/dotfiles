# Data Model: Statusline and Bufferline Upgrade

This feature does not introduce persisted application data. The model below describes runtime UI concepts that must remain coherent during implementation and validation.

## Entity: Status Context

**Purpose**: Represents the active editing context shown in the statusline.

**Fields**:

- `mode`: Current editor mode shown in a recognizable label.
- `branch`: Current version-control branch when available.
- `file_label`: Active file path or special-buffer label.
- `diagnostics`: Current diagnostic counts or status when available.
- `filetype`: Current buffer filetype or fallback label.
- `encoding`: File encoding when available.
- `position`: Current line, total lines, and column.

**Validation Rules**:

- Must remain useful when branch, diagnostics, or filetype are unavailable.
- Must not duplicate legacy custom statusline rendering.
- Must not show startup errors when optional context is missing.

## Entity: Buffer Item

**Purpose**: Represents one open buffer shown in the bufferline.

**Fields**:

- `buffer_id`: Neovim buffer identifier.
- `label`: Display name for the buffer.
- `active`: Whether this buffer is focused.
- `modified`: Whether the buffer has unsaved changes.
- `diagnostics`: Buffer-specific diagnostic indicator when available.
- `icon`: Filetype icon when available.

**Validation Rules**:

- Exactly one normal buffer should appear active in common editing workflows.
- Modified buffers should be visually distinguishable.
- Unnamed and special buffers should not break rendering.

## Entity: Buffer Command

**Purpose**: Represents user actions for navigating or closing buffers.

**Fields**:

- `mapping`: Key sequence used by the user.
- `domain`: Workflow group, expected to be `buffers` for buffer operations.
- `action`: Next, previous, list, close, or close-others.

**Validation Rules**:

- New buffer mappings must stay under `<leader>b` unless they are native non-leader navigation.
- Existing mappings must not be overwritten accidentally.
- New mappings must have descriptions for discoverability.

## State Transitions

```text
buffer opened -> buffer item visible -> buffer focused -> buffer item active
buffer active -> buffer closed -> remaining buffer focused or bufferline hidden
single buffer -> bufferline hidden or minimal -> multiple buffers -> bufferline visible
```
