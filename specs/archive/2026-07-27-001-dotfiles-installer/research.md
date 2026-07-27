# Research: Dotfiles Installer TUI

## Decision: Introduce a Go Bubble Tea CLI/TUI

**Rationale**: GitHub issue #37 names Bubble Tea as the intended TUI framework, and Bubble Tea's
model-update-view shape maps cleanly to installer screens, key handling, command execution, and
final reports. The repository has no existing `installer/go.mod`, so implementation should add a dedicated
Go module under `installer/` during the implementation phase and make `cd installer && go test
./...` the primary code validation command.

**Alternatives considered**: A shell-only menu was rejected because it would make richer state,
progress, and testable screen transitions harder. A separate `installer/` Go module was
considered. The implementation now uses an isolated `installer/` module to keep installer code,
dependencies, and tests away from root dotfiles content.

## Decision: Add a minimal shell bootstrap before the Go TUI

**Rationale**: A clean macOS machine may not have Go, Homebrew, or Xcode Command Line Tools, so a
Go-only entrypoint cannot be the first command. A small detection-first shell bootstrap can run
with system tools, initiate Xcode CLT installation, install Homebrew when missing, install Go as a
required development dependency, and then launch the Go TUI.

**Alternatives considered**: Requiring the user to install Go manually was rejected because the
installer should prepare the minimum required environment. Rewriting the entire TUI as shell was
rejected because it would lose the testable state model and report structure already chosen for
the installer.

## Decision: Support prebuilt binaries as an optional fast path

**Rationale**: A compatible prebuilt `dotfiles-installer` binary can improve first-run experience
by avoiding local compilation before the TUI opens. It does not remove the need to install Go,
because Go is part of the user's development environment and Neovim tooling must validate it.

**Alternatives considered**: Making prebuilt binaries mandatory was rejected because releases may
not exist for every architecture or branch. Skipping binary support was rejected because it leaves
avoidable first-run friction when a trusted compatible binary is available.

## Decision: Treat Xcode Command Line Tools as prompt-gated

**Rationale**: `xcode-select --install` can be initiated from a script, but macOS may require a
system UI prompt and manual completion. The bootstrap should detect absence with `xcode-select -p`,
start the install prompt when needed, and stop with clear rerun instructions instead of pretending
the install can always complete unattended.

**Alternatives considered**: Looping until CLT appears was rejected because it can hang scripts and
produce unclear failures. Using broad `setup/macos.sh` behavior was rejected because that script
performs unrelated mutations such as SSH, Git config, clone paths, and symlink setup.

## Decision: Treat the TUI as an orchestrator, not a script replacement

**Rationale**: Existing setup scripts already encode important safety behavior: Neovim and
Ghostty linkers default to dry-run, detect managed links, refuse unmanaged overwrites, support
explicit backup behavior, and report summaries. Reusing them avoids duplicating subtle safety
rules and preserves the constitution's non-destructive and idempotency gates.

**Alternatives considered**: Reimplementing all setup behavior in Go would centralize tests, but
it risks behavioral drift from the scripts that are already documented and validated.

## Decision: Keep module manifests and documentation as source of truth

**Rationale**: `nvim/dependencies.tsv`, `zsh/dependencies.tsv`, `ghostty/dependencies.tsv`, and
module READMEs already classify required, optional, Mason-backed, Homebrew, npm/pnpm, Go,
external, and manual dependencies. The installer should read or mirror these sources when
building action plans rather than hardcoding independent inventories.

**Alternatives considered**: Hardcoding module dependencies in Go would be fast initially but
would create drift from docs and validators.

## Decision: Default every top-level flow to preview/report before apply

**Rationale**: The feature spec and constitution both require non-destructive behavior. The TUI
should run validators and dry-run previews first, show an action plan, then require explicit
confirmation for mutating actions such as dependency bootstrap or config linking.

**Alternatives considered**: Immediate install-all after menu selection was rejected because it
would hide risk and conflict with the dry-run defaults already established by existing scripts.

## Decision: Classify modules by automation level

**Rationale**: Not every module has a safe linker or installer today. Neovim and Ghostty have
safe linkers; Neovim has dependency bootstrap support; zsh has validation but no linker; tmux,
keyboard, and broad macOS setup are currently documentation/manual-heavy. The TUI should expose
this honestly as automatic, confirmation-required, report-only, or manual-only work.

**Alternatives considered**: Treating every module as installable was rejected because it would
force unsafe automation for VIA import, TPM keypress installation, macOS security approvals, Git
SSH setup, and AWS local bundle repair.

## Decision: Do not invoke `setup/macos.sh` directly from the TUI

**Rationale**: `setup/macos.sh` performs broad mutations including Homebrew installation, shell
rc edits, global Git config, SSH key generation, cloning, and force-style symlinking with some
outdated paths. It is useful as historical setup intent, not as a safe one-click TUI action.

**Alternatives considered**: Wrapping the script as `install all` was rejected because it would
violate non-destructive, idempotent, and clear confirmation requirements.

## Decision: Normalize script and planner outcomes into report statuses

**Rationale**: The spec requires changed, skipped, failed, optional, manual, managed,
unmanaged, missing, backed-up, and removed states. A normalized report model lets the TUI show
consistent summaries while still preserving raw script output for troubleshooting.

**Alternatives considered**: Displaying only raw script output was rejected because it would make
the final report inconsistent across modules and harder to validate.

## Decision: Run external commands through Bubble Tea commands and a runner abstraction

**Rationale**: Bubble Tea `Update` functions should update model state and return commands.
Long-running validators/installers should run behind a runner abstraction so tests can fake
results and the TUI can surface progress or completion messages cleanly.

**Alternatives considered**: Blocking shell execution directly inside `Update` was rejected
because it makes the event loop less responsive and model tests harder.
