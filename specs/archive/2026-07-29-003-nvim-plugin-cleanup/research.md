# Research: Neovim Plugin Cleanup UI

## Decision: Preserve `PackClean` as the user-facing command and replace its internals

**Rationale**: `:PackClean` already exists and describes the desired workflow. Keeping the name preserves discoverability while allowing the implementation to add candidate review, path safety, confirmation, lockfile cleanup, and richer reporting.

**Alternatives considered**:

- **Create a separate command only**: Rejected because it leaves the old incomplete cleanup behavior around.
- **Delete `PackClean` without replacement**: Rejected because users already have a cleanup command entrypoint.

## Decision: Move cleanup logic into a dedicated module

**Rationale**: `nvim/lua/config/autocmds.lua` currently embeds destructive cleanup behavior directly in command registration. A dedicated module keeps detection, selection, deletion, lockfile changes, and reporting testable and easier to reason about.

**Alternatives considered**:

- **Keep everything in `autocmds.lua`**: Rejected as too hard to test and maintain.
- **Put cleanup into `vim-pack.lua`**: Rejected initially because `vim-pack.lua` is a generic helper for adding/configuring plugins. Cleanup has UI, reporting, and safety semantics that should not pollute the helper.

## Decision: Use `vim.pack.get()` and `vim.pack.del()` as primary managed-plugin APIs

**Rationale**: Neovim documents `vim.pack.get()` as returning managed plugin info including path, revision, and active status, and `vim.pack.del()` as removing managed plugins from disk by name. These are the right primitives for managed inactive plugins.

**Alternatives considered**:

- **Manual filesystem deletion first**: Rejected for managed plugins because it bypasses the package manager and increases safety risk.
- **Shell script only**: Rejected because the user wants an in-editor floating review workflow and live Neovim package context.

## Decision: Use Snacks picker as the preferred floating review UI

**Rationale**: Snacks is already installed and active in this repo. Its picker provides an existing floating UI pattern consistent with current configuration, avoiding a new dependency or plugin manager just for review UI.

**Alternatives considered**:

- **Mason-style custom floating buffer from scratch**: Deferred. Useful fallback if Snacks picker cannot support selection/preview needs, but more custom code.
- **Lazy.nvim UI**: Rejected because the repo does not use Lazy.nvim and should not switch plugin managers for cleanup UX.
- **Command-line prompts only**: Rejected because they do not solve discoverability or the user's desire for a visual list.

## Decision: Treat lockfile cleanup as explicit metadata cleanup, not automatic side effect

**Rationale**: The lockfile is committed source-of-truth metadata. Removing stale entries should be visible and reviewable. Candidate classification should distinguish disk cleanup from lockfile-only cleanup.

**Alternatives considered**:

- **Always rewrite lockfile automatically**: Rejected because it can create surprising review diffs.
- **Never touch lockfile**: Rejected because stale entries are part of the reported pain.

## Decision: Enforce strict safety boundaries before deletion

**Rationale**: Cleanup deletes files. Every path must resolve under allowed Neovim package roots and must belong to an inactive candidate. Unsafe paths are blocked and reported.

**Alternatives considered**:

- **Trust `vim.pack.del()` only**: Insufficient for disk-only or lockfile-only review cases and does not give the user enough visibility.
- **Allow force deleting active plugins**: Rejected. Active plugins must never be offered as cleanup candidates.

## Decision: Block final PR until issue #27 is approved

**Rationale**: Repository workflow requires approved issues before PRs. Issue #27 is currently open without `status:approved`.

**Alternatives considered**:

- **Proceed to PR without approval**: Rejected as workflow violation.
- **Skip planning**: Rejected. Planning/spec work can proceed and exposes the approval blocker early.
