# Quickstart: Validate the Windows Tooling Audit

Use this guide after `docs/windows-tooling-audit.md` is written. It validates that the feature meets the spec without installing anything.

## Prerequisites

- Work from the repository root.
- Do not run setup, bootstrap, installer, or package-manager installation commands as part of this validation.
- Review these artifacts first:
  - [spec.md](./spec.md)
  - [data-model.md](./data-model.md)
  - [contracts/windows-tooling-audit.md](./contracts/windows-tooling-audit.md)

## Scenario 1: Coverage Review

1. Open `docs/windows-tooling-audit.md`.
2. Confirm the summary table includes or explicitly excludes:
   - `README.md`
   - `nvim/`
   - `Tmux/`
   - `ghostty/`
   - `zsh/`
   - `keyboard/`
   - `installer/`
   - `setup/`
   - `.github/workflows/`
   - `dist/` when relevant as generated output
3. Expected result: 100% of relevant top-level repository areas are represented or marked out of scope.

## Scenario 2: Tool Detail Review

1. Pick three audited items from the summary table: one compatible, one partially compatible, and one not compatible or unknown if present.
2. For each selected item, confirm the detail section includes:
   - Windows compatibility status.
   - Repository evidence path.
   - Recommended usage path.
   - Rationale.
   - Official or reputable link, or a reason no link was found.
   - Installation guidance when compatible or partially compatible.
   - Advantages and disadvantages when compatible or partially compatible.
3. Expected result: The detail sections satisfy the contract without requiring source-code knowledge.

## Scenario 3: Non-Destructive Scope Review

1. Search the final document for wording that implies installation already happened.
2. Confirm any installation commands are clearly presented as optional future/manual guidance.
3. Confirm the feature did not add scripts, modify setup automation, or change user configuration paths.
4. Expected result: The feature remains documentation-only.

## Scenario 4: Windows Path Clarity

1. Review entries for tools with Unix/macOS assumptions such as shell config, tmux clipboard, Homebrew, Ghostty app paths, Xcode Command Line Tools, and darwin-only installer releases.
2. Confirm each entry distinguishes native Windows usage from WSL, Git Bash, MSYS2, or unsupported workflows.
3. Expected result: The user can avoid confusing "tool has a Windows build" with "this repository config works unchanged on Windows".

## Scenario 5: Fast Lookup

1. Ask a reviewer to find the Windows status and recommended usage path for Neovim, tmux, Ghostty, zsh, and the Go installer from the summary table.
2. Expected result: Each answer is findable in under 30 seconds without reading the full detail sections.
