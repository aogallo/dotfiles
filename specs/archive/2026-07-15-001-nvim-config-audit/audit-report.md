# Neovim Configuration Audit Report

## Summary

- **Target Neovim version**: v0.12.1
- **Overall readiness status**: `ready-with-warnings`
- **Scope**: `nvim/` repository configuration and follow-up fixes applied in-place.
- **Finding counts after fixes**: Critical 0, High 0, Medium 2, Low 1, Info 17

Documentation sources used:

- Context7 `/neovim/neovim`: Neovim 0.12 LSP, `vim.pack`, diagnostics, and breaking changes.
- Context7 `/nvim-treesitter/nvim-treesitter`: parser management, native highlighting/folding, indentation.
- Context7 `/mason-org/mason.nvim`: Mason install root, PATH behavior, registry/package model.
- Context7 `/stevearc/conform.nvim`: `formatters_by_ft`, `format_on_save`, `lsp_format`, formatter options.
- Context7 `/saghen/blink.cmp`: LuaSnip integration and `get_lsp_capabilities()`.
- Context7 `/ibhagwan/fzf-lua`: `winopts.height`, `vim.ui.select`, diagnostics options.
- Context7 `/lewis6991/gitsigns.nvim`: `signs`, `signs_staged`, `current_line_blame`, and `on_attach` keymaps.
- Context7 `/folke/snacks.nvim`: `explorer`, `picker`, and `lazygit` setup patterns.
- Context7 `/obsidian-nvim/obsidian.nvim`: `workspaces`, `legacy_commands`, picker integration, and dynamic workspace paths.

Fixes applied after the initial audit:

- Removed deprecated diagnostic sign definition via `vim.fn.sign_define` while preserving
  the existing `signs = false` gutter behavior.
- Replaced hardcoded Obsidian notes path with optional `OBSIDIAN_NOTES_DIR` discovery.
- Replaced work-specific GitLinker host routing with optional `GITLINKER_ENTERPRISE_HOST`.
- Fixed fzf-lua `heigh` typos to `height`.
- Guarded LuaSnip usage in the global `<Esc>` mapping with `pcall`.
- Added a nil guard for `LspProgress` client lookup in the statusline.
- Fixed `PackClean` empty-state messaging.
- Moved Blink native matcher build to a plugin update hook and removed duplicate setup.
- Normalized Conform formatter lists for web filetypes.
- Ran `stylua nvim`; `stylua --check nvim` now passes.
- Added `nvim/dependencies.tsv` as the Neovim dependency source of truth.
- Added `setup/validate-nvim-deps.sh` for non-destructive dependency validation.
- Added `nvim/README.md` with validation commands and local override environment variables.
- Added `setup/bootstrap-nvim-deps.sh` with dry-run-first dependency bootstrap behavior.
- Added `setup/link-nvim-config.sh` with dry-run-first, conflict-aware Neovim symlink management.

## Configuration Coverage

| Area | Paths Reviewed | Status | Evidence Source | Notes |
|------|----------------|--------|-----------------|-------|
| Startup | `nvim/init.lua` | Has findings | Neovim docs | Uses modern `vim.lsp.config`; uses experimental/private UI module. |
| Plugin manager | `nvim/lua/vim-pack.lua`, `nvim/nvim-pack-lock.json` | Has findings | Neovim `vim.pack` docs | Good direction for 0.12, but build hooks need blocking/error handling review. |
| Options | `nvim/lua/config/options.lua` | Has findings | Neovim docs | `exrc` is intentionally powerful but should be documented as trust-sensitive. |
| Keymaps | `nvim/lua/config/keymaps.lua` | Has findings | Local validation | Requires LuaSnip during `<Esc>`, even before plugin is loaded. |
| Autocmds | `nvim/lua/config/autocmds.lua` | Has findings | Neovim/Treesitter docs | Treesitter folding pattern is broadly correct; `PackClean` has small UX issue. |
| Statusline | `nvim/lua/statusline.lua` | Has findings | Neovim LSP docs | Uses `LspProgress`; needs nil guard for client lookup. |
| Icons | `nvim/lua/icons.lua` | Correct | Code inspection | Static icon table. |
| LSP core | `nvim/lua/lsp.lua` | Has findings | Neovim 0.12 docs | Modern LSP enable/config use is good; diagnostics signs need update. |
| Lightbulb | `nvim/lua/lightbulb.lua` | Has findings | Neovim diagnostics behavior | Works locally because `vim.lsp.diagnostic.from` exists, but it is compatibility-layer style. |
| LSP servers | `nvim/lsp/*.lua` | Has findings | Neovim LSP docs | Config shape is modern; dependency declaration is incomplete. |
| Mason | `nvim/plugin/mason.lua` | Has findings | Mason docs | Manual registry install loop works, but should become declarative inventory. |
| Treesitter | `nvim/plugin/treesitter.lua` | Has findings | nvim-treesitter docs | Native `vim.treesitter.start()` usage is correct; parser install during setup can block. |
| Completion/snippets | `nvim/plugin/blink.lua` | Validated | blink.cmp docs | LuaSnip preset is correct; manual double setup/build path is resolved. |
| Formatting | `nvim/plugin/conform.lua`, `nvim/stylua.toml` | Has findings | conform.nvim docs | Several formatter entries mix formatter names and options incorrectly. |
| Fuzzy finder | `nvim/plugin/fzf-lua.lua` | Has findings | fzf-lua docs | Main setup is reasonable; `heigh` typos should be `height`. |
| Editor/Git/Markdown | `nvim/plugin/editor.lua`, `gitsigns.lua`, `markdown.lua`, `schemastore.lua` | Has findings | Code inspection + plugin docs where queried | Contains personal/work-specific settings. |
| Filetype config | `nvim/ftplugin/markdown.lua`, `nvim/after/ftplugin/markdown.lua` | Correct | Code inspection | Markdown local options are straightforward. |

