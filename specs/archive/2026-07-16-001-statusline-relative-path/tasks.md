# Tasks: Statusline Relative File Path

**Input**: `/Users/allan/dotfiles/specs/001-statusline-relative-path/`
**Prerequisites**: `/Users/allan/dotfiles/specs/001-statusline-relative-path/plan.md`, `/Users/allan/dotfiles/specs/001-statusline-relative-path/spec.md`, `/Users/allan/dotfiles/specs/001-statusline-relative-path/research.md`, `/Users/allan/dotfiles/specs/001-statusline-relative-path/data-model.md`, `/Users/allan/dotfiles/specs/001-statusline-relative-path/contracts/statusline-display.md`, `/Users/allan/dotfiles/specs/001-statusline-relative-path/quickstart.md`
**Tests**: No automated tests; use manual quickstart smoke validation and `stylua --check` only.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 60-120 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

## Phase 1: Setup

- [x] T001 From `/Users/allan/dotfiles`, run `git switch -c statusline-relative-path` or switch to an existing feature branch before editing `/Users/allan/dotfiles/nvim/lua/statusline.lua` or committing.
- [x] T002 Inspect `M.file_component()` and `M.render()` in `/Users/allan/dotfiles/nvim/lua/statusline.lua` to identify the current file path, mode, filetype, encoding, and cursor-position segments.

---

## Phase 2: Foundational

- [x] T003 Capture the Neovim starting directory once near the module top in `/Users/allan/dotfiles/nvim/lua/statusline.lua` without hard-coding machine-specific absolute paths.
- [x] T004 Add local buffer-classification helpers in `/Users/allan/dotfiles/nvim/lua/statusline.lua` for normal files, unnamed buffers, and special buffers.
- [x] T005 Add a local relative-path helper in `/Users/allan/dotfiles/nvim/lua/statusline.lua` for files inside `/Users/allan/dotfiles` startup context and readable outside-directory fallbacks.
- [x] T006 Add a local width-aware path formatter in `/Users/allan/dotfiles/nvim/lua/statusline.lua` that shortens or yields the path segment under narrow width pressure while keeping the current mode segment visible.

---

## Phase 3: User Story 1 - Relative statusline file display (Priority: P1) 🎯 MVP

**Goal**: `/Users/allan/dotfiles/nvim/lua/statusline.lua` shows the active buffer relative to the Neovim starting directory while preserving the minimal statusline layout.
**Independent Test**: Manually follow `/Users/allan/dotfiles/specs/001-statusline-relative-path/quickstart.md` after implementation.

- [x] T007 [US1] Replace the raw `%f` path output in `M.file_component()` in `/Users/allan/dotfiles/nvim/lua/statusline.lua` with computed relative path text for normal files inside the starting directory.
- [x] T008 [US1] Render outside-directory files in `/Users/allan/dotfiles/nvim/lua/statusline.lua` with a readable fallback that does not expose unnecessary absolute prefixes or break `M.render()`.
- [x] T009 [US1] Render clear unnamed-buffer and special-buffer labels in `/Users/allan/dotfiles/nvim/lua/statusline.lua` instead of empty strings or misleading filesystem paths.
- [x] T010 [US1] Append compact modified and read-only/non-modifiable indicators in `/Users/allan/dotfiles/nvim/lua/statusline.lua` without adding decorative persistent statusline sections.
- [x] T011 [US1] Preserve existing mode, git, DAP/LSP, diagnostics, filetype, encoding, and cursor-position segments in `/Users/allan/dotfiles/nvim/lua/statusline.lua`, with the file path segment yielding before the current mode segment is hidden.

---

## Phase 4: Polish & Validation

- [x] T012 Run `stylua --check nvim/lua/statusline.lua --config-path nvim/stylua.toml` from `/Users/allan/dotfiles` and fix `/Users/allan/dotfiles/nvim/lua/statusline.lua` formatting if needed.
- [x] T013 Manually validate `/Users/allan/dotfiles/nvim/lua/statusline.lua` using `/Users/allan/dotfiles/specs/001-statusline-relative-path/quickstart.md`, explicitly confirming SC-002 file identification in under 2 seconds and narrow-width current mode visibility.
- [x] T014 Before PR creation from `/Users/allan/dotfiles`, verify the PR relates to `/Users/allan/dotfiles/specs/001-statusline-relative-path` and ask whether that spec should be closed.

---

## Dependencies & Execution Order

- Complete T001 before editing or committing any changes under `/Users/allan/dotfiles`.
- Complete T002-T006 before T007-T011 because `/Users/allan/dotfiles/nvim/lua/statusline.lua` helpers underpin the user-story behavior.
- Complete T007-T011 as the MVP user story before validation in T012-T013.
- Complete T014 only after `/Users/allan/dotfiles/nvim/lua/statusline.lua` passes validation and a PR is being prepared.

## Parallel Opportunities

- T001 and T002 can be prepared independently in `/Users/allan/dotfiles`, but no edits or commits should occur on `main`.
- Most implementation tasks touch `/Users/allan/dotfiles/nvim/lua/statusline.lua`, so parallel coding is intentionally limited.
- T012 and T013 are both validation tasks for `/Users/allan/dotfiles/nvim/lua/statusline.lua`, but run T012 first so formatting is settled before manual smoke validation.

## Implementation Strategy

### MVP Scope

Deliver T001-T013: one feature-branch change to `/Users/allan/dotfiles/nvim/lua/statusline.lua` that satisfies `/Users/allan/dotfiles/specs/001-statusline-relative-path/spec.md` and `/Users/allan/dotfiles/specs/001-statusline-relative-path/quickstart.md`.

### Incremental Delivery

Use one small PR from `/Users/allan/dotfiles`; chained PRs are not recommended for this single-file statusline update.

### Validation Status

Not run yet; execute T012-T013 after implementation.
