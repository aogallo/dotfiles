# Research: Windows Tooling Audit Document

## Decision: Deliver One Dedicated Docs Audit Document

**Rationale**: The audit cuts across `README.md`, `nvim/`, `Tmux/`, `ghostty/`, `zsh/`, `keyboard/`, `installer/`, and `setup/`. A dedicated `docs/windows-tooling-audit.md` keeps the report discoverable as user-facing documentation without forcing readers to open every module README.

**Alternatives considered**: Adding Windows notes inside every module README would scatter the answer and increase review effort. Adding the audit under `specs/` would hide a user-facing document inside planning artifacts. Keeping it at repository root was rejected because the user explicitly wants the document in `docs/`.

## Decision: Use Windows 11 as the Target Platform

**Rationale**: The spec assumes Windows 11 unless evidence says otherwise. It is the practical current target for Windows Terminal, WSL, winget, modern Neovim, and current development tooling.

**Alternatives considered**: Covering Windows 10 and older releases would expand the compatibility matrix without repository evidence requiring it. A generic "Windows" target would be too vague for installation guidance.

## Decision: Classify Tools by Practical Usage Path

**Rationale**: The document must distinguish native Windows support from WSL/Git Bash/MSYS2-dependent workflows. This prevents false confidence for tools whose binary exists on Windows but whose repository config assumes Unix paths, POSIX shells, macOS clipboards, Homebrew, or Apple-specific paths.

**Alternatives considered**: A binary yes/no compatibility status would be simpler but misleading. A highly granular support matrix would be harder to scan and would violate the user's request for a usable document.

## Decision: Prefer Official or Maintainer Documentation Links

**Rationale**: Installation guidance should point to trustworthy sources such as official docs, release pages, package-manager docs, or project repositories. This keeps the audit durable and avoids copying brittle third-party instructions.

**Alternatives considered**: Blog posts and ad hoc command snippets may be useful for troubleshooting, but they should not be the primary installation references unless no better source exists.

## Decision: Treat Repository Setup Scripts as Evidence, Not Actions

**Rationale**: The user explicitly requested no installations. Existing setup scripts document macOS assumptions and dependency sources, but running them is unnecessary and would risk side effects.

**Alternatives considered**: Running validators could provide live results for the current machine, but that would not answer Windows compatibility and could drift into environment mutation or machine-specific noise.

## Decision: Audit These Repository Areas First

**Rationale**: Current repository structure and module READMEs identify these as relevant to Windows compatibility: root `README.md`, `nvim/`, `Tmux/`, `ghostty/`, `zsh/`, `keyboard/`, `installer/`, `setup/`, and `.github/workflows/`. `dist/` and generated/local state should be out of scope unless referenced as generated artifacts.

**Alternatives considered**: Auditing every file equally would produce noise. Auditing only top-level README links would miss module-specific constraints such as `pbcopy`, Homebrew, macOS app paths, darwin release assets, and local override boundaries.

## Decision: Use a Reviewable Summary Table Plus Per-Tool Details

**Rationale**: The summary table satisfies the 30-second lookup success criterion, while per-tool sections provide the requested links, advantages, disadvantages, installation guidance, and caveats.

**Alternatives considered**: A prose-only report would be harder to scan. A table-only report would omit the reasoning needed for tradeoff decisions.