## Findings

| ID | Severity | Classification | Location | Observation | Impact | Recommendation | Validation |
|----|----------|----------------|----------|-------------|--------|----------------|------------|
| F001 | Info | Resolved | `nvim/lua/lsp.lua` | Deprecated `vim.fn.sign_define` diagnostic setup was removed. | Preserves Neovim 0.12 compatibility while keeping gutter signs disabled. | Keep `vim.diagnostic.config({ signs = false })`. | `nvim --headless -u nvim/init.lua '+quitall'`. |
| F002 | Info | Resolved | `nvim/plugin/markdown.lua` | Obsidian workspace now uses optional `OBSIDIAN_NOTES_DIR`. | Shared config no longer commits a personal absolute path. | Document `OBSIDIAN_NOTES_DIR` in future bootstrap docs. | Start Neovim with and without `OBSIDIAN_NOTES_DIR`. |
| F003 | Info | Resolved | `nvim/dependencies.tsv`, `setup/validate-nvim-deps.sh` | Neovim tools are now declared in one manifest and validated by a non-destructive script. | A fresh machine can identify missing required and optional tools before installation work. | Keep the manifest updated when LSPs, formatters, or linters change. | `setup/validate-nvim-deps.sh`. |
| F004 | Medium | LSP modernization | `nvim/lua/lsp.lua:259-272` | Server discovery via runtime `lsp/*.lua` plus `vim.lsp.enable(servers)` is modern and appropriate for 0.12. | This is good, but every runtime `lsp/*.lua` becomes enabled automatically. | Keep this pattern; add explicit dependency validation and document that files under `lsp/` are activation boundary. | Add/remove one `lsp/*.lua` and verify `vim.lsp.is_enabled(name)`. |
| F005 | Info | Resolved | `nvim/lua/lightbulb.lua` | Code-action diagnostics conversion is isolated in `get_lsp_diagnostics()`. | `textDocument/codeAction` requires LSP-shaped diagnostics, so direct `vim.diagnostic.get()` would be the wrong shape. | Keep conversion documented near the call site. | Trigger code actions with diagnostics and confirm lightbulb still appears. |
| F006 | Info | Resolved | `nvim/plugin/treesitter.lua` | Parser install/update no longer runs during normal setup. | Startup no longer blocks on parser downloads. | Use `:TSInstallConfigured`, `:TSUpdateConfigured`, or plugin `PackChanged` flow for parser work. | Launch with parsers missing and confirm startup does not install/block. |
| F007 | Info | Resolved | `nvim/plugin/conform.lua` | Web formatter entries now list `prettier` and `dprint` directly. | Aligns with Conform formatter list semantics. | Keep options with the formatter list table. | Run `:ConformInfo` on JS/TS/JSON buffers. |
| F008 | Info | Resolved | `nvim/plugin/fzf-lua.lua` | `heigh` typos changed to `height`. | fzf-lua windows can now honor intended sizes. | None. | Open affected picker and verify dimensions. |
| F009 | Info | Resolved | `nvim/plugin/gitsigns.lua` | Enterprise host routing now uses optional `GITLINKER_ENTERPRISE_HOST`. | Work-specific hostname no longer lives in shared config. | Document env var in future bootstrap docs. | Start without env var and verify no error. |
| F010 | Info | Resolved | `nvim/plugin/blink.lua` | Blink build moved to `PackChanged`; setup remains handled by `vim-pack`. | Avoids duplicate setup/build on normal startup. | None. | Start Neovim and verify completion works. |
| F011 | Info | Resolved | `nvim/lua/config/keymaps.lua` | `<Esc>` LuaSnip access now uses `pcall`. | Keymap no longer errors if LuaSnip is not loaded. | None. | Press Esc before snippet load. |
| F012 | Info | Resolved | `nvim/**` | `stylua nvim` was run and `stylua --check nvim` passes. | Formatting drift removed. | Keep formatter check in validation. | `stylua --check nvim`. |
| F013 | Info | Resolved | `nvim/lua/config/keymaps.lua` | Comment typo corrected. | Cosmetic cleanup. | None. | Review diff. |
| F014 | Info | Resolved | `nvim/lua/config/autocmds.lua` | `PackClean` now reports no inactive plugins and returns early. | Clearer UX. | None. | Run `:PackClean` when no inactive packages exist. |
| F015 | Info | Resolved | `nvim/lua/statusline.lua` | `LspProgress` now guards missing client. | Avoids rare nil access. | None. | Headless startup passes. |
| F016 | Info | Resolved | `nvim/snippets/markdown.json` | Empty JSON snippet file was removed. | No placeholder snippet file remains to confuse future maintainers. | Add real snippets only when needed. | File is absent. |
| F017 | Info | Correct-modern | `nvim/init.lua:14-23`, `nvim/lua/lsp.lua:259-272` | Uses `vim.lsp.config('*', ...)` and `vim.lsp.enable(servers)`. | This is the modern Neovim 0.11+/0.12 direction and avoids legacy `lspconfig.setup()` boilerplate. | Keep this architecture. | `:lua print(vim.inspect(vim.lsp.get_configs()))`. |
| F018 | Info | Correct-modern | `nvim/lua/config/autocmds.lua:41-57` | Uses `vim.treesitter.start()` and `vim.treesitter.foldexpr()`. | Matches current Neovim-native Treesitter docs. | Keep, but ensure parsers are installed outside normal startup. | Open Lua/Go/TS file and verify highlighting/folds. |
| F019 | Info | Correct | `nvim/plugin/blink.lua:90` | Uses `snippets = { preset = 'luasnip' }`. | Matches Blink docs for LuaSnip integration. | Keep, but avoid double setup/build. | Confirm snippet completions appear. |
| F020 | Info | Correct | `nvim/plugin/mason.lua:8-24` | Mason `PATH = 'prepend'` and registry install loop are valid. | Mason-managed tools become discoverable in Neovim PATH. | Keep Mason as one source, but do not force all tools into Mason. | `:Mason` and `command -v` inside Neovim. |

