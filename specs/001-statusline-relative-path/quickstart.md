# Quickstart: Validate Statusline Relative File Path

Use this guide after implementation to prove the feature works end-to-end.

## Prerequisites

- Neovim available locally.
- Run commands from the repository root unless noted otherwise.
- Before implementation commits, switch to a feature branch instead of working directly on
  `main`.

## Static Validation

```bash
stylua --check nvim/lua/statusline.lua --config-path nvim/stylua.toml
```

Expected outcome: formatting check passes.

## Manual Smoke Tests

### Relative Path From Starting Directory

1. Open Neovim from the repository root.
2. Open `nvim/lua/statusline.lua`.
3. Confirm the statusline shows `nvim/lua/statusline.lua`, not the machine-specific absolute
   path.

Expected outcome: the absolute prefix is omitted for files inside the starting directory.

### Nested File Context

1. Open a nested file under `nvim/`.
2. Confirm the statusline preserves enough parent directory context to identify the file.

Expected outcome: files with common names remain distinguishable.

### Modified Indicator

1. Edit a normal file without saving.
2. Confirm the statusline shows a compact modified marker.
3. Save the file.
4. Confirm the marker disappears.

Expected outcome: unsaved changes are visible without running another command.

### Read-Only or Non-Editable Indicator

1. Open a buffer in a read-only or non-modifiable state.
2. Confirm the statusline shows a compact restriction marker.

Expected outcome: edit restrictions are visible before the user tries to modify the buffer.

### Unnamed and Special Buffers

1. Open a new unnamed buffer.
2. Open a special buffer such as quickfix, help, or a plugin/tool buffer.
3. Confirm each case shows a meaningful label and the statusline still renders cleanly.

Expected outcome: unnamed and special buffers do not produce empty or misleading file labels.

### Narrow Window

1. Reduce the editor window width.
2. Open a deeply nested file.
3. Confirm the active file name remains visible.
4. Confirm the current mode remains visible.

Expected outcome: the file name and current mode survive width pressure even if parent context is shortened.

## PR Readiness Check

Before creating a PR, verify that this active spec is related to the implementation PR and ask
whether `specs/001-statusline-relative-path` should be closed when the PR completes the
solution.
