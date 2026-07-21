# Contract: Documentation Review

## Tmux README Contract

`Tmux/README.md` must let a reader answer these questions without opening any other file:

- What is this directory for?
- Which local tmux file should activate this config?
- What must be installed before tmux plugins work?
- How can the user reload or validate the config?
- Which major behaviors and shortcuts does the config provide?
- How can the user avoid overwriting existing local config?

## Neovim README Contract

`nvim/README.md` must keep these reader outcomes intact:

- The directory is shared Neovim configuration, not application code.
- The quick validation path is visible near the top.
- Dependency validation and installation previews remain discoverable.
- Local overrides and machine-specific values are described clearly.
- Existing user-facing sections are preserved unless they conflict with the configuration framing.

## Root README Contract

`README.md` may stay high-level, but it must not contradict the directory READMEs. If root guidance becomes stale or misleading, update it to point to `Tmux/README.md` or `nvim/README.md` instead of duplicating full setup instructions.

## Review Checklist

- A reviewer can identify the happy path in each README within 30 seconds.
- Commands are safe to copy or clearly marked as examples.
- No new private paths, credentials, or work-specific assumptions are introduced.
- Documentation changes match the committed config behavior.
