# Quickstart: Ghostty Configuration Module

Use this guide to validate the implementation after `/speckit.tasks` and apply are complete.

## Prerequisites

- Run commands from the repository root.
- Use a feature branch before implementation commits.
- Keep Ghostty local configuration backed up before applying any linker changes.
- Confirm issue #40 remains the linked feature request for this work.

## 1. Inspect the current machine baseline

Expected current-machine findings:

| Item | Expected |
|------|----------|
| Ghostty app | `/Applications/Ghostty.app` |
| Active config | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| Generated local state | `~/Library/Application Support/com.mitchellh.ghostty/auto/` stays local |
| Repository config | `ghostty/config.ghostty` |

Pass condition: the implementation documents any difference between the current machine and these expected values.

## 2. Review managed files

Confirm these files exist:

```sh
test -f ghostty/config.ghostty
test -f ghostty/local.example.ghostty
test -f ghostty/dependencies.tsv
test -f ghostty/README.md
test -f setup/validate-ghostty-config.sh
test -f setup/link-ghostty-config.sh
```

Pass condition: all files exist, and no generated Ghostty `auto/` files are committed.

## 3. Validate shared configuration hygiene

Run:

```sh
setup/validate-ghostty-config.sh
```

Expected outcome:

- Required repository files are present.
- Ghostty installation status is reported clearly.
- Missing optional dependencies are reported without surprising failure.
- No secrets, private identifiers, or user-specific absolute paths are found in shared Ghostty files.
- Managed Ghostty config loading is smoke-checked when supported by the local Ghostty installation.

## 4. Preview linking without changing the machine

Run:

```sh
setup/link-ghostty-config.sh --dry-run
```

Expected outcome:

- The command prints source and destination paths.
- Existing local config state is reported.
- No files are changed.
- If unmanaged local config exists, the command says backup is required before apply.

## 5. Validate backup-safe adoption

Only run this when ready to let the repository manage the active Ghostty config file.

```sh
setup/link-ghostty-config.sh --apply --backup
```

Expected outcome:

- Existing unmanaged config is backed up before replacement or linking.
- The active config becomes repository-managed.
- The generated `auto/` directory remains untouched.
- A final summary lists changed, skipped, failed, and backup paths.

## 6. Validate idempotency

Run twice:

```sh
setup/link-ghostty-config.sh --dry-run
setup/link-ghostty-config.sh --dry-run
```

If the managed config has been applied, also run the apply command twice.

Pass condition: repeated runs converge without duplicate links, repeated backups, or unclear ownership.

## 7. Validate rollback

Run:

```sh
setup/link-ghostty-config.sh --remove
```

Expected outcome:

- Only repository-managed Ghostty config is removed.
- Unmanaged local config is never deleted.
- Backup restoration instructions in `ghostty/README.md` are sufficient to restore the previous file.

## 8. Validate terminal behavior manually

Open Ghostty and confirm:

- Font family and size match the intended baseline or documented local override.
- Catppuccin Frappe theme and custom background are visible.
- Opacity and blur match the current-machine baseline.
- Window padding, decoration, and dimensions remain comfortable for normal development.
- Neovim remains readable in Ghostty after the managed config is active.

## 9. Review documentation

Open `ghostty/README.md` and verify it explains:

- Managed files.
- Current-machine baseline.
- Dependency expectations.
- Local-only customization boundaries.
- Validation.
- Linking.
- Backup.
- Rollback.
- Troubleshooting.
- Relationship to issue #40.

Pass condition: a maintainer can determine installation status, active config ownership, and next action in under 5 minutes.
