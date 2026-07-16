# Data Model: Statusline Relative File Path

This feature has no persisted data. The model below describes transient display state used to
render the statusline for the active buffer.

## Entity: Editor Session

**Purpose**: Defines the path context used for relative display.

**Fields**:

- `starting_directory`: Directory where the editor session was opened.

**Validation Rules**:

- Must be available for the duration of the session.
- Must not be hard-coded to a user-specific absolute path in shared configuration.

## Entity: Active Buffer

**Purpose**: Represents the file or special buffer currently shown in the editor.

**Fields**:

- `absolute_path`: Full path for normal file buffers when one exists.
- `display_name`: Human-readable label shown in the statusline.
- `filetype`: Existing file type context displayed elsewhere in the statusline.
- `is_named`: Whether the buffer has a file path or meaningful name.
- `is_special`: Whether the buffer represents an editor/plugin/tool buffer instead of a
  normal file.
- `is_modified`: Whether the buffer has unsaved changes.
- `is_readonly_or_unmodifiable`: Whether editing is restricted.

**Validation Rules**:

- Normal files inside `starting_directory` display relative paths.
- Normal files outside `starting_directory` display a readable fallback.
- Unnamed buffers display a clear placeholder.
- Special buffers display meaningful labels and do not masquerade as normal files.

## Entity: Statusline File Segment

**Purpose**: The rendered statusline segment that identifies the active buffer.

**Fields**:

- `path_text`: Primary file or buffer label.
- `modified_indicator`: Compact marker shown only when unsaved changes exist.
- `readonly_indicator`: Compact marker shown only when editing is restricted.

**State Transitions**:

- `normal` -> `modified`: user edits the buffer without saving.
- `modified` -> `normal`: user saves or reverts changes.
- `editable` -> `restricted`: buffer becomes read-only or non-modifiable.
- `restricted` -> `editable`: edit restriction is removed.
