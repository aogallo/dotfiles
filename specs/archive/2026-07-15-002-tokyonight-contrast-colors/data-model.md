# Data Model: Tokyonight Contrast Colors

## Theme Configuration

**Description**: The repository-managed Tokyonight setup.

| Field | Value |
|-------|-------|
| Location | `nvim/plugin/editor.lua` |
| Base theme | Tokyonight `moon` |
| Owner | Shared Neovim dotfiles |

**Validation Rules**:

- Must preserve the active Tokyonight base theme.
- Must not introduce machine-specific paths or local-only settings.
- Must load without Neovim startup errors.

## Highlight Override

**Description**: A targeted color adjustment for a low-readability UI group.

| Attribute | Meaning |
|-----------|---------|
| Group | Highlight group or capture affected |
| Target | Comment text, hidden dotfile entry, current-file row, directory/path, or related picker state |
| Color intent | More legible while preserving visual hierarchy |
| Risk | Potential collision with git status, diagnostics, selection, or normal file names |

**Validation Rules**:

- Must improve the requested readability target.
- Must not make unrelated UI states harder to distinguish, especially selected rows, current-file rows, diagnostics, and git status.
- Must be documented if a tradeoff remains.

## Explorer Hidden Entry

**Description**: Dotfile file or directory shown after hidden files are toggled in the explorer.

| Field | Meaning |
|-------|---------|
| Trigger | Press `H` in the explorer/picker |
| Example | `.gitignore`, `.env.example`, `.config` |
| Success state | Entry can be found and read quickly |

**Validation Rules**:

- Dotfiles must be readable after hidden files are revealed.
- Selected hidden entries must remain distinguishable from unselected entries.

## Comment Text

**Description**: Syntax-highlighted comments in source files.

**Validation Rules**:

- Comments must be readable in representative Lua, shell, Markdown, and config files.
- Comments may remain visually secondary to code, but not washed out.

## Current File Row

**Description**: The explorer row that points to the file currently open or focused in Neovim.

**Validation Rules**:

- Must be visually identifiable within 2 seconds.
- Must not be confused with the selected row when selection and current file are different states.
- Must preserve filename readability.

## Terminal Rendering Context

**Description**: The Ghostty environment that can influence how Neovim colors are perceived.

| Field | Meaning |
|-------|---------|
| Terminal | Ghostty |
| Potential factors | Theme, palette, background, foreground, selection colors, opacity, font rendering |
| Repository status | No versioned Ghostty config currently found |

**Validation Rules**:

- Must document whether Ghostty changes are needed.
- Must not add terminal configuration unless evidence shows Neovim-only changes are insufficient.

## State Transitions

```text
Neovim starts
  -> vim-pack configures Tokyonight
  -> Tokyonight applies base palette and overrides
  -> Snacks explorer opens
  -> user presses H
  -> hidden dotfile entries and current-file rows render with improved readability
  -> Ghostty rendering is considered during manual validation
```
