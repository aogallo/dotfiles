# Research: Obsidian Title-Based Filenames

## Decision: Use Obsidian.nvim's built-in title ID generator

**Rationale**: Current `obsidian-nvim/obsidian.nvim` documentation identifies `require("obsidian.builtin").title_id` as the built-in title ID generator. The installed plugin version honors this generator through `note_id_func`, handles UTF-8 characters, and appends numeric suffixes for duplicate slugs. This directly solves opaque filenames like `1784601236-HVCC` without custom slug code.

**Alternatives considered**: Write a local slug function; rejected because it duplicates maintained plugin behavior and would need custom duplicate/UTF-8 handling. Use template customizations per template; rejected for the default note creation flow because the desired behavior should apply to normal `:Obsidian new [TITLE]` notes, not only template-specific notes.

## Decision: Keep `:Obsidian new [TITLE]` as the canonical command flow

**Rationale**: The maintained fork documents `:Obsidian new [TITLE]` as the current note creation command, and the repo already sets `legacy_commands = false`. Preserving this command avoids training the user on legacy command names while changing the filename outcome underneath.

**Alternatives considered**: Re-enable legacy commands such as old-style `:ObsidianNew`; rejected because it conflicts with the current config and creates two command surfaces. Create a custom user command immediately; rejected because the built-in command already covers the core flow and a keymap can call it.

## Decision: Add a notes leader group instead of placing Obsidian under files or UI

**Rationale**: The existing keymap convention groups actions by user intent: files, search, git, code, buffers, UI, packages, and windows. Obsidian is a note-taking domain with creation, search, backlinks, tags, templates, and linking, so a dedicated notes group keeps future mappings coherent.

**Alternatives considered**: Put note creation under `<leader>f`; rejected because note creation is not generic file picking. Put it under `<leader>u`; rejected because it is not a display toggle. Use an orphan mapping; rejected because prior keymap work explicitly avoids single-action leader islands.

## Decision: Prefer a command-line mapping for titled note creation

**Rationale**: A mapping that opens the command line with `:Obsidian new ` lets the user type the title naturally and keeps behavior identical to the documented command. It avoids a custom prompt wrapper until there is a proven UX need.

**Alternatives considered**: Use `vim.ui.input` wrapper; rejected for first implementation because it adds custom code and error handling without a requirement beyond entering a title. Use only the command and no mapping; rejected because the feature explicitly asks to follow existing keymap practices.

## Decision: Preserve the existing notes directory configuration

**Rationale**: `nvim/plugin/markdown.lua` already reads `OBSIDIAN_NOTES_DIR` and falls back to `~/dev/notes`, matching the repository's portability model documented in `nvim/README.md`. The filename change does not require changing workspace discovery.

**Alternatives considered**: Hard-code a vault path; rejected by the portability and secret hygiene gates. Add a new environment variable; rejected because the existing one already covers the workspace path.
