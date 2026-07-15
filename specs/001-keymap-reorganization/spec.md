# Feature Specification: Neovim Keymap Reorganization

**Feature Branch**: `001-keymap-reorganization`

**Created**: 2026-07-15

**Status**: Draft

**Input**: User description: "quiero que analices la configuracion de neovim y espcificamente los keymaps del @nvim/lua/config/keymaps.lua y la de todos los plugins. Me inclino mucho por la idea de lazyvim de que sus keymaps son intiutivos por ejemplo <leader>g corresponde a todo el stuff de git, <leader>c todo lo de codigo, <leader>b todo lo de buffers, <leader>u todo lo de ui, y me propongas lo mismo siguiendo ese patron, quiero ver la propuesta para autorizarla"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review an Intuitive Keymap Proposal (Priority: P1)

As the dotfiles owner, I want a complete proposal for reorganizing Neovim keymaps by semantic leader groups before any configuration is changed, so I can approve a coherent layout instead of accepting piecemeal shortcuts.

**Why this priority**: This is the explicit user request and prevents accidental disruption of daily editing muscle memory.

**Independent Test**: Can be fully tested by reading the proposal and confirming that every existing global, LSP, and plugin keymap is either preserved, moved into a semantic group, or explicitly marked as intentionally unchanged.

**Acceptance Scenarios**:

1. **Given** the current Neovim configuration, **When** the proposal is reviewed, **Then** it lists the current relevant keymaps from `nvim/lua/config/keymaps.lua`, `nvim/lua/lsp.lua`, and `nvim/plugin/*.lua`.
2. **Given** an existing keymap, **When** the proposal assigns it a future shortcut, **Then** the assignment follows a predictable group such as git, code, buffers, UI, files, search, package management, or windows.
3. **Given** a keymap that should remain native-style rather than leader-based, **When** the proposal is reviewed, **Then** it explains why it remains unchanged.

---

### User Story 2 - Preserve Fast Editing Habits (Priority: P2)

As the dotfiles owner, I want the reorganization to keep high-frequency editing and navigation shortcuts stable unless there is a strong consistency reason to move them, so the new scheme improves discoverability without slowing normal work.

**Why this priority**: A beautiful grouping that breaks core motion, LSP navigation, or insert-mode workflows would be worse than the current state.

**Independent Test**: Can be tested by comparing the proposed changes against the current keymap inventory and verifying that core motions, insert-mode escapes, window navigation, diagnostic jumps, git hunk jumps, and standard LSP `g` mappings remain usable.

**Acceptance Scenarios**:

1. **Given** the current base editing keymaps, **When** the proposal is reviewed, **Then** movement, search-centering, paste behavior, visual indenting, window movement, and snippet escape behavior are preserved.
2. **Given** common native Neovim/LSP conventions, **When** the proposal is reviewed, **Then** `gd`, `gD`, `grr`, `gy`, `[e`, `]e`, `[g`, and `]g` remain outside leader groups because they are direct navigation motions.

---

### User Story 3 - Make Discovery Consistent in Which-Key (Priority: P3)

As the dotfiles owner, I want leader groups to appear consistently in the key discovery UI, so I can learn and remember shortcuts by topic.

**Why this priority**: The current configuration already has partial groups, but missing groups and misplaced entries reduce the value of discovery.

**Independent Test**: Can be tested by opening the key discovery UI and confirming that all leader prefixes in the approved proposal have matching group labels and no orphaned mappings under confusing prefixes.

**Acceptance Scenarios**:

1. **Given** the approved grouping scheme, **When** leader-key discovery is opened, **Then** each top-level group has a clear label.
2. **Given** a plugin-specific keymap, **When** it appears in discovery, **Then** it is grouped by user intent rather than plugin implementation.

---

### Proposed Keymap Grouping

The proposal follows the LazyVim-style mental model requested by the user: the first key after `<leader>` identifies the domain, and the second key identifies the action.

| Group | Meaning | Proposed Scope |
|-------|---------|----------------|
| `<leader>b` | Buffers | Buffer list, delete/close, next/previous, buffer cleanup |
| `<leader>c` | Code | Diagnostics, code actions, formatting, LSP symbols, lint fixes, Markdown preview as authoring/code-adjacent action |
| `<leader>f` | Files | File picker, recent files, explorer |
| `<leader>g` | Git | Git hunks, blame, links, lazygit, diff views, file history |
| `<leader>p` | Packages | Package update and lockfile synchronization |
| `<leader>s` | Search | Grep, current-buffer search, help search, highlights, resume picker, spelling suggestions when leader-based |
| `<leader>u` | UI | Display toggles such as inlay hints, color/highlight inspection, diagnostic display toggles, Markdown/render preview toggles if treated as visual presentation |
| `<leader>w` | Windows | Window or tab management actions when added in the future |

