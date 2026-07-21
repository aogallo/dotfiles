# Contract: Markdown Formatting Behavior

## Notes-Only Folder Contract

When a Markdown buffer belongs to a folder with no project formatter configuration:

- Save must complete without a missing Prettier error.
- The editor may apply safe whitespace cleanup.
- The editor must not create project tooling files in the notes folder.
- The behavior must not depend on a hard-coded notes path.

## Configured Project Contract

When a Markdown buffer belongs to a project with explicit formatter configuration:

- Project Markdown formatting remains enabled.
- The configured formatter is attempted before fallback behavior.
- Existing global autoformat disable behavior remains respected.
- Formatter errors remain visible when the project explicitly opts into that formatter and it cannot run.

## User Documentation Contract

The Neovim documentation must explain:

- Notes folders can remain lightweight Markdown/Obsidian vaults.
- Formatter/project files are optional for notes folders.
- Adding formatter config to a notes folder opts that folder into project-style Markdown formatting.
- Rollback is reverting the formatting configuration and documentation changes.

## Non-Goals

- Do not require Prettier installation inside every notes folder.
- Do not disable Markdown formatting globally.
- Do not change unrelated filetype formatter behavior.
- Do not add new dependencies for note formatting.
