# Zsh Configuration

This directory contains the repository-managed, portable zsh configuration extracted from the current machine's shell setup.

## Managed Files

- `zsh/.zshrc` manages portable interactive shell behavior.
- `zsh/.zshenv.example` documents environment values that should stay local.
- `zsh/local.example.zsh` documents personal aliases, project paths, and local toggles.
- `zsh/dependencies.tsv` lists required and optional shell dependencies.

## Current-Machine Baseline

The implementation is based on the current machine's zsh files, including `~/.zshrc`, `~/.zshenv`, `~/.p10k.zsh`, and any optional startup files that exist. The inventory lives at `specs/001-zsh-config-module/zsh-source-inventory.md`.

The repository does not copy local files verbatim. Portable behavior is extracted into `zsh/.zshrc`; private paths, generated prompt configuration, work settings, and machine-specific exports are documented as local-only.

## Local-Only Configuration

Keep real personal values outside Git:

- `~/.zshenv.local` for environment variables and machine paths.
- `~/.zshrc.local` for personal aliases, project paths, and behavior toggles.
- `~/.p10k.zsh` for generated Powerlevel10k prompt configuration.

Examples are provided in `zsh/.zshenv.example` and `zsh/local.example.zsh`. Do not commit real credentials, private endpoints, work-only values, or user-specific absolute paths.

## Dependencies

`zsh` is required. All other integrations are optional and guarded so shell startup can continue when a tool is missing.

Review `zsh/dependencies.tsv` for install hints and usage. Optional integrations include Oh My Zsh, zsh plugins, Powerlevel10k, fzf, zoxide, atuin, carapace, tmux, fd, bat, nvm, pnpm, and Terraform completion.

## Validation

From the repository root:

```sh
zsh -n zsh/.zshrc
setup/validate-zsh-config.sh
```

Expected results:

- Syntax validation passes.
- Missing optional tools are reported without failing baseline validation.
- Required dependencies fail validation when missing.
- Repeated sourcing does not duplicate managed PATH entries.
- Shared files do not contain real secrets or private absolute paths.

## Future Installation Contract

This feature prepares the module for a future installer but does not link files automatically.

A future zsh linker must:

- Default to dry-run.
- Detect existing `~/.zshrc` and `~/.zshenv` conflicts before changing anything.
- Refuse unmanaged conflicts unless backup behavior is explicitly requested.
- Create recoverable backups before replacing user-owned files.
- Remove only repository-managed links or files.
- Print a final summary of changed, skipped, failed, and backup paths.

## Rollback

If a future installer links this module, rollback should remove only repository-managed links and restore any backup it created. Until a linker exists, rollback is simply not sourcing `zsh/.zshrc` from local shell files.

For manual testing, keep a copy of existing local zsh files before sourcing repository-managed configuration.
