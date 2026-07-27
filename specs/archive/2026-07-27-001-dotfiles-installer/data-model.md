# Data Model: Dotfiles Installer TUI

## Installer Session

Represents one interactive TUI run.

**Fields**:
- `id`: opaque run identifier for in-memory correlation
- `startedAt`: start timestamp
- `selectedFlow`: `install`, `sync`, `upgrade`, or `quit`
- `currentScreen`: `main_menu`, `module_list`, `action_plan`, `confirmation`, `running`, `report`, or `exit`
- `selectedModules`: ordered module ids included in the current plan
- `confirmations`: confirmations granted during the run
- `report`: final or in-progress Installation Report
- `exitCode`: process exit code to return on quit

**Validation rules**:
- A mutating action cannot run unless the session contains an explicit confirmation for that
  action.
- `q` exits from the main menu and returns/backtracks from safe sub-screens without applying
  unconfirmed changes.

## Bootstrap Session

Represents one first-run shell bootstrap execution before the Go TUI starts.

**Fields**:
- `platform`: detected operating system, initially `macos`
- `architecture`: detected CPU architecture, such as `arm64` or `amd64`
- `repositoryRoot`: resolved repository root for launching the installer
- `prerequisites`: ordered Bootstrap Prerequisite results
- `selectedLaunchPath`: `prebuilt_binary` or `go_run`
- `exitStatus`: `ready`, `prompt_required`, or `failed`

**Relationships**:
- A Bootstrap Session evaluates one or more Bootstrap Prerequisites.
- A successful Bootstrap Session produces one Launch Result.

**Validation rules**:
- Bootstrap must be safe to rerun and must check current state before installing anything.
- Bootstrap must stop with clear guidance when Xcode Command Line Tools require manual system
  prompt completion.
- Bootstrap must not configure GitHub accounts, SSH keys, user Git identity, or dotfiles links.

## Bootstrap Prerequisite

One prerequisite required before the TUI can run or before development tools are healthy.

**Fields**:
- `name`: `xcode_clt`, `homebrew`, or `go`
- `status`: `present`, `installed`, `prompt_required`, `failed`, or `skipped`
- `detectedPath`: optional discovered executable or installation path
- `message`: concise user-facing status or next step

**Validation rules**:
- Missing Xcode CLT is `prompt_required` after `xcode-select --install` is initiated.
- Homebrew and Go install steps must be skipped when already present.
- Go remains required even when a prebuilt installer binary is used.

## Binary Candidate

Optional compiled installer artifact that can launch the TUI without local compilation.

**Fields**:
- `pathOrURL`: local path or release URL for the candidate binary
- `architecture`: supported CPU architecture
- `version`: optional version or commit identifier
- `status`: `available`, `incompatible`, `missing`, or `failed`

**Validation rules**:
- An incompatible or missing binary must not block bootstrap when Go can run from source.
- Binary execution must use an explicit path; no shell interpolation.

## Launch Result

Outcome of starting the guided installer after prerequisites are prepared.

**Fields**:
- `method`: `prebuilt_binary` or `go_run`
- `fallbackUsed`: boolean indicating whether source execution replaced binary execution
- `message`: concise user-facing launch result

**Validation rules**:
- Failed prebuilt binary launch falls back to `go run` when Go is available.
- Launch failure must produce a non-zero exit and actionable message.

## Module

Repository area with setup, validation, or guidance behavior.

**Fields**:
- `id`: stable module id (`nvim`, `zsh`, `ghostty`, `tmux`, `keyboard`, `macos`)
- `name`: display name
- `sourcePaths`: repository files that define the module behavior
- `dependencyManifest`: optional TSV manifest path
- `validator`: optional validation command
- `linker`: optional config linker command
- `automationLevel`: `automatic`, `confirmation_required`, `report_only`, or `manual_only`
- `supportedFlows`: allowed top-level flows for the module

**Relationships**:
- A Module owns zero or more Action Plan steps.
- A Module contributes zero or more Report Items.

**Validation rules**:
- Module paths must be repository-relative in reports and docs.
- Modules without safe linkers must not expose config-link apply actions.

## Action Plan

Classified set of work prepared before execution.

**Fields**:
- `flow`: `install`, `sync`, or `upgrade`
- `modulePlans`: per-module planned steps
- `steps`: ordered Action Steps
- `requiresConfirmation`: boolean derived from mutating steps
- `manualGuidance`: manual-only instructions to show in the report
- `createdFromInventory`: list of scripts, manifests, and docs used to build the plan

**Validation rules**:
- Every step must be classified before display.
- Dry-run/report steps must appear before apply steps.
- Manual-only steps must never be converted into shell commands.

## Action Step

One planned validation, preview, apply, backup, sync, upgrade, or guidance item.

**Fields**:
- `id`: stable id within the plan
- `moduleId`: owning module id
- `kind`: `validate`, `dry_run`, `install`, `link`, `backup`, `remove`, `upgrade`, `sync`, or `manual_guidance`
- `classification`: `automatic`, `confirmation_required`, `dry_run_report_only`, or `manual_only`
- `command`: optional command argv for executable steps
- `description`: user-facing summary
- `expectedStatuses`: allowed result statuses

**Validation rules**:
- Steps with `classification = manual_only` must not have executable commands.
- Steps that may mutate local files must require confirmation.
- Existing link scripts must be invoked with their documented flags rather than bypassed.

## Managed Config Target

Local config path managed or inspected by the installer.

**Fields**:
- `moduleId`: owning module
- `targetPath`: local target path, displayed with `$HOME` where applicable
- `sourcePath`: repository source path
- `state`: `missing`, `repo_managed`, `unmanaged`, `broken_symlink`, or `unknown`
- `safeActions`: allowed next actions for this state

**Validation rules**:
- `unmanaged` and `broken_symlink` states must not be overwritten without explicit backup or
  recovery guidance.
- Removal may only target repository-managed links/files.

## Backup Record

Recoverable copy created before replacing user-owned config.

**Fields**:
- `moduleId`: owning module
- `sourceTarget`: original target path
- `backupPath`: backup path reported by the script
- `createdByStepId`: action step that created it
- `createdAt`: timestamp if available
- `restoreGuidance`: user-facing restore instruction

**Validation rules**:
- Backup records are created only from script output or confirmed planner state.
- A second run must not create a new backup when the target is already repository-managed.

## Installation Report

Final user-facing summary of the run.

**Fields**:
- `flow`: executed flow
- `items`: ordered Report Items
- `totals`: counts by status
- `backups`: Backup Records
- `manualNextSteps`: manual guidance that remains after the run
- `rawLogs`: optional raw command output grouped by step
- `exitCode`: final process exit code

**Validation rules**:
- Report totals must distinguish changed, unchanged, skipped, failed, backup, and manual items.
- A failed required validation or apply step must produce a non-zero exit code.
- Optional or manual-only missing items must be visible but non-blocking unless the plan marks
  them required.

## Report Item

One normalized result line in the Installation Report.

**Fields**:
- `moduleId`: owning module
- `stepId`: source action step
- `status`: `changed`, `unchanged`, `skipped`, `failed`, `optional`, `manual`, `managed`,
  `unmanaged`, `missing`, `backed_up`, or `removed`
- `message`: concise user-facing result
- `details`: optional troubleshooting or next-step text

**Validation rules**:
- `failed` items must include actionable details.
- `manual` items must include next-step guidance.
