# Contract: Release Artifact Launch Behavior

## Purpose

Defines what users must experience after downloading a release binary such as `dotfiles-installer-darwin-arm64`.

## Supported Launch Paths

| Launch Path | Expected Behavior |
|-------------|-------------------|
| Terminal execution | Starts the interactive installer or prints a clear startup error with next action |
| Non-terminal execution | Explains that the installer must be run from a terminal and shows the exact command |
| Unsupported architecture | Explains the mismatch and points to the correct artifact |
| Missing execute permission | Explains how to make the file executable and rerun it |
| OS security/quarantine block | Explains the security block and points to safe release/bootstrap instructions |

## Required User-Facing Instructions

- Artifact names for Apple Silicon and Intel must be documented.
- The direct terminal command must be documented.
- The bootstrap `--prefer-binary` path must be documented as the recommended clean-machine path.
- Failure messages must avoid silent exits.
