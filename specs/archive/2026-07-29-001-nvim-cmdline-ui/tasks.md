# Tasks: Neovim Command-Line UI

## Closure Decision

This change is closed as deferred, not completed. Manual validation rejected both Noice attempts because the native bottom command line remained visible and the LazyVim-like retry introduced a statusline error. Noice/Nui were removed from config, lockfile, and local `vim.pack` state; command-line UI replacement remains future work for issue #62.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250-450 |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | Provider approval/config → conflict cleanup/docs → validation/rollback |
| Delivery strategy | ask-on-risk |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Approval gate and Noice provider wiring | PR 1 | Integration branch slice; no code until Noice-first approval |
| 2 | Notification/message conflict cleanup and docs | PR 2 | Depends on Unit 1; preserve one final PR to `main` |
| 3 | Validation and rollback proof | PR 3 | Depends on Unit 2; include quickstart evidence |

## Phase 1: Approval and Branch Gate

- [x] 1.1 Confirm user approval for the Noice-first provider decision in `specs/001-nvim-cmdline-ui/research.md` before modifying `nvim/` files; covers User Story 5.
- [x] 1.2 Confirm implementation is on integration branch `nvim-config-integration` and not `main`; link GitHub issue #62 in PR preparation notes.
- [x] 1.3 Confirm chain strategy under `ask-on-risk` before apply because forecast risk is Medium.

## Gate Notes

- User approved the Noice-first approach and `feature-branch-chain` strategy.
- Implementation moved from `main` to integration branch `nvim-config-integration` before editing `nvim/` for this change.

## Phase 2: Provider Implementation

- [ ] 2.1 Add `folke/noice.nvim` and `MunifTanjim/nui.nvim` through vim-pack in `nvim/plugin/editor.lua` and refresh `nvim/nvim-pack-lock.json`.
- [ ] 2.2 Configure Noice `cmdline_popup` in `nvim/plugin/editor.lua` with centered width/position for User Story 1.
- [ ] 2.3 Configure Noice popupmenu view in `nvim/plugin/editor.lua` to align with command input width for User Story 2.
- [ ] 2.4 Configure Noice message, error/warning, `:messages`, and LSP progress routes in `nvim/plugin/editor.lua` for User Stories 3 and 4.
- [x] 2.5 Keep `nvim/plugin/blink.lua` insert completion unchanged and leave `cmdline = { enabled = false }` unless approved Noice behavior requires a documented change.

## Phase 3: Conflict Cleanup

- [x] 3.1 Audit `nvim/lua/notifications.lua` and `nvim/plugin/editor.lua` so only one visible notification provider owns `vim.notify` output.
- [x] 3.2 Adjust or disable Snacks notifier config in `nvim/plugin/editor.lua` only if Noice causes duplicate visible notifications.
- [x] 3.3 Review `nvim/lua/config/autocmds.lua` command-line message capture and disable replaced behavior if Noice already captures it safely.
- [x] 3.4 Preserve `<leader>un` notification history or replace it with an equivalent documented Noice/Snacks history action.

## Phase 4: Validation

- [x] 4.1 Run `nvim --headless -u nvim/init.lua '+quitall'` and record result.
- [x] 4.2 Run `stylua --check nvim` and `setup/validate-nvim-deps.sh` and record results.
- [x] 4.3 Manually validate `specs/001-nvim-cmdline-ui/quickstart.md` command entry, option width at 80/120/160 columns, notifications, history, LSP progress, and five repeated starts.

## Phase 5: Documentation and Rollback

- [x] 5.1 Update `nvim/README.md` with provider ownership, usage, customization, troubleshooting, validation, and rollback guidance.
- [x] 5.2 Document rollback in `nvim/README.md`: remove/disable Noice config, restore prior Snacks/custom notification behavior, rerun static checks.
- [x] 5.3 Before final PR to `main`, review spec relationship and closure/archive decision with the user.

## Validation Notes

- `nvim --headless -u nvim/init.lua '+quitall'` passed.
- `stylua --check nvim` passed.
- `setup/validate-nvim-deps.sh` passed with 0 required missing dependencies; optional `shfmt` and `shellcheck` remain missing/non-blocking.
- Manual validation rejected the Noice implementation because it duplicated the bottom command line; this closes the spec as deferred rather than complete.

## Noice Rejection Notes

- Initial manual UI validation showed the eager/custom Noice config duplicated the native bottom command line even with `cmdheight=0`.
- The LazyVim-like retry also failed manual validation: it still showed the bottom command line and introduced a statusline Lua error through Noice status integration.
- Noice and Nui were removed from `nvim/plugin/editor.lua`, `nvim/lua/statusline.lua`, local `vim.pack` state, and `nvim/nvim-pack-lock.json`.
- Floating command-line UI remains deferred until a provider can satisfy the no-duplicate-cmdline requirement without statusline errors.
