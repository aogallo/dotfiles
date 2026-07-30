# Data Model: Neovim Treesitter Textobjects

## Semantic Textobject

Represents a syntax-aware selectable code region.

**Fields**:

- `mapping`: key sequence used in visual/operator-pending mode.
- `capture`: Treesitter capture name such as function outer, function inner, class/type outer, comment outer, parameter inner, or local scope.
- `query_group`: query source such as textobjects or locals.
- `selection_mode`: characterwise, linewise, or blockwise selection behavior.
- `supported_filetypes`: filetypes where validation confirms useful behavior.
- `fallback_behavior`: expected result when the capture is unavailable.

**Validation rules**:

- Mapping must not conflict with existing repository-managed keymaps.
- Missing captures must fail safely.
- Native punctuation textobjects must remain unaffected.

## Incremental Selection Session

Represents structural selection that starts at the cursor and expands/shrinks through syntax nodes.

**Fields**:

- `start_mapping`: mapping that initializes selection.
- `expand_mapping`: mapping that expands to a larger syntax node.
- `shrink_mapping`: mapping that returns to the previous node.
- `active_node_stack`: conceptual selection history during the session.
- `supported_filetypes`: filetypes where validation confirms useful behavior.

**Validation rules**:

- Must expand through at least 3 nested syntax levels in validated fixtures.
- Must shrink back to a previously selected node.
- Must not leave selection in a broken state when no parent node exists.

## Structural Movement

Represents navigation between semantic units.

**Fields**:

- `mapping`: movement key sequence.
- `direction`: next or previous.
- `boundary`: start or end.
- `capture`: function/class/type or equivalent capture.
- `sets_jump`: whether movement records the jump in jumplist.

**Validation rules**:

- Must move to expected neighboring semantic units in fixtures.
- Must not override existing important motions without explicit documentation.
- Unsupported captures must not create errors during normal editing.

## Structural Swap

Represents an edit that swaps adjacent semantic units.

**Fields**:

- `mapping`: swap key sequence.
- `direction`: next or previous.
- `capture`: usually parameter inner or outer.
- `supported_filetypes`: filetypes where syntax remains valid after swap.

**Validation rules**:

- Must preserve syntactic validity in supported fixtures.
- Must not perform destructive edits when no adjacent node exists.
- Should be omitted if validation is brittle.

## Language Query Support

Represents parser/query capability for a filetype.

**Fields**:

- `filetype`: target filetype.
- `parser_available`: whether a parser is installed/configured.
- `textobjects_available`: whether relevant textobject captures exist.
- `locals_available`: whether locals/scope captures exist.
- `known_limitations`: documented unsupported captures or behaviors.

**Validation rules**:

- At least Go plus Lua or TypeScript must be validated.
- Unsupported captures must be documented rather than treated as implementation failures.

## Mapping Contract

Represents the agreed keymap behavior for this feature.

**Fields**:

- `selection_mappings`: semantic selection mappings.
- `incremental_mappings`: structural expand/shrink mappings.
- `movement_mappings`: optional navigation mappings.
- `swap_mappings`: optional swap mappings.
- `native_mappings_preserved`: native punctuation mappings verified as unchanged.

**Validation rules**:

- Must be documented in `nvim/README.md`.
- Must be linked from tasks back to spec user stories.
- Must be validated before final PR.
