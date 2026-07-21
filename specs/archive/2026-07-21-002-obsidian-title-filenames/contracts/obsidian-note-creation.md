# Contract: Obsidian Note Creation

## User Command Contract

### `:Obsidian new [TITLE]`

Creates and opens a new note in the active Obsidian workspace.

**Inputs**:
- `TITLE`: Optional human-readable note title typed by the user.

**Expected outcomes**:
- When `TITLE` is provided, the resulting note ID and filename are derived from that title.
- When `TITLE` is omitted, the plugin uses a safe fallback ID.
- Duplicate titles do not overwrite existing note files; the generated ID remains distinct and readable.
- The title remains available to Obsidian metadata and linking workflows where the template provides it.

**Failure behavior**:
- If the workspace path is unavailable, the user sees the plugin's normal error path and no repository-owned fallback writes outside the workspace.
- Invalid or awkward filename characters are normalized by the plugin's title ID behavior.

## Keymap Contract

### Notes Group

All repository-owned Obsidian note mappings should live under a semantic notes group.

**Expected group**:
- Prefix: `<leader>n`
- Label: `notes`

### New Note Action

**Expected mapping**:
- Prefix: `<leader>nn`
- Description: `New note`
- Behavior: opens the documented Obsidian note creation command with space for the user to type a title.

**Acceptance contract**:
- Opening key discovery shows `<leader>n` as `notes`.
- The new note mapping is discoverable under the notes group.
- Creating `AWS CodePipeline` through the mapping produces the same title-derived filename behavior as typing the command manually.

## Non-Goals

- Do not re-enable legacy Obsidian command names.
- Do not create a custom note picker or prompt wrapper unless a later task proves the documented command-line flow is insufficient.
- Do not change the configured workspace path model.
