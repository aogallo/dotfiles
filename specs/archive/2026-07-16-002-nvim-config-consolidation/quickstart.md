# Quickstart: Validate Neovim Config Consolidation

Use this guide to validate each work unit and the final integration branch. Run commands from the repository root.

## Prerequisites

- Active integration branch: `feat/nvim-config-consolidation`
- Work-unit branches are based on `feat/nvim-config-consolidation`
- Neovim is installed
- `stylua` is installed for Lua formatting checks

## 1. Confirm Branch Topology

```bash
git branch --show-current
```

Expected result for integration work:

```text
feat/nvim-config-consolidation
```

Expected result for a work unit:

```text
feat/nvim-options-consolidation
feat/nvim-keymaps-consolidation
feat/nvim-plugins-consolidation
chore/nvim-legacy-cleanup
```

## 2. Validate Options Work Unit

Review source material:

```bash
git diff -- nvim/lua/config/options.lua lvim/config.lua kickstart.nvim/lua/config/options.lua lazyvim/lua/config/options.lua
```

Run formatting for touched Lua files:

```bash
stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml
```

Expected result:

- Adopted options have documented workflow value.
- Existing canonical behavior is preserved unless deliberately changed.
- No user-specific absolute paths or secrets are introduced.

## 3. Validate Keymaps Work Unit

Review keymap changes:

```bash
git diff -- nvim/lua/config/keymaps.lua lvim/config.lua kickstart.nvim/lua/config/keymaps.lua lazyvim/lua/config/keymaps.lua
```

Run formatting for touched Lua files:

```bash
stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml
```

Expected result:

- Every added or changed mapping has a clear purpose.
- Conflicts with existing canonical mappings are resolved explicitly.
- No unrelated plugin or cleanup changes are included.

## 4. Validate Plugins Work Unit

Review plugin, LSP, and dependency changes:

```bash
git diff -- nvim/plugin nvim/lsp nvim/dependencies.tsv kickstart.nvim/lua/custom/plugins lazyvim/lua/plugins lvim/config.lua
```

Run formatting for touched Lua files:

```bash
stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml
```

Run a targeted Neovim smoke check:

```bash
nvim --headless '+quitall'
```

Expected result:

- Adopted plugins have a documented purpose.
- Duplicate plugin responsibilities are avoided.
- New required or optional tools are reflected in `nvim/dependencies.tsv`.
- Startup completes without configuration errors.

## 5. Validate Cleanup Work Unit

Review cleanup changes:

```bash
git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation
```

Expected result:

- Cleanup includes the already-deleted files when appropriate: `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, and `lazyvim/ftplugin/json.lua`.
- Cleanup happens only after relevant migration decisions are recorded.
- `nvim/` remains the clear source of truth.
- Deleted legacy material is recoverable through Git history.

## 6. Validate Final Integration Branch

Run final checks from `feat/nvim-config-consolidation`:

```bash
git branch --show-current
stylua --check nvim/lua nvim/plugin nvim/lsp --config-path nvim/stylua.toml
nvim --headless '+quitall'
git status --short
```

Expected result:

- Branch is `feat/nvim-config-consolidation`.
- Formatting passes for canonical Neovim Lua files.
- Neovim starts headlessly without configuration errors.
- Worktree contains only intentional consolidation changes.

## 7. PR Closure Check

Before opening the final PR from `feat/nvim-config-consolidation` to `main`:

- Confirm the PR scope relates to `specs/002-nvim-config-consolidation/`.
- Ask whether the spec should be archived if the PR completes the consolidation.
- Link the required approved issue if repository workflow requires it.
