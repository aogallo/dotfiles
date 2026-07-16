# Migration Decisions: Neovim Config Consolidation

**Purpose**: Record adopt, reject, and defer decisions while consolidating legacy Neovim configuration into `nvim/`.

**Feature**: [spec.md](./spec.md)

## Decision Format

Use one row per reviewed behavior.

| Source | Area | Decision | Target | Rationale | Dependency Impact | Validation |
|--------|------|----------|--------|-----------|-------------------|------------|
| `path/to/source.lua` | options/keymaps/plugins/cleanup | adopt/reject/defer | `path/to/target.lua` or N/A | Why this decision is correct | none/optional/required/removed | Command, manual check, or review note |

## Source Of Truth

`nvim/` is the canonical maintained Neovim configuration. `lvim/`, `kickstart.nvim/`, and `lazyvim/` are source material until cleanup is approved.

### Canonical Target Paths

| Area | Canonical Path | Ownership Decision | Validation |
|------|----------------|--------------------|------------|
| Options | `nvim/lua/config/options.lua` | Source of truth for portable editor defaults. | Reviewed against `data-model.md` fields and options workstream scope. |
| Keymaps | `nvim/lua/config/keymaps.lua` | Source of truth for maintained keymaps; legacy keymaps remain source material until T019+. | Reviewed against `data-model.md`; no keymap implementation in options slice. |
| Plugins | `nvim/plugin/` and `nvim/lsp/` | Source of truth for plugin and LSP behavior; dependency declarations live in `nvim/dependencies.tsv`. | Reviewed against `data-model.md`; no plugin implementation in options slice. |
| Dependencies | `nvim/dependencies.tsv` | Source of truth for required/optional Neovim tooling dependencies. | Reviewed against `data-model.md`; no dependency changes in options slice. |

### Legacy Source Paths

| Legacy Config | Source Paths | Current Role | Cleanup Status |
|---------------|--------------|--------------|----------------|
| LunarVim | `lvim/config.lua`, `lvim/lazy-lock.json`, `lvim/snippets/` | Source material for options, keymaps, plugins, LSP, formatting, snippets, and workflow ideas. | Cleanup approved after options, keymaps, and plugins decisions were recorded. |
| Kickstart | `kickstart.nvim/init.lua`, `kickstart.nvim/lua/config/`, `kickstart.nvim/lua/custom/plugins/`, `kickstart.nvim/lua/kickstart/plugins/`, `kickstart.nvim/snippets/` | Source material for options, keymaps, plugin ideas, snippets, and framework defaults. | Cleanup approved after options, keymaps, and plugins decisions were recorded; includes existing local deletes. |
| LazyVim | `lazyvim/init.lua`, `lazyvim/lua/config/`, `lazyvim/lua/plugins/`, `lazyvim/snippets-as-vscode/` | Source material for options, keymaps, plugin ideas, snippets, and framework defaults. | Cleanup approved after options, keymaps, and plugins decisions were recorded; includes existing local deletes. |

### Workstream Scope Evidence

