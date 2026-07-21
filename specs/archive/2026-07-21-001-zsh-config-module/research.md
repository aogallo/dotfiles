# Research: Zsh Configuration Module

## Decision: Create a top-level `zsh/` module

**Rationale**: Existing repository modules are tool-scoped (`nvim/`, `Tmux/`, `keyboard/`). A dedicated `zsh/` directory satisfies modularity and keeps shell behavior independent from unrelated tools.

**Alternatives considered**: Keep zsh content in `setup/` or repository root. Rejected because it hides the source of truth and mixes configuration with automation.

## Decision: Treat local zsh files as analysis input, not direct committed source

**Rationale**: `~/.zshrc` and `~/.zshenv` include portable behavior and local-only values. The implementation must catalog both, then commit only safe shared configuration.

**Alternatives considered**: Copy the local files verbatim. Rejected because it would commit user-specific paths and optional tool assumptions.

## Decision: Use guarded optional integrations

**Rationale**: Current zsh startup references tools that may not exist everywhere: Homebrew, Oh My Zsh, zsh plugins, powerlevel10k, fzf, zoxide, atuin, carapace, tmux, fd, bat, nvm, pnpm, Java/Android tooling, and Terraform completion. Shared config must check availability before sourcing or evaluating integrations.

**Alternatives considered**: Require all tools. Rejected because missing optional tools would break clean-machine startup.

## Decision: Put personal paths and secrets behind local overrides

**Rationale**: Values such as project directories, Flutter path, pnpm user path, Android/Java paths, and other machine-specific exports belong in ignored local files or documented environment variables.

**Alternatives considered**: Normalize all current paths into the shared file. Rejected because several paths are owner- or machine-specific.

## Decision: Document future linking behavior without requiring installer delivery now

**Rationale**: The specification requires installer readiness, not a complete installer. The plan should define conflict detection, backups, idempotency, removal, and rollback expectations so later tasks can implement safely.

**Alternatives considered**: Build the full installer in planning. Rejected because `/speckit.plan` stops at design artifacts and implementation belongs to later phases.
