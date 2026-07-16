# Research: Neovim Config Consolidation

## Decision: Use `nvim/` as the only maintained target

**Rationale**: The existing canonical config already has modular boundaries for options, keymaps, plugins, LSP configs, and dependencies. Keeping one maintained target prevents future drift and aligns with the source-of-truth requirement.

**Alternatives considered**: Maintain multiple configs in parallel; rejected because it preserves the current ambiguity. Replace `nvim/` wholesale with a legacy framework config; rejected because it imports unrelated assumptions and raises review risk.

## Decision: Split implementation into four work-unit branches

**Rationale**: Options, keymaps, plugins, and cleanup have different risks and validation needs. Four work-unit branches keep PRs reviewable and let each unit prove its own behavior before the integration branch reaches `main`.

**Alternatives considered**: One large PR; rejected because it mixes behavior migration with cleanup and increases review load. Four independent branches directly targeting `main`; rejected because the user wants a principal integration branch before merging to `main`.

## Decision: Integration branch is `feat/nvim-config-consolidation`

**Rationale**: The branch name follows the repository's conventional feature branch style and represents the full consolidation scope. Work-unit branches will target this branch, then the integration branch targets `main`.

**Alternatives considered**: Use the Spec Kit generated name `002-nvim-config-consolidation`; rejected for PR branch naming because repository guidance prefers conventional branch prefixes. Use work-unit branches directly from `main`; rejected because it does not provide the integration checkpoint the user requested.

## Decision: Record migration decisions before cleanup

**Rationale**: Legacy configs are still source material. Cleanup without decisions risks deleting behavior context before options, keymaps, and plugins have been evaluated.

**Alternatives considered**: Delete legacy configs first and recover from Git as needed; rejected because it makes review and comparison harder. Keep legacy configs forever; rejected because stale configs are the maintenance problem being solved.

## Decision: Plugin adoption requires purpose and dependency impact

**Rationale**: Current `nvim/` already includes plugin modules for Markdown, fuzzy finding, completion, editor behavior, diffview, formatting, Git signs, Treesitter, Mason, and schemastore. Legacy configs include overlapping tools such as conform, gitsigns, LSP, treesitter, completion, snacks, Octo, SQL, Java, testing, Kulala, Obsidian, img-clip, cloak, and tmux navigation. Adoption must be deliberate to avoid duplicate responsibilities.

**Alternatives considered**: Copy all legacy plugin declarations; rejected because it recreates framework complexity. Reject all legacy plugin ideas; rejected because some match the user's workflow, especially databases, SQL files, Docker-adjacent tooling, Go, Markdown, TypeScript, Python, and API workflows.

## Decision: Dependency inventory remains `nvim/dependencies.tsv`

**Rationale**: The repository already has a reviewable dependency inventory covering LSPs and formatters. Updating it keeps setup expectations visible and verifiable.

**Alternatives considered**: Document dependencies only in plugin files; rejected because dependency requirements become harder to audit. Add a new dependency file for this feature; rejected because it duplicates an existing source of truth.

## Decision: Validation combines static checks and smoke/manual checks

**Rationale**: Neovim config changes need Lua formatting, startup/module smoke checks, and manual checks for behavior that cannot be proven by static validation alone, such as keymap ergonomics and plugin workflow value.

**Alternatives considered**: Manual validation only; rejected because syntax errors should be caught earlier. Full automated integration testing; deferred because this dotfiles repo currently relies on targeted headless checks and manual quickstarts.

## Decision: Cleanup includes already-deleted local files

**Rationale**: `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, and `lazyvim/ftplugin/json.lua` are already deleted locally and must be treated as part of cleanup scope rather than accidental unrelated changes.

**Alternatives considered**: Ignore the local deletes; rejected because it leaves ambiguous worktree state. Restore them before planning; rejected because the user explicitly wanted cleanup of old Neovim versions and these files belong in that review.
