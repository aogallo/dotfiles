# Data Model: Neovim Config Consolidation

## Canonical Neovim Config

**Description**: The maintained `nvim/` configuration that receives adopted behavior.

**Fields**:

- `root_path`: `nvim/`
- `options_path`: `nvim/lua/config/options.lua`
- `keymaps_path`: `nvim/lua/config/keymaps.lua`
- `plugin_paths`: `nvim/plugin/*.lua`
- `lsp_paths`: `nvim/lsp/*.lua`
- `dependency_inventory`: `nvim/dependencies.tsv`

**Validation Rules**:

- Must remain the only maintained Neovim target after consolidation.
- Must not contain user-specific absolute paths, secrets, or local-only state.
- Must keep options, keymaps, plugins, LSP, and dependency declarations inspectable by responsibility.

## Legacy Neovim Config

**Description**: A non-canonical config used as source material or cleanup scope.

**Fields**:

- `name`: `lvim`, `kickstart.nvim`, or `lazyvim`
- `source_paths`: option, keymap, plugin, ftplugin, doc, and framework-specific files
- `status`: `source-material`, `partially-reviewed`, `ready-for-cleanup`, or `archived`

**Validation Rules**:

- Must not remain a maintained target after cleanup.
- Must not be deleted until relevant migration decisions are recorded.
- Must be recoverable through Git history after cleanup.

## Workstream

**Description**: A reviewable unit of consolidation work.

**Fields**:

- `name`: `options`, `keymaps`, `plugins`, or `cleanup`
- `branch`: work-unit branch name
- `base_branch`: `feat/nvim-config-consolidation`
- `target_branch`: `feat/nvim-config-consolidation`
- `scope_paths`: repository paths allowed for the unit
- `validation`: checks required before merge
- `dependencies`: earlier workstreams that must complete first

**Validation Rules**:

- Must have one clear purpose.
- Must be independently reviewable.
- Must include validation evidence before merge.
- Cleanup depends on recorded decisions from options, keymaps, and plugins.

## Migration Decision

**Description**: A recorded choice about behavior found in a legacy config.

**Fields**:

- `source_config`: legacy config path where the behavior was found
- `target_area`: options, keymaps, plugins, LSP, dependencies, docs, or cleanup
- `decision`: `adopt`, `reject`, or `defer`
- `rationale`: reason for the decision
- `dependency_impact`: none, optional dependency, required dependency, or removed dependency
- `validation`: how the decision is verified

**Validation Rules**:

- Adopted behavior must identify user value and target path.
- Rejected behavior must explain why it does not belong in `nvim/`.
- Deferred behavior must identify what future information is needed.

## Dependency Declaration

**Description**: A reviewable dependency required or optionally used by canonical Neovim behavior.

**Fields**:

- `name`
- `executable`
- `required`
- `source`
- `install_hint`
- `used_by`

**Validation Rules**:

- Must be represented in `nvim/dependencies.tsv` when canonical behavior depends on it.
- Optional tools must not block unrelated editor startup.
- Required tools must have clear install hints.

## State Transitions

```text
legacy behavior discovered
  -> migration decision recorded
  -> adopted into nvim OR rejected OR deferred
  -> validation evidence captured
  -> legacy source eligible for cleanup when all relevant decisions are complete
```

```text
workstream branch created from feat/nvim-config-consolidation
  -> scoped implementation completed
  -> validation completed
  -> merged into feat/nvim-config-consolidation
  -> final integration branch verified
  -> integration PR targets main
```
