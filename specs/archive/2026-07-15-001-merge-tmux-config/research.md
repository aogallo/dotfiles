# Research: Merge Tmux Configuration

## Decision: Use `Tmux/tmux.conf` as the canonical repository file

**Rationale**: The user wants the tmux configuration visible in Neovim's explorer without enabling hidden-file display. A non-hidden filename also gives the future installer an obvious source file to copy.

**Alternatives considered**: Keep `Tmux/.tmux.conf` as canonical. Rejected because it preserves the hidden-file friction the user explicitly wants to remove.

## Decision: Prefer active config values when equivalent settings conflict

**Rationale**: The active `~/.tmux.conf` reflects the current working setup. For terminal behavior, prefer `tmux-256color`, `,*:Tc`, and `extended-keys off` over the older repository `screen-256color` and `xterm-256color:RGB` settings.

**Alternatives considered**: Prefer the repository file. Rejected because the repository file is older and includes theme-specific Catppuccin settings the user wants removed.

## Decision: Exclude both Catppuccin and Kanagawa entirely

**Rationale**: The user explicitly requested no themes from either source configuration for now. This means removing theme plugin declarations and theme-specific options.

**Alternatives considered**: Keep theme plugin lines commented for later. Rejected because the spec asks not to add either theme now, and commented theme blocks add noise to the canonical file.

## Decision: Keep non-theme workflow plugins

**Rationale**: Plugins such as TPM, tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect, tmux-which-key, and tmuxifier support behavior rather than visual theme. They align with the user's workflow-oriented merge request.

**Alternatives considered**: Keep only plugins already active in `~/.tmux.conf`. Rejected because the repository includes `tmuxifier`, which is behavior-oriented and does not conflict with the no-theme constraint.

## Decision: Do not modify active `~/.tmux.conf` during this feature

**Rationale**: The feature is about creating the repository source of truth. Applying it to the runtime location belongs to future installer work and should preserve the user's stated copy-not-symlink preference.

**Alternatives considered**: Copy the merged file into `~/.tmux.conf` immediately. Rejected because installer behavior is explicitly deferred.

## Decision: No external contracts are needed

**Rationale**: This change exposes no public API, CLI schema, endpoint, or machine-readable interface. The relevant contract is the repository file location and validation guide.

**Alternatives considered**: Create a formal contract file for installer copy behavior. Rejected because the installer is out of scope and would create premature process detail.