## Dependency Inventory

| Dependency | Executable | Used By | Source | Required | Install Hint | Validation Command |
|------------|------------|---------|--------|----------|--------------|--------------------|
| Go language server | `gopls` | `nvim/lsp/gopls.lua` | external/language-toolchain | Yes for Go | `go install golang.org/x/tools/gopls@latest` | `command -v gopls` |
| TypeScript native preview | `tsgo` | `nvim/lsp/tsgo.lua` | external/language-toolchain | Yes for TS/JS LSP | `pnpm install -g @typescript/native-preview` | `command -v tsgo` |
| dprint | `dprint` | `nvim/lsp/dprint.lua`, `conform.lua` | homebrew/external | Optional | `brew install dprint` | `command -v dprint` |
| ty | `ty` | `nvim/lsp/ty.lua` | external | Optional Python LSP | `curl -LsSf https://astral.sh/ty/install.sh \| sh` | `command -v ty` |
| Lua language server | `lua-language-server` | `nvim/lsp/lua_ls.lua` | homebrew/external | Yes for Lua | `brew install lua-language-server` | `command -v lua-language-server` |
| JSON language server | `vscode-json-language-server` | `nvim/lsp/jsonls.lua` | mason/npm | Yes for JSON | Mason `json-lsp` or `pnpm add -g vscode-langservers-extracted` | `command -v vscode-json-language-server` |
| ESLint language server | `vscode-eslint-language-server` | `nvim/lsp/eslint.lua` | mason/npm | Yes for JS lint LSP | Mason `eslint-lsp` or `pnpm add -g vscode-langservers-extracted` | `command -v vscode-eslint-language-server` |
| CSS language server | `vscode-css-language-server` | `nvim/lsp/cssls.lua` | mason/npm | Yes for CSS | Mason `css-lsp` or `pnpm add -g vscode-langservers-extracted` | `command -v vscode-css-language-server` |
| HTML language server | `vscode-html-language-server` | `nvim/lsp/html.lua` | mason/npm | Yes for HTML | Mason `html-lsp` or `pnpm add -g vscode-langservers-extracted` | `command -v vscode-html-language-server` |
| Bash language server | `bash-language-server` | `nvim/lsp/bashls.lua` | npm/external | Optional shell LSP | `pnpm add -g bash-language-server` | `command -v bash-language-server` |
| YAML language server | `yaml-language-server` | `nvim/lsp/yamlls.lua` | mason/npm | Yes for YAML | Mason `yaml-language-server` or `pnpm add -g yaml-language-server` | `command -v yaml-language-server` |
| Marksman | `marksman` | `nvim/lsp/marksman.lua` | mason/homebrew | Optional Markdown LSP | `brew install marksman` or Mason `marksman` | `command -v marksman` |
| Stylelint LSP | `stylelint-lsp` | `nvim/lsp/stylelint_lsp.lua` | npm/external | Optional CSS lint LSP | `npm i -g stylelint-lsp` | `command -v stylelint-lsp` |
| Prettier | `prettier` | `nvim/plugin/conform.lua` | mason/npm | Yes for web formatting | Mason `prettier` or `pnpm add -g prettier` | `command -v prettier` |
| StyLua | `stylua` | `nvim/plugin/conform.lua`, `stylua.toml` | homebrew | Yes for Lua formatting | `brew install stylua` | `command -v stylua` |
| shfmt | `shfmt` | `nvim/plugin/conform.lua` | homebrew | Optional shell formatting | `brew install shfmt` | `command -v shfmt` |
| shellcheck | `shellcheck` | `nvim/lsp/bashls.lua` comment | homebrew | Optional shell diagnostics | `brew install shellcheck` | `command -v shellcheck` |

