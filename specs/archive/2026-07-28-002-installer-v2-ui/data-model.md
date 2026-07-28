# Data Model: Installer V2 UI and Install Flow

## Install Session

Represents one installer run.

**Fields**: selected flow, current screen, terminal width/height, confirmation state, current step index, total steps, active step ID, cancelled flag, exit code, plan, progress records, report.

**Validation**: One active flow at a time. Mutating execution cannot start without a built plan and explicit confirmation.

**States**: main menu -> module list -> action plan -> confirmation -> running -> report -> exit. Cancellation before confirmation exits without changes; cancellation during running records completed and incomplete work.

## Install Step

Represents an ordered unit of installer work from `installer.Action`.

**Fields**: ID, module ID, kind, classification, command argv, description, expected statuses, started time, completed time, result status, output summary.

**Validation**: Step IDs are unique within a plan. Mutating kinds require confirmation. Manual-only steps must not have commands. Command-backed steps must use approved repository-relative commands.

**States**: pending -> active -> succeeded | skipped | manual | failed | cancelled.

## Configuration Item

Represents a managed local configuration target.

**Fields**: module ID, source path, target path, ownership state, safe actions.

**Validation**: Source paths stay inside the repository. Target paths are user-local config paths. Unknown or unmanaged states cannot be overwritten without backup or manual review.

**States**: missing, repo-managed, unmanaged, broken symlink, unknown.

## Tool Item

Represents a dependency/tool surfaced by module manifests or command output.

**Fields**: name, executable, required flag, source, install hint, used-by module, current status.

**Validation**: Required missing tools must be visible before mutating install. Optional/manual tools must not block unrelated completed work unless the owning step fails.

**States**: missing, installing, installed, upgraded, optional, manual, failed, skipped.

## Backup Record

Represents a recoverable backup made before changing a user-owned file.

**Fields**: module ID, original target path, backup path, creating step ID, creation time, restore guidance.

**Validation**: Backup path must be distinct and must not overwrite an existing backup. Backup records must appear in the final report.

**States**: planned, created, failed, restore-documented.

## UI Status

Represents the user-facing state shown in lists, progress areas, and reports.

**Fields**: canonical status, text label, color role, optional emoji, severity, fallback label.

**Validation**: Text label is required. Emoji is optional and never the only status indicator.

## Final Report

Represents the end-of-run summary.

**Fields**: flow, item list, totals, backups, manual next steps, raw logs, exit code.

**Validation**: Every planned step must be accounted for as completed, changed, backed up, skipped, manual, cancelled, or failed. Secret values must not be displayed.
