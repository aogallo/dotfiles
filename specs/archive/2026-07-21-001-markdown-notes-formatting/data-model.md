# Data Model: Markdown Notes Formatting

## Markdown Note

Represents a Markdown file used for personal notes or knowledge management.

**Fields**:
- `path`: File path under a notes folder.
- `filetype`: Markdown-compatible filetype.
- `context`: Notes-only when no project formatter signal is found.

**Validation rules**:
- Saving must not report missing project formatter errors.
- Formatting must not require package manifests or formatter config.

## Notes Folder

Represents an Obsidian-style vault or plain notes directory.

**Fields**:
- `contains_markdown`: Markdown note files.
- `contains_vault_settings`: Optional application-local settings such as a vault settings directory.
- `contains_formatter_config`: Optional, only when the user intentionally wants project-style formatting.

**Validation rules**:
- Must remain usable without formatter/project configuration.
- Must not depend on a user-specific absolute path.

## Project Markdown File

Represents Markdown inside a project with formatting expectations.

**Fields**:
- `path`: File path under a project root.
- `formatter_signal`: Local formatter configuration or project root indicator.
- `formatter`: Project Markdown formatter when available.

**Validation rules**:
- Existing configured Markdown formatting must still run.
- Missing formatter executables should report normal project formatter errors.

## Formatter Configuration

Represents portable local signals that formatting should run.

**Fields**:
- `config_files`: Formatter/project config files near the current file or ancestors.
- `available`: Whether the selected formatter can run for the buffer.

**Validation rules**:
- Detection must use local filesystem signals, not fixed private paths.
- Explicit project configuration takes priority over notes fallback.

## Formatting Decision

Represents the outcome for a Markdown save or manual format request.

**Fields**:
- `mode`: `project-format`, `notes-fallback`, or `skip`.
- `reason`: Why this mode was selected.
- `formatters`: Formatter list selected for the buffer.

**Validation rules**:
- `project-format` uses project formatting when available.
- `notes-fallback` avoids external toolchain errors.
- Global autoformat disable still returns no format action.

## State Transitions

```text
Markdown buffer saved
  ├─ autoformat disabled -> skip
  ├─ project formatter signal -> project-format
  └─ no formatter signal -> notes-fallback
```