| Workstream | Branch | Target | Scope | Validation Path | Status |
|------------|--------|--------|-------|-----------------|--------|
| Options | `feat/nvim-options-consolidation` | `feat/nvim-config-consolidation` | `nvim/lua/config/options.lua`, `lvim/config.lua`, `kickstart.nvim/lua/config/options.lua`, `lazyvim/lua/config/options.lua` | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` | Active in T016-T018. |
| Keymaps | `feat/nvim-keymaps-consolidation` | `feat/nvim-config-consolidation` | `nvim/lua/config/keymaps.lua`, legacy keymap sources | `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml` plus conflict review | Prepared; implementation deferred to T019-T021. |
| Plugins | `feat/nvim-plugins-consolidation` | `feat/nvim-config-consolidation` | `nvim/plugin/`, `nvim/lsp/`, `nvim/dependencies.tsv`, legacy plugin sources | `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml` plus smoke check | Prepared; implementation deferred to T022-T025. |
| Cleanup | `chore/nvim-legacy-cleanup` | `feat/nvim-config-consolidation` | `lvim/`, `kickstart.nvim/`, `lazyvim/`, cleanup notes | `git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation` | Prepared; cleanup deferred to T028-T033. |

No `.specify/extensions.yml` hook is required for this tasks artifact; filesystem/spec artifacts are updated directly.

## Options Decisions

| Source | Area | Decision | Target | Rationale | Dependency Impact | Validation |
|--------|------|----------|--------|-----------|-------------------|------------|
| `lvim/config.lua` | options | adopt | `nvim/lua/config/options.lua` | `shiftwidth=2`, `tabstop=2`, and relative numbers already match canonical behavior; no code change needed. | none | Reviewed current canonical values. |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `showmode=false` avoids redundant mode text when a statusline is active. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `breakindent=true` improves wrapped-line readability and complements canonical `linebreak=true`. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `splitright=true` and `splitbelow=true` make new splits open in the expected reading direction without adding dependencies. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `inccommand=split` provides live substitution preview with native Neovim behavior. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `cursorline=true` improves current-line orientation and has no portability impact. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `scrolloff=10` preserves context around the cursor while navigating. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | adopt | `nvim/lua/config/options.lua` | `hlsearch=true` keeps search matches visible; canonical `<Esc>` mapping already clears highlights intentionally. | none | `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml` |
| `kickstart.nvim/lua/config/options.lua` | options | reject | N/A | `vim._so_trails` uses private Neovim internals for local dynamic-library loading and is not portable shared configuration. | none | Reviewed against constitution portability and source-of-truth gates. |
| `kickstart.nvim/lua/config/options.lua` | options | reject | N/A | `vim.g.have_nerd_font` is a Kickstart framework flag and has no canonical consumer in `nvim/`. | none | Reviewed canonical config ownership. |
| `kickstart.nvim/lua/config/options.lua` | options | reject | N/A | `updatetime=250` and `timeoutlen=300` would override existing canonical latency choices without a documented workflow benefit. | none | Preserved canonical `updatetime=300` and `timeoutlen=500`. |
| `kickstart.nvim/lua/config/options.lua` | options | reject | N/A | Kickstart `listchars` would remove canonical visible-space behavior; existing `nvim/` whitespace display remains deliberate. | none | Preserved canonical `listchars`. |
| `kickstart.nvim/lua/config/options.lua` | options | reject | N/A | Global `spell=true` and `spelllang=en_us` would affect all buffers, including code, and should not be imported blindly. | none | Reviewed against preserve-behavior requirement. |
| `lvim/config.lua` | options | defer | N/A | `format_on_save` and trailing-whitespace autocmd behavior belong with formatting/plugin workflow review rather than the options slice. | optional | Deferred to plugins/tooling review. |
| `lazyvim/lua/config/options.lua` | options | reject | N/A | File contains no project-specific option behavior beyond LazyVim defaults, so there is nothing portable to migrate. | none | Reviewed source file. |

## Keymaps Decisions

| Source | Area | Decision | Target | Rationale | Dependency Impact | Validation |
|--------|------|----------|--------|-----------|-------------------|------------|
| `lvim/config.lua`, `lazyvim/lua/config/keymaps.lua` | keymaps | adopt | `nvim/lua/config/keymaps.lua` | Insert-mode `JK` complements existing `jk` without conflicting with canonical behavior. | none | Conflict review: no existing `JK` mapping; `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`. |
| `lvim/config.lua` | keymaps | adopt | `nvim/lua/config/keymaps.lua` | Normal-mode `<C-s>` provides an explicit save shortcut and does not overlap with existing canonical mappings. | none | Conflict review: no existing `<C-s>` mapping; `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`. |
| `lvim/config.lua` | keymaps | adopt | `nvim/lua/config/keymaps.lua` | Buffer close behavior is useful, but canonicalizes it under the existing buffer prefix as `<leader>bx` instead of legacy `<leader>x`. | none | Conflict review: no existing `<leader>bx`; `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | adopt | `nvim/lua/config/keymaps.lua` | Diagnostic navigation with `[d` and `]d` uses standard mnemonic bindings without changing existing `<leader>cd` diagnostic float behavior. | none | Conflict review: no existing `[d`/`]d`; `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | adopt | `nvim/lua/config/keymaps.lua` | Diagnostic list behavior is useful, but canonicalizes it as `<leader>cq` under the existing code/diagnostics prefix instead of legacy `<leader>q`. | none | Conflict review: no existing `<leader>cq`; `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`. |
| `kickstart.nvim/lua/config/keymaps.lua`, `lazyvim/lua/config/keymaps.lua` | keymaps | reject | N/A | Terminal escape with `<Esc><Esc>` is not desired in the canonical keymap set. | none | User rejected after reviewing keymap decisions; removed from `nvim/lua/config/keymaps.lua`. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | reject | N/A | `<C-,>` and `<C-.>` split resize mappings are not desired in the canonical keymap set. | none | User rejected after reviewing keymap decisions; removed from `nvim/lua/config/keymaps.lua`. |
| `kickstart.nvim/lua/config/keymaps.lua`, `lazyvim/lua/config/keymaps.lua` | keymaps | adopt | `nvim/lua/config/keymaps.lua` | Visual `J`/`K` line movement preserves visual selection and imports a common editing workflow. | none | Conflict review: no existing visual `J`/`K` mapping; `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`. |
| `lazyvim/lua/config/keymaps.lua` | keymaps | reject | N/A | Bottom terminal opener `,st` is not desired in the canonical keymap set. | none | User rejected after reviewing keymap decisions; removed from `nvim/lua/config/keymaps.lua`. |
| `kickstart.nvim/lua/config/keymaps.lua`, `lazyvim/lua/config/keymaps.lua` | keymaps | reject | N/A | JQ filter cleanup via `<leader>cj` is not desired in the canonical keymap set. | none | User rejected after reviewing keymap decisions; removed from `nvim/lua/config/keymaps.lua`. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | reject | N/A | Normal and visual `+`/`-` increment mappings override built-in line navigation behavior without enough evidence that canonical `nvim/` should change it. | none | Conflict review recorded; no code change. |
| `kickstart.nvim/lua/config/keymaps.lua`, `lazyvim/lua/config/keymaps.lua` | keymaps | reject | N/A | Plain `<Esc>` nohlsearch duplicates the existing canonical powerful `<Esc>` mapping, which already clears highlights and handles snippet sessions. | none | Preserved canonical mapping. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | reject | N/A | `L`/`H` buffer navigation overrides native screen-position motions and duplicates existing `<leader>bn`/`<leader>bp`. | none | Conflict review recorded; no code change. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | reject | N/A | `<leader>e` diagnostic float duplicates canonical `<leader>cd`; `<leader>q` is rejected in favor of adopted `<leader>cq`. | none | Conflict review recorded; no code change. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | reject | N/A | `;bn` new-buffer mapping introduces a second buffer namespace instead of extending the canonical `<leader>b` buffer prefix. | none | Conflict review recorded; no code change. |
| `kickstart.nvim/lua/config/keymaps.lua` | keymaps | reject | N/A | `<Tab>`, `<S-Tab>`, and `<S-t>` tab mappings add tab-page workflow that is not present in canonical `nvim/`; `<S-t>` also conflicts with Kickstart's own split resize mapping. | none | Conflict review recorded; no code change. |
| `lazyvim/lua/config/keymaps.lua` | keymaps | reject | N/A | `<C-a>` select-all conflicts with the built-in increment command and with the rejected increment/decrement keymap family. | none | Conflict review recorded; no code change. |
| `lazyvim/lua/config/keymaps.lua` | keymaps | reject | N/A | Normal-mode `x` black-hole delete changes core register behavior and is not necessary because canonical visual paste already preserves yanked text. | none | Conflict review recorded; no code change. |
| `lvim/config.lua` | keymaps | defer | N/A | `<S-x>` BufferKill, `<S-l>`/`<S-h>` BufferLine, `<C-t>` terminal, `<leader>dt` Trouble, Markdown preview, and ToggleTerm mappings depend on plugin choices and belong in the plugins/tooling review. | optional | Deferred to T022-T027 plugin workflow review. |

## Plugins And Tooling Decisions

| Source | Area | Decision | Target | Rationale | Dependency Impact | Validation |
|--------|------|----------|--------|-----------|-------------------|------------|
| `kickstart.nvim/lua/custom/plugins/markdown-stuff.lua`, `lvim/config.lua`, `lazyvim/lua/plugins/obsidian.lua` | plugins | covered | `nvim/plugin/markdown.lua`, `nvim/lsp/marksman.lua` | Markdown preview, rendered Markdown, Obsidian notes, and Marksman LSP are already covered by canonical Markdown modules. Legacy private vault paths are not portable and were not copied. | none | Reviewed canonical Markdown plugin and dependency inventory; `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`. |
| `kickstart.nvim/lua/custom/plugins/sql.lua` | plugins | adopt | `nvim/plugin/database.lua` | `vim-dadbod` and `vim-dadbod-ui` add concrete database exploration and query execution value without copying a full legacy distribution. Local DB UI state is written under Neovim data, not the repository. | optional | `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`; `nvim --headless '+quitall'`. |
| `kickstart.nvim/lua/custom/plugins/lsp.lua` | LSP | adopt | `nvim/lsp/sqls.lua`, `nvim/dependencies.tsv` | SQL files gain language-server diagnostics/completion hooks through `sqls`; the tool remains optional so missing SQL tooling does not block unrelated startup. | optional | `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`; dependency row reviewed. |
| `kickstart.nvim/lua/custom/plugins/lsp.lua` | LSP | adopt | `nvim/lsp/dockerls.lua`, `nvim/dependencies.tsv` | Dockerfile LSP support complements the existing Dockerfile Treesitter parser and covers Docker workflow without adding framework-specific Docker tooling. | optional | `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`; dependency row reviewed. |
| `kickstart.nvim/lua/custom/plugins/lsp.lua`, `nvim/plugin/conform.lua` | dependencies | adopt | `nvim/dependencies.tsv` | Canonical Python formatting already uses `ruff_format`; declaring `ruff` closes the dependency inventory gap for Python workflow support. | optional | Dependency row reviewed; `nvim --headless '+quitall'`. |
| `lazyvim/lua/plugins/treesitter.lua` | plugins | adopt | `nvim/plugin/treesitter.lua` | The SQL parser adds syntax coverage for SQL files and database workflows with low maintenance cost. Existing TypeScript, Python, Dockerfile, Go, Markdown, GraphQL, YAML, Terraform, and HCL parsers are already covered. | none | `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`. |
| `kickstart.nvim/lua/custom/plugins/conform.lua`, `lvim/config.lua` | plugins | covered | `nvim/plugin/conform.lua` | Format-on-save and formatters for TypeScript, Python, Go, Markdown, YAML, JSON, shell, Terraform, and whitespace trimming are already represented in the canonical Conform setup. No legacy formatter stack was copied wholesale. | optional | Reviewed canonical Conform setup and `nvim/dependencies.tsv`. |
| `kickstart.nvim/lua/custom/plugins/lsp.lua`, `lazyvim/lua/plugins/lsp.lua` | LSP | covered | `nvim/lsp/*.lua`, `nvim/plugin/mason.lua`, `nvim/dependencies.tsv` | Canonical LSP configs already cover TypeScript, Python, Go, Markdown, JSON/YAML schemas, HTML/CSS, Bash, Lua, and stylelint. Only SQL and Docker LSP gaps were added. | optional | Reviewed canonical LSP files and Mason/dependency inventory. |
| `kickstart.nvim/lua/custom/plugins/snacks.lua`, `lazyvim/lua/plugins/snacks.lua` | plugins | covered | `nvim/plugin/editor.lua` | Snacks explorer, lazygit, and buffer deletion are already covered. Terminal/image/dashboard extras were not adopted because they add separate UI responsibilities without enough current workflow value. | none | Duplicate responsibility review recorded. |
| `kickstart.nvim/lua/custom/plugins/gitsigns.lua`, `lazyvim/lua/plugins/gitsigns.lua` | plugins | covered | `nvim/plugin/gitsigns.lua` | Git signs, blame, hunk navigation, and git-link behavior are already covered by canonical Gitsigns/Gitlinker configuration. | none | Duplicate responsibility review recorded. |
| `kickstart.nvim/lua/custom/plugins/tmux-navigator.lua` | plugins | covered | `nvim/plugin/editor.lua`, `nvim/lua/config/keymaps.lua` | Tmux-aware navigation plugin is already declared and canonical window keymaps are in place. | none | Duplicate responsibility review recorded. |
| `lazyvim/lua/plugins/autocompletion.lua`, `kickstart.nvim/lua/custom/plugins/cmp.lua` | plugins | covered | `nvim/plugin/blink.lua` | Completion and snippet behavior is already implemented with Blink and LuaSnip; importing nvim-cmp or alternate Blink presets would duplicate completion ownership. | none | Duplicate responsibility review recorded. |
| `kickstart.nvim/lua/custom/plugins/trouble.lua` | plugins | reject | N/A | Diagnostics are already available through built-in lists, fzf-lua diagnostics, and adopted diagnostic keymaps; Trouble would add another diagnostics UI without concrete current need. | none | Duplicate responsibility review recorded. |
| `kickstart.nvim/lua/custom/plugins/testing.lua`, `kickstart.nvim/lua/custom/plugins/nvim-dap-go.lua`, `lvim/config.lua` | plugins | defer | N/A | Neotest, DAP, and JavaScript/Go debug setup are useful but larger workflow areas than this plugins/tooling consolidation slice and need separate test/debug design to avoid speculative dependencies. | optional | Deferred by scope review; no code change. |
| `kickstart.nvim/lua/custom/plugins/kulala.lua` | plugins | defer | N/A | REST/API execution may be useful for Serverless work, but this repository already removed unrelated HTTP ftplugin material pending cleanup review; adopting Kulala needs a separate API workflow decision. | optional | Deferred by scope review; no code change. |
| `lazyvim/lua/plugins/cloak.lua` | plugins | reject | N/A | Secret masking is valuable in principle, but shared dotfiles must keep secrets out of the repo; adding cloak without project-specific secret patterns would be speculative. | none | Security gate review; no code change. |
| `kickstart.nvim/lua/custom/plugins/java.lua`, `kickstart.nvim/lua/custom/plugins/sonarlint.lua`, `kickstart.nvim/lua/custom/plugins/octo.lua`, `lazyvim/lua/plugins/octo.lua` | plugins | reject | N/A | Java, SonarLint, and Octo are outside the requested workflow list for this batch or duplicate external CLI/browser workflows without enough current evidence. | optional | Scope review; no code change. |
| `kickstart.nvim/lua/custom/plugins/nvim-ts-autotag.lua`, `lvim/config.lua` | plugins | reject | N/A | Auto-tagging is web-framework-specific and not necessary for the requested Markdown, TypeScript, Python, Serverless, database, SQL, Docker, or Go coverage. | none | Scope review; no code change. |
| `kickstart.nvim/lua/custom/plugins/lazygit.lua`, `kickstart.nvim/lua/custom/plugins/ui.lua`, `kickstart.nvim/lua/custom/plugins/which-key.lua`, `kickstart.nvim/lua/custom/plugins/colorscheme.lua`, `kickstart.nvim/lua/custom/plugins/mini.lua`, `lazyvim/lua/plugins/mini.pairs.lua`, `lazyvim/lua/plugins/telescope.lua`, `lazyvim/lua/plugins/outline.lua`, `lazyvim/lua/plugins/example.lua` | plugins | covered | `nvim/plugin/editor.lua`, `nvim/plugin/fzf-lua.lua` | Canonical config already owns editor UI, colorscheme, which-key groups, lazygit, fuzzy finding, and related UI helpers; copying legacy UI/plugin framework modules would increase duplicate responsibility. | none | Duplicate responsibility review recorded. |

## Workflow Coverage Inventory

Track whether canonical `nvim/` support is adopted, rejected, or deferred for each workflow area.

| Workflow | Decision | Target | Rationale | Dependency Impact | Validation |
|----------|----------|--------|-----------|-------------------|------------|
| Markdown | covered | `nvim/plugin/markdown.lua`, `nvim/lsp/marksman.lua`, `nvim/plugin/conform.lua`, `nvim/plugin/treesitter.lua` | Canonical config already provides preview/rendering, Obsidian notes via portable env/default path, Marksman, Treesitter, and Prettier formatting. | optional | Reviewed canonical Markdown files; validation commands recorded below. |
| TypeScript | covered | `nvim/lsp/tsgo.lua`, `nvim/lsp/eslint.lua`, `nvim/plugin/conform.lua`, `nvim/plugin/treesitter.lua` | TypeScript has native-preview LSP, ESLint, Prettier/dprint formatting, TS/TSX Treesitter, and completion via Blink. | required/optional mix | Dependency rows for `tsgo`, ESLint, Prettier, and dprint reviewed. |
| Python | covered | `nvim/lsp/ty.lua`, `nvim/plugin/conform.lua`, `nvim/plugin/treesitter.lua`, `nvim/dependencies.tsv` | Python has ty LSP, Ruff formatting, and Treesitter; the missing Ruff dependency row was added. | optional | Dependency row reviewed; validation commands recorded below. |
| Serverless Framework | covered | `nvim/lsp/yamlls.lua`, `nvim/lsp/jsonls.lua`, `nvim/plugin/schemastore.lua`, `nvim/plugin/treesitter.lua` | Serverless YAML/JSON workflows are covered by YAML/JSON LSP plus SchemaStore rather than a framework-specific plugin. Kulala/API execution is deferred. | optional | Reviewed SchemaStore-backed YAML/JSON LSP coverage. |
| Databases | adopt | `nvim/plugin/database.lua` | Added vim-dadbod and vim-dadbod-ui for database exploration and query execution without committing local connection state. | optional | `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`; `nvim --headless '+quitall'`. |
| SQL files | adopt | `nvim/lsp/sqls.lua`, `nvim/plugin/treesitter.lua`, `nvim/dependencies.tsv` | Added SQL LSP and SQL Treesitter parser for SQL-file editing while keeping `sqls` optional. | optional | Dependency row reviewed; validation commands recorded below. |
| Docker | adopt | `nvim/lsp/dockerls.lua`, `nvim/plugin/treesitter.lua`, `nvim/dependencies.tsv` | Added Dockerfile LSP to complement existing Dockerfile Treesitter coverage. Compose/Serverless YAML remains covered by YAML LSP and SchemaStore. | optional | Dependency row reviewed; validation commands recorded below. |
| Go | covered | `nvim/lsp/gopls.lua`, `nvim/plugin/conform.lua`, `nvim/plugin/treesitter.lua`, `nvim/dependencies.tsv` | Go has gopls, Treesitter, and Conform LSP-preferred formatting; DAP/neotest additions are deferred as a separate test/debug workflow. | optional | Dependency row reviewed; validation commands recorded below. |

## Duplicate And Idempotency Findings

| Area | Finding | Resolution | Validation |
|------|---------|------------|------------|
| Plugins | Legacy Markdown, Gitsigns, Snacks, tmux navigator, completion, LSP, Conform, Schemas, Treesitter, Diffview, fuzzy finding, colorscheme, and which-key responsibilities overlap with existing canonical modules. | Recorded as covered/rejected rather than duplicating plugin declarations. | Reviewed `nvim/plugin/*.lua`, `nvim/lsp/*.lua`, and legacy plugin sources. |
| LSP | Canonical `vim.lsp.enable()` loads every `nvim/lsp/*.lua` config; duplicate server configs would auto-enable duplicate clients for the same filetypes. | Added only missing `sqls` and `dockerls`; preserved existing TypeScript, Python, Go, Markdown, JSON/YAML, HTML/CSS, Bash, Lua, and stylelint configs. | Reviewed `nvim/lua/lsp.lua` and `nvim/lsp/*.lua`. |
| Dependencies | `ruff_format` was used by canonical Conform but `ruff` was not declared; SQL and Docker LSP additions also needed dependency rows. | Added optional dependency rows for `ruff`, `sqls`, and `docker-langserver`; existing rows were not duplicated. | Reviewed `nvim/dependencies.tsv`. |
| Headless validation | Mason auto-install starts async package installs during `nvim --headless '+quitall'`, which can abort installs as Neovim exits. | Skipped Mason auto-install when no UI is attached; interactive startup still installs missing Mason packages, while headless smoke checks remain idempotent. | Initial smoke exposed the abort; rerun result recorded after the guard. |
| Keymaps | Legacy plugin keymaps for Markdown preview, diagnostics, buffer deletion, tmux navigation, and terminal/image helpers could conflict with existing canonical prefixes. | Preserved existing canonical keymaps and added no new plugin keymaps in this slice. | Reviewed `nvim/lua/config/keymaps.lua` alongside plugin decisions. |
| Local state | Database UI state could create generated files if placed in the repo. | Configured DB UI save location under `stdpath('data')`, keeping local state out of shared configuration. | Reviewed `nvim/plugin/database.lua`. |

## Plugin Workstream Validation Evidence

| Check | Result | Notes |
|-------|--------|-------|
| `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml` | pass | Ran from `/Users/allan/dotfiles` after plugin/LSP changes. |
| `nvim --headless '+quitall'` | initial abort, then pass | Initial run installed Dadbod plugins but Mason aborted new async installs on immediate quit; added the headless Mason guard and reran successfully with no output. |
| Branch check | pass | Stayed on `feat/nvim-config-consolidation` because the worktree already has many uncommitted spec/archive changes and unrelated local deletes; switching branches would risk disrupting out-of-scope work. |

## Cleanup Decisions

| Source | Area | Decision | Target | Rationale | Dependency Impact | Validation |
|--------|------|----------|--------|-----------|-------------------|------------|
| `lvim/` | cleanup | remove | N/A | LunarVim is no longer a maintained target. Its option, keymap, plugin, formatting, and workflow material has been adopted, rejected, covered, or deferred in the decisions above; retaining the directory would keep stale source material beside canonical `nvim/`. | removed | `git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation`; `nvim --headless '+quitall'`. |
| `kickstart.nvim/` | cleanup | remove | N/A | Kickstart is no longer a maintained target. Relevant options, keymaps, plugin/LSP/tooling behavior, snippets, and framework defaults have been reviewed; useful behavior was migrated or recorded, and remaining framework material is intentionally out of scope. | removed | `git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation`; `nvim --headless '+quitall'`. |
| `lazyvim/` | cleanup | remove | N/A | LazyVim is no longer a maintained target. Relevant options, keymaps, plugin/LSP/tooling behavior, snippets, and framework defaults have been reviewed; useful behavior was migrated or recorded, and remaining framework material is intentionally out of scope. | removed | `git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation`; `nvim --headless '+quitall'`. |
| `kickstart.nvim/doc/kickstart.txt` | cleanup | remove | N/A | This file was already locally deleted and belongs to the removed Kickstart legacy target, not canonical `nvim/`. | removed | Included in cleanup diff review. |
| `kickstart.nvim/ftplugin/http.lua` | cleanup | remove | N/A | This file was already locally deleted; REST/API execution was deferred instead of migrating the legacy HTTP/Kulala workflow into canonical `nvim/`. | removed | Included in cleanup diff review. |
| `lazyvim/ftplugin/json.lua` | cleanup | remove | N/A | This file was already locally deleted and belongs to the removed LazyVim legacy target; canonical JSON/YAML support remains under `nvim/lsp/` and `nvim/plugin/`. | removed | Included in cleanup diff review. |

## Rollback And Recovery

Cleanup removes repository-managed legacy Neovim material only. It does not modify user-owned configuration outside this repository. Recovery is through Git history before the cleanup diff is committed or merged.

| Removed Or Archived Path | Recovery Source | Recovery Steps | Validation |
|--------------------------|-----------------|----------------|------------|
| `lvim/` | Git history on `feat/nvim-config-consolidation` before the cleanup change. | Before commit: run `git restore -- lvim`. After commit but before merge: revert the cleanup commit or restore with `git restore --source=<cleanup-parent> -- lvim`. After merge: open a follow-up PR restoring only the needed paths from the pre-cleanup commit. | Run `git diff -- lvim`; confirm restored material is intentional and does not replace canonical `nvim/`. |
| `kickstart.nvim/` | Git history on `feat/nvim-config-consolidation` before the cleanup change. | Before commit: run `git restore -- kickstart.nvim`. After commit but before merge: revert the cleanup commit or restore with `git restore --source=<cleanup-parent> -- kickstart.nvim`. After merge: open a follow-up PR restoring only the needed paths from the pre-cleanup commit. | Run `git diff -- kickstart.nvim`; confirm restored material is intentional and does not replace canonical `nvim/`. |
| `lazyvim/` | Git history on `feat/nvim-config-consolidation` before the cleanup change. | Before commit: run `git restore -- lazyvim`. After commit but before merge: revert the cleanup commit or restore with `git restore --source=<cleanup-parent> -- lazyvim`. After merge: open a follow-up PR restoring only the needed paths from the pre-cleanup commit. | Run `git diff -- lazyvim`; confirm restored material is intentional and does not replace canonical `nvim/`. |
| Already-deleted `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, `lazyvim/ftplugin/json.lua` | Git history before the pre-existing local deletes. | Restore individually with `git restore -- kickstart.nvim/doc/kickstart.txt kickstart.nvim/ftplugin/http.lua lazyvim/ftplugin/json.lua` before commit, or recover from the cleanup parent commit after commit/merge if review identifies missing reference value. | Run `git diff -- kickstart.nvim/doc/kickstart.txt kickstart.nvim/ftplugin/http.lua lazyvim/ftplugin/json.lua`. |

## Cleanup Workstream Validation Evidence

| Check | Result | Notes |
|-------|--------|-------|
| Migration decision precheck | pass | Options, keymaps, and plugins/tooling decisions are recorded above before cleanup. |
| Existing local deletes review | pass | `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, and `lazyvim/ftplugin/json.lua` are included in cleanup decisions and recovery notes. |
| `git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation` | pass | Reviewed cleanup diff after removing legacy material and updating spec artifacts. |
| `nvim --headless '+quitall'` | pass | Ran from `/Users/allan/dotfiles` after cleanup; startup completed without output. |
| Branch check | pass | `git branch --show-current` returned `feat/nvim-config-consolidation`. |
