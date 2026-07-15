# Implementation Plan: Neovim Config Audit

**Branch**: `001-nvim-config-audit` | **Date**: 2026-07-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-nvim-config-audit/spec.md`

## Summary

Audit the repository `nvim/` configuration for Neovim v0.12.1 readiness, focusing on LSP,
Treesitter, plugin management, completion, formatting, diagnostics, snippets, external
dependencies, and future dotfiles bootstrap safety. The plan uses a documentation-backed
review: inspect the current Lua configuration, verify version-sensitive behavior with
Context7 and primary documentation, produce a structured audit report, and capture a
portable dependency strategy that can feed installer work later.

## Technical Context

**Language/Version**: Lua configuration for Neovim v0.12.1 target compatibility.

**Primary Dependencies**: Neovim core APIs (`vim.pack`, `vim.lsp.config`,
`vim.lsp.enable`, `vim.diagnostic.config`, Treesitter APIs), `mason.nvim`,
`nvim-treesitter`, `blink.cmp`, `LuaSnip`, `conform.nvim`, `fzf-lua`, `gitsigns.nvim`,
`snacks.nvim`, `obsidian.nvim`, Markdown plugins, and language servers referenced under
`nvim/lsp/`.

**Storage**: Repository files under `nvim/`, plugin lock data in
`nvim/nvim-pack-lock.json`, local Neovim data/cache locations at runtime, and future
ignored local override files if introduced by follow-up work.

**Testing**: Static Lua formatting via StyLua, Neovim headless startup checks, `:checkhealth`
for Neovim/Mason/Treesitter where available, LSP executable availability checks, parser
availability checks, repeated install/update smoke checks, and conflict/rollback tests in
future installer tasks.

**Target Platform**: macOS dotfiles, supporting Apple Silicon and Intel Macs where
practical; current audit should not introduce platform-specific absolute paths.

**Project Type**: Dotfiles/editor configuration audit and installer-readiness design.

**Performance Goals**: Startup and plugin loading recommendations should avoid unnecessary
blocking installs during normal editing. Any long-running install/update behavior must be
called out for later bootstrap-only handling.

**Constraints**: Must use documentation evidence for version-sensitive claims, must support
externally installed language servers when Mason is insufficient, must preserve user-owned
configuration in future installation work, and must not treat machine-local state as shared
configuration.

**Scale/Scope**: One Neovim module tree: `nvim/init.lua`, `nvim/lua/**`, `nvim/plugin/**`,
`nvim/lsp/**`, `nvim/ftplugin/**`, `nvim/after/**`, snippets, lockfile, and formatter
configuration.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS with required follow-up checks. The audit explicitly includes
  absolute path detection. Known preliminary risk: `nvim/plugin/markdown.lua` hardcodes
  `/Users/allan/dev/notes` for Obsidian and must be classified as non-portable.
- **Idempotency**: PASS for planning. The audit must flag plugin, parser, Mason, and future
  installer behavior that performs repeated installs or duplicated side effects.
- **Non-destructive safety**: PASS for planning. The audit itself is read-only; follow-up
  installer recommendations must require conflict detection, backups, and safe failure.
- **Modularity**: PASS. The scope is limited to the Neovim module and must not require tmux,
  Ghostty, lazygit, or unrelated modules to proceed.
- **Source of truth**: PASS with required validation. Shared config under `nvim/` must be
  separated from generated plugin data, local notes paths, work-specific settings, and
  private overrides.
- **Dependencies**: PASS with required inventory. All LSPs, formatters, parsers, and CLI
  tools referenced by config must be classified as Mason-managed, externally installed,
  optional, or unresolved.
- **Security**: PASS with required scan. The audit must identify committed personal paths,
  private hostnames, credentials, or work-specific identifiers. Known preliminary risks:
  Obsidian personal path and `github.palantir.build` routing are local/work-specific.
- **Verification**: PASS for plan. The design includes headless startup, health checks,
  parser checks, LSP executable checks, and report completeness validation.
- **Installer UX**: PASS for plan. The audit must produce findings actionable enough to
  inform future progress, skip/fail reporting, and final summary design.
- **Recovery**: PASS for plan. The audit must identify restore/unlink/backup requirements
  for future managed Neovim files.
- **Maintainability**: PASS. The approach uses existing files and documentation-backed
  review without introducing new frameworks.
- **Documentation**: PASS. Outputs include research, data model, quickstart validation, and
  an audit report contract for the next phase.

Post-design re-check: PASS. No constitutional exception is required for the audit phase.
The implementation phase must not modify user configuration directly; any fixes must remain
repository-local and validated before completion.

## Project Structure

### Documentation (this feature)

```text
specs/001-nvim-config-audit/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── audit-report.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── init.lua
├── lua/
│   ├── config/
│   │   ├── autocmds.lua
│   │   ├── keymaps.lua
│   │   └── options.lua
│   ├── icons.lua
│   ├── lightbulb.lua
│   ├── lsp.lua
│   ├── statusline.lua
│   └── vim-pack.lua
├── plugin/
│   ├── blink.lua
│   ├── conform.lua
│   ├── editor.lua
│   ├── fzf-lua.lua
│   ├── gitsigns.lua
│   ├── markdown.lua
│   ├── mason.lua
│   ├── schemastore.lua
│   └── treesitter.lua
├── lsp/
│   ├── bashls.lua
│   ├── cssls.lua
│   ├── dprint.lua
│   ├── eslint.lua
│   ├── gopls.lua
│   ├── html.lua
│   ├── jsonls.lua
│   ├── lua_ls.lua
│   ├── marksman.lua
│   ├── stylelint_lsp.lua
│   ├── tsgo.lua
│   ├── ty.lua
│   └── yamlls.lua
├── ftplugin/
├── after/
├── snippets/
├── nvim-pack-lock.json
└── stylua.toml
```

**Structure Decision**: Use the existing Neovim module layout as the audit boundary. Do not
introduce implementation directories during planning. The only new files in this phase are
SDD artifacts under `specs/001-nvim-config-audit/`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
