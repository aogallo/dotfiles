# Contract: Repository Organization and Optional Dependency Validation

## Keyboard Configuration Contract

### Before

- `iris_rev__5.json` exists at repository root.

### After

- `keyboard/iris_rev__5.json` is the only active Iris Rev. 5 keyboard JSON in the repository.
- `keyboard/README.md` explains what the file is for and how to use or roll back the location.
- The root-level `iris_rev__5.json` path no longer exists as an active duplicate.

### Validation

- JSON parses successfully.
- `name`, `vendorProductId`, `macros`, `layers`, and `encoders` remain present.
- Content comparison proves the move did not alter keyboard data.

## Optional Dependency Contract

### Required Behavior

- `setup/validate-nvim-deps.sh` exits successfully when all required dependencies exist, even if optional dependencies are missing.
- Missing optional `shfmt` and `shellcheck` entries are visibly reported as optional.
- Output includes source, usage, and install guidance for each missing optional tool.

### User Resolution Path

- A user who wants no optional warnings can find the install path from documentation or validation output.
- A user who does not need optional tools can leave them absent without blocking validation.

### Validation

- Run dependency validation and confirm required missing count is zero.
- Run bootstrap dry-run with optional dependencies included and confirm it previews optional tooling without installing by default.
