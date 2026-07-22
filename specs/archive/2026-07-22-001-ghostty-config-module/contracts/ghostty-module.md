# Ghostty Module Contract

This contract defines the user-facing behavior expected from the Ghostty module and its future-safe setup scripts.

## Managed Files

| Path | Contract |
|------|----------|
| `ghostty/config.ghostty` | Portable shared Ghostty defaults extracted from the current machine. |
| `ghostty/local.example.ghostty` | Example-only local customization file with no real private values. |
| `ghostty/dependencies.tsv` | Reviewable dependency manifest for Ghostty and optional visual dependencies. |
| `ghostty/README.md` | Installation, ownership, validation, backup, rollback, customization, and troubleshooting guide. |
| `setup/validate-ghostty-config.sh` | Non-destructive validation command. |
| `setup/link-ghostty-config.sh` | Non-destructive adoption/removal command. |

## Active Config Ownership

The module manages only the active `config.ghostty` file under Ghostty's macOS support directory. It must not replace the full support directory or commit generated files such as `auto/`.

## Validation Command Contract

Command:

```sh
setup/validate-ghostty-config.sh
```

Expected behavior:

- Prints the managed config path and expected active config path.
- Reports whether Ghostty is installed or missing.
- Verifies required repository files exist.
- Reports missing optional dependencies without failing the baseline unless the missing item is required.
- Checks shared Ghostty files for committed secrets, private identifiers, and user-specific absolute paths.
- Smoke-checks Ghostty configuration loading when the local Ghostty command supports it.
- Exits non-zero only for required missing files, invalid managed config, required dependency failures, or security/path hygiene failures.

## Linker Command Contract

Command examples:

```sh
setup/link-ghostty-config.sh --dry-run
setup/link-ghostty-config.sh --apply
setup/link-ghostty-config.sh --apply --backup
setup/link-ghostty-config.sh --remove
```

Expected behavior:

- Defaults to dry-run when no mutating flag is provided.
- Shows the repository source and active Ghostty config destination before any change.
- Creates the parent support directory only when applying and when it is safe to do so.
- Refuses to overwrite unmanaged local config unless `--backup` is provided with `--apply`.
- Creates a recoverable backup before replacing or linking over unmanaged local config.
- Does not repeatedly back up an already managed config on repeated runs.
- Removes only a repository-managed Ghostty config link or file during `--remove`.
- Refuses to delete unmanaged local config during `--remove`.
- Prints a final summary of changed, skipped, failed, and backup paths.

## Rollback Contract

Rollback must be understandable without reading script source:

- If the active config is a managed link, removal deletes only the managed link.
- If a backup was created, documentation explains how to restore it to the active config path.
- If adoption was interrupted, rerunning dry-run reports the current state and next safe action.

## Documentation Contract

`ghostty/README.md` must let a maintainer answer these questions in under 5 minutes:

- Is Ghostty installed?
- Which file is repository-managed?
- Which local file does Ghostty read on macOS?
- What current-machine settings became shared defaults?
- Which values should stay local?
- How do I validate the module?
- How do I preview, apply, back up, remove, and roll back the managed config?
