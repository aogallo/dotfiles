# Implementation Plan: Installer Release v1

**Branch**: `001-installer-release-v1` | **Date**: 2026-07-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-installer-release-v1/spec.md`

## Summary

Publish the merged dotfiles installer as `v1.0.0` with a clear manual release playbook, a repeatable GitHub Actions release workflow, macOS installer binaries for Apple Silicon and Intel, `checksums.txt`, and bootstrap guidance for safely preferring released binaries while preserving source fallback.

## Technical Context

**Language/Version**: Go 1.22 for the installer module; Bash for bootstrap and shell validation; Markdown/YAML for release documentation and workflow.

**Primary Dependencies**: Existing Go module dependencies in `installer/go.mod`; GitHub Actions hosted macOS runner; GitHub Releases; standard `shasum`, `curl`, and shell tools available on macOS.

**Storage**: Repository files and GitHub Release assets; no application database.

**Testing**: `cd installer && go test ./...`, `setup/bootstrap-dotfiles-installer_test.sh`, `bash -n`, `git diff --check`, and release workflow dry-run/review validation.

**Target Platform**: macOS Apple Silicon (`darwin/arm64`) and Intel (`darwin/amd64`) installer binaries; GitHub Actions for automation.

**Project Type**: Dotfiles repository with a Go CLI/TUI installer and shell bootstrap scripts.

**Performance Goals**: Manual release playbook is executable in under 15 minutes after validation passes; binary-preferred bootstrap clearly reports selected path immediately after prerequisite checks.

**Constraints**: No direct implementation commits to `main`; no secrets in repository; no destructive bootstrap behavior; released binary path must fail safely or fall back to source.

**Scale/Scope**: First stable installer release plus repeatable release path for future versions; UX/UI installer redesign is explicitly out of scope for `v1.0.0`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. Plan targets both `darwin/arm64` and `darwin/amd64`; bootstrap continues to discover platform/architecture dynamically.
- **Idempotency**: Pass. Release workflow creates versioned immutable artifacts; bootstrap binary preference must not duplicate local state across repeated runs.
- **Non-destructive safety**: Pass. Release process does not overwrite user config; bootstrap download must use temporary/cache paths and fail or fallback safely.
- **Modularity**: Pass. Scope is limited to installer release automation, installer docs, and bootstrap binary preference behavior.
- **Source of truth**: Pass. Release inputs come from repository-managed installer source; generated artifacts remain GitHub Release assets, not committed binaries.
- **Dependencies**: Pass. Go, shell tools, and GitHub Actions requirements are explicit and testable.
- **Security**: Pass. Workflow uses GitHub-provided token permissions only; no credentials or private values are committed.
- **Verification**: Pass. Plan includes Go tests, shell tests, syntax checks, checksum validation, and failure-path checks.
- **Installer UX**: Pass. Bootstrap output must distinguish release binary, source fallback, and recovery paths.
- **Recovery**: Pass. Source fallback remains documented; failed binary verification must not block documented recovery.
- **Maintainability**: Pass. Prefer a small first-party workflow over adding GoReleaser for this initial two-binary release.
- **Documentation**: Pass. Root README and `installer/README.md` require release/manual/bootstrap updates.
- **Module README**: Pass. `installer/README.md` exists and will be updated with release behavior.
- **Spec navigation**: Pass. Future `tasks.md` must include marker legend and user-story links.
- **Branch/PR discipline**: Pass. Implementation should happen on a fresh feature branch and PR before creating the release tag.

## Project Structure

### Documentation (this feature)

```text
specs/001-installer-release-v1/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── installer-release.md
└── tasks.md
```

### Source Code (repository root)

```text
.github/
└── workflows/
    └── release-installer.yml

installer/
├── README.md
├── go.mod
└── cmd/dotfiles-installer/
    └── main.go

setup/
├── bootstrap-dotfiles-installer.sh
└── bootstrap-dotfiles-installer_test.sh

README.md
```

**Structure Decision**: Add the first repository workflow under `.github/workflows/`, keep installer builds inside the existing `installer/` Go module, update the existing bootstrap script rather than adding a second launcher, and document maintainer/user flows in root and installer READMEs.

## Complexity Tracking

No constitutional violations require complexity exceptions.

## Phase 0 Research

Completed in [research.md](./research.md). All technical unknowns are resolved.

## Phase 1 Design

Completed artifacts:

- [data-model.md](./data-model.md)
- [contracts/installer-release.md](./contracts/installer-release.md)
- [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

- **Portability**: Pass. Contracts require architecture-specific assets and documented unsupported platforms.
- **Idempotency**: Pass. Re-running bootstrap with binary preference must reuse or replace only managed temporary/cache artifacts.
- **Non-destructive safety**: Pass. No user config writes are introduced by release discovery.
- **Modularity**: Pass. Workflow and bootstrap changes stay installer-scoped.
- **Source of truth**: Pass. Committed source and docs remain canonical; generated binaries/checksums live in Releases.
- **Dependencies**: Pass. Required tooling and fallback behavior are captured in quickstart validation.
- **Security**: Pass. `contents: write` is limited to release publication; checksum verification is required before execution.
- **Verification**: Pass. Quickstart covers manual checks, workflow path, checksum behavior, and bootstrap fallback.
- **Installer UX**: Pass. Contract requires explicit output for selected binary/source/recovery path.
- **Recovery**: Pass. Source fallback remains the documented recovery path.
- **Maintainability**: Pass. No new release framework dependency is introduced.
- **Documentation**: Pass. README updates are part of implementation scope.
- **Module README**: Pass. Installer module README update is required.
- **Spec navigation**: Pass. Enforced in next tasks phase.
- **Branch/PR discipline**: Pass. Plan expects implementation via PR before tagging `v1.0.0`.
