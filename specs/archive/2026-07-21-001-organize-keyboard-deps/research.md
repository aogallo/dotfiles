# Research: Organize Keyboard and Optional Dependencies

## Decision: Keep `shfmt` and `shellcheck` optional

**Rationale**: The current dependency manifest already marks both tools as optional, and the user framed the warning as non-blocking. Preserving optional status keeps baseline Neovim setup usable without forcing shell tooling on machines that do not edit shell scripts often.

**Alternatives considered**: Making them required would remove warnings for fully provisioned machines but would violate the stated non-blocking expectation. Removing them from the manifest would hide useful tooling and weaken validation.

## Decision: Improve optional-tool resolution through docs and dry-run validation

**Rationale**: `setup/validate-nvim-deps.sh` already prints `source`, `used by`, and `install` hints for optional missing tools. The missing piece is making the intended resolution path obvious: either install optional tools with the existing bootstrap path or accept the non-blocking warning.

**Alternatives considered**: Auto-installing optional tools during validation was rejected because the validator is intentionally non-destructive. Suppressing optional warnings was rejected because it would hide actionable quality-of-life dependencies.

## Decision: Create a top-level `keyboard/` module

**Rationale**: A dedicated root-level `keyboard/` folder matches the repository's tool/module organization pattern and keeps hardware configuration assets out of the repository root. It leaves room for future keyboard files and a focused README.

**Alternatives considered**: `hardware/keyboard/` adds hierarchy not needed for one keyboard family. `config/keyboard/` is vague in a dotfiles repository where many folders are already configuration. Keeping the JSON at root fails the user's organization request.

## Decision: Move `iris_rev__5.json` without semantic changes

**Rationale**: The user asked for organization, not keymap redesign. Preserving the JSON content reduces risk and makes validation straightforward by comparing macros, layers, and encoders before and after the move.

**Alternatives considered**: Reformatting or renaming the JSON contents was rejected because it increases review noise and could alter VIA import behavior.

## Decision: Document rollback as a repository move/revert

**Rationale**: The change does not install, overwrite, or mutate local keyboard firmware. Recovery is moving the file back to the previous root path or reverting the commit.

**Alternatives considered**: A recovery script is unnecessary for a single repository-managed file move.
