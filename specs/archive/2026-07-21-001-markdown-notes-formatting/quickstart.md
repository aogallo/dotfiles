# Quickstart: Markdown Notes Formatting

## Prerequisites

- Run from the repository root.
- Use temporary directories outside the repository for smoke tests.
- Do not write test notes into the real notes vault.

## Static Validation

1. Format Lua config:

   ```sh
   stylua --check nvim
   ```

2. Startup smoke test:

   ```sh
   nvim --headless -u nvim/init.lua '+quitall'
   ```

3. Dependency validation:

   ```sh
   setup/validate-nvim-deps.sh
   ```

## Manual/Headless Smoke Scenarios

### Scenario 1: Notes-Only Markdown Folder

1. Create a temporary folder with only `note.md`.
2. Open Neovim in that folder with this config.
3. Save `note.md`.

**Expected**: Save completes with zero Prettier/no-formatter error notifications. Safe whitespace cleanup may run.

### Scenario 2: Obsidian-Style Vault Folder

1. Create a temporary folder with `note.md` and a vault-local settings directory.
2. Open Neovim in that folder with this config.
3. Save `note.md`.

**Expected**: Save completes without requiring package manifests or formatter config.

### Scenario 3: Project Markdown Folder

1. Create a temporary project folder with a Markdown file and explicit formatter configuration.
2. Open Neovim in that folder with this config.
3. Save the Markdown file.

**Expected**: Project Markdown formatting remains available and is attempted before fallback behavior.

### Scenario 4: Autoformat Disabled

1. Open a Markdown file.
2. Disable global autoformat using the existing config mechanism.
3. Save the file.

**Expected**: No formatter runs, preserving the current global autoformat behavior.

### Scenario 5: Repeated Saves

1. Save the same notes-only Markdown file repeatedly.
2. Observe notifications and formatting behavior.

**Expected**: No accumulating warnings, duplicate messages, or repeated setup side effects appear.

## Rollback

Rollback is a normal repository revert of the Neovim formatting configuration and documentation changes. Notes folders do not need cleanup because the configuration must not create project tooling files in them.

## PR Readiness Gate

This apply run does not create a pull request. Before PR creation, review `spec.md`, confirm the PR scope is related to this active spec, and ask whether the completed PR should close/archive `001-markdown-notes-formatting`.
