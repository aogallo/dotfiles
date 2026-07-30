# Quickstart: Neovim Plugin Cleanup UI Validation

## Prerequisites

- Work from the repository root.
- Use the Neovim integration branch/final PR flow for this batch.
- Confirm issue #27 is approved before opening the final PR.

## Static Validation

Run formatting validation:

```sh
stylua --check nvim
```

Run Neovim startup validation:

```sh
nvim --headless -u nvim/init.lua '+quitall'
```

Confirm the cleanup command exists:

```sh
nvim --headless -u nvim/init.lua '+command PackClean' '+quitall'
```

## Candidate Review Validation

1. Start Neovim with the repository config.
2. Run `:PackClean`.
3. Confirm a floating review surface or documented fallback opens.
4. Confirm candidates show name, path, active state, lockfile state, and cleanup reason.
5. Confirm the empty state is clear when no candidates exist.

Expected result: the user does not need to know package directory names manually.

## Safe Deletion Validation

Use controlled test candidates or a temporary runtime setup.

Validate these cases:

- Inactive managed plugin candidate.
- Disk-only orphan under allowed package roots.
- Lockfile-only stale entry.
- Active plugin that must be excluded.
- Missing directory.
- Unsafe path outside allowed roots.

Expected result: unsafe paths are blocked, active plugins are excluded, and every processed candidate appears in a report category.

Automatable helper coverage can exercise disk-only removal, lockfile-only removal, active blocking,
missing paths, unsafe paths, and repeated execution against temporary paths. Inactive managed
plugin deletion and the Snacks multi-select flow should be validated manually in a disposable
Neovim runtime because they depend on live `vim.pack` state and an interactive picker.

## Lockfile Validation

1. Create or simulate a stale lockfile entry.
2. Open cleanup review.
3. Confirm stale metadata appears separately from disk cleanup.
4. Confirm cleanup only mutates the lockfile after user confirmation.
5. Confirm the lockfile remains valid JSON.

Expected result: lockfile cleanup is explicit and reviewable.

## Repeated Run Validation

1. Run cleanup and confirm selected removals.
2. Run cleanup again.

Expected result: the second run reports no duplicate removals and no stale UI state.

## Reporting Validation

After cleanup, confirm the report includes:

- Removed items.
- Skipped items.
- Blocked items.
- Not-found items.
- Errors, if any.

Expected result: cleanup outcome is understandable without reading source code.

## Documentation Validation

Confirm `nvim/README.md` documents:

- How to open plugin cleanup.
- What candidate states mean.
- Safety boundaries.
- Lockfile cleanup behavior.
- Validation commands.
- Rollback/recovery steps.

## Rollback Validation

If cleanup behavior must be reverted:

1. Restore prior plugin config or lockfile entries from version control.
2. Re-run startup validation.
3. Reinstall removed plugins through normal Neovim package loading if needed.
4. Confirm `:PackClean` still resolves to the intended user-facing workflow.
