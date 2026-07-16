# Research: Statusline Relative File Path

## Decision: Use the editor starting directory as the relative-path base

**Rationale**: The user explicitly wants the file name shown from the directory where `nvim`
was opened. This matches the mental model of opening an editor in a project and reading all
paths relative to that working context.

**Alternatives considered**:

- Git root: useful in many projects, but wrong when the user intentionally opens Neovim from
  a subdirectory.
- Current working directory after runtime changes: more dynamic, but confusing if plugins or
  user commands change the working directory after startup.
- Absolute path: current behavior; too noisy and machine-specific for this statusline.

## Decision: Keep the statusline focused on file orientation and editing state

**Rationale**: The current statusline is intentionally minimal. The added indicators should
prevent mistakes or improve orientation, not turn the statusline into a dashboard.

**Alternatives considered**:

- Add more Git diagnostics or LSP detail: useful elsewhere, but distracts from the user's
  stated goal of knowing the active file.
- Remove existing line/column/filetype information: too aggressive; the user said those are
  useful supporting details.

## Decision: Add compact modified and read-only/non-editable indicators

**Rationale**: These states directly affect editing confidence. They are small, visible, and
help avoid leaving changes unsaved or trying to edit a restricted buffer.

**Alternatives considered**:

- No state indicators: keeps the line smallest, but misses cheap high-value context.
- Verbose labels such as `[modified]` and `[readonly]`: clearer but consumes too much space.

## Decision: Treat unnamed and special buffers as display states, not normal file paths

**Rationale**: Special buffers often do not have meaningful file-system paths. A clear label
is more useful than an empty string or misleading path.

**Alternatives considered**:

- Always display raw buffer name: can expose plugin internals and produce noisy names.
- Hide file component for special buffers: too ambiguous; the user still needs orientation.

## Decision: Validate through formatting plus Neovim smoke scenarios

**Rationale**: The feature is UI configuration logic, not an install script or library. A
small set of editor scenarios proves the behavior better than heavy test scaffolding.

**Alternatives considered**:

- Full automated UI tests: too much complexity for a personal dotfiles statusline change.
- No validation beyond opening Neovim: too weak; edge cases are easy to miss.
