# Data Model: Neovim Keymap Reorganization

## Entity: Keymap

Represents one user-facing shortcut binding.

**Fields**:

- `mode`: Vim mode or modes where the binding applies.
- `current_trigger`: Existing shortcut before implementation.
- `proposed_trigger`: Approved shortcut after implementation, if moved.
- `action`: User-facing behavior invoked by the shortcut.
- `description`: Discovery label shown to the user.
- `scope`: Global, buffer-local, plugin-local, or panel-local.
- `source_file`: Repository file where the keymap is defined.
- `status`: `move`, `preserve`, `context-local`, or `remove-old`.

**Validation Rules**:

- A keymap must have a clear user-facing action.
- A moved keymap must have both current and proposed triggers.
- No two active keymaps may share the same `mode` and `proposed_trigger` unless their scopes cannot overlap.
- Buffer-local and panel-local mappings must not be converted to global mappings unless the behavior is valid globally.

## Entity: Keymap Group

Represents a semantic top-level leader namespace.

**Fields**:

- `prefix`: Top-level leader prefix such as `<leader>g`.
- `label`: Discovery group name such as `git`.
- `domain`: User intent covered by the group.
- `examples`: Representative actions in the group.

**Validation Rules**:

- Every top-level leader prefix used by moved mappings must have a matching discovery group.
- Group labels must describe user intent, not plugin implementation.
- Existing groups must be updated rather than duplicated.

## Entity: Mapping Migration

Represents an approved movement from one shortcut to another.

**Fields**:

- `from`: Current shortcut.
- `to`: Proposed shortcut.
- `reason`: Why the new group is more intuitive.
- `compatibility_impact`: Expected muscle-memory impact.
- `verification`: Manual or automated check that proves the action still works.

**Validation Rules**:

- The old mapping should not remain active unless explicitly kept as a compatibility alias.
- Compatibility aliases are not planned by default because the user approved reorganization rather than a transition layer.
- Each migration must be reflected in discovery labels where applicable.

## Entity: Preserved Mapping

Represents an intentionally unchanged binding.

**Fields**:

- `trigger`: Existing shortcut.
- `reason`: Native convention, high-frequency motion, insert workflow, or context-local UI.
- `source_file`: Where the mapping remains defined.

**Validation Rules**:

- Preserved mappings must remain functional after implementation.
- Preserved mappings should not be re-advertised under leader groups unless a separate action exists.

## State Transitions

- `proposed` -> `approved`: User approves the mapping proposal.
- `approved` -> `implemented`: Keymap source files are edited.
- `implemented` -> `verified`: Syntax/config load and smoke checks pass.
- `implemented` -> `rolled-back`: Git revert restores previous keymap behavior if validation fails.
