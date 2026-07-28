# Quickstart: Installer V2 UI and Install Flow Validation

## Prerequisites

- macOS terminal session.
- Repository checkout on branch `002-installer-v2-ui`.
- Go available for development validation.

## Baseline Commands

```sh
cd installer
go test ./...
go run ./cmd/dotfiles-installer
```

Expected result: tests pass and the installer opens with a full-screen or readable terminal UI, clear safe/preview state, keyboard footer, and no unclear labels such as `confirmation_required`, `manual_only`, or `dry_run_report_only` shown directly to users.

## Scenario 1: Downloaded Binary Launch

Build a local release-like binary:

```sh
mkdir -p dist
(cd installer && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -o ../dist/dotfiles-installer-darwin-arm64 ./cmd/dotfiles-installer)
./dist/dotfiles-installer-darwin-arm64
```

Expected result: terminal execution visibly starts the installer. If it cannot start, the message explains the reason and next command/action.

## Scenario 2: Clear Confirmation and Automatic Backup Summary

Run the installer and choose a flow that plans config sync or install work.

Expected result: before mutation, the confirmation screen summarizes changed files, automatic backup behavior, skipped items, and manual actions in plain language. Cancelling before confirmation makes no changes.

## Scenario 3: Visible Running Progress

Run an install or upgrade flow with command-backed steps.

Expected result: the running screen shows current step, module/tool name, completed count out of total, and activity/progress within 2 seconds. The UI must not jump directly from confirmation to final report without a visible running state.

## Scenario 4: Final Report Accountability

Complete, fail, or cancel an install run.

Expected result: the final report accounts for every planned step as completed, changed, backed up, skipped, manual, cancelled, or failed. Backup paths and restore guidance are visible when backups are created.

## Scenario 5: Repeated Run Safety

Run the same successful flow twice.

Expected result: already-correct files/tools are reported without unnecessary duplicate changes or backup overwrites.

## Scenario 6: UI Fallback

Run in a small terminal, then resize.

Expected result: at 80x24, title, current action/status, progress, and footer shortcuts remain readable. If emojis or color render poorly, labels still explain every state.

## Documentation Validation

Review `installer/README.md` and release instructions.

Expected result: docs explain Apple Silicon/Intel artifact names, direct terminal execution, `--prefer-binary` bootstrap path, and troubleshooting for permission/quarantine/non-terminal launch issues.
