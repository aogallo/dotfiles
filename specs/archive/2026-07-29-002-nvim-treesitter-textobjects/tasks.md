# Tasks: Neovim Treesitter Textobjects

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 180-280 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single integration-branch work unit, final PR to `main` |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Add textobjects, fixtures, validation, and docs | Final PR | Implement on the shared Neovim integration branch; coordinate with separate Neovim specs before final PR to `main`. |

## Phase 1: Dependency and Mapping Foundation

- [x] 1.1 Add `nvim-treesitter/nvim-treesitter-textobjects` to `nvim/plugin/treesitter.lua` through `vim-pack` using the direct API pattern from `plan.md`.
- [x] 1.2 Update `nvim/nvim-pack-lock.json` with the new plugin revision through the existing plugin workflow, not manual guessed metadata.
- [x] 1.3 Review repository-managed keymaps before selecting final mappings from `contracts/mapping-behavior.md`; block accidental conflicts.

## Phase 2: Core Treesitter Behavior

- [x] 2.1 Configure semantic selection in `nvim/plugin/treesitter.lua` for `af`, `if`, `ac`, `ic`, `ao`, and `as` for **User Story 1 - Select Semantic Code Regions**.
- [x] 2.2 Configure incremental selection start, expand, and shrink mappings in `nvim/plugin/treesitter.lua` for **User Story 2 - Expand Selection Structurally**.
- [x] 2.3 Preserve existing `TSInstallConfigured`, `TSUpdateConfigured`, and runtime query path behavior in `nvim/plugin/treesitter.lua`.
- [x] 2.4 Add movement mappings only after conflict review passes; defer brittle swap mappings if parameter validation is unsafe for **User Story 4 - Move or Swap Structural Units**.

## Phase 3: Fixtures and Validation

- [x] 3.1 Create `specs/002-nvim-treesitter-textobjects/fixtures/sample.go` covering const blocks, functions, parameters, and comments for **User Story 3 - Preserve Native Punctuation Textobjects**.
- [x] 3.2 Create `specs/002-nvim-treesitter-textobjects/fixtures/sample.lua` or `sample.ts` covering nested structures, parameters, and comments.
- [x] 3.3 Run `stylua --check nvim`, headless startup, Treesitter health, and `TSInstallConfigured`/`TSUpdateConfigured` smoke checks from `quickstart.md`.
- [x] 3.4 Manually validate semantic selections, 3-level incremental selection, native `a(`/`i(`/`ca(`/`va(` behavior, and any enabled movement/swap mappings.

## Phase 4: Documentation and PR Readiness

- [x] 4.1 Update `nvim/README.md` with enabled mappings, semantic-vs-native guidance using the Go const-block scenario, validation commands, troubleshooting, and rollback.
- [x] 4.2 Record unsupported captures or deferred swap behavior in `nvim/README.md` so safe failures are expected, not surprising.
- [x] 4.3 Before final PR, review issue #48 linkage plus the active spec relationship and closure/archive decision required by `spec.md` FR-019/FR-020.

## Release Gate Notes

- Issue #48 was checked with `gh issue view 48 --json number,state,title,labels,url`; it is open with `status:approved`, so implementation is approved for the final coordinated Neovim PR.
- Final closure/archive remains coordinated with the active Neovim spec batch and should happen after verification and final PR decisions.
- Interactive textobject behavior was manually validated in a real Neovim UI/runtime.
