# Implementation Plan: Obsidian Title-Based Filenames

**Branch**: `002-obsidian-title-filenames` | **Date**: 2026-07-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-obsidian-title-filenames/spec.md`

## Summary

Make Obsidian.nvim note creation use the provided title as the note ID and visible filename instead of opaque zettel-style IDs, while adding a discoverable notes keymap group that follows the repository's semantic leader-key convention. The implementation will update the existing Obsidian configuration in `nvim/plugin/markdown.lua`, rely on Obsidian.nvim's built-in title ID generator through the installed version's `note_id_func` option, and register note mappings through the existing Which-Key grouping pattern.

## Technical Context

**Language/Version**: Lua for Neovim configuration; shell for existing validation commands.

**Primary Dependencies**: `obsidian-nvim/obsidian.nvim`, `folke/which-key.nvim`, existing `vim-pack` plugin registration helper, Neovim built-in Lua APIs.

**Storage**: Markdown files in the configured Obsidian notes directory. The shared config uses `OBSIDIAN_NOTES_DIR` when set and defaults to `~/dev/notes`.

**Testing**: `stylua --check nvim`, `nvim --headless -u nvim/init.lua '+quitall'`, `setup/validate-nvim-deps.sh`, and attached-UI manual smoke tests from [quickstart.md](./quickstart.md).

**Target Platform**: Neovim on supported macOS dotfiles machines, portable across Apple Silicon and Intel where the existing Neovim setup is supported.

**Project Type**: Dotfiles-managed Neovim configuration.

**Performance Goals**: A titled note can be created and found by filename in under 10 seconds during manual validation; key discovery shows the note creation action immediately under the notes group.

**Constraints**: No custom note ID implementation unless the built-in title generator fails a concrete requirement; no user-specific committed vault paths; no unrelated dotfiles module changes; no legacy Obsidian commands because `legacy_commands = false` is already configured.

**Scale/Scope**: Single-user interactive editor workflow for creating and finding Obsidian notes in one configured workspace.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. The plan preserves `OBSIDIAN_NOTES_DIR` and the existing `~/dev/notes` fallback without introducing new user-specific paths.
- **Idempotency**: Pass. Configuration changes are declarative plugin options and fixed keymap/group registrations; repeated loads must not add duplicate behavior.
- **Non-destructive safety**: Pass. The plugin's title ID generator appends suffixes for duplicate slugs instead of overwriting existing notes.
- **Modularity**: Pass. Scope is limited to Neovim Markdown/Obsidian configuration and Which-Key grouping.
- **Source of truth**: Pass. Shared behavior lives in repository-managed Neovim config; note files remain user-owned vault content outside the repo.
- **Dependencies**: Pass. Uses existing dependencies already configured in the repo; no new plugin or package is planned.
- **Security**: Pass. No credentials, private vault names, or machine secrets are introduced.
- **Verification**: Pass. Plan includes formatting, startup/dependency checks, and manual title/duplicate/no-title smoke tests.
- **Installer UX**: Pass. No installer behavior changes are required; validation docs describe expected outcomes.
- **Recovery**: Pass. Rollback is reverting `nvim/plugin/markdown.lua` and any related docs; existing note files are not modified by rollback.
- **Maintainability**: Pass. Prefer Obsidian.nvim's built-in title ID generator over custom slug logic.
- **Documentation**: Pass. Quickstart documents validation and rollback; README update is deferred to implementation if user-facing mappings change.
- **Branch/PR discipline**: Pass. Work is planned for `002-obsidian-title-filenames`; PR creation must verify active spec relationship and ask whether the completed spec should close.

## Project Structure

### Documentation (this feature)

```text
specs/002-obsidian-title-filenames/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── obsidian-note-creation.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── plugin/
│   ├── markdown.lua        # Obsidian.nvim setup, note ID behavior, note keymaps
│   └── editor.lua          # Which-Key top-level group labels
├── README.md               # User-facing mapping/Obsidian behavior docs if implementation changes them
└── stylua.toml             # Lua formatting configuration

setup/
└── validate-nvim-deps.sh   # Existing dependency validation
```

**Structure Decision**: Keep the implementation in `nvim/plugin/markdown.lua` for Obsidian-specific behavior. Add only the top-level notes group to `nvim/plugin/editor.lua` if Which-Key group registration cannot live cleanly beside the Obsidian mappings. Avoid a new module until there are multiple reusable note helpers.

## Phase 0: Research Summary

See [research.md](./research.md). All technical unknowns are resolved with no open clarification markers.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [contracts/obsidian-note-creation.md](./contracts/obsidian-note-creation.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Portability**: Pass. Design keeps environment-based notes directory behavior and uses repository-relative documentation.
- **Idempotency**: Pass. Declarative plugin options and fixed mappings remain safe across repeated config loads.
- **Non-destructive safety**: Pass. Duplicate note titles resolve to distinct slugged filenames, not overwrites.
- **Modularity**: Pass. No tmux, shell, Git, or installer modules are touched.
- **Source of truth**: Pass. Only shared Neovim configuration is changed; generated note files stay in the user's configured vault.
- **Dependencies**: Pass. No new dependencies after design.
- **Security**: Pass. No secrets or private paths are stored.
- **Verification**: Pass. Quickstart covers automated and attached-UI smoke tests.
- **Installer UX**: Pass. No installer changes; user-facing outcomes are documented in validation.
- **Recovery**: Pass. Rollback is a config revert; created test notes can be deleted manually from the vault if desired.
- **Maintainability**: Pass. Built-in plugin behavior is preferred over custom slug code.
- **Documentation**: Pass. Quickstart is present; README update remains an implementation task if mappings are added.
- **Branch/PR discipline**: Pass. Active spec linkage must be checked before PR creation.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.
