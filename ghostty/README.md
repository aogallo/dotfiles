# Ghostty Configuration

This module stores the repository-managed Ghostty defaults for issue #40. It manages only
Ghostty's active `config.ghostty` file and leaves generated application state local.

## Managed Files

- `ghostty/config.ghostty` contains portable shared defaults.
- `ghostty/local.example.ghostty` documents safe local overrides.
- `ghostty/dependencies.tsv` lists required and optional dependencies.
- `setup/validate-ghostty-config.sh` validates the module without changing files.
- `setup/link-ghostty-config.sh` previews, applies, backs up, and removes the active config.

## Current-Machine Baseline

- Expected app: `/Applications/Ghostty.app`.
- Active macOS config: `$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty`.
- Generated state: `$HOME/Library/Application Support/com.mitchellh.ghostty/auto/` stays local and must not be committed.
- Implementation branch: `feat/ghostty-config-module`.
- Related issue: GitHub issue #40.

The shared config captures these current portable settings: `font-family = IosevkaTerm NF`,
`font-size = 19`, `theme = Catppuccin Frappe`, `background = 0E1419`,
`background-opacity = 0.95`, `background-blur-radius = 20`, `window-decoration = true`,
`window-padding-color = extend`, `window-step-resize = false`,
`window-padding-balance = true`, `window-height = 100`, `window-width = 100`, and
`gtk-tabs-location = hidden`.

## Local-Only Configuration

Keep real local values outside Git. Use `ghostty/local.example.ghostty` as a template and copy
it to `$HOME/.config/ghostty/local.ghostty` when host-specific overrides are needed.

Good local-only values include alternate fonts, display-specific window dimensions, visual
effect tuning, private paths, and work-specific settings. The shared config includes this file
with an optional `config-file = ?~/.config/ghostty/local.ghostty` line, so Ghostty can start
when the override does not exist.

No current local values were excluded from the shared baseline except generated `auto/` state
and any future private or machine-specific overrides.

## Dependencies

Review `ghostty/dependencies.tsv` for the source of truth.

- Ghostty.app is required to use the terminal and load the active config.
- The `ghostty` CLI is optional and only enables richer validation when available on `PATH`.
- IosevkaTerm NF is an optional visual dependency for matching the baseline font. If it is
  unavailable, set a local `font-family` override.

## Validation

From the repository root:

```sh
setup/validate-ghostty-config.sh
```

Expected results:

- Required module files are present.
- Ghostty installation status is reported clearly.
- Missing optional dependencies are reported without failing baseline validation.
- Shared files avoid secrets, private identifiers, generated `auto/` state, and private
  absolute paths.
- Ghostty config loading is smoke-checked when the installed CLI exposes a supported
  validation command.

## Linking

Preview adoption without changing the machine:

```sh
setup/link-ghostty-config.sh --dry-run
```

Apply only when there is no unmanaged active config:

```sh
setup/link-ghostty-config.sh --apply
```

If an unmanaged active config already exists, preserve it first:

```sh
setup/link-ghostty-config.sh --apply --backup
```

The linker creates a symlink from the active Ghostty config path to `ghostty/config.ghostty`.
It defaults to dry-run, refuses unmanaged overwrites without `--backup`, and reports changed,
skipped, failed, and backup paths.

## Removal and Rollback

Remove only the repository-managed active config link:

```sh
setup/link-ghostty-config.sh --remove
```

Removal refuses to delete unmanaged local files. If `--apply --backup` created a backup,
restore it manually by copying the reported backup path back to:

```text
$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty
```

If adoption is interrupted, rerun `setup/link-ghostty-config.sh --dry-run` to inspect the
current state before applying or restoring anything.

## Troubleshooting

- Missing Ghostty app: install Ghostty, then rerun validation.
- Missing IosevkaTerm NF: install the font or set a local `font-family` override.
- Unmanaged active config conflict: rerun with `--apply --backup` after reviewing the dry-run
  output.
- Unexpected removal refusal: the active config is not managed by this repository, so the
  script is protecting user-owned configuration.

## PR Note

Before opening the PR for this change, verify that the active spec is related to issue #40 and
ask whether the PR should close issue #40.
