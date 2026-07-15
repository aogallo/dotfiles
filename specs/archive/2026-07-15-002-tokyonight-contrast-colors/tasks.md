# Tasks: Tokyonight Contrast Colors

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 35-80 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Add targeted Tokyonight highlight overrides and validation notes | PR 1 | Single scoped Neovim config change with manual checks |

## Phase 1: Runtime Inspection

- [x] 1.1 In `nvim/plugin/editor.lua`, identify the active `folke/tokyonight.nvim` declaration and confirm `style = 'moon'` remains the base.
- [x] 1.2 In a Neovim session, inspect highlight groups for comments, Snacks hidden dotfile entries after `H`, current-file row, selected row, git status, diagnostics, and directories.
- [x] 1.3 Record the final groups to override in apply notes or comments only if needed for reviewer clarity; do not add machine-specific Ghostty settings.

## Phase 2: Targeted Theme Overrides

- [x] 2.1 Update `nvim/plugin/editor.lua` so the Tokyonight plugin uses setup-time `opts` overrides, preserving `style = 'moon'`.
- [x] 2.2 Add comment highlight overrides that improve readability in Lua, shell, Markdown, and config buffers while keeping comments secondary to code.
- [x] 2.3 Add Snacks explorer/picker highlight overrides for hidden dotfile filenames revealed with `H`, without collapsing normal files, directories, git status, or diagnostics.
- [x] 2.4 Add current-file row highlight overrides that keep the current-file state readable and distinct from the selected row.

## Phase 3: Ghostty Context Documentation

- [x] 3.1 Verify the repo still has no versioned Ghostty config before deciding scope.
- [x] 3.2 Document in `specs/002-tokyonight-contrast-colors/quickstart.md` or apply notes whether Ghostty needs follow-up after Neovim-only validation.

## Phase 4: Validation

- [x] 4.1 Run `stylua --check nvim` from the repo root.
- [x] 4.2 Run `nvim --headless -u nvim/init.lua '+colorscheme tokyonight' '+quitall'` and confirm startup/colorscheme load succeeds.
- [x] 4.3 Run the quickstart manual explorer check: open with `<leader>e`, press `H`, and confirm dotfiles like `.gitignore` are readable within 2 seconds.
- [x] 4.4 Run the quickstart manual current-file check and confirm current-file and selected rows remain distinguishable.
- [x] 4.5 Run the quickstart comment checks in `nvim/plugin/editor.lua`, `setup/validate-nvim-deps.sh`, `README.md`, and `Tmux/tmux.conf`.

## Phase 5: Cleanup

- [x] 5.1 Remove temporary highlight-inspection commands or scratch notes before review.
- [x] 5.2 Confirm no secrets, absolute paths, local-only overrides, or unrequested Ghostty config were added.
