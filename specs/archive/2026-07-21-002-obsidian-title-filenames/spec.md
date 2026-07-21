# Feature Specification: Obsidian Title-Based Filenames

**Feature Branch**: Not created by this command

**Created**: 2026-07-20

**Status**: Draft

**Input**: User description: "Quiero crear una nota de obsidian pero el nombre qu ele doy quiero que ese sea el nombre del archivo, y el ID, porque obsidian crean un nombre de archivo con numeros y pues al momento de buscar por archivo a mi se me hace dificil. Cree una nota con :Obsidian new AWS CodePipeline y el nombre de archivo es este 1784601236-HVCC. AWS CodePipeline lo crea como aliases. Puedes investigar que comando funcion crear con la informacion del plugin. Puedes utilizar context7 para investigar. Quiero que me des una propuesta, architecto y experto en Neovim y Obsidian, quiero que tambien consideres y sigamos las practicas que ya definimos para las keymaps para ejecutar ese comando"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Notes With Recognizable Filenames (Priority: P1)

As the dotfiles owner, I want a new Obsidian note created from a title to use that title as the visible filename and note identity, so file-based search and navigation remain understandable outside Obsidian.

**Why this priority**: The current behavior creates opaque numbered filenames while placing the meaningful title only in aliases, which makes file lookup harder.

**Independent Test**: Can be tested by creating a note titled "AWS CodePipeline" and confirming that the resulting note is discoverable by a filename derived from that title rather than by an unrelated numeric identifier.

**Acceptance Scenarios**:

1. **Given** the user creates a new note with the title "AWS CodePipeline", **When** the note is saved, **Then** the filename and note identity are derived from "AWS CodePipeline" rather than from a random or timestamp-like value.
2. **Given** the user searches the notes directory by filename for "AWS" or "CodePipeline", **When** matching files are listed, **Then** the newly created note appears with a human-recognizable name.
3. **Given** the note has frontmatter or note metadata, **When** the note is opened, **Then** the meaningful title remains available as a title or alias for Obsidian workflows.

---

### User Story 2 - Use a Discoverable Neovim Note Command (Priority: P2)

As the dotfiles owner, I want a clear Neovim command path and keymap for creating Obsidian notes, so I can create notes without remembering plugin internals or accepting confusing filenames.

**Why this priority**: The user wants a command/function proposal and the existing keymap convention values semantic leader groups over isolated shortcuts.

**Independent Test**: Can be tested by opening key discovery, finding the note creation action under a semantic notes group, and using it to create a title-based note.

**Acceptance Scenarios**:

1. **Given** the user opens leader-key discovery, **When** note-related mappings are shown, **Then** the note creation action appears under a notes-oriented group with a clear description.
2. **Given** the user triggers the note creation action from Neovim, **When** a title is provided, **Then** the created note follows the same title-based naming behavior as the command flow.
3. **Given** future Obsidian mappings are added, **When** they are reviewed, **Then** they follow the same semantic grouping practice rather than scattering note actions across unrelated groups.

---

### User Story 3 - Preserve Safe Dotfiles Behavior (Priority: P3)

As a maintainer, I want the Obsidian note naming change to remain scoped, portable, and reversible, so the dotfiles stay safe across machines and vault locations.

**Why this priority**: The repository constitution requires portable shared configuration, clear dependencies, verification, and rollback for tool behavior changes.

**Independent Test**: Can be tested by reviewing the changed Neovim configuration and documentation to confirm that no machine-specific paths, secrets, or unrelated tool changes are introduced.

**Acceptance Scenarios**:

1. **Given** the notes directory is configured through the existing environment-based workflow, **When** the naming change is applied, **Then** the workspace remains portable across machines.
2. **Given** the user wants to undo the change, **When** the relevant Neovim configuration is reverted, **Then** unrelated dotfiles modules remain unaffected.
3. **Given** the configuration is validated, **When** the checks run, **Then** the Obsidian configuration loads without errors.

---

### Proposed User-Facing Direction

The proposed direction is to make the note title the default source of truth for new note identity. For a title such as "AWS CodePipeline", the created note should have a readable filename derived from that title, while still keeping Obsidian-friendly metadata such as aliases when useful.

The proposed keymap direction is to introduce a semantic notes group for Obsidian actions, with note creation as the first action in that group. This follows the previously approved LazyVim-style rule: the first key after `<leader>` identifies the domain, and the next key identifies the action. Note workflows are a distinct domain from generic file search because they include note creation, backlinks, tags, templates, and Obsidian navigation.