Local availability snapshot:

- Present: `tsgo`, `dprint`, `ty`, `lua-language-server`, `vscode-json-language-server`, `vscode-eslint-language-server`, `vscode-css-language-server`, `vscode-html-language-server`, `yaml-language-server`, `marksman`, `prettier`, `stylua`.
- Optional missing: `gopls`, `bash-language-server`, `stylelint-lsp`, `shfmt`, `shellcheck`.
- Required missing: none.

## Recommendation Priority

Must-fix before treating the Neovim module as bootstrap-ready: none currently open.

Optional improvements:

- Install optional tools when desired: `gopls`, `bash-language-server`, `stylelint-lsp`, `shfmt`, and `shellcheck`.
- Promote Mason package installation to a dedicated work unit if shell-driven bootstrap should install Mason packages automatically.

Resolved items to keep guarded in future changes:

- Keep Obsidian workspace path environment-aware: `OBSIDIAN_NOTES_DIR` or default `~/dev/notes`.
- Keep enterprise GitLinker host environment-aware: `GITLINKER_ENTERPRISE_HOST`.
- Keep dependency validation non-destructive by default.

## Plugin Evidence Summary

| Plugin/Area | Evidence | Current Status |
|-------------|----------|----------------|
| Neovim LSP | Context7 `/neovim/neovim` documents `vim.lsp.config()` and `vim.lsp.enable()`. | Correct modern pattern. |
| Diagnostics | Context7 `/neovim/neovim` documents 0.12 diagnostic sign changes. | `sign_define` issue resolved; signs remain disabled intentionally. |
| Treesitter | Context7 `/nvim-treesitter/nvim-treesitter` documents `vim.treesitter.start()`, `foldexpr()`, `install()`, `update()`, and `:TSUpdate`. | Runtime usage correct; parser work is explicit via configured commands and plugin update flow. |
| Mason | Context7 `/mason-org/mason.nvim` documents PATH and install root behavior. | Valid as one dependency source; manifest/validator added. |
| Conform | Context7 `/stevearc/conform.nvim` documents formatter list semantics. | Formatter list issue resolved. |
| Blink.cmp | Context7 `/saghen/blink.cmp` documents LuaSnip preset and build flow. | Double setup/build issue resolved. |
| fzf-lua | Context7 `/ibhagwan/fzf-lua` documents `winopts.height`. | Typo resolved. |
| gitsigns.nvim | Context7 `/lewis6991/gitsigns.nvim` documents `signs`, `signs_staged`, blame, and `on_attach`. | Config shape is valid; enterprise host override resolved. |
| snacks.nvim | Context7 `/folke/snacks.nvim` documents `explorer`, `picker`, and `lazygit`. | Config shape is valid. |
| obsidian.nvim | Context7 `/obsidian-nvim/obsidian.nvim` documents `workspaces` and `legacy_commands = false`. | Config shape is valid; path is portable with default/override. |

