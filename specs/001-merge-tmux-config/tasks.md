# Tasks: Merge Tmux Configuration

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 90-140 |
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
| 1 | Create canonical non-theme tmux config and validation docs/status updates | PR 1 | Single low-risk config change; validation included |

## Phase 1: Source Classification

- [x] 1.1 Review `Tmux/.tmux.conf` and classify each plugin, option, binding, and command as keep/drop, dropping Catppuccin-specific lines.
- [x] 1.2 Review `/Users/allan/.tmux.conf` as read-only input and classify keep/drop items, dropping Kanagawa-specific lines.
- [x] 1.3 Resolve duplicate/conflicting settings, preferring active config values for terminal handling: `tmux-256color`, `,*:Tc`, and `extended-keys off`.

## Phase 2: Canonical Config Creation

- [x] 2.1 Create `Tmux/tmux.conf` as the canonical visible repository tmux configuration.
- [x] 2.2 Add retained non-theme plugins to `Tmux/tmux.conf`: TPM, tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect, tmux-which-key, and tmuxifier.
- [x] 2.3 Add retained workflow settings and bindings to `Tmux/tmux.conf`: mouse, indexes, vi copy mode, clipboard copy, splits, pane navigation/resize, popup scratch session, kill-other-sessions, image passthrough, and TPM init.
- [x] 2.4 Ensure `Tmux/tmux.conf` contains no user-specific absolute paths and does not require symlinks or modifying `/Users/allan/.tmux.conf`.

## Phase 3: Retire Hidden Repository Config

- [x] 3.1 Remove or retire `Tmux/.tmux.conf` so `Tmux/tmux.conf` is the only repository source of truth.
- [x] 3.2 Confirm no project documentation or task artifact still names `Tmux/.tmux.conf` as canonical.

## Phase 4: Verification

- [x] 4.1 Run static presence checks: `test -f Tmux/tmux.conf` and `test ! -f Tmux/.tmux.conf`.
- [x] 4.2 Validate theme exclusion with `! grep -Ei 'catppuccin|kanagawa' Tmux/tmux.conf`.
- [x] 4.3 Validate expected workflow content with `grep -E 'mouse|base-index|pane-base-index|vim-tmux-navigator|tmux-yank|tmux-resurrect|tmux-which-key|tmuxifier|allow-passthrough|display-popup' Tmux/tmux.conf`.
- [x] 4.4 Run tmux parse/source smoke test: `tmux -f Tmux/tmux.conf start-server \; source-file Tmux/tmux.conf`.

## Phase 5: Documentation and Status

- [x] 5.1 Update `specs/001-merge-tmux-config/quickstart.md` only if validation commands change during implementation.
- [x] 5.2 Update `specs/001-merge-tmux-config/spec.md` status from Draft if the project convention requires it after implementation.
- [x] 5.3 Record verification results for `Tmux/tmux.conf` and note that `/Users/allan/.tmux.conf` was not modified.

## Apply Verification Results

- `test -f Tmux/tmux.conf`: passed.
- `test ! -f Tmux/.tmux.conf`: passed.
- `! grep -Ei 'catppuccin|kanagawa' Tmux/tmux.conf`: passed.
- `grep -E 'mouse|base-index|pane-base-index|vim-tmux-navigator|tmux-yank|tmux-resurrect|tmux-which-key|tmuxifier|allow-passthrough|display-popup' Tmux/tmux.conf`: passed.
- `tmux -f Tmux/tmux.conf start-server \; source-file Tmux/tmux.conf`: passed.
- `/Users/allan/.tmux.conf` was used as read-only input and was not modified.
