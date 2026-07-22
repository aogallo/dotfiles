# Data Model: Ghostty Configuration Module

## Ghostty Installation

**Description**: Represents whether Ghostty is available on the current macOS machine.

| Field | Description | Validation |
|-------|-------------|------------|
| `app_name` | Human-readable application name. | Must be `Ghostty`. |
| `app_location` | Expected macOS application location. | Prefer standard application locations; current baseline is `/Applications/Ghostty.app`. |
| `cli_available` | Whether a Ghostty command is available for validation. | Optional; missing CLI must be reported clearly. |
| `status` | Installed, missing, or unknown. | Missing Ghostty must not block unrelated modules. |

**Relationships**: Used by validation and documentation to explain prerequisites.

## Active Ghostty Configuration

**Description**: Represents the config file Ghostty reads on this machine.

| Field | Description | Validation |
|-------|-------------|------------|
| `active_path` | Local active config path. | Current baseline is `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`. |
| `managed_source` | Repository source file. | Must be `ghostty/config.ghostty`. |
| `ownership` | Whether active config is unmanaged, repo-managed link, or missing. | Linker must detect and report state before changing anything. |
| `generated_state` | Application-generated files near the config. | Must stay local and uncommitted; current baseline includes `auto/`. |

**State Transitions**:

| From | To | Trigger | Rule |
|------|----|---------|------|
| Missing | Repo-managed | Apply linker with no conflict. | Create parent directory if needed and activate managed config. |
| Unmanaged local file | Backed up then repo-managed | Apply linker with backup enabled. | Backup must exist before replacement/linking. |
| Unmanaged local file | Unchanged | Dry-run or apply without backup. | Report conflict and fail safely. |
| Repo-managed | Missing or restored backup | Remove/rollback. | Remove only managed link/file and restore backup when requested. |

## Portable Ghostty Setting

**Description**: A setting safe to keep in shared repository configuration.

| Field | Description | Validation |
|-------|-------------|------------|
| `name` | Ghostty config key. | Must be supported by Ghostty or documented as removed before implementation completes. |
| `value` | Shared default value. | Must not contain secrets, host-specific absolute paths, or private identifiers. |
| `source` | Where the value came from. | Current-machine inventory or explicit design choice. |
| `classification` | Portable, local-only, or excluded. | 100% of current local settings must be classified. |

**Initial Setting Inventory**:

| Setting | Current Value | Classification | Notes |
|---------|---------------|----------------|-------|
| `font-family` | `IosevkaTerm NF` | Portable default with dependency | Requires font documentation/fallback guidance. |
| `font-size` | `19` | Portable default | User-facing preference; can be overridden locally. |
| `theme` | `Catppuccin Frappe` | Portable default | Preserves current terminal appearance. |
| `background` | `0E1419` | Portable default | Review as visual preference, not secret/local state. |
| `background-opacity` | `0.95` | Portable default | Display preference; can be overridden locally. |
| `background-blur-radius` | `20` | Portable default | Display preference; can be overridden locally. |
| `window-decoration` | `true` | Portable default | Current window behavior. |
| `window-padding-color` | `extend` | Portable default | Current padding behavior. |
| `window-step-resize` | `false` | Portable default | Current resize behavior. |
| `window-padding-balance` | `true` | Portable default | Current padding behavior. |
| `window-height` | `100` | Portable default | Local override allowed for display-specific needs. |
| `window-width` | `100` | Portable default | Local override allowed for display-specific needs. |
| `gtk-tabs-location` | `hidden` | Portable default | Harmless on macOS if accepted by Ghostty; validation must prove config compatibility. |

## Local Ghostty Override

**Description**: A private or machine-specific setting that must stay outside committed shared config.

| Field | Description | Validation |
|-------|-------------|------------|
| `example_path` | Example override file path. | Must be an example, not a real local file with private values. |
| `allowed_values` | Categories appropriate for local overrides. | Fonts, display size, opacity, work-specific paths, or private visual preferences. |
| `ignored_real_file` | Real local override file. | Must be ignored or outside repository tracking. |

## Backup Record

**Description**: Recoverable copy created before replacing unmanaged local Ghostty config.

| Field | Description | Validation |
|-------|-------------|------------|
| `original_path` | Path that was protected. | Must be the active Ghostty config file, not the full support directory. |
| `backup_path` | Recoverable backup location. | Must be reported to the user and not silently overwritten. |
| `created_at` | Timestamp or unique suffix. | Must prevent backup collisions. |
| `restore_status` | Whether rollback has restored it. | Rollback docs must explain restoration. |

## Ghostty Module Documentation

**Description**: User-facing guide for managing Ghostty through this repository.

| Section | Purpose | Validation |
|---------|---------|------------|
| Managed files | Shows repository ownership. | Must include `ghostty/config.ghostty`, examples, dependencies, and setup scripts. |
| Current-machine baseline | Explains source inventory. | Must mention active config path and generated state boundary. |
| Dependencies | Explains required/optional tools. | Must identify Ghostty and font dependency expectations. |
| Validation | Shows runnable checks. | Must include normal, missing-app, conflict, repeated-run, and secret/path checks. |
| Linking and rollback | Shows safe adoption and recovery. | Must state dry-run default, backup behavior, and managed-only removal. |
