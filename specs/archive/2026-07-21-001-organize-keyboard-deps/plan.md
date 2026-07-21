# Implementation Plan: Organize Keyboard and Optional Dependencies

**Branch**: `001-organize-keyboard-deps` | **Date**: 2026-07-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-organize-keyboard-deps/spec.md`

## Summary

Resolve the recurring optional Neovim dependency follow-up by making the `shfmt` and `shellcheck` status clearly actionable while preserving their optional/non-blocking policy. Move the root-level Iris keyboard JSON into a dedicated `keyboard/` configuration module, preserve its content, document the new location, and provide rollback/validation steps.

## Technical Context

**Language/Version**: Bash for validation scripts; Markdown for documentation; JSON for keyboard configuration.

**Primary Dependencies**: Existing `setup/validate-nvim-deps.sh`, `setup/bootstrap-nvim-deps.sh`, `nvim/dependencies.tsv`, root `README.md`, existing `iris_rev__5.json`, and standard file comparison tools available on macOS.

**Storage**: Repository-managed files only: keyboard JSON assets and Markdown documentation.

**Testing**: `setup/validate-nvim-deps.sh`, `setup/bootstrap-nvim-deps.sh --dry-run --include-optional`, JSON parse validation for the moved Iris config, root duplicate check, content-preservation comparison, and `git diff --check`.

**Target Platform**: macOS dotfiles machines supported by the repository, across Apple Silicon and Intel where the existing setup applies.

**Project Type**: Dotfiles repository configuration and documentation.

**Performance Goals**: Dependency validation remains quick and non-blocking; keyboard configuration is discoverable from the root README or `keyboard/` folder in under 2 minutes.

**Constraints**: Keep `shfmt` and `shellcheck` optional; do not introduce user-specific paths; do not redesign the keyboard layout; do not change unrelated Neovim dependency behavior; preserve PR/spec closure governance.

**Scale/Scope**: One optional dependency status cleanup and one keyboard configuration relocation for the existing Iris Rev. 5 file.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. Uses repository-relative paths and existing Homebrew install hints; no machine-specific paths.
- **Idempotency**: Pass. Validation/dry-run commands are repeatable; file relocation leaves a single source copy.
- **Non-destructive safety**: Pass. Keyboard file content is preserved and rollback is documented as a repository move/revert.
- **Modularity**: Pass. Changes stay in Neovim dependency docs/scripts and a keyboard configuration module.
- **Source of truth**: Pass. `nvim/dependencies.tsv` remains dependency source of truth; `keyboard/` becomes keyboard asset source.
- **Dependencies**: Pass. Optional tools remain declared, reviewable, and validated.
- **Security**: Pass. No secrets, private hostnames, or absolute local keyboard paths.
- **Verification**: Pass. Plan includes dependency validation, dry-run optional install validation, JSON parse, duplicate check, and content comparison.
- **Installer UX**: Pass. Optional missing tools must stay clearly reported with actionable install hints.
- **Recovery**: Pass. Rollback path is documented for moving the keyboard JSON back or reverting the repo change.
- **Maintainability**: Pass. Prefer documentation/manifest clarity and a simple folder move over new abstractions.
- **Documentation**: Pass. Root/keyboard/Neovim documentation updates are planned where relevant.
- **Branch/PR discipline**: Pass. Implementation must happen on a feature branch, link an approved issue, and ask whether to close/archive this spec before PR creation.

## Project Structure

### Documentation (this feature)

```text
specs/001-organize-keyboard-deps/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── repository-organization.md
└── tasks.md
```

### Source Code (repository root)

```text
keyboard/
├── README.md
└── iris_rev__5.json

nvim/
├── README.md
└── dependencies.tsv

setup/
├── validate-nvim-deps.sh
└── bootstrap-nvim-deps.sh

README.md
```

**Structure Decision**: Create a top-level `keyboard/` module for keyboard assets, move `iris_rev__5.json` there unchanged, and add a small `keyboard/README.md`. Keep Neovim optional dependency policy in the existing Neovim dependency manifest, validator, bootstrap docs, and `nvim/README.md`; update scripts only if planning evidence shows the current output is not actionable enough.

## Phase 0: Research Summary

See [research.md](./research.md). All technical unknowns are resolved with no open clarification markers.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [contracts/repository-organization.md](./contracts/repository-organization.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Portability**: Pass. All paths remain repository-relative; install hints use documented package manager commands.
- **Idempotency**: Pass. Re-running validation and dry-run commands does not mutate files; duplicate root copy checks prevent drift.
- **Non-destructive safety**: Pass. Move is content-preserving with explicit rollback.
- **Modularity**: Pass. Keyboard assets live under `keyboard/`; Neovim dependencies remain under `nvim/` and `setup/`.
- **Source of truth**: Pass. One active Iris JSON remains after move.
- **Dependencies**: Pass. Optional tooling remains optional and reviewable.
- **Security**: Pass. No secrets or machine-specific data introduced.
- **Verification**: Pass. Quickstart covers dependency status and keyboard file integrity.
- **Installer UX**: Pass. Optional warnings remain clear and non-blocking.
- **Recovery**: Pass. Rollback documented in quickstart and planned docs.
- **Maintainability**: Pass. Small file move/doc update; no new framework.
- **Documentation**: Pass. Root, keyboard, and Neovim docs are included.
- **Branch/PR discipline**: Pass. Active spec closure remains a PR gate.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.
