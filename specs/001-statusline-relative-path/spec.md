# Feature Specification: Statusline Relative File Path

**Feature Branch**: Not created by hook  
**Created**: 2026-07-15  
**Status**: Draft  
**Input**: User description: "Quiero que revises @nvim/lua/statusline.lua es minima y la uso mas para saber en que archivo estoy. lo demas para mi es linea o columna etc. lo que si quiero cambiar es de que el nombre del archivo no muestra absolute path si no que desde el directorio donde se abrio nvim."

## User Scenarios & Testing

### Primary User Story

As a user working inside the editor, I want the statusline to show the current file path relative to the directory where the editor session was opened, so I can quickly understand which file I am editing without seeing an unnecessarily long absolute path.

### Acceptance Scenarios

1. **Given** the editor was opened from a project directory, **When** a file inside that directory is active, **Then** the statusline shows the file path relative to that starting directory.
2. **Given** the editor was opened from a project directory, **When** a nested file is active, **Then** the statusline includes enough parent directories to identify the file location within that project.
3. **Given** the active file has unsaved changes, **When** the statusline is rendered, **Then** the statusline gives a small visual indication that the buffer is modified.
4. **Given** the active buffer is read-only or not modifiable, **When** the statusline is rendered, **Then** the statusline gives a small visual indication that edits are restricted.
5. **Given** the active buffer has no associated file name, **When** the statusline is rendered, **Then** the statusline still displays a clear unnamed-buffer label instead of an empty or confusing path.
6. **Given** a file outside the starting directory is active, **When** the statusline is rendered, **Then** the displayed path remains understandable and does not break the rest of the statusline.

### Edge Cases

- The active buffer has no file path.
- The active buffer is a special editor buffer rather than a normal file.
- The active file is outside the directory where the editor session was opened.
- The active file path is deeply nested and could consume most of the statusline width.
- The active file has unsaved changes.
- The active buffer is read-only or not modifiable.

## Requirements

### Functional Requirements

- **FR-001**: The statusline MUST display the active file path relative to the directory where the editor session was opened when the active file is inside that directory.
- **FR-002**: The statusline MUST avoid displaying the full absolute path for files inside the starting directory.
- **FR-003**: The displayed file path MUST include enough directory context to distinguish nested files with the same name.
- **FR-004**: The displayed file path MUST favor readability when space is limited by preserving the file name and the most useful parent directory context without hiding the current mode segment.
- **FR-005**: The statusline MUST keep its current minimal purpose: helping the user identify the active file while preserving existing supporting context such as mode, file type, encoding, and cursor position.
- **FR-006**: The statusline MUST display a readable placeholder for unnamed buffers.
- **FR-007**: The statusline MUST display a meaningful label for special buffers instead of treating them as normal files.
- **FR-008**: The statusline MUST remain readable when the active file is outside the starting directory or belongs to a special buffer.
- **FR-009**: The statusline SHOULD show a compact modified indicator when the active file has unsaved changes.
- **FR-010**: The statusline SHOULD show a compact read-only or non-editable indicator when edits are restricted.
- **FR-011**: The statusline SHOULD avoid adding persistent decorative elements that do not help identify the active file or editing state.

## Success Criteria

- **SC-001**: For files inside the starting directory, 100% of displayed file paths omit the machine-specific absolute prefix.
- **SC-002**: In normal project usage, the user can identify the active file location from the statusline in under 2 seconds.
- **SC-003**: The statusline continues to render for unnamed, special, and outside-directory buffers without visible errors or empty file labels.
- **SC-004**: The change does not remove existing statusline information the user currently relies on.
- **SC-005**: When a normal file has unsaved changes, the user can tell from the statusline without opening another editor view or command.
- **SC-006**: On narrow editor widths, the active file name and current mode remain visible in the statusline.

## Assumptions

- "Directory where the editor was opened" means the working directory at the start of the editor session.
- The existing statusline should remain minimal and mostly unchanged except for how the active file path is displayed.
- The desired path should be project-relative when the editor is opened from the project root.
- Small state indicators are acceptable only when they help prevent editing mistakes, such as forgetting unsaved changes or editing a restricted buffer.

## Proposed Improvements

These improvements are intentionally small so the statusline stays focused on orientation instead of becoming a dashboard.

| Improvement | User Value | Priority |
|-------------|------------|----------|
| Relative file path from the starting directory | Removes noisy absolute prefixes while preserving location context | Must have |
| Modified indicator | Makes unsaved changes visible at a glance | Should have |
| Read-only or non-editable indicator | Prevents confusion when edits are restricted | Should have |
| Special-buffer labels | Makes tool, help, quickfix, and plugin buffers easier to identify | Should have |
| Width-aware path display | Keeps the file name visible when the editor window is narrow | Could have |
