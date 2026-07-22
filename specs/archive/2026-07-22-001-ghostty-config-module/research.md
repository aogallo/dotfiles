# Research: Ghostty Configuration Module

## Decision: Manage only Ghostty's active config file, not the whole support directory

**Rationale**: The current machine stores active configuration at `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` and generated state under `~/Library/Application Support/com.mitchellh.ghostty/auto/`. Managing only `config.ghostty` keeps repository ownership narrow, avoids deleting generated files, and satisfies the constitution's non-destructive and source-of-truth gates.

**Alternatives considered**: Replace or link the full `com.mitchellh.ghostty` directory. Rejected because it would risk overwriting generated or application-owned state and make rollback broader than necessary.

## Decision: Store portable defaults in `ghostty/config.ghostty`

**Rationale**: Ghostty configuration uses a readable `key = value` format with full-line `#` comments. The current local configuration is small and maps cleanly to portable settings: font family, font size, theme, background, background opacity, blur radius, window decoration, padding behavior, window dimensions, and tab-location behavior.

**Alternatives considered**: Keep Ghostty setup local-only. Rejected because issue #40 explicitly asks for reviewable, reusable, installer-ready Ghostty configuration.

## Decision: Include an optional local override example but keep real overrides untracked

**Rationale**: Ghostty supports splitting configuration through `config-file`, including optional files prefixed with `?`. This allows a shared config to document a local override path while avoiding failure when the local file does not exist. Real local values must stay outside the repository to preserve portability and secret hygiene.

**Alternatives considered**: Commit all current settings with no override path. Rejected because font availability, display preferences, work/private values, and machine-specific visual settings can vary across Macs.

## Decision: Keep IosevkaTerm NF as a portable default with dependency documentation

**Rationale**: The current terminal setup uses `font-family = IosevkaTerm NF`. This is user-facing behavior and should be preserved as the baseline, but the module must declare the font dependency and explain fallback/customization because another Mac may not have it installed.

**Alternatives considered**: Replace the font with JetBrains Mono from the README. Rejected because the user asked to take the current machine configuration as the initial source, and changing the font would be a behavioral choice unrelated to portability.

## Decision: Preserve Catppuccin Frappe and current visual settings as initial shared defaults

**Rationale**: The local Ghostty config sets `theme = Catppuccin Frappe`, `background = 0E1419`, `background-opacity = 0.95`, and `background-blur-radius = 20`. These define the current terminal appearance and do not contain secrets or host paths. They are acceptable portable defaults if documented as visual preferences with validation guidance.

**Alternatives considered**: Use Ghostty defaults or align with the Neovim Tokyonight theme. Rejected because the feature goal is to capture the current Ghostty setup, not redesign the entire color system.

## Decision: Provide a safe linker with dry-run, apply, backup, and remove behavior

**Rationale**: The constitution requires non-destructive operations, idempotency, clear installer UX, and rollback. A linker can satisfy issue #40's installable-module goal only if it refuses unmanaged conflicts by default, creates recoverable backups before replacement, removes only repository-managed links, and reports changed/skipped/failed actions.

**Alternatives considered**: Documentation-only adoption. Rejected because the issue requests an installable module prepared for safe linking and backup behavior.

## Decision: Validate with repository checks plus Ghostty smoke checks when available

**Rationale**: Ghostty provides CLI-accessible configuration documentation and loads default config files unless disabled by CLI options. The validation script should verify required files exist, shared files avoid private paths/secrets, the app or CLI is discoverable where practical, and the managed config can be loaded or smoke-checked when Ghostty exposes the needed command on the machine.

**Alternatives considered**: Visual-only validation. Rejected because manual appearance checks are useful but insufficient for repeatable repository verification.

## Decision: Treat implementation branch discipline as a planning gate for the next phase

**Rationale**: The setup script reports `BRANCH=001-ghostty-config-module`, but the current checkout remains `main`. Planning artifacts can be created now, but implementation commits must happen on a feature branch before code changes are committed or a pull request is opened.

**Alternatives considered**: Continue implementation on `main`. Rejected because the constitution forbids direct implementation commits on `main` outside emergency recovery.
