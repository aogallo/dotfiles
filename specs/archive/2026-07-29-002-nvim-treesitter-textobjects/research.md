# Research: Neovim Treesitter Textobjects

## Decision: Use `nvim-treesitter-textobjects` for semantic selection, movement, and swap

**Rationale**: The plugin directly provides syntax-aware textobjects, select, move, swap, and repeatable movement support. It is the focused tool for issue #48 and avoids writing custom structural-editing behavior.

**Alternatives considered**:

- **Native punctuation textobjects only**: Rejected as incomplete. Native `a(`/`i(`/`ca(`/`va(` remain valuable for delimiters, but they do not cover semantic function/class/comment/scope regions.
- **Custom Treesitter mappings without plugin**: Rejected initially. It would increase maintenance and require reimplementing selection/move/swap behavior.
- **Copy old `nvim-treesitter.configs` examples**: Rejected. Current `nvim-treesitter` main has dropped legacy modules and this repo already uses main-branch `install/update()` APIs with manual query runtime path setup.

## Decision: Configure textobjects through the current direct plugin API

**Rationale**: Current `nvim-treesitter-textobjects` documentation shows direct setup with `require("nvim-treesitter-textobjects").setup` and explicit `vim.keymap.set` calls. This fits the repo's `vim-pack` helper model better than Lazy.nvim snippets.

**Alternatives considered**:

- **Use Lazy.nvim-style plugin spec**: Rejected because this repo does not use Lazy.nvim.
- **Use `nvim-treesitter.configs.setup`**: Rejected unless implementation research proves it is still required for a compatibility path. The current examples for the plugin use direct setup and keymaps.

## Decision: Preserve native punctuation textobjects and document complementarity

**Rationale**: The user's Go const-block example is delimiter-oriented. Native `ca(` and `va(` are the right primitives for removing/selecting content inside parentheses. Semantic Treesitter textobjects should add function/class/comment/parameter/scope behavior, not replace punctuation edits.

**Alternatives considered**:

- **Override native textobjects**: Rejected. It would violate user expectations and create surprising editing behavior.
- **Avoid semantic textobjects because native ones exist**: Rejected. Semantic objects solve different problems, especially function/type/comment/scope selection and movement.

## Decision: Start with conservative, explicit mappings

**Rationale**: The repo should avoid broad or surprising keymap changes. The plan should add a small mapping set, validate conflicts, and document it clearly.

**Recommended initial mapping contract**:

- `af`: function outer
- `if`: function inner
- `ac`: class/type outer where supported
- `ic`: class/type inner where supported
- `ao`: comment outer where supported
- `as`: local scope where supported
- movement mappings should prefer established Treesitter examples only after conflict review
- swap mappings should be added only if parameter swap validates safely in supported fixtures

**Alternatives considered**:

- **Add every example mapping**: Rejected. Too much surface area and more conflict risk.
- **Only add selection mappings**: Acceptable fallback if movement/swap validation is brittle.

## Decision: Validate against Go plus Lua or TypeScript fixtures

**Rationale**: Go covers the user's concrete const-block concern and common function/type structures. Lua or TypeScript provides another parser/query shape to catch language-specific assumptions.

**Alternatives considered**:

- **Manual-only validation in arbitrary files**: Rejected because repeatable validation needs stable fixtures.
- **Validate every configured parser**: Rejected as excessive for this feature.

## Decision: Keep current parser install/update and runtime path behavior unchanged

**Rationale**: Existing `nvim/plugin/treesitter.lua` already owns configured parser lists, `TSInstallConfigured`, `TSUpdateConfigured`, and main-branch runtime path setup. Textobjects should compose with this behavior, not replace it.

**Alternatives considered**:

- **Rewrite Treesitter setup around `configs.setup`**: Rejected due to unnecessary migration risk.
- **Move folding autocommands into plugin setup**: Deferred unless implementation reveals a real conflict.
