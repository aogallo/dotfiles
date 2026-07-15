# Feature Specification: Neovim Config Audit

**Feature Branch**: `001-nvim-config-audit`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "Quiero que revises la carpeta @nvim/ Analiza el codigo, utiliza context7 para verificar si lsp, treesitter y los demas plugins se estan utilizando de la manera correcta para neovim v0.12.1. Dame mejoras si encuentras alguna. La idea de esto es crear un repositorio de esta configuracion y de los demas archivos de configuracion para que cuando reinicie o me mueva de computadora pueda ejecutar un comando de brew o descargar un binario y se ejecute e instale todo lo necesario, algunos lsp no estan con mason por ejemplo golsp no me dejaba instalarlo y lo instale por fuera"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Audit Neovim Configuration Correctness (Priority: P1)

As the dotfiles maintainer, I want the `nvim/` configuration reviewed against current
authoritative Neovim and plugin documentation so I can know whether LSP, Treesitter,
formatting, completion, diagnostics, and plugin setup are correct for the target Neovim
version.

**Why this priority**: The configuration must be technically sound before it becomes the
foundation for a portable dotfiles installer.

**Independent Test**: A reviewer can inspect the audit report and verify that every major
Neovim subsystem found in `nvim/` has a documented status, evidence source, and recommended
action when needed.

**Acceptance Scenarios**:

1. **Given** the current `nvim/` folder, **When** the audit is performed, **Then** the report identifies LSP, Treesitter, plugin manager, completion, formatting, diagnostics, snippets, filetype-specific configuration, and startup entry points that are present.
2. **Given** a subsystem uses APIs or plugin behavior that may differ by Neovim version, **When** the audit cites documentation, **Then** the report states whether the usage is valid, deprecated, risky, or requires version confirmation.
3. **Given** an issue or improvement is found, **When** the report describes it, **Then** it includes the affected path, the observed behavior, the recommended change, and the reason.

---

### User Story 2 - Identify Portable Dependency Strategy (Priority: P2)

As the dotfiles maintainer, I want all Neovim-related external dependencies and language
servers identified with their installation source so the future installer can reproduce the
setup on a new Mac.

**Why this priority**: Some language servers may not be managed by Mason, so the repository
needs a reliable dependency inventory before automation can be safe.

**Independent Test**: A reviewer can compare the dependency inventory against the Neovim
configuration and confirm that each required external tool has a declared installation or
validation path.

**Acceptance Scenarios**:

1. **Given** the current configuration references language servers, formatters, linters, or CLI tools, **When** dependencies are inventoried, **Then** each dependency is classified as managed by Neovim plugin tooling, installed externally, optional, or missing.
2. **Given** a dependency is installed outside Neovim plugin tooling, **When** the inventory documents it, **Then** it records the expected executable name and a portable installation recommendation without hardcoding user-specific paths.
3. **Given** a dependency cannot be installed through the preferred manager, **When** it is documented, **Then** the report explains the fallback strategy and how the installer should validate it.

---

### User Story 3 - Prepare for Reproducible Dotfiles Installation (Priority: P3)

As the dotfiles maintainer, I want improvement recommendations framed around portability,
idempotency, safety, and rollback so the Neovim setup can later become part of a single
bootstrap command for a new machine.

**Why this priority**: The audit should not only find plugin issues; it should shape the
future repository into something recoverable and maintainable.

**Independent Test**: A reviewer can use the recommendations to create follow-up planning
tasks for installation, dependency validation, backups, and smoke tests without guessing the
intended safety requirements.

**Acceptance Scenarios**:

1. **Given** recommendations are produced, **When** they affect installation or local configuration, **Then** they state whether the change impacts portability, idempotency, non-destructive behavior, dependencies, secrets, verification, installer UX, or rollback.
2. **Given** the future installer will manage Neovim configuration, **When** the audit identifies managed files or links, **Then** it flags conflict detection, backup, and restore requirements.
3. **Given** optional tools or plugins are not required for all users, **When** recommendations are documented, **Then** they distinguish required setup from optional enhancements.

---

### Edge Cases

