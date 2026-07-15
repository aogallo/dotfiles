# Feature Specification: Merge Tmux Configuration

**Feature Branch**: N/A  
**Created**: 2026-07-14  
**Status**: Draft  
**Input**: User description: "quiero que hagas merge de @Tmux/.tmux.conf y la configuracion de tmux actual no quiero que agregues por el momento ninguno de los dos temas de las configuraciones. La idea sera que este archivo sea la fuente de la verdad y cuando se cree la herramienta de instalacion se instale tmux y se copie la configuracion. no quiero por el momento hacer un symbolic link preferia copiar el archivo pero eso lo vemos cuando creemos la herramienta. Luego pidió cambiar el archivo canónico de .tmux.conf a tmux.conf para evitar tener que mostrar dotfiles en el explorer de Neovim."

## User Scenarios & Testing

### Primary User Story

As the owner of these dotfiles, I want the repository tmux configuration to consolidate the useful behavior from the existing repository file and my current active tmux configuration, while excluding theme-specific settings, so that a normally visible `tmux.conf` file becomes the single source of truth for future installation workflows.

### Acceptance Scenarios

1. **Given** the repository tmux configuration and the current active tmux configuration both contain useful tmux behavior, **When** the merge is completed, **Then** the repository tmux configuration includes the non-theme behavior from both sources without duplicated or contradictory settings.
2. **Given** both source configurations include theme plugins or theme settings, **When** the merge is completed, **Then** no theme plugin or theme-specific option from either source is included in the resulting configuration.
3. **Given** the repository tmux configuration is intended to become the future source of truth, **When** the merge is completed, **Then** the resulting file is suitable to be copied by a future installation tool as the active tmux configuration.
4. **Given** the user prefers copying configuration files for now, **When** the merge is completed, **Then** the resulting requirements do not depend on symbolic links.
5. **Given** the user browses this repository from Neovim's explorer, **When** locating the canonical tmux configuration, **Then** the file is visible without enabling hidden-file display.

### Edge Cases

- If both configurations define the same behavior with different values, the resulting configuration must keep the value that best supports the current active tmux behavior unless it conflicts with the source-of-truth goal.
- If a setting is only needed by a removed theme, that setting must also be excluded.
- If a plugin is useful independently of theming, it may be retained even if it appears near theme-related configuration.
- If a key binding exists in only one source and does not conflict with another binding, it should be retained.
- If the source file currently uses a hidden filename, the canonical repository file must be renamed or represented with a non-hidden filename.

## Requirements

### Functional Requirements

- **FR-001**: `Tmux/tmux.conf` MUST become the canonical tmux configuration file for this dotfiles project.
- **FR-002**: The merged configuration MUST include general tmux usability behavior from both the repository tmux configuration and the current active tmux configuration.
- **FR-003**: The merged configuration MUST exclude all Catppuccin theme plugin declarations and Catppuccin-specific settings.
- **FR-004**: The merged configuration MUST exclude all Kanagawa theme plugin declarations and Kanagawa-specific settings.
- **FR-005**: The merged configuration MUST keep plugin manager initialization when plugins remain in use.
- **FR-006**: The merged configuration MUST avoid duplicate declarations for the same plugin, key binding, or setting.
- **FR-007**: The merged configuration MUST preserve current practical navigation, clipboard, split-pane, mouse, index, and popup workflow behavior when those behaviors do not depend on themes.
- **FR-008**: The merged configuration MUST remain usable as a standalone file that a future installer can copy into the user's tmux configuration location.
- **FR-009**: The merged configuration MUST NOT require symbolic links as part of the current change.
- **FR-010**: The resulting configuration MUST be organized clearly enough for future installer work to identify `Tmux/tmux.conf` as the file that should be copied.
- **FR-011**: The canonical repository filename MUST NOT start with a dot, so it remains visible in Neovim's explorer without toggling hidden files.

## Key Entities

- **Repository Tmux Configuration**: The version-controlled `Tmux/tmux.conf` file that will become the project source of truth.
- **Current Active Tmux Configuration**: The user's currently active tmux configuration used as an input source for behavior to preserve.
- **Theme Configuration**: Any plugin declaration, option, or setting whose purpose is to style the tmux status line or visual theme.
- **Future Installer**: A planned setup workflow that will install tmux and copy the canonical configuration into place.

## Assumptions

- The repository tmux configuration should be `Tmux/tmux.conf`, even though the current repository source file is `Tmux/.tmux.conf`.
- The current active tmux configuration is the user's active `~/.tmux.conf`.
- Theme exclusion applies to both theme plugin declarations and their theme-specific options.
- Copy-based installation is the desired future direction, while symbolic linking is intentionally out of scope for this change.
- The actual installer creation is out of scope for this feature.
- The future installer may still copy `Tmux/tmux.conf` to the active tmux destination expected by the user's environment.

## Success Criteria

- **SC-001**: A reviewer can identify one canonical tmux configuration file in the repository in under 30 seconds.
- **SC-002**: 100% of theme-specific Catppuccin and Kanagawa declarations from the source configurations are absent from the merged configuration.
- **SC-003**: At least 90% of non-theme user workflow behaviors from the two source configurations are preserved, excluding only duplicates or direct conflicts.
- **SC-004**: A future installer specification can reference the canonical tmux configuration without requiring additional decisions about symlink versus copy behavior.
- **SC-005**: The merged configuration can be manually copied into the active tmux configuration location and loaded without theme-related missing dependency errors.
- **SC-006**: The canonical tmux configuration is visible in Neovim's explorer without enabling hidden-file display.
