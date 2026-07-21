# Data Model: Obsidian Title-Based Filenames

## Note Title

Represents the human-readable title entered by the user when creating a note.

**Fields**:
- `raw_title`: Text entered after the note creation command.
- `display_title`: Title preserved for Obsidian metadata and user-facing display.

**Validation rules**:
- Explicit titles should be non-empty after trimming whitespace.
- Spaces, punctuation, mixed case, and UTF-8 characters must not prevent note creation.
- A missing title must fall back to safe plugin behavior rather than crashing.

## Note Identity

Represents the identifier used by Obsidian.nvim to derive the note path and filename.

**Fields**:
- `id`: Title-derived slug or fallback ID.
- `source`: `title` when generated from a title, `fallback` when no title is available.
- `collision_suffix`: Optional suffix added when another note already uses the same slug.

**Validation rules**:
- IDs generated from titled notes must remain recognizable from the original title.
- Duplicate titles must create distinct IDs without overwriting existing notes.
- IDs must be safe for filesystem use in the configured notes directory.

## Note Filename

Represents the filesystem-visible Markdown filename created for a note.

**Fields**:
- `basename`: Note identity without the Markdown extension.
- `extension`: Markdown file extension.
- `path`: Location under the active Obsidian workspace.

**Validation rules**:
- Titled note filenames must not use opaque numeric prefixes unrelated to the title.
- Filename search for a title word should find the note quickly.
- The path must remain under the configured workspace.

## Note Alias

Represents Obsidian metadata that preserves human-readable names for search and linking.

**Fields**:
- `alias`: Human-readable title or alternate name.
- `metadata_location`: Note frontmatter when a template provides aliases.

**Validation rules**:
- Title-derived filenames must not remove useful alias metadata.
- Alias behavior should stay compatible with the plugin's default note template behavior.

## Notes Keymap Group

Represents the semantic leader-key namespace for note actions.

**Fields**:
- `prefix`: Top-level leader prefix for note actions.
- `label`: Discovery label shown by Which-Key.
- `actions`: Note-related mappings such as new note creation.

**Validation rules**:
- The group must not conflict with existing leader groups.
- Note creation must have a clear description in key discovery.
- Future Obsidian actions should be placed under the same group when practical.

## State Transitions

```text
Title entered -> Title-derived ID -> Markdown filename -> Note opened in Neovim
      │                 │                    │
      └─ no title ──────┴─ fallback ID ──────┘

Duplicate title -> Existing slug detected -> Suffix added -> Distinct note opened
```
