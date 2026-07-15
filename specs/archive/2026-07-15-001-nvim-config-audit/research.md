# Research: Neovim Config Audit

## Decision: Use Neovim v0.12 APIs as the primary compatibility lens

**Rationale**: The target version requested is Neovim v0.12.1. Context7 documentation for
Neovim exposes 0.12 news covering `vim.pack`, LSP enhancements, diagnostic breaking changes,
and LSP client management. The audit must review current usage of `vim.pack.add`,
`PackChanged`, `vim.lsp.config`, `vim.lsp.enable`, `vim.diagnostic.config`, and any removed
or changed diagnostic APIs.

**Evidence**: Context7 `/neovim/neovim` reports Neovim 0.12 adds built-in `vim.pack`, LSP
client management through `vim.lsp.enable()`, and diagnostic sign configuration changes.
It also states diagnostic signs can no longer be configured with `sign_define()` in 0.12 and
should use `vim.diagnostic.config({ signs = ... })`.

**Alternatives considered**: Treat the existing config as correct if it starts locally. This
was rejected because the spec requires documentation-backed compatibility and portability,
not just local success.

## Decision: Treat Treesitter main-branch configuration as version-sensitive

**Rationale**: The current config installs `nvim-treesitter` and uses `vim.treesitter.start`
for highlighting/folding, plus manual runtimepath handling for queries. Context7 documents
native Neovim highlighting/folding activation through `vim.treesitter.start()` and
`vim.treesitter.foldexpr()`, while Treesitter indentation remains plugin-provided and
experimental.

**Evidence**: Context7 `/nvim-treesitter/nvim-treesitter` documents enabling highlighting
with `vim.treesitter.start()`, folding with `vim.treesitter.foldexpr()`, parser management
commands such as `:TSInstall` and `:TSUpdate`, and experimental indentation through
`require'nvim-treesitter'.indentexpr()`.

**Alternatives considered**: Assume old `nvim-treesitter.configs.setup` semantics. This was
rejected because the repo appears to be using newer Neovim-native Treesitter flows and the
audit must verify the actual branch/API combination.

## Decision: Keep Mason as one dependency source, not the only source of truth

**Rationale**: The user explicitly noted that some language servers, such as Go's server,
may be installed outside Mason. The current config also contains inline install comments for
external tools. The future installer should support Mason-managed packages and externally
installed tools through a single dependency inventory.

**Evidence**: Context7 `/mason-org/mason.nvim` documents Mason's install root at
`stdpath('data') .. '/mason'`, PATH modification behavior, registry setup, and package bin
exposure. This makes Mason useful for managed tools but does not remove the need to validate
external executables such as `gopls`, `tsgo`, `dprint`, `ty`, or formatters not in the Mason
list.

**Alternatives considered**: Force every LSP and formatter through Mason. This was rejected
because it conflicts with the user's real constraint and would reduce portability for tools
that are better installed with language-native tooling or Homebrew.

## Decision: Produce a structured audit report before applying fixes

**Rationale**: The requested work is a review plus improvement recommendations. The safest
next implementation is a report that classifies findings, dependencies, and installer risks
before modifying configuration.

**Evidence**: The constitution requires non-destructive behavior, explicit reporting,
verification, and recoverable paths. A report-first flow satisfies those gates and avoids
silently changing editor behavior.

**Alternatives considered**: Immediately edit the config while auditing. This was rejected
for this phase because it would mix discovery with remediation and make it harder to verify
which changes are required vs optional.

## Preliminary Risk Inventory From Code Inspection

- `nvim/lua/lsp.lua` defines diagnostic signs with `vim.fn.sign_define`, which Context7
  indicates is no longer valid for diagnostic signs in Neovim 0.12.
- `nvim/plugin/markdown.lua` hardcodes `/Users/allan/dev/notes`, which violates portability
  and must become a local override or environment-derived path.
- `nvim/plugin/gitsigns.lua` contains `github.palantir.build` routing, which appears
  work-specific and should be separated from portable shared config.
- `nvim/plugin/fzf-lua.lua` contains `heigh` keys that likely intend `height`; the audit
  should verify against fzf-lua docs or runtime behavior.
- `nvim/plugin/conform.lua` contains formatter entries combining list and keyed table
  fields, such as `{ 'prettier', name = 'dprint', ... }`; the audit should verify this
  against conform.nvim formatter list semantics.
- `nvim/plugin/treesitter.lua` installs parsers during plugin setup and waits up to five
  minutes, which may be acceptable for bootstrap/update but risky during normal startup.
- `nvim/snippets/markdown.json` is empty; the audit should classify it as intentional,
  placeholder, or cleanup.

## Documentation Gaps

- Context7 resolution exposed a versioned Neovim entry for `v0_11_4`, while query results
  included Neovim 0.12 news from master docs. The audit must state exact-source limitations
  for any 0.12.1-specific claim.
- Plugin-specific docs for `blink.cmp`, `conform.nvim`, `fzf-lua`, `snacks.nvim`, and
  `obsidian.nvim` still need targeted lookup during implementation if findings depend on
  their option schemas.

## Local Validation Observations

- `nvim --version` reports `NVIM v0.12.1`, matching the requested target version.
- `nvim --headless -u nvim/init.lua '+quitall'` exits successfully in this workspace.
- `nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'` completes the requested health checks in this workspace.
- `stylua --check nvim` reports formatting diffs in existing files, including
  `nvim/lua/config/keymaps.lua`, `nvim/lua/config/autocmds.lua`, and
  `nvim/plugin/gitsigns.lua`. The audit should classify formatting drift separately from
  behavioral correctness.
