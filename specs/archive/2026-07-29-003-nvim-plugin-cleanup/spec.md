# Feature Specification: Neovim Plugin Cleanup UI

**Feature Branch**: `003-nvim-plugin-cleanup`

**Created**: 2026-07-28

**Status**: Draft

**Input**: User description: "Add issue #27 to the Neovim work. When a plugin is removed from config, nothing clearly removes it from disk. The existing PackClean command is based on inactive plugins and requires knowing plugin names as they appear on disk, which is confusing. The user wants a floating buffer UI similar to Mason or Lazy.nvim that lists plugins no longer present in active config and lets users understand what can be cleaned safely. If plugin-backed replacements remove custom behavior, unused custom code should also be removed instead of leaving dead code."

**Related Issue**: [#27](https://github.com/aogallo/dotfiles/issues/27)

## Clarifications

### Session 2026-07-28

- Q: Should this work be merged into the command-line UI or Treesitter specs? -> A: No; keep plugin cleanup as a separate spec coordinated through the same integration branch and final PR to `main`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review Orphaned Plugins Visually (Priority: P1)

As a Neovim user, I want a floating review UI that lists plugins installed on disk but no longer present in active configuration so I can understand cleanup candidates without manually guessing directory names.

**Why this priority**: The main pain is discoverability. The user needs to see what is installed, what is active, and what is stale before deleting anything.

**Independent Test**: Can be tested by simulating an installed plugin that is not active in current config and opening the cleanup UI.

**Acceptance Scenarios**:

1. **Given** a plugin exists on disk but is not active in current config, **When** the user opens the cleanup UI, **Then** the plugin appears as a cleanup candidate with enough context to identify it.
2. **Given** no orphaned plugins are found, **When** the user opens the cleanup UI, **Then** an empty state explains that no cleanup is needed.
3. **Given** a cleanup candidate appears, **When** the user reviews it, **Then** the UI shows the plugin name, resolved path, active/inactive status, and lockfile status where available.

---

### User Story 2 - Remove Selected Plugins Safely (Priority: P1)

As a Neovim user, I want to remove selected orphaned plugins only after path validation and confirmation so cleanup cannot accidentally delete unrelated files.

**Why this priority**: Cleanup deletes files. Safe path validation and confirmation are non-negotiable.

**Independent Test**: Can be tested by selecting one candidate, confirming deletion, and verifying only the intended plugin directory and stale metadata are removed.

**Acceptance Scenarios**:

1. **Given** a selected orphaned plugin has a path inside the Neovim package area, **When** the user confirms removal, **Then** only that plugin directory is removed.
2. **Given** a selected path resolves outside the allowed package area, **When** removal is attempted, **Then** deletion is blocked and a clear warning is shown.
3. **Given** cleanup completes, **When** the final report is shown, **Then** it lists removed, skipped, blocked, and not-found items.

---

### User Story 3 - Clean Stale Lockfile Entries (Priority: P2)

As a Neovim user, I want stale plugin lockfile entries to be identified and cleaned with the same workflow so the repository source of truth does not keep removed plugins around.

**Why this priority**: Disk cleanup without lockfile cleanup leaves confusing stale state in reviewable config.

**Independent Test**: Can be tested by creating a stale lockfile entry and verifying the cleanup workflow reports and removes it when confirmed.

**Acceptance Scenarios**:

1. **Given** a plugin is absent from active config but present in the lockfile, **When** the cleanup UI opens, **Then** the lockfile entry is shown as stale metadata.
2. **Given** the user confirms cleanup for a stale lockfile entry, **When** cleanup completes, **Then** the entry is removed from the lockfile.
3. **Given** a lockfile entry still belongs to an active plugin, **When** cleanup candidates are computed, **Then** the active entry is not offered for removal.

---

### User Story 4 - Retire Replaced Custom Code (Priority: P3)

As a maintainer, I want plugin-backed replacements to remove unused custom code in the same work unit so Neovim config does not accumulate dead wrappers, commands, or fallback paths.

**Why this priority**: The user explicitly does not want dead custom code left behind when plugins replace behavior.

**Independent Test**: Can be tested by reviewing implementation diffs and confirming replaced custom cleanup behavior is removed or intentionally documented as retained.

**Acceptance Scenarios**:

1. **Given** a plugin replaces custom cleanup behavior, **When** implementation is reviewed, **Then** the replaced custom behavior is removed or disabled in the same work unit.
2. **Given** custom fallback code remains, **When** implementation is reviewed, **Then** the fallback is explicitly documented with rationale and activation conditions.
3. **Given** no custom behavior is replaced, **When** implementation is reviewed, **Then** no unrelated cleanup code is removed.

### Edge Cases

- Cleanup must block deletion of paths outside Neovim's managed package directories.
- Cleanup must handle missing directories, already-removed plugins, and stale lockfile-only entries.
- Cleanup must not remove active plugins, dependencies still referenced by active specs, or unrelated local files.
- Cleanup must be safe to run repeatedly and produce stable results.
- Cleanup must report skipped and blocked items clearly.
- Cleanup must work without requiring the user to know the on-disk directory name in advance.
- Cleanup must not commit or expose machine-specific plugin cache paths beyond documented local runtime context.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a discoverable cleanup workflow for Neovim plugins no longer present in active configuration.
- **FR-002**: The system MUST present cleanup candidates in a floating UI or equivalent review surface before deletion.
- **FR-003**: The system MUST show each candidate's display name, resolved disk path, active/inactive status, and lockfile status where available.
- **FR-004**: The system MUST allow the user to select one or more cleanup candidates without typing the on-disk directory name manually.
- **FR-005**: The system MUST validate that every deletion target resolves inside allowed Neovim package directories before removing anything.
- **FR-006**: The system MUST block deletion for any path outside allowed package directories.
- **FR-007**: The system MUST never remove active plugins from disk or lockfile metadata.
- **FR-008**: The system MUST remove selected stale lockfile entries when the user confirms metadata cleanup.
- **FR-009**: The system MUST report removed, skipped, blocked, and not-found items after cleanup.
- **FR-010**: The system MUST be safe to run repeatedly without accumulating stale UI state or duplicate commands.
- **FR-011**: The system MUST preserve or improve the existing `PackClean` behavior; if replaced, the old behavior must be removed or redirected in the same work unit.
- **FR-012**: The system MUST document cleanup usage, safety rules, validation, troubleshooting, and rollback in the Neovim module README.
- **FR-013**: The system MUST include validation for disk-only orphan plugins, lockfile-only stale entries, active plugins, missing directories, and blocked unsafe paths.
- **FR-014**: The system MUST remain portable across supported macOS environments and avoid committed machine-specific absolute paths.
- **FR-015**: The system MUST avoid requiring unrelated tools or plugin managers.
- **FR-016**: If plugin-backed functionality replaces custom code, the implementation MUST remove or disable the replaced custom code in the same work unit unless a documented fallback is approved.
- **FR-017**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification.
- **FR-018**: Before pull request creation, the active specification relationship and closure/archival decision MUST be reviewed with the user.
- **FR-019**: Delivery MUST coordinate with the related Neovim specs through one integration branch and one final pull request to `main`.

### Key Entities

- **Plugin Candidate**: A plugin discovered as installed, inactive, stale in lockfile, or otherwise eligible for review.
- **Active Plugin Set**: Plugins currently declared by repository-managed config during the active Neovim session.
- **Installed Plugin Path**: A resolved local runtime directory where Neovim stores plugin files.
- **Lockfile Entry**: Metadata in `nvim/nvim-pack-lock.json` that records plugin source and revision.
- **Cleanup Selection**: User-selected candidates approved for deletion or metadata cleanup.
- **Cleanup Report**: Final categorized result showing removed, skipped, blocked, and not-found items.
- **Safety Boundary**: The allowed Neovim package directory roots within which deletion is permitted.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can identify orphaned plugin candidates without manually inspecting package directories.
- **SC-002**: 100% of deletion attempts outside allowed package directories are blocked in validation.
- **SC-003**: 100% of active plugins in validation fixtures are excluded from deletion candidates.
- **SC-004**: Cleanup reports include removed, skipped, blocked, and not-found categories for every run.
- **SC-005**: Re-running cleanup after successful removal reports no duplicate removals and no stale UI state.
- **SC-006**: Documentation explains plugin cleanup usage and safety model in under 2 minutes of reading.

## Assumptions

- Issue #27 still needs approval before a final PR can be opened under the repository approval workflow.
- The existing `PackClean` command is a baseline to improve or replace, not a complete solution.
- The cleanup UI should be inspired by Mason/Lazy-style review surfaces, but this feature does not require switching plugin managers.
- Runtime plugin directories are local machine state; committed specs and docs must not hard-code a user's absolute package path.
- This spec remains separate from command-line UI and Treesitter textobject specs, but final delivery is coordinated through one integration branch and one final PR to `main`.
