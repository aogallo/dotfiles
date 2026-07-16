# Feature Specification: Neovim Config Consolidation

**Feature Branch**: Not created by hook  
**Created**: 2026-07-15  
**Status**: Draft  
**Input**: User description: "Consolidate the Neovim configs from `lvim/`, `kickstart.nvim/`, and `lazyvim/` into the canonical `nvim/` config. Review options, keymaps, plugins, and cleanup of old Neovim versions before implementation."

## User Scenarios & Testing

### User Story 1 - Canonical Neovim Config (Priority: P1)

As the dotfiles owner, I want `nvim/` to be the single maintained Neovim configuration, so future edits happen in one place and I do not have to remember which legacy config contains the current behavior.

**Why this priority**: A canonical target is the foundation for every other consolidation decision. Without it, options, keymaps, plugins, and cleanup can drift again.

**Independent Test**: Review the repository and confirm all proposed Neovim behavior changes target `nvim/`, while legacy directories are treated only as source material or cleanup scope.

**Acceptance Scenarios**:

1. **Given** multiple Neovim config directories exist, **When** consolidation work is planned, **Then** `nvim/` is identified as the only target for maintained shared configuration.
2. **Given** a behavior exists in `lvim/`, `kickstart.nvim/`, or `lazyvim/`, **When** it is considered for migration, **Then** the proposal records whether it should be adopted, rejected, or deferred instead of copied blindly.
3. **Given** a future contributor reviews the repository, **When** they look for the maintained Neovim config, **Then** they can identify `nvim/` as the source of truth without inspecting legacy configs first.

---

### User Story 2 - Reviewable Workstreams (Priority: P1)

As the dotfiles owner, I want consolidation split into options, keymaps, plugins, and cleanup workstreams, so each future implementation can be reviewed and verified independently.

**Why this priority**: Neovim configuration changes are easy to over-merge. Splitting work by responsibility keeps review focused and avoids hiding behavior changes inside cleanup.

**Independent Test**: Validate that each workstream has its own scope, acceptance scenarios, and success criteria before any implementation begins.

**Acceptance Scenarios**:

1. **Given** options, keymaps, plugins, and cleanup have different risks, **When** the consolidation is specified, **Then** each area is listed as a separate workstream.
2. **Given** one workstream is ready before the others, **When** implementation begins, **Then** it can be delivered without requiring unrelated workstreams in the same change.
3. **Given** a PR is prepared for a workstream, **When** scope is reviewed, **Then** unrelated behavior changes are excluded or moved to another workstream.

---

### User Story 3 - Preserve Editing Behavior Deliberately (Priority: P2)

As the dotfiles owner, I want useful options, keymaps, plugins, LSP support, formatting, and filetype behavior from legacy configs to be evaluated deliberately, so I keep valuable workflow improvements without importing accidental complexity.

**Why this priority**: The legacy configs contain useful editor behavior, but they also represent different frameworks and assumptions. Consolidation should improve the canonical config, not recreate every old setup.

**Independent Test**: Compare source configs against `nvim/` and confirm every adopted behavior has a clear reason, dependency expectation, and verification path.

**Acceptance Scenarios**:

1. **Given** an option appears in a legacy config, **When** it is already present or intentionally different in `nvim/`, **Then** the implementation preserves the canonical choice unless a specific benefit is documented.
2. **Given** a keymap appears in a legacy config, **When** it overlaps with an existing `nvim/` keymap, **Then** the conflict is resolved explicitly instead of creating duplicate or surprising bindings.
3. **Given** a plugin appears in a legacy config, **When** it is considered for `nvim/`, **Then** its purpose, dependency impact, and maintenance cost are evaluated before adoption.
4. **Given** language or tooling support is relevant to the user's workflow, **When** plugins and dependencies are reviewed, **Then** Markdown, TypeScript, Python, Serverless Framework, databases, SQL files, Docker, and Go are considered.

---

### User Story 4 - Remove Legacy Config Drift Safely (Priority: P3)

As the dotfiles owner, I want old Neovim config versions cleaned up safely, so stale files do not confuse future maintenance while recoverability and review history remain intact.

**Why this priority**: Cleanup is valuable, but it is riskier after behavior migration decisions are made. It should not erase source material before the proposal and future implementation have captured what matters.

**Independent Test**: Confirm cleanup scope is explicit, reviewable, and non-destructive until the user approves implementation.

**Acceptance Scenarios**:

