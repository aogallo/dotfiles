# Quickstart: Zsh Configuration Module Validation

## Prerequisites

- macOS with zsh available.
- Repository checked out on branch `001-zsh-config-module`.
- Optional shell tools may be absent; validation should report them clearly.

## Validate planned module contents

1. Confirm the module exists and is self-contained:

   ```sh
   test -d zsh
   test -f zsh/README.md
   test -f zsh/.zshrc
   test -f zsh/dependencies.tsv
   ```

2. Check zsh syntax:

   ```sh
   zsh -n zsh/.zshrc
   ```

3. Review secret and local-path boundaries:

   ```sh
   git diff -- zsh README.md setup specs/001-zsh-config-module
   ```

   Expected outcome: shared files contain no real credentials, private endpoints, or owner-specific absolute paths.

4. Validate dependency documentation:

   ```sh
   test -f zsh/dependencies.tsv
   ```

   Expected outcome: required dependencies are distinguishable from optional integrations.

5. If a linker is implemented later, preview before applying:

   ```sh
   setup/link-zsh-config.sh --dry-run
   ```

   Expected outcome: no user-owned zsh files are overwritten; conflicts, backups, removals, and skipped optional operations are reported clearly.