### Proposed Mapping Changes for Authorization

| Current Mapping | Current Action | Proposed Mapping | Group Rationale |
|-----------------|----------------|------------------|-----------------|
| `<leader>cd` | Open diagnostic float | `<leader>cd` | Keep under code diagnostics |
| `<leader>cl` | Apply all ESLint/Stylelint fixes | `<leader>cL` | Code lint fix; uppercase avoids crowding common lowercase actions |
| `gQ` | Format whole buffer | `<leader>cf` | Formatting is a code action and should be discoverable under code |
| `<leader>fs` | Document symbols | `<leader>cs` | Symbols are code structure, not file search |
| `<leader>cp` | Markdown preview toggle | `<leader>up` | Preview is a UI/presentation toggle |
| `<leader>fb` | Buffer picker | `<leader>bb` | Buffer picker belongs with buffers |
| `H` | Previous buffer | `<leader>bp` | Buffer navigation should be discoverable; preserve `H` only if the user wants old muscle memory retained temporarily |
| `L` | Next buffer | `<leader>bn` | Buffer navigation should be discoverable; preserve `L` only if the user wants old muscle memory retained temporarily |
| `<leader>bo` | Delete other buffers | `<leader>bo` | Already correct under buffers |
| `<leader>e` | Explorer | `<leader>fe` | Explorer is file navigation; avoids single-letter orphan under leader |
| `<leader>ff` | Find files | `<leader>ff` | Already correct under files |
| `<leader>fr` | Recent files | `<leader>fr` | Already correct under files |
| `<leader>f/` | Search current buffer | `<leader>sb` | Search action scoped to current buffer |
| `<leader>fg` | Live grep / visual grep | `<leader>sg` | Grep is search, not file |
| `<leader>fh` | Help tags | `<leader>sh` | Help lookup is search |
| `<leader>fc` | Highlights | `<leader>uh` | Highlight inspection is UI/theme-oriented |
| `<leader>fd` | Document diagnostics picker | `<leader>sd` | Diagnostic list is a search/discovery picker; keep `<leader>cd` for diagnostic float |
| `<leader>f<` | Resume last picker | `<leader>sr` | Resuming picker is search workflow |
| `<leader>gg` | Lazygit | `<leader>gg` | Already correct under git |
| `<leader>gd` | Diff view | `<leader>gd` | Already correct under git |
| `<leader>gf` | File history | `<leader>gh` | Git file history is better remembered as history |
| `<leader>gb` | Blame line | `<leader>gb` | Already correct under git |
| `<leader>gc` | Yank git link | `<leader>gy` | Action is yank/copy link; avoids collision with code group semantics |
| `<leader>go` | Open git link blame | `<leader>gO` | Open external git link; uppercase signals external/browser action |
| `<leader>gp` | Preview hunk | `<leader>gp` | Already correct under git |
| `<leader>gr` | Reset hunk | `<leader>gr` | Already correct under git |
| `<leader>gR` | Reset buffer | `<leader>gR` | Already correct under git; uppercase signals broader scope |
| `<leader>gs` | Stage hunk | `<leader>gs` | Already correct under git |
| `<leader>G*` | Diffview conflict actions | `<leader>gx*` | Merge conflict actions should stay under git but avoid a separate uppercase top-level group; `x` reads as conflict |
| `<leader>pu` | Update packages | `<leader>pu` | Already correct under packages |
| `<leader>ps` | Sync packages to lockfile | `<leader>pl` | Lockfile action is clearer as package lock sync |

### Mappings Proposed to Remain Unchanged

| Mapping | Reason |
|---------|--------|
| `jk`, enhanced `<esc>` | Core insert/snippet escape behavior; leader grouping would not improve it |
| `j`, `k`, `<C-d>`, `<C-u>`, `n`, `N`, visual `<`, visual `>` | Core editing and movement ergonomics |
| `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` | Fast window navigation convention shared with tmux-style navigation |
| `[e`, `]e` | Diagnostic navigation mirrors native previous/next patterns |
| `[g`, `]g` | Git hunk navigation mirrors native previous/next patterns |
| `gd`, `gD`, `grr`, `gy`, `grc` | LSP navigation conventions are already mnemonic and common |
| Insert-mode completion and snippet mappings | Plugin-local insert workflows should remain close to completion/snippet conventions |
| Diffview panel-local keys | Modal panel keys are context-specific and should not be forced into global leader groups |

