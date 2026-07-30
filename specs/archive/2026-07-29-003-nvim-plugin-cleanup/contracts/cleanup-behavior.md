# Cleanup Behavior Contract: Neovim Plugin Cleanup UI

## Scope

This contract defines observable behavior for reviewing and cleaning stale Neovim plugin state.

## Candidate Discovery

- The cleanup workflow discovers inactive managed plugins from current package state.
- The workflow discovers stale lockfile entries that are no longer active.
- The workflow may discover disk-only plugin directories when they can be safely associated with managed package roots.
- Active plugins are never offered as deletion targets.

## Review UI

- `:PackClean` opens a review surface instead of immediately deleting candidates.
- Candidates show name, path, active/inactive status, lockfile status, and cleanup reason.
- Empty state clearly reports that no cleanup is needed.
- The user can select one or more candidates without typing disk directory names manually.

## Confirmation and Deletion

- No disk deletion occurs before explicit confirmation.
- Every deletion target is path-boundary validated before removal.
- Paths outside allowed Neovim package roots are blocked and reported.
- Managed inactive plugins should be removed through the package manager deletion API when possible.
- Lockfile-only cleanup is explicit and reviewable.

## Reporting

- Every cleanup run reports removed, skipped, blocked, and not-found categories.
- Errors include actionable messages.
- Re-running cleanup after successful removal does not report duplicate removals.

## Replacement Cleanup

- If this workflow replaces the old inline `PackClean` implementation, the old inline implementation must be removed or redirected in the same work unit.
- If any custom fallback remains, it must be documented with rationale and activation conditions.

## Approval Gate

- Final PR must not be opened until issue #27 has the required approval label or the maintainer explicitly resolves that workflow blocker.
