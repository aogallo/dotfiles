# Tasks: Neovim Plugin Cleanup UI

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 350-500 |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 cleanup module/command → PR 2 UI/docs/validation |
| Delivery strategy | ask-on-risk |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Safe discovery, deletion, reporting, and `PackClean` redirect | PR 1 | Integration branch; validates User Stories 1-3. |
| 2 | Snacks UI, docs, validation, and approval gate | PR 2 | Depends on Unit 1; final PR to `main` needs issue #27 approval. |

## Phase 1: Foundation and Safety Model

- [x] 1.1 Create `nvim/lua/pack-clean.lua` with candidate fields from `spec.md` User Stories 1-3: name, path, active, installed, lockfile status, type, and reason.
- [x] 1.2 Add runtime safety-boundary helpers in `nvim/lua/pack-clean.lua` that resolve paths and block anything outside Neovim package roots.
- [x] 1.3 Add lockfile read/write helpers for `nvim/nvim-pack-lock.json`, preserving valid JSON and excluding active entries.

## Phase 2: Core Cleanup Behavior

- [x] 2.1 Implement candidate discovery in `nvim/lua/pack-clean.lua` from `vim.pack.get()`, safe disk-only paths, missing paths, and stale lockfile-only entries.
- [x] 2.2 Implement selection execution that confirms before deletion, prefers `vim.pack.del()` for inactive managed plugins, and records skipped, blocked, not-found, removed, and errors.
- [x] 2.3 Implement repeated-run/idempotency behavior so successfully removed candidates do not appear as duplicate removals.
- [x] 2.4 Keep active plugins and active lockfile entries out of deletable candidates, matching `contracts/cleanup-behavior.md`.

## Phase 3: UI and Wiring

- [x] 3.1 Replace the inline `PackClean` body in `nvim/lua/config/autocmds.lua` with a call to `require('pack-clean').open()`.
- [x] 3.2 Add the Snacks picker review surface in `nvim/lua/pack-clean.lua`, showing name, path, active/inactive state, lockfile status, and reason.
- [x] 3.3 Add a documented fallback review/report path if Snacks picker is unavailable from `nvim/plugin/editor.lua` timing.
- [x] 3.4 Ensure old inline cleanup behavior is removed or redirected; do not leave competing cleanup commands.

## Phase 4: Tests and Validation

- [x] 4.1 Run `stylua --check nvim` and fix formatting in `nvim/lua/pack-clean.lua` and `nvim/lua/config/autocmds.lua`.
- [x] 4.2 Run `nvim --headless -u nvim/init.lua '+quitall'` and `nvim --headless -u nvim/init.lua '+command PackClean' '+quitall'`.
- [x] 4.3 Validate `quickstart.md` cases: inactive managed, disk-only orphan, lockfile-only stale entry, active exclusion, missing directory, unsafe path, and repeated run.
- [x] 4.4 Review diffs for replaced custom behavior per User Story 4; remove dead custom code or document retained fallback rationale.

## Phase 5: Documentation and Release Gate

- [x] 5.1 Update `nvim/README.md` with `:PackClean` usage, candidate states, safety boundaries, lockfile cleanup, validation commands, rollback, and troubleshooting.
- [x] 5.2 Before final PR, verify issue #27 has `status:approved` or record maintainer resolution as a blocker outcome.
- [x] 5.3 Before final PR to `main`, review coordinated Neovim specs and confirm closure/archive decision with the user.

## Unit 2 Release Gate Notes

- Issue #27 was approved by adding `status:approved` with `gh issue edit 27 --add-label "status:approved"`; final PR approval gate is resolved.
- Final PR coordination remains pending for the integrated Neovim specs. Unit 2 is limited to the child PR slice targeting the Unit 1 branch; do not target `main` until closure/archive coordination is resolved.
- Interactive Snacks picker behavior and inactive managed plugin deletion require manual validation in a real Neovim UI/runtime. Automated helper validation covered disk-only removal, lockfile-only removal, active blocking, missing path handling, unsafe path blocking, and repeated-run reporting against temporary paths.
