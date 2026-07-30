# Mapping Behavior Contract: Neovim Treesitter Textobjects

## Scope

This contract defines observable keymap behavior for Treesitter textobjects, incremental selection, structural movement, and optional swap behavior.

## Semantic Selection

- `af` selects the outer function region where supported.
- `if` selects the inner function region where supported.
- `ac` selects the outer class/type/equivalent region where supported.
- `ic` selects the inner class/type/equivalent region where supported.
- `ao` selects an outer comment region where supported.
- `as` selects local scope where supported.
- Unsupported captures fail safely and do not break native editing behavior.

## Incremental Selection

- A documented start mapping initializes selection at the nearest meaningful syntax node.
- A documented expand mapping grows selection to parent syntax nodes.
- A documented shrink mapping returns to the previous smaller node.
- Selection must expand through at least 3 nested levels in validated fixtures.

## Native Textobject Preservation

- Native parenthesis textobjects such as `a(`, `i(`, `ca(`, and `va(` remain available.
- Treesitter semantic textobjects do not claim to replace delimiter-based edits.
- Documentation must explain the practical distinction using the Go const-block scenario.

## Structural Movement

- Movement mappings may navigate between functions/classes/types if conflict review passes.
- Movement should set jumps when practical so users can return with normal jump navigation.
- Unsupported captures must not error during normal editing.

## Structural Swap

- Swap mappings may be enabled for parameters only after fixture validation proves syntax-safe behavior.
- If swap validation is brittle, swap mappings should be deferred and documented as out of initial scope.

## Documentation and Validation

- All enabled mappings must appear in `nvim/README.md`.
- Validation must include Go and Lua or TypeScript fixtures.
- Validation must confirm no keymap conflicts with existing repository-managed Neovim mappings.
