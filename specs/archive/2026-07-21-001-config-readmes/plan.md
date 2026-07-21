# Implementation Plan: Configuration README Documentation

**Branch**: `001-config-readmes` | **Date**: 2026-07-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-config-readmes/spec.md`

## Summary

Add focused configuration documentation for `Tmux/` and update `nvim/README.md` so both directories are clearly presented as shared dotfiles configuration. The implementation will create a concise `Tmux/README.md` from the committed `Tmux/tmux.conf`, preserve the existing Neovim README's operational guidance, and avoid duplicating root README content except where contradiction removal is needed.

## Technical Context

**Language/Version**: Markdown documentation; shell commands only as documented validation examples.

**Primary Dependencies**: Existing tmux configuration, TPM (`tmux-plugins/tpm`), Neovim config docs, setup scripts under `setup/`.

**Storage**: Repository-managed Markdown files only; no generated state or local machine files.

**Testing**: Documentation review, Markdown readability check, command snippet review, and optional safe dry-run validation commands already documented in `nvim/README.md`.

**Target Platform**: macOS dotfiles users on Apple Silicon or Intel where existing tmux/Neovim setup is supported.

**Project Type**: Dotfiles-managed configuration documentation.

**Performance Goals**: A user can identify Tmux purpose/setup in under 2 minutes and Neovim validation/linking/local override guidance in under 3 minutes.

**Constraints**: Do not add new installation behavior; do not introduce user-specific absolute paths beyond documented standard locations; keep docs concise and scannable; do not remove existing Neovim guidance unless it is misleading.

**Scale/Scope**: Two configuration documentation surfaces: new `Tmux/README.md` and updated `nvim/README.md`; root README updates only if contradictions must be removed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. Docs describe repository paths, standard tmux/Neovim locations, and environment/local override patterns without hard-coding private paths.
- **Idempotency**: Pass. Docs must favor dry-run and reload/validation actions that are safe to repeat.
- **Non-destructive safety**: Pass. Docs must warn against overwriting existing local tmux/Neovim configs and point to safe linking/copying behavior.
- **Modularity**: Pass. Tmux and Neovim guidance stays in their tool directories.
- **Source of truth**: Pass. Directory READMEs become the local source of truth for each tool's configuration behavior.
- **Dependencies**: Pass. Tmux plugin manager and Neovim dependency validation are documented where relevant.
- **Security**: Pass. Docs keep machine-specific values in environment variables or ignored local overrides.
- **Verification**: Pass. Quickstart defines documentation review and safe command validation.
- **Installer UX**: Pass. No installer changes; docs make setup/validation paths clearer.
- **Recovery**: Pass. Docs include rollback/recovery guidance for local config activation.
- **Maintainability**: Pass. Prefer short, reader-first docs over broad root README duplication.
- **Documentation**: Pass. This feature is documentation-only and directly satisfies the documentation gate.
- **Branch/PR discipline**: Pass. Work is on `docs/config-readmes`; PR creation must verify active spec relationship and ask whether the spec should be closed.

## Project Structure

### Documentation (this feature)

```text
specs/001-config-readmes/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── documentation-review.md
└── tasks.md
```

### Source Code (repository root)

```text
Tmux/
├── README.md              # New directory guide for tmux configuration
└── tmux.conf              # Existing tmux configuration to document

nvim/
├── README.md              # Existing Neovim configuration guide to refine
├── dependencies.tsv       # Existing dependency manifest referenced by README
└── plugin/                # Existing config referenced only for behavior context

README.md                  # Root overview; update only if needed to avoid contradiction
setup/
├── validate-nvim-deps.sh
├── bootstrap-nvim-deps.sh
└── link-nvim-config.sh
```

**Structure Decision**: Keep detailed tool guidance next to each tool. Create `Tmux/README.md` because the directory has no local README. Update `nvim/README.md` in place because it already contains the right operational sections and only needs configuration-focused refinement if gaps remain.

## Phase 0: Research Summary

See [research.md](./research.md). All technical unknowns are resolved with no open clarification markers.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [contracts/documentation-review.md](./contracts/documentation-review.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Portability**: Pass. Design uses standard paths and documents local overrides.
- **Idempotency**: Pass. Validation and reload instructions are repeatable.
- **Non-destructive safety**: Pass. Activation guidance includes existing-config caution and rollback.
- **Modularity**: Pass. Tmux and Neovim docs remain separate.
- **Source of truth**: Pass. Directory READMEs own detailed tool guidance.
- **Dependencies**: Pass. TPM and Neovim dependency validation are explicit.
- **Security**: Pass. No secrets or private values are introduced.
- **Verification**: Pass. Quickstart defines concrete review checks.
- **Installer UX**: Pass. No installer changes.
- **Recovery**: Pass. Rollback is documented as reverting docs and local activation actions.
- **Maintainability**: Pass. Docs are short and scoped.
- **Documentation**: Pass. Documentation artifacts are complete.
- **Branch/PR discipline**: Pass. Active spec closure must be verified before PR.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.
