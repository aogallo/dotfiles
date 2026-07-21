# Quickstart: Obsidian Title-Based Filenames

## Prerequisites

- Run commands from the repository root.
- Neovim dependencies should be available as documented in `nvim/README.md` and `nvim/dependencies.tsv`.
- Set `OBSIDIAN_NOTES_DIR` to a temporary test vault if you do not want smoke-test notes in the default notes directory.

## Static Validation

1. Format check:

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

## Manual Validation Scenarios

### Scenario 1: Title-Based Filename From Command

1. Open Neovim with this config.
2. Run `:Obsidian new AWS CodePipeline`.
3. Inspect the created file path or notes directory listing.

**Expected**: The created Markdown filename contains recognizable title words such as `AWS`/`CodePipeline` or their normalized slug form. It must not start with an unrelated opaque value like `1784601236-HVCC`.

### Scenario 2: Title-Based Filename From Keymap

1. Open key discovery for `<leader>n`.
2. Confirm the group label is `notes`.
3. Trigger `<leader>nn`, enter `AWS CodePipeline`, and inspect the created filename.

**Expected**: The mapping is discoverable as `New note` and produces the same filename behavior as the command flow.

### Scenario 3: Duplicate Title Safety

1. Create a note titled `AWS CodePipeline`.
2. Create a second note with the same title.
3. Inspect both filenames.

**Expected**: Both files exist, neither is overwritten, and the second filename remains readable with a distinct suffix.

### Scenario 4: No-Title Fallback

1. Run `:Obsidian new` without a title.
2. Inspect whether a note is created or whether the plugin reports a clear fallback/error.

**Expected**: Neovim does not crash. The plugin either creates a safe fallback note or reports an understandable error through its normal command behavior.

### Scenario 5: Repeated Load/Idempotency

1. Restart Neovim or source the relevant config repeatedly during development.
2. Open key discovery for `<leader>n`.
3. Trigger the new note action once.

**Expected**: The notes group and mapping appear once, and note creation runs once.

## Rollback

Rollback is a normal repository revert of the Neovim configuration changes. Existing notes created during validation are user vault content and can be removed manually if they were test notes.
