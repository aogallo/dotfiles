# Contract: Zsh Module

## Managed Files

- `zsh/.zshrc`: repository-managed portable interactive zsh configuration.
- `zsh/.zshenv.example`: example environment-only values with placeholders, not real local values.
- `zsh/local.example.zsh`: example personal customization file with no secrets.
- `zsh/dependencies.tsv`: reviewable dependency manifest.
- `zsh/README.md`: user-facing scope, setup, validation, customization, troubleshooting, and rollback guide.

## Local Override Contract

Shared zsh files MAY source an optional local override from the user's home directory. The local override MUST be absent-safe, ignored by Git, and documented as the place for personal aliases, private paths, credentials, work settings, and machine-specific exports.

## Startup Contract

- Required baseline startup must not fail when optional tools are missing.
- Optional integrations must check `command -v`, file existence, or environment variables before sourcing or evaluating code.
- PATH additions must avoid repeated duplicate entries when the file is sourced more than once.
- Apple Silicon and Intel Homebrew paths must be discovered rather than hard-coded to one architecture.

## Future Linker Contract

If implemented, `setup/link-zsh-config.sh` must default to dry-run, refuse unmanaged conflicts, require explicit backup before replacement, remove only repository-managed links, return non-zero on unsafe failures, and print a final summary of changed, skipped, failed, and backup paths.
