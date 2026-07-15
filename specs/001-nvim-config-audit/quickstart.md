# Quickstart: Validate the Neovim Config Audit Plan

## Prerequisites

- Repository root: `/Users/allan/dotfiles`
- Active feature directory: `specs/001-nvim-config-audit`
- Neovim available on the machine, ideally matching the requested target version v0.12.1
- Network access for documentation lookup and plugin/dependency validation when needed

## Validation Path

1. Confirm the feature artifacts exist:

   ```sh
   test -f specs/001-nvim-config-audit/spec.md
   test -f specs/001-nvim-config-audit/plan.md
   test -f specs/001-nvim-config-audit/research.md
   test -f specs/001-nvim-config-audit/data-model.md
   test -f specs/001-nvim-config-audit/contracts/audit-report.md
   ```

2. Confirm the audit scope can be discovered:

   ```sh
   test -f nvim/init.lua
   test -d nvim/lua
   test -d nvim/plugin
   test -d nvim/lsp
   test -f nvim/nvim-pack-lock.json
   ```

3. Run formatting/static checks for the configuration files where tools are available:

   ```sh
   stylua --check nvim
   ```

4. Run a Neovim headless startup smoke test:

   ```sh
   nvim --headless -u nvim/init.lua '+quitall'
   ```

5. Run health checks relevant to the audit, accepting that missing optional tools should be
   classified rather than silently ignored:

   ```sh
   nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'
   ```

6. During implementation, produce an audit report that satisfies
   `contracts/audit-report.md` and confirm every file under `nvim/` is covered.

## Expected Result

The plan is ready for task generation when the artifacts exist, the audit scope is clear,
and any failed local validation is captured as a finding or follow-up task instead of being
ignored.