### Edge Cases

- Reorganization must not create duplicate mappings where two actions share the same mode and shortcut.
- Reorganization must not hide buffer-local LSP mappings behind global mappings that behave differently per buffer.
- Reorganization must preserve plugin-local keymaps inside Diffview panels where those keys are only meaningful in that UI.
- Reorganization must keep discoverability metadata accurate so the key discovery UI does not advertise stale groups or old shortcuts.
- Reorganization must avoid user-specific paths, secrets, and machine-local assumptions.
- Reorganization must be safe to apply repeatedly without accumulating duplicate registration entries.
- Reorganization must include a rollback path: reverting the keymap files should restore the previous behavior without touching unrelated dotfiles modules.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The proposal MUST inventory existing Neovim keymaps from the base keymap file, LSP attachment logic, and plugin configuration files.
- **FR-002**: The proposal MUST assign leader-based mappings to semantic top-level groups where the first key after `<leader>` identifies the domain.
- **FR-003**: The proposal MUST keep high-frequency native-style movement, editing, diagnostic navigation, git hunk navigation, LSP navigation, insert-mode completion, and plugin panel mappings unchanged unless a clear discoverability benefit justifies moving them.
- **FR-004**: The proposal MUST identify each mapping that should move, the current shortcut, the proposed shortcut, and the reason for the group assignment.
- **FR-005**: The proposal MUST identify mappings that should remain unchanged and explain why they should not be forced into leader groups.
- **FR-006**: The approved future implementation MUST update key discovery group labels so every top-level leader group has an accurate name.
- **FR-007**: The approved future implementation MUST not introduce duplicate shortcuts for the same mode.
- **FR-008**: The approved future implementation MUST not silently remove an existing behavior; removed or moved mappings must be documented in the change summary.
- **FR-009**: The approved future implementation MUST remain scoped to the Neovim module and must not require unrelated dotfiles tools to be installed or changed.
- **FR-010**: The approved future implementation MUST avoid secrets, user-specific absolute paths, and machine-specific assumptions.
- **FR-011**: The approved future implementation MUST be verifiable with a syntax/configuration check and a manual key discovery smoke test.
- **FR-012**: The approved future implementation MUST be recoverable by reverting the Neovim keymap-related files without requiring broader dotfiles rollback.
- **FR-013**: The approved future implementation MUST happen on a feature branch and be prepared for pull-request review rather than direct integration into `main`.

### Key Entities

- **Keymap**: A shortcut binding with mode, trigger, action, description, scope, and source file.
- **Keymap Group**: A top-level leader namespace that represents a domain such as git, code, buffers, files, search, UI, packages, or windows.
- **Mapping Migration**: A proposed movement from an existing shortcut to a new shortcut, including rationale and compatibility impact.
- **Preserved Mapping**: An existing shortcut intentionally left unchanged because it is native-style, high-frequency, buffer-local, or context-specific.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of current relevant keymaps are classified as moved, unchanged, or context-local before implementation begins.
- **SC-002**: At least 90% of active leader mappings after implementation use one of the approved semantic top-level groups listed in Proposed Keymap Grouping.
- **SC-003**: Zero duplicate mappings exist for the same mode and shortcut after the approved implementation.
- **SC-004**: A user can find any leader-based git, code, buffer, UI, file, search, or package action through key discovery in under 10 seconds.
- **SC-005**: Core editing/navigation mappings listed as preserved continue to work after the approved implementation.
- **SC-006**: The Neovim configuration passes a syntax/configuration validation check after the approved implementation.

## Assumptions

- The first phase is proposal-only; implementation requires explicit user authorization.
- The target user is the repository owner and primary Neovim user.
- The desired mental model is close to LazyVim, but the exact mappings do not need to copy LazyVim when this configuration has stronger existing conventions.
- Existing native-style LSP and motion conventions are valuable and should be preserved by default.
- `which-key.nvim` remains the discovery surface for leader group labels.
- Changes are limited to repository-managed Neovim configuration.
