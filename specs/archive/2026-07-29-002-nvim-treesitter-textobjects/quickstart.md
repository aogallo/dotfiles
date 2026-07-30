# Quickstart: Neovim Treesitter Textobjects Validation

## Prerequisites

- Work from the repository root.
- Use the Neovim integration branch/final PR flow for the batch of Neovim specs.
- Confirm issue #48 remains approved before opening the final PR.

## Static Validation

Run formatting validation:

```sh
stylua --check nvim
```

Run Neovim startup validation:

```sh
nvim --headless -u nvim/init.lua '+quitall'
```

Run Treesitter health validation:

```sh
nvim --headless -u nvim/init.lua '+checkhealth nvim-treesitter' '+quitall'
```

Validate configured parser commands still exist and run:

```sh
nvim --headless -u nvim/init.lua '+TSInstallConfigured' '+quitall'
nvim --headless -u nvim/init.lua '+TSUpdateConfigured' '+quitall'
```

## Fixture Setup

Use at least these fixture categories:

- Go fixture with a const block, functions, parameters, and comments.
- Lua or TypeScript fixture with nested functions/classes/types, parameters, and comments.

Fixtures should live under `specs/002-nvim-treesitter-textobjects/fixtures/` so they can be reviewed and archived with the spec.

## Semantic Selection Validation

1. Open the Go fixture.
2. Validate function outer and inner selections.
3. Validate comment selection where supported.
4. Validate class/type/equivalent selection where supported.
5. Repeat in the Lua or TypeScript fixture.

Expected result: at least 4 semantic selection mappings work in validated supported filetypes.

## Incremental Selection Validation

1. Place the cursor inside a nested expression or statement.
2. Start incremental selection.
3. Expand selection through at least 3 syntax levels.
4. Shrink selection back to a smaller node.

Expected result: selection grows and shrinks predictably without stale selection state.

## Native Textobject Preservation Validation

1. Open a Go const block wrapped in parentheses.
2. Run native parenthesis textobject workflows such as selecting/changing inside parentheses.
3. Confirm existing behavior still works.
4. Compare semantic textobject behavior and document whether it is complementary, better, or unsupported for that structure.

Expected result: native delimiter-based edits remain the right tool for delimiter content and are not broken by semantic textobjects.

## Movement and Swap Validation

1. Validate movement between functions/classes/types only if mappings are enabled.
2. Validate parameter swap only if mappings are enabled.
3. Confirm syntax remains valid after swap in supported fixtures.
4. Confirm unsupported captures fail safely.

Expected result: optional movement/swap mappings are enabled only when reliable.

## Keymap Conflict Validation

Review existing repository-managed mappings and validate that newly enabled mappings do not conflict with important existing behavior.

Expected result: any intentional overlap is documented; accidental conflicts block completion.

## Documentation Validation

Confirm `nvim/README.md` documents:

- Semantic textobject mappings.
- Incremental selection mappings.
- Optional movement/swap mappings if enabled.
- Native punctuation textobject preservation.
- Validation commands.
- Rollback instructions.

## Rollback Validation

If the feature must be reverted:

1. Disable/remove the textobjects plugin entry and related mappings.
2. Remove stale lockfile entry if applicable.
3. Re-run static validation.
4. Confirm native textobjects and parser install/update commands still work.