1. **Given** legacy directories contain source material, **When** cleanup is planned, **Then** files are removed only after needed behavior has been adopted, rejected, or documented as intentionally out of scope.
2. **Given** deleted local files already exist in the worktree, **When** cleanup scope is documented, **Then** `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, and `lazyvim/ftplugin/json.lua` are included in the cleanup review.
3. **Given** a cleanup PR is prepared, **When** the active spec relationship is checked, **Then** the user is asked whether this spec should be closed if the PR completes the consolidation.

### Edge Cases

- Repeated setup or validation should not duplicate Neovim plugin state, generated files, symlinks, shell entries, or dependency declarations.
- Existing local Neovim configuration outside this repository must not be overwritten silently by consolidation or cleanup work.
- Optional tools for language support may be missing; missing optional dependencies should be reported clearly without blocking unrelated editor startup.
- Apple Silicon and Intel machines may have different installed tool paths or Homebrew locations; shared config should avoid hard-coded architecture-specific assumptions.
- Legacy configs may contain framework-specific behavior that does not map directly to the canonical `nvim/` structure.
- Keymaps may conflict with built-in Neovim defaults, plugin defaults, terminal behavior, or existing canonical keymaps.
- Plugins may overlap in responsibility, creating duplicated UI, duplicated LSP features, duplicated completion sources, or conflicting formatters.
- Cleanup may remove files that are still useful as reference material if migration decisions are not recorded first.
- Generated, local, private, or machine-specific state must remain separate from shared repository configuration.

## Requirements

### Functional Requirements

- **FR-001**: The consolidation MUST define `nvim/` as the canonical maintained Neovim configuration.
- **FR-002**: The consolidation MUST evaluate `lvim/`, `kickstart.nvim/`, and `lazyvim/` as source material, not as additional maintained targets.
- **FR-003**: The work MUST be split into four reviewable workstreams: options, keymaps, plugins, and cleanup of legacy Neovim config versions.
- **FR-004**: Each workstream MUST be independently implementable, reviewable, and verifiable without requiring unrelated workstream changes in the same PR.
- **FR-005**: Options migration MUST preserve existing canonical `nvim/` behavior unless a legacy option provides a documented workflow benefit.
- **FR-006**: Keymap migration MUST identify and resolve conflicts with current `nvim/` keymaps before adding or changing bindings.
- **FR-007**: Plugin migration MUST document the user-facing purpose of each adopted plugin and reject or defer plugins that duplicate existing canonical behavior without a clear benefit.
- **FR-008**: Plugin and tooling review MUST consider support for Markdown, TypeScript, Python, Serverless Framework, databases, SQL files, Docker, and Go.
- **FR-009**: Dependency changes MUST be explicitly declared and verifiable through the repository's dependency documentation or validation path.
- **FR-010**: The canonical config MUST remain modular by responsibility, so options, keymaps, plugins, LSP, and dependencies stay easy to inspect independently.
- **FR-011**: Consolidation MUST avoid user-specific absolute paths, private identifiers, credentials, tokens, machine secrets, and local-only configuration.
- **FR-012**: Setup and validation behavior related to Neovim MUST remain idempotent after consolidation.
- **FR-013**: Cleanup MUST explicitly include review of `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, and `lazyvim/ftplugin/json.lua` because they are already locally deleted.
- **FR-014**: Cleanup MUST not remove legacy files until their relevant behavior has been adopted, rejected, or documented as intentionally out of scope.
- **FR-015**: Any removal or replacement of repository-managed Neovim files MUST have a clear recovery path through version control and review history.
- **FR-016**: Validation MUST include syntax or smoke checks appropriate for Neovim configuration changes before any implementation is marked complete.
- **FR-017**: Documentation or review notes MUST identify the final source of truth for Neovim configuration after cleanup.
- **FR-018**: Implementation work MUST happen on a feature branch, not directly on `main`.
- **FR-019**: Before PR creation, the active specification relationship MUST be checked and the user MUST be asked whether the spec should be closed if the PR completes the consolidation scope.

### Key Entities

- **Canonical Neovim Config**: The maintained `nvim/` directory that should contain shared editor behavior after consolidation.
- **Legacy Neovim Config**: Any non-canonical Neovim config directory used only as source material or cleanup scope, including `lvim/`, `kickstart.nvim/`, and `lazyvim/`.
- **Workstream**: A reviewable slice of consolidation work: options, keymaps, plugins, or cleanup.
- **Migration Decision**: A recorded choice to adopt, reject, or defer a behavior found in a legacy config.
- **Dependency Declaration**: A reviewable record of required or optional tools needed by the canonical config.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A reviewer can identify `nvim/` as the canonical Neovim config from the proposal and resulting repository state without inspecting every legacy directory.
- **SC-002**: 100% of future consolidation tasks map to one of the four workstreams: options, keymaps, plugins, or cleanup.
- **SC-003**: 100% of adopted legacy behaviors include a clear migration decision explaining why the behavior belongs in `nvim/`.
- **SC-004**: 100% of keymap additions or changes are checked for conflict with existing canonical keymaps before implementation is accepted.
- **SC-005**: 100% of adopted plugin changes identify their user-facing purpose and dependency impact.
- **SC-006**: Neovim validation completes without configuration syntax errors after each implemented workstream.
- **SC-007**: Cleanup removes or archives legacy config material only after migration decisions for relevant behavior are recorded.
- **SC-008**: No committed Neovim consolidation change introduces user-specific absolute paths, secrets, or private local state.

## Assumptions

- The canonical target is `nvim/`; `lvim/`, `kickstart.nvim/`, and `lazyvim/` are not intended to remain maintained in parallel.
- This proposal defines scope and review boundaries first; implementation will happen later through one or more focused changes.
- Existing `nvim/` structure should be preferred unless a concrete consolidation requirement justifies reshaping it.
- Legacy framework-specific behavior should be translated only when it improves the canonical config directly.
- Cleanup should be the final workstream unless the user explicitly approves earlier removal of a clearly unrelated legacy file.

## Proposed Workstreams

| Workstream | Goal | Initial Scope | Out of Scope |
|------------|------|---------------|--------------|
| Options | Make editor defaults deliberate in `nvim/` | Compare option values across all configs, keep canonical defaults, adopt only useful missing behavior | Reformatting unrelated files |
| Keymaps | Preserve useful shortcuts without conflicts | Compare leader mappings, navigation, diagnostics, formatting, terminal, and plugin maps | Adding speculative keymaps without current workflow value |
| Plugins | Keep tooling that supports real work | Review plugin overlap, language support, UI/editor helpers, dependency impact | Recreating full LunarVim, Kickstart, or LazyVim distributions |
| Cleanup | Remove stale Neovim config versions safely | Delete or archive legacy files after migration decisions; include current local deletes in review | Removing source material before decisions are documented |
