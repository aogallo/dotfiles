<!--
Sync Impact Report
Version change: 1.0.0 -> 1.1.0
Modified principles:
- XII. Documentation and Governance: expanded governance enforcement expectations
Added sections:
- XIII. Feature Branch and PR Discipline
Removed sections:
- None
Templates requiring updates:
- ✅ updated: .specify/templates/plan-template.md
- ✅ updated: .specify/templates/spec-template.md
- ✅ updated: .specify/templates/tasks-template.md
- ✅ updated: .specify/templates/checklist-template.md
- ⚠ pending: .specify/templates/commands/*.md does not exist in this checkout
- ✅ reviewed: .opencode/commands/*.md
- ✅ updated: README.md
Follow-up TODOs:
- None
-->
# macOS Dotfiles Constitution

## Core Principles

### I. Portable by Default
Configurations MUST avoid user-specific absolute paths and MUST support both Apple Silicon
and Intel Macs where practical. Paths MUST be discovered from environment variables,
standard macOS locations, command discovery, or documented configuration inputs. Shared
configuration MUST be separate from machine-specific, work-specific, private, or local
override files.

Rationale: dotfiles are useful only when they can move between machines without carrying
one person's filesystem, hardware assumptions, or private environment into every install.

### II. Idempotent Installation
Install, update, validate, and removal commands MUST be safe to run repeatedly. Re-running
an installer MUST produce the same valid result without duplicated shell entries, broken
links, unnecessary reinstallations, stale generated output, or accumulated side effects.

Rationale: dotfiles are maintained over years; every command must converge the system to a
known state rather than depend on a single perfect first run.

### III. Non-Destructive Operations
Existing user configuration MUST never be silently overwritten or deleted. Installers MUST
detect conflicts, report the proposed change, create recoverable backups before replacing
anything, and fail safely when the requested operation cannot be completed without risk.

Rationale: a dotfiles repository manages personal development environments; data loss or
surprise replacement is a release-blocking defect.

### IV. Modular Tool Boundaries
Configuration and installation logic MUST be organized by tool or responsibility. Neovim,
tmux, Ghostty, lazygit, shell tools, Git, and related CLI applications MUST be installable,
updatable, validated, and removable as individual modules without requiring every supported
tool to be present.

Rationale: users adopt dotfiles incrementally, and one broken or unwanted tool must not
block the rest of the environment.

### V. Repository as Shared Source of Truth
Repository-managed shared configuration MUST originate from the repository. Generated
files, local state, machine-specific values, work-specific settings, personal overrides,
and secrets MUST remain clearly separated from portable shared configuration.

Rationale: reviewers and future maintainers must be able to tell what is governed,
portable configuration and what is local runtime state.

### VI. Reproducible Dependencies
Required and optional dependencies MUST be explicitly declared, reviewable, and
verifiable. Installers MUST validate prerequisites before use and MUST NOT rely on
undocumented manual installation steps.

Rationale: a clean machine must reveal missing dependencies through documented checks, not
through mysterious failures halfway through setup.

### VII. Security and Secret Hygiene
Credentials, tokens, private keys, personal identifiers, machine secrets, and private
configuration MUST never be committed. Sensitive configuration MUST use ignored local
files, environment variables, secure operating-system facilities, or documented example
templates that contain no real secrets.

Rationale: dotfiles are easy to publish and copy; the repository must be safe to inspect,
clone, and review.

### VIII. Verification Before Completion
Installation scripts and configuration changes MUST pass syntax checks, static validation,
and relevant smoke tests before a change is considered complete. Tests MUST cover clean
installation, repeated installation, existing configuration conflicts, partial failures,
and supported macOS environments where practical. A change with failing validation MUST
not be marked complete.

Rationale: environment automation breaks at boundaries; validation must prove the common
success path and the dangerous failure paths.

### IX. Clear Installer Experience
Commands MUST provide understandable progress, explicit skipped and failed operations,
actionable error messages, correct exit codes, and a final summary. Users MUST be able to
understand what changed, what was skipped, and what failed without reading installer
source code.

Rationale: clear operational feedback turns setup failures into fixable problems instead
of guesswork.

### X. Recovery and Rollback
Every destructive or replacing operation MUST have a documented recovery path. Backups
MUST be restorable, managed links and files MUST be removable safely, and interrupted
installations MUST be recoverable without requiring manual forensic cleanup.

Rationale: a safe installer needs an exit strategy before it changes user-owned files.

### XI. Simplicity and Maintainability
Scripts and configuration MUST remain small, readable, and composable. Native capabilities
and straightforward shell or tool features SHOULD be preferred over frameworks or
abstractions unless a concrete requirement justifies the added dependency and complexity.

Rationale: dotfiles are long-lived infrastructure; clever automation that is hard to audit
is a maintenance liability.

### XII. Documentation and Governance
Supported environments, installation, updates, customization, validation, rollback, and
troubleshooting MUST remain documented. Every specification, implementation plan, and code
review MUST verify compliance with this constitution. Exceptions MUST be explicit and
justified. Constitutional amendments MUST document rationale, compatibility impact, and
semantic version change.

Rationale: governance only works when contributors know the rules and reviewers can check
them consistently.

### XIII. Feature Branch and PR Discipline
Implementation commits MUST NOT be made directly on `main`. Every repository change MUST be
developed on a feature branch, committed there with conventional commit messages, and
submitted through a pull request before merge. Pull requests MUST link an approved issue
when the repository workflow requires issue approval. Direct commits to `main` are permitted
only for emergency recovery explicitly documented after the fact.

Rationale: `main` is the integration branch. Keeping work on feature branches preserves
reviewability, rollback boundaries, CI visibility, and a clean history of why changes were
accepted.

## Quality Gates

Every change that affects installation, configuration, dependencies, or repository-managed
tool behavior MUST pass these gates before completion:

- Portability gate: no new user-specific absolute paths; Apple Silicon and Intel behavior
  is supported where practical or the limitation is documented.
- Idempotency gate: repeated execution does not duplicate entries, recreate existing valid
  links, reinstall unchanged dependencies unnecessarily, or leave stale side effects.
- Safety gate: conflicts are detected, replacements are backed up, destructive actions are
  opt-in or explicitly reported, and failures leave the system in a recoverable state.
- Modularity gate: changes are scoped to the relevant tool module and do not require
  unrelated tools to be installed, updated, or removed.
- Source-of-truth gate: shared repo files, generated files, local overrides, and secrets
  remain visibly separated.
- Dependency gate: required and optional dependencies are declared and prerequisite checks
  are documented and testable.
- Security gate: no credentials, tokens, keys, private identifiers, or real local secrets
  are committed.
- Verification gate: syntax checks, static validation, smoke tests, and failure-path tests
  relevant to the change pass.
- Installer UX gate: progress, skipped operations, failures, exit codes, and final summary
  are understandable and actionable.
- Recovery gate: backup restoration, managed-file removal, and interrupted-install recovery
  paths are documented and validated where practical.
- Simplicity gate: new abstractions or dependencies have a documented concrete requirement.
- Documentation gate: usage, customization, validation, rollback, and troubleshooting docs
  are updated when behavior changes.
- Branch/PR gate: implementation work happens on a feature branch, commits do not target
  `main` directly, and the pull request links the required approved issue before review.

## Repository Scope

This constitution governs portable macOS dotfiles and automation for Neovim, tmux,
Ghostty, lazygit, shell tools, Git, and related CLI applications. It defines durable
project principles and quality gates. It does not prescribe exact directory structures,
package managers, scripting languages, testing frameworks, or implementation mechanisms
unless those mechanisms are required to satisfy a principle.

## Governance

This constitution supersedes conflicting repository practices, plans, templates, and code
review preferences. When a feature, script, or configuration cannot comply, the exception
MUST be documented with scope, rationale, risk, and recovery expectations before the work
is accepted.

Amendments MUST update this file, include a Sync Impact Report, identify affected
templates or runtime guidance, and document the semantic version impact:

- MAJOR: backward-incompatible governance changes, removed principles, or redefined
  obligations that invalidate previously compliant work.
- MINOR: new principles, new required sections, or materially expanded quality gates.
- PATCH: clarifications, wording fixes, or non-semantic refinements.

Specifications MUST include constitution-relevant requirements when a change touches
installation, configuration, dependencies, secrets, portability, validation, or rollback.
Implementation plans MUST evaluate every applicable quality gate before design and again
after design. Task lists MUST include concrete validation, documentation, and rollback
tasks whenever the change creates those obligations. Code review MUST block changes that
violate MUST-level principles, commit implementation work directly to `main`, or leave
required validation failing.

**Version**: 1.1.0 | **Ratified**: 2026-07-14 | **Last Amended**: 2026-07-15
