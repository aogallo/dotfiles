# Zsh Source Inventory

This inventory records the current-machine zsh configuration reviewed for issue #38. It intentionally summarizes local values instead of copying secrets, private paths, or generated prompt configuration into the repository.

## Reviewed Sources

| Source | Status | Notes |
|--------|--------|-------|
| `~/.zshrc` | Reviewed | Main interactive config; contains portable aliases, guarded integrations, plugin list, prompt loading, and local-only paths. |
| `~/.zshenv` | Reviewed | Contains a Flutter SDK path; classified as local-only and represented as a placeholder in `zsh/.zshenv.example`. |
| `~/.zprofile` | Not present | No login-shell configuration to extract on this machine. |
| `~/.zlogin` | Not present | No login-shell configuration to extract on this machine. |
| `~/.zlogout` | Not present | No logout configuration to extract on this machine. |
| `~/.p10k.zsh` | Reviewed | Generated Powerlevel10k wizard output; kept local-only and sourced when present. |
| `~/Gentleman.Dots/GentlemanZsh/.zshrc` | Reviewed | Older repository-local copy similar to current `~/.zshrc`; used only as context. |
| `~/Gentleman.Dots/GentlemanZsh/.p10k.zsh` | Reviewed | Older generated Powerlevel10k copy; kept local-only. |

## Portable Items Extracted

| Item | Destination | Rationale |
|------|-------------|-----------|
| Powerlevel10k instant prompt loader | `zsh/.zshrc` | Portable when guarded by cache-file existence. |
| Oh My Zsh root and plugin list | `zsh/.zshrc` | Portable when Oh My Zsh is optional and guarded. |
| Homebrew shellenv discovery | `zsh/.zshrc` | Supports Apple Silicon and Intel paths without committing machine-specific state. |
| Common PATH entries under `$HOME` and Nix default profile | `zsh/.zshrc` | Useful shared shell behavior when duplicate-safe. |
| `EDITOR` and `VISUAL` defaults | `zsh/.zshrc` | Portable preference for Neovim-based workflows. |
| `LS_COLORS`, `ls`, `lla`, fzf/bat aliases, Neovim distribution aliases | `zsh/.zshrc` | Portable interactive aliases with guarded command behavior. |
| fzf, zoxide, atuin, carapace, nvm, Terraform completion | `zsh/.zshrc` | Optional integrations guarded by command or file checks. |
| tmux auto-start behavior | `zsh/.zshrc` and `zsh/local.example.zsh` | Preserved as opt-in via `ZSH_AUTO_START_TMUX=1` to avoid surprising new shells. |

## Local-Only or Excluded Items

| Item | Reason | Replacement |
|------|--------|-------------|
| Flutter SDK path from `~/.zshenv` | User-specific absolute path | Placeholder in `zsh/.zshenv.example`. |
| Android SDK and Java home values | Machine-specific local development paths | Placeholders in `zsh/.zshenv.example`. |
| pnpm home with concrete user path | User-specific absolute path | Placeholder in `zsh/.zshenv.example`. |
| Project search roots | Personal directory layout | Example in `zsh/local.example.zsh`. |
| Generated Powerlevel10k body | Generated and personal prompt configuration | Keep `~/.p10k.zsh` local; source it when present. |
| Termux-specific behavior | Outside macOS acceptance target | Not included in managed macOS module. |
| Older `Gentleman.Dots` source paths | Historical local checkout path | Used only as context, not copied. |

## Dependency Findings

Dependencies discovered in the current setup are documented in `zsh/dependencies.tsv`. Only `zsh` is required for baseline validation; optional integrations must degrade gracefully when absent.