- The referenced Neovim version is newer than the latest versioned Context7 documentation available; the audit must state the documentation source and flag version-specific uncertainty.
- A language server, formatter, or parser is referenced by configuration but missing from any dependency declaration.
- A language server is intentionally installed outside Mason or Neovim plugin tooling and must remain supported by the future installer.
- Configuration depends on a user-specific path, local machine state, private file, or manually installed binary.
- Re-running the future installer would duplicate plugin setup, shell entries, symlinks, or generated files.
- Existing user Neovim configuration already exists on a target machine and conflicts with repository-managed files.
- Optional tools are absent on a clean machine but should not break unrelated Neovim functionality.
- Apple Silicon and Intel Macs require different installation locations or binary availability for a dependency.
- A partial installation is interrupted after links or dependencies are created but before validation completes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The audit MUST inspect the `nvim/` folder and identify all major configuration entry points, plugin definitions, plugin lock data, LSP configuration, Treesitter configuration, filetype-specific configuration, snippets, and custom Lua modules present in scope.
- **FR-002**: The audit MUST verify Neovim core API usage, LSP setup, diagnostics behavior, and related configuration patterns against authoritative documentation available through Context7 or another cited primary source when Context7 lacks the exact target version.
- **FR-003**: The audit MUST verify Treesitter and plugin-specific usage against authoritative documentation for the installed or configured plugin behavior where such documentation is available.
- **FR-004**: The audit MUST classify each finding as correct, improvement, risk, deprecated or incompatible usage, missing dependency, portability concern, or installer-readiness concern.
- **FR-005**: Each finding MUST include the affected file path, observed configuration, evidence or documentation basis, impact, and recommended action.
- **FR-006**: The audit MUST inventory external Neovim dependencies including language servers, formatters, linters, parsers, snippet engines, plugin managers, terminal integrations, and CLI tools referenced by the configuration.
- **FR-007**: The dependency inventory MUST distinguish dependencies managed inside Neovim tooling from dependencies expected to be installed externally.
- **FR-008**: The dependency inventory MUST explicitly support external language server installation when Mason or equivalent tooling cannot reliably install a server.
- **FR-009**: Recommendations MUST avoid user-specific absolute paths and MUST prefer environment-based discovery, executable lookup, or documented local overrides.
- **FR-010**: Recommendations for future installation MUST preserve existing user configuration through conflict detection, reporting, recoverable backups, and safe failure behavior.
- **FR-011**: Recommendations MUST keep shared repository configuration separate from generated files, private overrides, machine-specific settings, work-specific settings, and secrets.
- **FR-012**: Recommendations MUST include validation expectations for syntax checks, health checks, plugin loading, LSP availability, Treesitter parser availability, repeated runs, conflict handling, and partial failure recovery.
- **FR-013**: The audit MUST produce a prioritized improvement list suitable for follow-up planning, separating must-fix issues from optional cleanup or enhancements.
- **FR-014**: The audit MUST document any uncertainty caused by unavailable exact-version documentation instead of presenting unverified assumptions as fact.

### Key Entities *(include if feature involves data)*

- **Configuration Area**: A Neovim subsystem or repository area under review, such as startup, plugins, LSP, Treesitter, completion, formatting, diagnostics, snippets, or filetype configuration.
- **Finding**: A documented audit result with location, classification, evidence, impact, and recommended action.
- **Dependency**: An external executable, plugin-managed asset, parser, language server, formatter, linter, or CLI tool required or optionally used by the configuration.
- **Installation Strategy**: The future method for declaring, installing, validating, or intentionally skipping a dependency or module.
- **Local Override**: A private or machine-specific configuration layer that must stay separate from shared repository-managed configuration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of discovered Neovim configuration areas in `nvim/` have an audit status and evidence-backed conclusion.
- **SC-002**: 100% of discovered external dependencies are classified as managed, externally installed, optional, or unresolved.
- **SC-003**: 100% of must-fix findings include a file path, impact statement, recommended action, and validation method.
- **SC-004**: The final recommendation list separates required fixes from optional improvements with no unclassified findings.
- **SC-005**: The audit identifies all known version-documentation gaps and does not rely on uncited claims for version-sensitive behavior.
- **SC-006**: The resulting report provides enough detail to create implementation tasks for a portable, idempotent, non-destructive installer without re-auditing the same files.

## Assumptions

- The target Neovim configuration scope is the repository `nvim/` directory provided by the user.
- The target editor version for compatibility analysis is Neovim v0.12.1 as requested by the user.
- Context7 must be used for authoritative documentation lookups where available; if exact v0.12.1 documentation is unavailable, the audit must state the closest source used and flag uncertainty.
- The future dotfiles repository is intended for macOS and should support both Apple Silicon and Intel Macs where practical.
- Mason or equivalent Neovim tooling is allowed for dependencies it can manage reliably, but externally installed language servers and tools are valid when documented and validated.
