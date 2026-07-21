# Data Model: Organize Keyboard and Optional Dependencies

## Optional Shell Tooling

**Fields**

- `name`: Human-readable tool name.
- `executable`: Command checked by validation.
- `required`: Whether missing status blocks validation.
- `source`: Supported installation source.
- `install_hint`: User-facing resolution path.
- `used_by`: Repository files or features that use the tool.

**Validation Rules**

- `shfmt` and `shellcheck` remain optional unless policy changes explicitly.
- Missing optional tools must not cause required dependency validation failure.
- Each optional missing tool must show an actionable install hint.

## Iris Keyboard Configuration

**Fields**

- `name`: Keyboard display name.
- `vendorProductId`: VIA device identifier.
- `macros`: Existing macro definitions.
- `layers`: Existing keymap layers.
- `encoders`: Existing encoder definitions.

**Validation Rules**

- The active file lives under `keyboard/` after implementation.
- The root-level `iris_rev__5.json` active copy is removed.
- JSON content remains valid and semantically unchanged.

## Keyboard Configuration Folder

**Fields**

- `path`: Repository-relative folder path.
- `purpose`: Keyboard configuration asset storage.
- `documents`: README or discoverability note.

**Validation Rules**

- Folder must be repository-managed and portable.
- Folder documentation must point users to the Iris JSON file and rollback approach.

## Dependency Validation Result

**Fields**

- `required_missing_count`: Count of required missing tools.
- `optional_missing_count`: Count of optional missing tools.
- `status`: Blocking or non-blocking outcome.
- `messages`: User-facing output with install hints.

**State Transitions**

- Optional missing -> Optional installed when user installs the tool.
- Required pass remains pass as long as `required_missing_count` is zero.
- Optional missing remains non-blocking unless repository policy changes.
