# Data Model: Merge Tmux Configuration

## Repository Tmux Configuration

**Description**: The canonical repository-managed tmux config.

| Field | Value |
|-------|-------|
| Path | `Tmux/tmux.conf` |
| Visibility | Non-hidden filename |
| Ownership | Repository source of truth |
| Runtime role | Source file for future copy-based installation |

**Validation Rules**:

- Must not start with a dot.
- Must include merged non-theme behavior from both source configs.
- Must not include Catppuccin or Kanagawa plugin declarations or options.
- Must remain loadable by tmux as a standalone config file.

## Source Configuration

**Description**: An input configuration used to build the canonical file.

| Source | Role | Mutated |
|--------|------|---------|
| `Tmux/.tmux.conf` | Existing repository source | Yes, retired or replaced during implementation |
| `~/.tmux.conf` | Current active user source | No |

**Validation Rules**:

- Active user config is read-only input for this feature.
- Theme-only settings from either source must not transfer into the canonical file.

## Configuration Item

**Description**: A plugin, option, binding, or command considered during the merge.

| Attribute | Meaning |
|-----------|---------|
| Category | plugin, option, binding, command, comment |
| Source | repository, active, or both |
| Theme-specific | true when tied to Catppuccin, Kanagawa, or visual theme behavior |
| Retention | keep, drop, or replace |

**Validation Rules**:

- Theme-specific items must be dropped.
- Duplicate retained items must collapse into one canonical declaration.
- Conflicting equivalent settings should prefer the active config unless that conflicts with portability or source-of-truth requirements.

## State Transitions

```text
Existing hidden repo config + active user config
  -> classify items as theme or non-theme
  -> resolve duplicates and conflicts
  -> create visible canonical repo config
  -> future installer copies canonical config to active tmux location
```
