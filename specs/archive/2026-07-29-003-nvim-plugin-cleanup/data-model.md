# Data Model: Neovim Plugin Cleanup UI

## Plugin Candidate

Represents a plugin that may need cleanup review.

**Fields**:

- `name`: display name from package metadata, lockfile entry, or inferred directory.
- `source`: repository/source URL when known.
- `path`: resolved local disk path when present.
- `active`: whether current `vim.pack` state marks the plugin active.
- `installed`: whether the plugin directory exists on disk.
- `lockfile_present`: whether the plugin appears in `nvim/nvim-pack-lock.json`.
- `candidate_type`: inactive-managed, disk-only, lockfile-only, missing, blocked, or active.
- `reason`: human-readable explanation for why it appears or is blocked.

**Validation rules**:

- Active plugins are never deletable candidates.
- Candidates must not require the user to know the disk directory name.
- Candidate display must include enough context to identify the plugin safely.

## Active Plugin Set

Represents repository-managed plugins active in the current session.

**Fields**:

- `names`: active plugin names from current package state.
- `sources`: source URLs for active plugins where available.
- `paths`: local paths for active plugins where available.

**Validation rules**:

- Any plugin in this set is excluded from deletion.
- Lockfile entries matching this set are not stale.

## Installed Plugin Path

Represents a local package directory.

**Fields**:

- `raw_path`: path reported or discovered.
- `resolved_path`: normalized path after resolving symlinks/relative components.
- `inside_boundary`: whether the path is under an allowed Neovim package root.
- `exists`: whether the directory currently exists.

**Validation rules**:

- Deletion requires `inside_boundary = true`.
- Missing paths are reported as not found, not treated as successful deletion.

## Lockfile Entry

Represents committed plugin revision metadata.

**Fields**:

- `name`: lockfile plugin key.
- `source`: recorded source URL.
- `revision`: recorded revision.
- `active_match`: whether active plugin state still references this entry.
- `installed_match`: whether a local plugin path still exists for this entry.

**Validation rules**:

- Active matches are not stale.
- Stale entries are removed only after confirmation.
- Lockfile updates must remain valid JSON.

## Cleanup Selection

Represents the user-approved set of cleanup targets.

**Fields**:

- `selected_candidates`: candidates selected for disk cleanup and/or lockfile cleanup.
- `confirmed`: whether the user confirmed destructive actions.
- `dry_run`: whether the selection is preview-only.

**Validation rules**:

- Destructive cleanup requires confirmation.
- Unsafe candidates cannot be promoted to selected deletion targets.

## Cleanup Report

Represents final cleanup results.

**Fields**:

- `removed`: plugin directories or lockfile entries removed.
- `skipped`: candidates intentionally skipped.
- `blocked`: candidates blocked by safety validation.
- `not_found`: requested targets no longer present.
- `errors`: cleanup failures with messages.

**Validation rules**:

- Every candidate processed appears in exactly one result category.
- Repeated runs after successful cleanup must not report duplicate removals.

## Safety Boundary

Represents allowed root directories for deletion.

**Fields**:

- `roots`: allowed Neovim package root directories discovered at runtime.
- `description`: user-facing explanation of the allowed cleanup scope.

**Validation rules**:

- Paths outside roots are blocked.
- Boundary values are runtime context and should not be committed as user-specific paths.