### Edge Cases

- A user creates a note with spaces, punctuation, or mixed capitalization in the title.
- A user creates a note with the same title as an existing note.
- A user creates a note without providing a title.
- A user creates a note title containing characters that are invalid or awkward in filenames.
- A user relies on aliases to find notes from inside Obsidian.
- The notes directory is customized through the existing environment variable.
- The Obsidian plugin is not loaded because the filetype or plugin conditions have not been met yet.
- The change is applied repeatedly and must not duplicate keymap registration or discovery group entries.
- The implementation must remain reversible without touching non-Neovim dotfiles modules.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: New notes created from an explicit title MUST use a filename and note identity derived from the provided title instead of an opaque random or timestamp-like value.
- **FR-002**: The title-derived filename MUST be readable in normal file search and directory listings.
- **FR-003**: The naming behavior MUST handle spaces and common punctuation safely while preserving enough title meaning for recognition.
- **FR-004**: If a title would collide with an existing note, the system MUST avoid overwriting the existing note and MUST produce a distinct, recognizable result.
- **FR-005**: If the user creates a note without a title, the system MUST continue to provide a safe fallback name rather than failing unexpectedly.
- **FR-006**: The created note MUST preserve useful Obsidian metadata so the human title remains available for Obsidian search, linking, and alias-based workflows.
- **FR-007**: The proposal MUST identify the researched command path for creating notes and define a user-facing note creation action that uses the title-based naming behavior.
- **FR-008**: The keymap proposal MUST place note creation under a semantic notes-oriented leader group and avoid isolated leader mappings.
- **FR-009**: The keymap proposal MUST include accurate discovery metadata so the action is understandable in key discovery.
- **FR-010**: The change MUST remain scoped to the Neovim Obsidian/Markdown configuration and MUST NOT require unrelated dotfiles modules to change.
- **FR-011**: The change MUST preserve the existing portable notes-directory behavior and MUST NOT introduce user-specific absolute paths, private vault names, credentials, or secrets.
- **FR-012**: The change MUST be safe to apply repeatedly without accumulating duplicate keymaps, duplicate groups, or conflicting note creation behaviors.
- **FR-013**: The change MUST include a validation path that proves the Neovim configuration loads and a manual smoke test that creates a sample title-based note.
- **FR-014**: The change MUST include a rollback path where reverting the Neovim Obsidian configuration restores the previous note naming behavior without affecting existing note files.
- **FR-015**: Implementation work MUST happen on a feature branch and be prepared for pull-request review before merge.

### Key Entities

- **Note Title**: The human-readable title provided by the user when creating a note.
- **Note Identity**: The stored identifier used by the note system and reflected in the filename for new titled notes.
- **Note Filename**: The filesystem-visible name used for finding and opening the note outside Obsidian.
- **Note Alias**: Obsidian metadata that preserves alternate human-readable names for search and linking.
- **Note Creation Action**: The user-facing Neovim action that creates a new note from a title.
- **Notes Keymap Group**: The semantic leader namespace used for note-related actions in key discovery.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Creating a note titled "AWS CodePipeline" results in a filename that contains recognizable words from the title and no opaque numeric prefix.
- **SC-002**: A user can find a newly created titled note by filename search in under 10 seconds using a word from the note title.
- **SC-003**: 100% of new note creation mappings appear under the approved notes-oriented keymap group with clear descriptions.
- **SC-004**: Zero existing files are overwritten when creating a note with a duplicate title.
- **SC-005**: The Neovim configuration passes a load or syntax validation check after the change.
- **SC-006**: The manual smoke test creates, opens, and identifies at least one title-based note successfully.
- **SC-007**: Documentation or change notes identify the rollback path and the expected filename behavior before implementation is considered complete.

## Assumptions

- The target user is the repository owner and primary Neovim/Obsidian user.
- The active Obsidian plugin is the maintained `obsidian-nvim/obsidian.nvim` fork already configured in the Neovim Markdown plugin module.
- The existing `:Obsidian new [TITLE]` workflow remains the baseline command behavior to preserve, but its naming outcome should become title-based.
- A filename derived from the title may normalize spaces or punctuation as long as the result remains recognizable.
- Duplicate titles should produce a distinct readable filename rather than replacing an existing note.
- A semantic notes group is acceptable as an extension of the existing keymap grouping convention because Obsidian note workflows are a distinct domain.
- The implementation phase will research exact plugin options and helper functions again before editing configuration.
