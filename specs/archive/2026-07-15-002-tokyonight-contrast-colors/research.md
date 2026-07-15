# Research: Tokyonight Contrast Colors

## Decision: Keep Tokyonight `moon` as the base theme

**Rationale**: The user asked to improve pale colors, not replace the theme. Keeping `moon` preserves the existing visual identity and limits review scope.

**Alternatives considered**: Switch to another Tokyonight style or a different colorscheme. Rejected because it changes too much at once and does not target the specific dotfile/comment readability problem.

## Decision: Place overrides in `nvim/plugin/editor.lua`

**Rationale**: `editor.lua` already declares both `folke/snacks.nvim` and `folke/tokyonight.nvim`. The existing `vim-pack` loader passes `opts` to plugin setup, so theme overrides belong beside the Tokyonight plugin declaration.

**Alternatives considered**: Create a new color module. Rejected for now because the change is small and localized.

## Decision: Use colorscheme setup-time highlight overrides

**Rationale**: Applying overrides through the Tokyonight configuration keeps highlight changes tied to the colorscheme lifecycle and avoids post-load ordering problems.

**Alternatives considered**: Run standalone `vim.api.nvim_set_hl()` calls after `colorscheme`. Rejected because future colorscheme reloads may overwrite them unless additional autocmds are added.

## Decision: Target comments, Snacks picker/explorer groups, and current-file row states

**Rationale**: The user specifically named code comments, hidden dotfiles revealed with `H`, and the explorer line that indicates the current file. Context7 Snacks documentation confirms `H` toggles hidden files and documents picker/explorer file formatting/highlight behavior, so implementation must inspect the exact runtime highlight groups for file names, paths, current rows, and selected rows.

**Alternatives considered**: Brighten all muted theme colors. Rejected because it can flatten the palette and make git status, diagnostics, and selected rows less distinguishable.

## Decision: Treat Ghostty as rendering context first, not a default config change

**Rationale**: The repo does not currently contain a Ghostty configuration. Context7 Ghostty docs show terminal-level options such as `theme`, custom palettes, `background`, `foreground`, selection colors, font settings, and opacity can affect perceived contrast. However, the user’s reported pain is specific to Neovim explorer/comment highlight states, so Neovim highlight fixes should be attempted first and Ghostty should be documented as a follow-up only if needed.

**Alternatives considered**: Add Ghostty configuration immediately. Rejected because it would expand scope beyond Neovim and risk changing the entire terminal appearance without proof that Ghostty is the root cause.

## Decision: Validate manually and with startup checks

**Rationale**: Color readability depends on terminal, font, and display calibration. Automated startup checks prove the config loads; manual checks prove the actual visual outcome.

**Alternatives considered**: Screenshot-only validation. Rejected because screenshots do not reliably capture perceived contrast across displays.

## Decision: No external contracts

**Rationale**: This is an internal visual configuration change with no public API, CLI, or external integration contract.

**Alternatives considered**: Add a UI contract document. Rejected as unnecessary overhead for a small theme configuration change.
