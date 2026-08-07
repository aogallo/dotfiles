# Feature Specification: Neovim Treesitter Textobjects

**Feature Branch**: `002-nvim-treesitter-textobjects`

**Created**: 2026-07-28

**Status**: Draft

**Input**: User description: "Add issue #48 to the Neovim work. The user saw Treesitter configuration examples for incremental selection and textobjects, including function/class/comment objects and parameter swapping. They do not want to copy Lazy.nvim-oriented configuration directly; the implementation must fit this dotfiles distribution and current `vim-pack` setup. The user wants to analyze whether Treesitter textobjects are actually useful compared with existing native textobjects such as `ca(` and `va(` for Go const blocks, then add the feature only if it improves structural editing."

**Related Issue**: [#48](https://github.com/aogallo/dotfiles/issues/48)

## Clarifications

### Session 2026-07-28

- Q: Should this work be merged into the command-line UI spec? -> A: No; keep it as a separate spec coordinated through the same integration branch and final PR to `main`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select Semantic Code Regions (Priority: P1)

As a Neovim user, I want semantic textobjects for functions, classes/types, comments, parameters, and scopes so I can select meaningful code structures without relying only on punctuation-based textobjects.

**Why this priority**: This is the primary value of Treesitter textobjects and directly addresses issue #48.

**Independent Test**: Can be tested by opening supported source files and selecting inner/outer semantic regions with documented mappings.

**Acceptance Scenarios**:

1. **Given** a supported source file with a function, **When** the user invokes the outer function textobject, **Then** the whole function region is selected.
2. **Given** a supported source file with a function body, **When** the user invokes the inner function textobject, **Then** only the useful inner function region is selected.
3. **Given** a supported source file with comments, **When** the user invokes the comment textobject, **Then** the expected comment region is selected where parser queries support it.

---

### User Story 2 - Expand Selection Structurally (Priority: P1)

As a Neovim user, I want incremental selection to expand and shrink by syntax tree nodes so I can progressively select expressions, statements, blocks, and larger structures without guessing textobject boundaries.

**Why this priority**: Incremental selection is a distinct structural-editing workflow and was part of the requested issue.

**Independent Test**: Can be tested by placing the cursor inside nested code and expanding/shrinking selection through multiple syntax nodes.

**Acceptance Scenarios**:

1. **Given** the cursor is inside an expression, **When** the user starts incremental selection, **Then** the nearest meaningful syntax node is selected.
2. **Given** incremental selection is active, **When** the user expands selection, **Then** the selected region grows to the next parent node.
3. **Given** selection was expanded, **When** the user shrinks selection, **Then** the selection returns to the previous smaller node.

---

### User Story 3 - Preserve Native Punctuation Textobjects (Priority: P2)

As a Neovim user, I want native textobjects such as `ca(` and `va(` to keep working so Treesitter behavior adds semantic editing without breaking familiar punctuation-based edits.

**Why this priority**: The user specifically compared Treesitter textobjects with existing native parenthesis textobjects in a Go const block and wants analysis instead of blind replacement.

**Independent Test**: Can be tested by editing a Go const block and confirming existing punctuation textobjects still behave normally after the new feature is enabled.

**Acceptance Scenarios**:

1. **Given** a Go const block wrapped in parentheses, **When** the user runs a native parenthesis textobject action, **Then** the existing punctuation-based behavior still works.
2. **Given** the same Go block, **When** the user uses a Treesitter semantic textobject, **Then** the result is documented as complementary, better, or intentionally unsupported for that structure.
3. **Given** a parser does not expose a useful semantic capture for a structure, **When** the user tries a semantic mapping, **Then** the feature fails safely without breaking native fallback edits.

---

### User Story 4 - Move or Swap Structural Units (Priority: P3)

As a Neovim user, I want optional structural movement or swapping for parameters and functions so common refactors can be performed without manual cut-and-paste.

**Why this priority**: Movement/swapping is useful, but less essential than selection and should not make the initial feature brittle.

**Independent Test**: Can be tested by moving between functions/classes and swapping parameters in a small supported fixture.

**Acceptance Scenarios**:

1. **Given** a file with multiple functions, **When** the user invokes next/previous structural movement, **Then** the cursor jumps to the expected neighboring function or structural unit.
2. **Given** a function call or declaration with multiple parameters, **When** the user invokes parameter swap, **Then** adjacent parameters swap without corrupting syntax.
3. **Given** a language/query does not support the requested structure, **When** movement or swap is invoked, **Then** no destructive edit occurs.

### Edge Cases

- Current `nvim-treesitter` main-branch parser install/update behavior must remain intact.
- Runtime path handling for `nvim-treesitter` main-branch queries must remain intact.
- Existing native textobjects such as `a(`, `i(`, `ca(`, and `va(` must continue to work.
- Mappings must not conflict with existing keymaps or make common edits surprising.
- Unsupported languages or missing queries must fail safely without errors during normal editing.
- Repeated Neovim starts must not register duplicate mappings, commands, or parser update hooks.
- Any new dependency must be declared, lockable, removable, and documented.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST evaluate the current Treesitter setup before adopting configuration examples written for another plugin manager.
- **FR-002**: The system MUST keep the existing parser install and update commands working.
- **FR-003**: The system MUST keep current main-branch runtime query path handling working.
- **FR-004**: The system MUST provide semantic selection for function outer and function inner regions where supported by language queries.
- **FR-005**: The system MUST provide semantic selection for class, type, or equivalent structural regions where supported by language queries.
- **FR-006**: The system MUST provide comment selection where supported by language queries.
- **FR-007**: The system MUST provide a way to expand and shrink selection by syntax tree nodes.
- **FR-008**: The system MUST preserve native punctuation textobject behavior such as parenthesis-based changes and selections.
- **FR-009**: The system MUST document how Treesitter semantic textobjects complement native textobjects rather than replacing them.
- **FR-010**: The system MUST avoid keymap conflicts with existing repository-managed Neovim mappings.
- **FR-011**: The system SHOULD provide structural movement between functions/classes or equivalent units if it can be done without brittle mappings.
- **FR-012**: The system SHOULD provide parameter swapping if it works safely in supported languages and does not conflict with existing mappings.
- **FR-013**: The system MUST fail safely when a parser or query does not support a requested textobject.
- **FR-014**: The system MUST include validation using at least one Go fixture and one Lua or JavaScript/TypeScript fixture.
- **FR-015**: The system MUST update Neovim module documentation with mappings, supported behavior, validation, troubleshooting, and rollback guidance.
- **FR-016**: The system MUST declare and lock any added plugin dependency through the repository's existing plugin workflow.
- **FR-017**: The system MUST remain portable across supported macOS environments and avoid user-specific absolute paths.
- **FR-018**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification.
- **FR-019**: Before pull request creation, the active specification relationship and closure/archival decision MUST be reviewed with the user.
- **FR-020**: Delivery MUST coordinate with the related Neovim specs through one integration branch and one final pull request to `main`.

### Key Entities

- **Semantic Textobject**: A syntax-aware selectable code region such as function, class/type, comment, parameter, or scope.
- **Incremental Selection Session**: A selection workflow that starts at the cursor syntax node and expands or shrinks through parent/previous nodes.
- **Structural Movement**: Navigation between semantic units such as functions or classes/types.
- **Structural Swap**: A safe edit that swaps adjacent semantic units, especially parameters.
- **Language Query Support**: The available parser and query captures that determine whether a textobject works for a filetype.
- **Mapping Contract**: The documented keymap behavior, conflict boundaries, and fallback expectations for this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 4 semantic selection mappings work in validated supported filetypes.
- **SC-002**: Incremental selection expands and shrinks through at least 3 nested syntax levels in validated fixtures.
- **SC-003**: Native parenthesis textobjects still work in the Go const block validation scenario after the feature is enabled.
- **SC-004**: No existing repository-managed keymap conflict is introduced by the selected mappings.
- **SC-005**: Headless Neovim startup and Treesitter health checks pass after the configuration change.
- **SC-006**: Documentation explains when to use semantic textobjects versus native punctuation textobjects in under 2 minutes of reading.

## Assumptions

- This feature is limited to repository-managed Neovim Treesitter behavior and documentation.
- The implementation will not switch plugin managers or copy Lazy.nvim examples directly.
- Some captures may be unavailable in some languages; safe fallback and documentation are acceptable when query support is absent.
- Issue #48 is approved and can be linked by the final PR.
- This spec remains separate from command-line UI and plugin cleanup specs, but final delivery is coordinated through one integration branch and one final PR to `main`.