## Installer Readiness

- [x] **Portability**: Personal notes path and enterprise Git host are now environment-based.
- [x] **Idempotency**: Startup no longer blocks on Treesitter parser installs, and Blink build runs through plugin update flow.
- [x] **Non-destructive behavior**: `setup/link-nvim-config.sh` refuses conflicts unless `--backup` is explicit.
- [x] **Dependency declaration**: `nvim/dependencies.tsv` declares Mason-managed and external tools.
- [x] **Secret/local override separation**: No credentials found, but private/work config must move to local override.
- [x] **Validation commands**: Startup, healthcheck, formatter check, and executable checks are defined.
- [x] **Rollback/recovery**: `setup/link-nvim-config.sh --apply --remove` removes only managed symlinks; conflict backups go to `~/.dotfiles_backup`.

## Contract Acceptance

- [x] Every `nvim/` Lua file is represented in Configuration Coverage, either directly or through a scoped grouped row.
- [x] Every `nvim/lsp/*.lua` server config has a dependency inventory row.
- [x] There are no remaining high or critical findings after applied fixes.
- [x] Machine-specific settings are handled through `OBSIDIAN_NOTES_DIR`, `GITLINKER_ENTERPRISE_HOST`, or safe defaults.
- [x] Validation commands are documented and have been run locally.

Covered Lua files:

- `nvim/init.lua`
- `nvim/lua/config/autocmds.lua`
- `nvim/lua/config/keymaps.lua`
- `nvim/lua/config/options.lua`
- `nvim/lua/icons.lua`
- `nvim/lua/lightbulb.lua`
- `nvim/lua/lsp.lua`
- `nvim/lua/statusline.lua`
- `nvim/lua/vim-pack.lua`
- `nvim/plugin/blink.lua`
- `nvim/plugin/conform.lua`
- `nvim/plugin/editor.lua`
- `nvim/plugin/fzf-lua.lua`
- `nvim/plugin/gitsigns.lua`
- `nvim/plugin/markdown.lua`
- `nvim/plugin/mason.lua`
- `nvim/plugin/schemastore.lua`
- `nvim/plugin/treesitter.lua`
- `nvim/lsp/bashls.lua`
- `nvim/lsp/cssls.lua`
- `nvim/lsp/dprint.lua`
- `nvim/lsp/eslint.lua`
- `nvim/lsp/gopls.lua`
- `nvim/lsp/html.lua`
- `nvim/lsp/jsonls.lua`
- `nvim/lsp/lua_ls.lua`
- `nvim/lsp/marksman.lua`
- `nvim/lsp/stylelint_lsp.lua`
- `nvim/lsp/tsgo.lua`
- `nvim/lsp/ty.lua`
- `nvim/lsp/yamlls.lua`
- `nvim/ftplugin/markdown.lua`
- `nvim/after/ftplugin/markdown.lua`

## Constitution Gate Validation

- [x] **Portability**: no user-specific absolute paths remain in shared Lua config; notes/work host use environment variables or `$HOME`-based defaults.
- [x] **Idempotency**: validation and bootstrap scripts skip existing tools and are safe to re-run; linker no-ops on an already managed link.
- [x] **Non-destructive behavior**: linker refuses unmanaged conflicts unless `--backup` is explicit; dependency scripts do not remove anything.
- [x] **Modularity**: all new scripts target the Neovim module only.
- [x] **Source of truth**: `nvim/dependencies.tsv` is the declared dependency source; shared config remains under `nvim/`.
- [x] **Dependencies**: required/optional Neovim tools are declared and validated.
- [x] **Security**: no credentials or private keys were introduced; work/private values are environment-driven.
- [x] **Verification**: `stylua --check nvim`, headless startup, healthchecks, dependency validation, bootstrap dry-run, and linker dry-run were executed.
- [x] **Installer UX**: scripts print mode, paths, skipped/planned operations, conflicts, and final summaries.
- [x] **Recovery**: linker backups go to `~/.dotfiles_backup`; removal only applies to managed symlinks.
- [x] **Simplicity**: implementation uses small Bash scripts and TSV manifest, no new framework.
- [x] **Documentation**: `nvim/README.md` documents validation, bootstrap, linking, and local overrides.

## Open Questions

- Should work-specific Git routing such as `github.palantir.build` become a separate ignored local module or a named optional work profile?
- Should Obsidian workspace paths be disabled by default unless an environment variable is present, or should the plugin be optional entirely?
