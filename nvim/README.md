# Neovim Configuration

This directory contains the shared Neovim configuration for the dotfiles repository. It is
portable by default: machine-specific paths and work-specific settings must come from the
environment or ignored local overrides, not from committed Lua files.

## Quick Path

1. Validate the config starts:

   ```sh
   nvim --headless -u nvim/init.lua '+quitall'
   ```

2. Validate formatting and health checks:

   ```sh
   stylua --check nvim
   nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'
   ```

3. Validate external dependencies without installing anything:

   ```sh
   setup/validate-nvim-deps.sh
   ```

4. Preview dependency installation without changing the machine:

   ```sh
   setup/bootstrap-nvim-deps.sh --dry-run
   ```

5. Preview linking this repo's Neovim config into `~/.config/nvim`:

   ```sh
   setup/link-nvim-config.sh --dry-run
   ```

## Plugin Cleanup

Use `:PackClean` to review stale Neovim plugin state before deleting anything. The command opens
the Snacks picker when Snacks is loaded; use `<Tab>` to select individual candidates, `<C-a>` to
select all candidates, and `<CR>` to continue to the confirmation prompt. No plugin directory or
lockfile entry is removed until the prompt is confirmed with `yes`.

The review surface shows each candidate's name, path, active state, lockfile state, and cleanup
reason:

- `inactive-managed`: known to `vim.pack`, installed on disk, but inactive in the current session.
- `disk-only`: installed under a managed package root but absent from active `vim.pack` state.
- `lockfile-only`: present in `nvim/nvim-pack-lock.json` but absent from active plugin state.
- `missing`: known to `vim.pack`, but the local plugin directory is already gone.

Safety boundaries are resolved at runtime from Neovim's package roots. `:PackClean` blocks paths
outside those roots, excludes active plugins, and reports every processed item as removed, skipped,
blocked, not found, or errored. Lockfile cleanup is explicit: stale entries are removed only for
confirmed candidates and the lockfile is rewritten as valid JSON.

If Snacks picker is unavailable during startup timing or a minimal/headless session, `:PackClean`
falls back to a `vim.ui.input` report path. The fallback intentionally keeps the same confirmation
gate and safety validation, but it cleans all listed candidates after confirmation because there is
no multi-select picker available.

Validate the command with:

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u nvim/init.lua '+command PackClean' '+quitall'
```

Interactive validation still needs a real Neovim UI: run `:PackClean`, confirm the picker or
fallback report opens, inspect disk-only/orphan, lockfile-only, active-exclusion, missing-path, and
unsafe-path cases in a controlled runtime, and repeat the cleanup to confirm idempotent reporting.

Rollback is a normal repository revert for config and lockfile changes. Removed plugin directories
can be restored by re-adding/restoring the plugin spec or lockfile entry, then starting Neovim so
`vim.pack` installs the plugin again.

## Statusline and Bufferline

The statusline is provided by `lualine.nvim` and renders mode, branch, filename, diagnostics, encoding, filetype, and cursor location in a single global statusline. The buffer list is provided by `bufferline.nvim` in `buffers` mode with LSP diagnostics and per-buffer close icons. Whether the buffer *row* itself is drawn is bufferline's own decision, governed by its `auto_toggle_bufferline` option; this configuration leaves that option as bufferline ships it and does not change it. A missing row and a missing tab are different questions, and the row is not what hides a buffer.

Buffer visibility follows one contract, implemented by the guard in
[`lua/config/buffers.lua`](lua/config/buffers.lua): a tab exists for every buffer you opened, generated
output takes none, and closing is final until you explicitly reopen. The guard only ever adds — it
re-lists an unlisted buffer when you come back to it, and it never unlists, unloads or wipes anything.

| Buffer | Tab | Why |
| --- | --- | --- |
| a query you opened from `:DBObjects` | yes, always | it is yours to come back to |
| a query you closed, then reopened | yes, again | the reopen is what brings the tab back |
| query output (`.dbout`, `nofile` drawers, `b:aogallo_no_tab`) | no | generated output is not somewhere to work |
| a closed query you have not reopened | no | closing is final; nothing revives it implicitly |

Nothing about this is persisted. A query buffer keeps its text, language and connection in memory for
the session, so a restart does not bring drafts back; only what you saved to disk does. Opening the
same query twice is safe: the first buffer keeps the plain name and the second gets a `.2`, `.3`, ...
suffix instead of raising `Vim:E95`.

Bufferline markers: `h` on a buffer means it is loaded but not currently displayed, and no marker
means the buffer is displayed. That is a statement about the buffer, not a sign that its tab is
missing. `auto_toggle_bufferline` still governs whether the row itself shows; this configuration does
not change that behavior.

Source of truth for this behavior:

| Concern | File |
| --- | --- |
| the guard, the generated-output rules, the opt-out flag | `nvim/lua/config/buffers.lua` |
| query naming, the reclaim, the draft registry | `nvim/lua/config/db_query_buffer.lua` |
| the single wiring point for the guard | `nvim/plugin/editor.lua` |
| the single wiring point for the registry | `nvim/plugin/database.lua` |
| the regression tests | `nvim/lua/tests/buffer_visibility_smoke.lua` |

Prerequisites: none. No plugin, no dependency and no keymap is involved; the guard uses only core
Neovim APIs and `bufferline.nvim` reads the result. Manual activation is not required either --
`buffers.setup()` runs from `nvim/plugin/editor.lua` and `db_query_buffer.setup()` from
`nvim/plugin/database.lua` at plugin source time, both idempotent, so a reload is harmless and there
is nothing to call by hand. The opt-out flag for a future generated buffer that matches neither the
`.dbout` nor the `nofile` rule is `b:aogallo_no_tab`.

Troubleshooting -- **my query buffer has no tab**: check that you are looking at a query you opened,
not at query *output* (`.dbout` results intentionally take none), and check whether you closed the
buffer without reopening it. To bring it back, switch to it explicitly -- `<S-h>`/`<S-l>`, `:buffer N`,
or re-running the `:DBObjects` entry that produced it.

Buffer navigation uses `<S-h>` (next) and `<S-l>` (previous). These mappings are muted from which-key. Closing and buffer-list actions stay under the `<leader>b` domain (`<leader>bx`, `<leader>bo`, `<leader>bb`).

### Number column and buffer-row colors

**What decides the appearance of both the number column and the buffer row**: the `on_highlights`
hook of the `tokyonight` entry in `nvim/plugin/editor.lua`. It is the only place these colors are
set. The hook owns **14 highlight groups**:

| Region | Groups |
| --- | --- |
| number column | `LineNr`, `LineNrAbove`, `LineNrBelow` |
| buffer row | `BufferLineBufferSelected`, `BufferLineBufferVisible`, `BufferLineBuffer`, `BufferLineIndicatorSelected`, `BufferLineSeparatorSelected` |
| overlays on the active tab | `BufferLineErrorSelected`, `BufferLineWarningSelected`, `BufferLineInfoSelected`, `BufferLineHintSelected`, `BufferLineModifiedSelected`, `BufferLineCloseButtonSelected` |

Two thresholds are shared by both regions: **4.5** for text that must be read (the active tab's name,
every diagnostic overlay, `CursorLineNr`) and **3.0** for the rest (`LineNr*`, the inactive tab's
name). Each value is a literal, never derived from another plugin's tint math, so an intentional
override is always tellable from an accident.

To change a color, edit the `on_highlights` hook and nothing else. The active tab's background is a
local named `active_tab_bg`, kept separate from `explorer_row` on purpose: both currently hold
`#2d3f76`, but `explorer_row` drives the picker's cursor line, and sharing one name would let a
change to the picker silently repaint the active buffer tab.

Two things must move together: raising the active background raises the bar the inactive row has to
clear. `BufferLineBuffer` measures **3.47:1** against a 3.0 floor, so it is the invariant that
**tightens** whenever `active_tab_bg` rises -- re-check it in the same edit. Separately, `bold` marks
a diagnostic severity, not a row state: only `Error`, `Warning`, `Info` and `Hint` carry it, while
`Modified` and `CloseButton` do not.

`CursorLineNr` is out of scope and must not be recolored to satisfy the others. It stays `#ff966c`
at 7.16:1 so the cursor's number remains the strongest in the column (6.07:1 for the relative
numbers) and keeps its own column position.

The full contract, including the measured ratios behind every value and the change protocol for
editing them, is
[`specs/012-line-number-buffer-highlights/contracts/highlight-contract.md`](../specs/012-line-number-buffer-highlights/contracts/highlight-contract.md).

Prerequisites: none. Both plugins ship with this configuration -- there is nothing to install,
enable or opt into.

Manual activation: none. The hook runs during `:colorscheme`, so the values are present on the first
draw after a normal start. There is nothing to call by hand.

Installer support: none. The change creates, installs, links or copies no file; it only sets
highlight values inside an existing hook.

Manual-only operations: none for the change itself. The interactive walkthroughs in
[`specs/012-line-number-buffer-highlights/quickstart.md`](../specs/012-line-number-buffer-highlights/quickstart.md)
§5 are validation steps to run once by hand, not operations the configuration requires. Everything
else here is asserted headlessly.

Reduced-color terminals: the change sets only `fg` and `bg`, never `ctermfg`/`ctermbg` or a truecolor
escape, so Neovim maps the colors to whatever the terminal supports. A terminal without truecolor
degrades rather than errors -- `--cmd 'set notermguicolors'` starts clean.

Rollback: an ordinary `git revert`. Nothing to restore, unlink or re-seed, because the change
creates and replaces no file and adds no dependency, keymap, autocmd or user command. Reverting the
hook restores tokyonight's and bufferline's own colors, which is the pre-change state.

Troubleshooting -- **my change did not take effect**: confirm the value lives in the `on_highlights`
hook in `nvim/plugin/editor.lua` and not in some local override layered on top of it, and confirm you
restarted or re-ran `:colorscheme tokyonight` -- the hook fires on that event, not on every redraw.
`nvim/nvim-pack-lock.json` is unrelated to appearance; a change there affects plugin versions, never
colors.

When Neovim starts without a file argument, the Snacks dashboard shows a header, quick keymaps, and recent files.

### Which database am I querying

`lualine_y` carries a database indicator for `sql` buffers, and nothing at all for every other
filetype, so a non-SQL window stays visually unchanged. It is answered locally, from the buffer's
connection URL and its own text: it never queries the server, and it never renders a URL, host, or
credential — only a database name.

| Buffer state | Indicator |
| --- | --- |
| connection with a database, no `use` in the text | `DB ventas` |
| connection with a database and a `use` naming another | `DB ventas` plus a warning mark naming `base-a` |
| connection with a database and a `db..object` name | `DB ventas` plus a mark naming that object |
| connection with no database in its URL | the "no database" marker, so a query is never sent blind |
| any other filetype, or no connection | nothing |

`--` comments, `/* … */` blocks, and `'…'` literals are ignored, so a `use` inside a comment or a
string does not produce a false mark. On the last `use` wins, matching what the adapter does. When a
`sql` buffer is executed and its text switches database, one warning names both databases before the
query runs; the query itself is not modified. The whole thing lives in `nvim/lua/config/db_context.lua`
so the status line and the query path cannot disagree about the name.

Validate with:

```sh
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
```

### When a query fails

A query the server rejects is reported by the server's own words. When a run finishes, the editor
reads the completed response and, if it carries a `Msg N, Level N` complaint, raises one warning
naming that complaint — the complaint's prose, not a generic "query failed". Several complaints in
one response are all kept; the warning shows the first and the complete response remains in the
query's result buffer, byte-for-byte, so the rest can be read there. A run the user cancels is
reported as cancelled, never as a server rejection.

An empty response is a success that returned nothing, never a warning. A response the editor cannot
read at all — a non-zero exit with no recognizable complaint — is reported as unreadable, so "my
query failed and nothing was shown" cannot happen silently.

| Response | Reported as |
| --- | --- |
| `Msg 207, Level 16 … Invalid column name 'x'` | warning naming `Invalid column name 'x'` |
| several `Msg …` complaints | one warning; each complaint kept in full |
| rows, then a complaint | warning; the partial rows are kept beside it |
| zero rows, no complaint | nothing — a successful empty result |
| non-zero exit, no recognizable complaint | an unreadable-response warning |
| cancelled by the user | cancelled, not a server complaint |

The query text is also inspected before it runs — de-commented so `--`, `/* … */` and `'…'` cannot
hide a database switch — and if that inspection itself faults, the editor says so and the query
still runs. A fault in the editor never blocks a valid query and is never dressed up as a server
complaint. Reporting lives in `nvim/lua/config/db_results.lua`; the pre-run inspection lives in
`nvim/lua/config/db_context.lua`.

Validate with:

```sh
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
```

### Markdown and trailing whitespace on save

Saving a supported file type runs exactly one formatting path — the one already configured in
`nvim/plugin/conform.lua` — and no cleanup auto command is registered alongside it. The rules below
are the formatter's own, measured in `tests/markdown_whitespace_smoke.lua` rather than assumed:

| Input | Result | Why |
| --- | --- | --- |
| two trailing spaces with text after them in the same paragraph | preserved | CommonMark hard break; removing it changes the rendering |
| three or more trailing spaces mid-paragraph | reduced to exactly two | same hard break, normalized |
| two trailing spaces on the last line of a paragraph | removed | renders identically without them |
| two trailing spaces on a heading or table row | removed | not significant in those constructs |
| trailing spaces inside a fenced block or an indented example | removed | not significant to the example |

None of it changes the rendered document. Two qualifications, both verified rather than assumed:
the byte-for-byte content guarantees (leading indentation, tabs, and a line of only whitespace) hold
for the **whitespace-only fallback**, because a main formatter is free to collapse blank lines and
reindent code — which is what the Lua formatter here does. And on a machine **without** the main
Markdown formatter, the fallback trims bluntly and flattens this document's hard breaks; that
degradation is accepted and pre-existing for the non-project chain, which this feature now matches.

When a file type has no formatter at all, a save reports it: one warning naming the file type, on
**every** failing save rather than only the first, with no duplicate from the formatting toolchain.
The check never modifies the buffer, and it observes the same guards the formatter does
(`minifiles_active`, `skip_formatting`, `autoformat`, Java), so it cannot report a failure for a
save that was never going to be formatted.

The formatter chain is built in `nvim/lua/config/formatter_chains.lua` rather than inside the plugin
file, so it can be checked without the plugin being loaded. Both branches end with the whitespace-only
steps and both stop after the first available formatter: a missing main formatter degrades to
trimming instead of to nothing, and the trims never run alongside a formatter that would flatten the
hard breaks above.

Validate with:

```sh
nvim --headless -u NORC -c 'lua require("tests.formatter_chains_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'
```

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
```

Full manual validation steps live in `specs/archive/2026-08-14-001-install-statusline-bufferline/quickstart.md`.

## Dependency Strategy

`nvim/dependencies.tsv` is the reviewable source of truth for Neovim language servers,
formatters, linters, and supporting CLI tools. Some tools are intentionally external instead
of Mason-managed, for example `gopls`, `tsgo`, `dprint`, and `ty`.

The validator checks both the shell `PATH` and Mason's default bin directory:

```text
$HOME/.local/share/nvim/mason/bin
```

It is non-destructive: it reports missing required and optional tools but does not install,
upgrade, delete, or link anything.

### todo-comments.nvim

`folke/todo-comments.nvim` highlights `TODO`, `FIXME`, `HACK`, and `WARN` annotations in both code
and Markdown, so a leftover marker is visible without opening a search. It is declared in
`nvim/plugin/editor.lua` with an empty `opts` table: the defaults are the whole intent, and the entry
carries no configuration surface. The version is pinned in `nvim/nvim-pack-lock.json`
(`31e3c38ce9b29781e4422fc0322eb0a21f4e8668`).

It belongs to neither story of the whitespace or database-context work; it rides along in the same
change because the constitution requires a new dependency to be declared and documented with the
change that introduces it. It is not covered by any spec here, and removing the `opts` table or the
lockfile pin would be a separate decision.

`setup/bootstrap-nvim-deps.sh` consumes the same manifest. It defaults to `--dry-run`; use
`--install` only when you want it to install supported missing tools. Optional tools are
skipped unless `--include-optional` is provided.

```sh
setup/bootstrap-nvim-deps.sh --dry-run
setup/bootstrap-nvim-deps.sh --install
setup/bootstrap-nvim-deps.sh --install --include-optional
```

### Optional Shell Tools

`shfmt` and `shellcheck` are intentionally optional. They improve shell-script formatting
and diagnostics in Neovim, but missing them must not block the baseline Neovim setup or
validation flow.

When `setup/validate-nvim-deps.sh` reports them as optional missing tools, choose one of two
valid paths:

- Install them when you want a fully provisioned shell-editing environment:

  ```sh
  setup/bootstrap-nvim-deps.sh --dry-run --include-optional
  setup/bootstrap-nvim-deps.sh --install --include-optional
  ```

  The current manifest resolves both through Homebrew: `brew install shfmt` and
  `brew install shellcheck`.

- Leave them absent when you do not need shell formatting or shell diagnostics. The validator
  will continue to report them as optional and should still exit successfully when required
  dependencies are present.

Mason-backed entries are reported with instructions instead of being installed by the shell
script. This keeps the bootstrap non-surprising until Mason installation is promoted to its
own explicit work unit.

Treesitter parser installation is also explicit and does not block normal startup. After
installing or updating plugins, use these Neovim commands when parser work is needed:

```vim
:TSInstallConfigured
:TSUpdateConfigured
```

### Treesitter Textobjects

The config adds `nvim-treesitter-textobjects` as a semantic editing layer on top of native
Vim textobjects. It does not override delimiter textobjects: keep using `a(`, `i(`, `ca(`,
and `va(` for parenthesis-oriented edits such as changing the contents of a Go `const (...)`
block. Use Treesitter textobjects when the target is semantic code structure instead of
punctuation.

Semantic selection mappings are available in visual and operator-pending mode:

| Mapping | Behavior |
|---------|----------|
| `af` | outer function |
| `if` | inner function |
| `ac` | outer class, type, or equivalent structure where the parser supports it |
| `ic` | inner class, type, or equivalent structure where the parser supports it |
| `ao` | outer comment where textobject queries support comments |
| `as` | local scope where locals queries support scopes |

Incremental structural selection uses repository-local mappings to avoid conflicting with
native `gn` selection behavior:

| Mapping | Mode | Behavior |
|---------|------|----------|
| `<leader>vs` | normal, visual | start selection at the nearest Treesitter node |
| `<leader>ve` | normal, visual | expand to the parent syntax node |
| `<leader>vr` | visual | shrink back to the previous node |

Structural movement is enabled only for conflict-free function/type navigation. Parameter swap
mappings are intentionally deferred until fixture validation proves them syntax-safe across the
supported languages.

| Mapping | Mode | Behavior |
|---------|------|----------|
| `]f` | normal, visual, operator-pending | next function start |
| `[f` | normal, visual, operator-pending | previous function start |
| `]t` | normal, visual, operator-pending | next class/type start |
| `[t` | normal, visual, operator-pending | previous class/type start |

Unsupported captures fail safely when a language parser or query does not expose the requested
structure. In that case, use the closest native textobject or a supported semantic mapping and
check parser/query health with:

```sh
nvim --headless -u nvim/init.lua '+checkhealth nvim-treesitter' '+quitall'
```

Validate textobjects with the fixtures in
`specs/archive/2026-07-29-002-nvim-treesitter-textobjects/fixtures/`:

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u nvim/init.lua '+checkhealth nvim-treesitter' '+quitall'
nvim --headless -u nvim/init.lua '+command TSInstallConfigured' '+command TSUpdateConfigured' '+quitall'
```

Manual validation should cover semantic selections, three levels of incremental selection,
native `a(`/`i(`/`ca(`/`va(` behavior in `sample.go`, and the enabled `]f`/`[f`/`]t`/`[t`
movement mappings. Roll back by removing the textobjects plugin entry and mapping setup from
`nvim/plugin/treesitter.lua`, syncing `nvim/nvim-pack-lock.json`, and re-running the validation
commands above.

## AWS YAML, CloudFormation, and SAM Editing

The editor uses layered YAML support:

- `yamlls` plus SchemaStore remains active for normal YAML files.
- `cfn_lsp` is CloudFormation-first and only attaches to buffers classified as
  CloudFormation or SAM templates.
- Serverless Framework files stay generic YAML by default because `serverless.yml` is not a
  CloudFormation/SAM template document.

This keeps Docker Compose, application configuration, notes, and other YAML formats free from
CloudFormation-only diagnostics and completion noise.

### Template Classification

CloudFormation/SAM classification is intentionally narrow. `nvim/lsp/cfn_lsp.lua` starts the
AWS CloudFormation language server only when a YAML/JSON buffer matches one of these signals:

- A CloudFormation/SAM filename such as `*.cfn.yaml`, `*.cloudformation.yaml`,
  `*.template.yaml`, `cloudformation*.yaml`, `cfn*.yaml`, `sam*.yaml`, or `template.yaml`.
- CloudFormation markers in the first part of the file, such as
  `AWSTemplateFormatVersion`, `Resources`, `Parameters`, `Mappings`, `Conditions`, `Outputs`,
  or resource types like `AWS::S3::Bucket`.
- SAM markers such as `Transform: AWS::Serverless-2016-10-31` or `AWS::Serverless::*`
  resources.
- A manual classification comment near the top of an ambiguous file:

  ```yaml
  # cfn-lsp: cloudformation
  # cfn-lsp: sam
  ```

When the CloudFormation language server attaches, Neovim records the classified context in
`vim.b.aws_template_context` as `cloudformation` or `sam`. Use this when troubleshooting which
AWS template context a suggestion or diagnostic belongs to:

```vim
:lua print(vim.b.aws_template_context or 'generic-yaml')
:LspInfo
```

### Local CloudFormation Language Server

The CloudFormation language server is optional and local-only. Missing it must not break normal
YAML editing.

Default path:

```text
~/.local/share/cfn-lsp/cfn-lsp-server-standalone.js
```

Install/update manually from the standalone bundle:

```sh
mkdir -p ~/.local/share/cfn-lsp
# Download a release from https://github.com/aws-cloudformation/cloudformation-languageserver/releases
# and unzip cfn-lsp-server-standalone.js into ~/.local/share/cfn-lsp/
```

To test another local bundle without changing shared config:

```sh
CFN_LSP_SERVER=/path/to/cfn-lsp-server-standalone.js nvim template.yaml
```

Do not commit downloaded language server bundles, generated parser binaries, caches, quarantine
state, or machine-specific absolute paths.

### Fallback Validation

Editor diagnostics are useful feedback, but `cfn-lint` is the fallback validation authority for
CloudFormation and SAM templates.

CloudFormation:

```sh
cfn-lint specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/cloudformation-valid.yaml
cfn-lint specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/cloudformation-invalid.yaml
```

SAM:

```sh
cfn-lint specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/sam-template.yaml
sam validate --lint --template-file specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/sam-template.yaml
```

Install optional fallback tools only when needed:

```sh
brew install cfn-lint aws-sam-cli
```

Missing `cfn-lint`, `sam`, or the CloudFormation language server is reported as optional by
`setup/validate-nvim-deps.sh`; it should not block unrelated Neovim startup.

### Support Strategy and Tradeoffs

CloudFormation is the first-class supported AWS template context because it has a concrete
document shape and direct validation tooling. SAM is supported as a CloudFormation extension:
files with the SAM transform or `AWS::Serverless::*` resources are classified for
CloudFormation/SAM assistance, and `sam validate --lint` is the documented fallback when editor
diagnostics are incomplete.

Serverless Framework is intentionally generic YAML by default. Although it can deploy AWS
resources, its top-level `service`, `provider`, `functions`, `plugins`, and `custom` sections are
Serverless Framework configuration, not a CloudFormation template. Treating it as
CloudFormation would create misleading diagnostics.

### YAML Parser and AWS LSP Troubleshooting

These are separate layers; fix the failing layer instead of treating every YAML error as an AWS
LSP problem.

#### macOS blocks `@tree-sitter-grammars+tree-sitter-yaml.node`

That warning points to the YAML Treesitter parser binary, not the CloudFormation language server.
Symptoms include YAML highlight/parser failures before AWS template analysis is trustworthy.

Validate parser health:

```sh
nvim --headless -u nvim/init.lua "+checkhealth nvim-treesitter" "+quitall"
```

Reinstall/update configured parsers:

```vim
:TSInstallConfigured
:TSUpdateConfigured
```

If macOS quarantine blocks a locally generated parser, remove or approve the local machine's
blocked parser state outside this repository. Do not commit parser binaries or security state.

#### CloudFormation language server internal errors

If generic YAML works but AWS template diagnostics fail or `cfn_lsp` exits, check the AWS layer:

```vim
:LspInfo
:messages
:lua print(vim.b.aws_template_context or 'generic-yaml')
```

Then confirm the local server path and Node.js are available:

```sh
node --version
test -r "${CFN_LSP_SERVER:-$HOME/.local/share/cfn-lsp/cfn-lsp-server-standalone.js}"
```

While the language server is unavailable, keep editing with generic YAML support and run the
fallback `cfn-lint` or `sam validate --lint` commands above.

If Node reports no native build for
`@tree-sitter-grammars/tree-sitter-yaml` on `darwin arm64`, the downloaded AWS bundle is missing
the Apple Silicon YAML parser prebuild. Reinstall the AWS release bundle first. If the release is
still missing `prebuilds/darwin-arm64/@tree-sitter-grammars+tree-sitter-yaml.node`, repair the
local bundle from the npm package and remove quarantine from the trusted local copy:

```sh
tmpdir=$(mktemp -d)
npm pack @tree-sitter-grammars/tree-sitter-yaml@0.7.1 --pack-destination "$tmpdir"
mkdir -p ~/.local/share/cfn-lsp/node_modules/@tree-sitter-grammars/tree-sitter-yaml/prebuilds/darwin-arm64
tar -xzf "$tmpdir"/tree-sitter-grammars-tree-sitter-yaml-0.7.1.tgz \
  -C "$tmpdir" \
  package/prebuilds/darwin-arm64/@tree-sitter-grammars+tree-sitter-yaml.node
cp "$tmpdir"/package/prebuilds/darwin-arm64/@tree-sitter-grammars+tree-sitter-yaml.node \
  ~/.local/share/cfn-lsp/node_modules/@tree-sitter-grammars/tree-sitter-yaml/prebuilds/darwin-arm64/
xattr -dr com.apple.quarantine ~/.local/share/cfn-lsp
```

That repair is machine-local setup. Do not commit the copied `.node` file or any quarantine state.

## Notifications and Message History

Snacks owns visible notifications and `lua/notifications.lua` keeps the repository-local
notification history. Noice was evaluated twice, including a LazyVim-like `UIEnter` experiment,
and was rejected because it still duplicated the native bottom command line in the real UI.

Provider ownership:

| Surface | Owner | Notes |
|---------|-------|-------|
| Command entry | Native Neovim | Floating command-line UI is deferred until a provider can avoid duplicate cmdline rendering. |
| Command options | Native Neovim | Keep native completion behavior until a replacement passes manual validation. |
| Editor messages and `:messages` | Native Neovim + custom capture | `CmdlineLeave` captures recent status/warning/error messages into notification history. |
| Visible notifications | Snacks notifier | `lua/notifications.lua` sends visible helper notifications through `vim.notify`, which Snacks displays. |
| Notification/message history | `<leader>un` | Opens Snacks/custom floating history from `lua/notifications.lua`; it must not fall back to quickfix. |
| LSP progress | Existing LSP/client behavior | Do not add another progress provider without disabling overlapping output. |

Use `<leader>un` to inspect recent notification and message history. For manual validation,
trigger notifications with:

```vim
:lua require('notifications').notify('UI validation info', 'info', { title = 'Validation' })
:lua require('notifications').notify('UI validation warning', 'warn', { title = 'Validation' })
:lua require('notifications').notify('UI validation error', 'error', { title = 'Validation' })
```

Expected result: notifications appear outside the bottom command-line area, are not duplicated,
warnings/errors remain noticeable, and `<leader>un` shows recent history in a floating window.
Command-line behavior remains native until a replacement passes manual validation at 80, 120,
and 160 columns.

Troubleshooting:

- If command entry uses the bottom command line, that is expected for the current native fallback.
- If notifications duplicate, check that only Snacks is wrapping visible `vim.notify` output.
- If `<leader>un` opens no history, trigger a helper notification first, for example by running a
  command that uses `lua/notifications.lua`. The fallback should still use a floating window, not
  quickfix.
- If LSP progress is noisy or stale, fix the active LSP/progress source before adding another
  provider such as Fidget.

Validate command-line UI changes with:

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
setup/validate-nvim-deps.sh
```

Rollback:

1. Restore the previous notification block from version control if this custom history is broken.
2. Refresh `nvim/nvim-pack-lock.json` through normal `vim-pack` sync/startup behavior if plugin
   ownership changes.
3. Re-run `stylua --check nvim`, `nvim --headless -u nvim/init.lua '+quitall'`, and any relevant
   interactive notification/history checks.

Manual validation for the older notification helper remains documented in
`specs/archive/2026-07-17-002-unify-notifications/quickstart.md`. Diagnostics UI is intentionally out of scope
for the notification flow and should only be checked for no-regression behavior.

## Linking

`setup/link-nvim-config.sh` manages the `~/.config/nvim` symlink safely. It defaults to
`--dry-run`, refuses to overwrite existing user config, and only backs up conflicts when
`--backup` is explicitly provided with `--apply`.

```sh
setup/link-nvim-config.sh --dry-run
setup/link-nvim-config.sh --apply
setup/link-nvim-config.sh --apply --backup
setup/link-nvim-config.sh --apply --remove
```

Removal is conservative: it removes only a symlink that points back to this repository's
`nvim/` directory. It refuses to delete unmanaged files or directories.

The guided installer in `installer/` uses this same script boundary. Its TUI previews Neovim
dependency and link work first, reports required, optional, Mason-backed, and manual items, and
requires confirmation before running install or apply steps. Manual AWS language server bundle
repair remains report-only guidance.

## Database Client (Sybase ASE, SQL Server, MongoDB)

A full database client built on vim-dadbod + vim-dadbod-ui + vim-dadbod-completion, driven by a
single user-owned connection registry. A custom `sybase://` adapter shells out to `sqsh` on
macOS and the SAP ASE `isql` client on Windows so large stored procedures and multi-result-set
batches run without truncation.

### Source of truth

| File | Purpose |
|------|---------|
| `nvim/autoload/db/adapter/sybase.vim` | Sybase adapter: `interactive`, `input` (with the sqsh `go`→`\go` transform), `input_extension`, `output_extension`, `tables`, `objects`, `source`, `complete_database`. The URL database is selected with a `use <db>` batch line (portable across `isql` variants and `sqsh`; no `-D` flag dependency) |
| `nvim/lua/config/db_connections.lua` | Registry loader → `g:dbs`; reloads on `BufEnter` of a `dbui` window (`R` in `:DBUI` picks up edits) |
| `nvim/db-connections.example.lua` | Committed, secret-free registry template |
| `nvim/lua/config/db_objects.lua` | `:DBObjects` schema-object search (fzf-lua picker over `vim.ui.select`) + database-scope control (chooser over the readable databases, typed-name path, visible active-scope header, non-silent failure feedback when a scope cannot be applied) + procedure save dialog (startup-root default, always-ask, database-qualified names, save-path confirmation notification) |
| `nvim/lua/config/db_jump.lua` | Toggle between the code buffer and the DB workspace (`<leader>q`) |
| `nvim/lua/config/db_results.lua` | Last query-result summon (`<leader>qr`): records dadbod `User */DBExecutePre|Post` into a per-session slot and focuses/reopens the result window |
| `nvim/dependencies.tsv` | `sqsh`, `sqlcmd`/`go-sqlcmd`, `mongosh` rows (all optional) |
| `nvim/plugin/database.lua` | dadbod stack wiring, Sybase "List" table helper, `:DBObjects` command, launch-cwd capture for the save dialog |

### Connection registry

Connections live in one Lua file returning `{ name = 'url', ... }`:

- Default path: `~/.config/nvim/db-connections.lua` (gitignored).
- Override: set `NVIM_DB_CONNECTIONS` to any path (e.g. machine-specific or a location outside
  this repo).
- Seeding: copy `nvim/db-connections.example.lua` and fill in URLs; prefer `$VAR` placeholders
  for passwords (dadbod resolves them from the environment).

Example:

```lua
return {
    ase = 'sybase://apps:$ASE_PASSWORD@ase-prod/master?charset=iso_1',
    sqlsrv = 'sqlserver://sa:$SA_PASSWORD@sql-prod:1433/AdventureWorks',
    mongo = 'mongodb://app:$MONGO_TOKEN@mongo-prod:27017/orders',
}
```

The `sybase://` host is the **registered server name** (as configured in `sql.ini`/interfaces on
Windows or `interfaces` on macOS) — do **not** append `:port`, since the port already lives in the
server definition (`-S <name>` resolves it). Using an explicit `host:port` with clients like the
portable MS `isql` fails with DB-Library error 53 (`specified sql server not found`).

Browse connections with `:DBUI`; press `R` over a connection to reload after editing the file.
Execute the current buffer against a URL with `:%DB`. Open an interactive client with `:DB <url>`
(macOS submissions use `\go` as the batch terminator; `go` lines in files are transformed
automatically). Database selection uses a `use <db>` batch line instead of a client `-D` flag, so
the adapter works with any ASE client — including portable `isql` builds that reject `-D` with
`unknown option D`.

### Database window navigation

Neovim buffers are global: tabs only split the window layout, so a dadbod query buffer opened in
another tab shares the buffer cycle used by `<S-h>`/`<S-l>` (`:bnext`/`:bprev`). For an explicit
one-key route to the database workspace instead of relying on that cycle:

- `<leader>qj` — toggle the database window: from any code buffer jumps to the database window
  (drawer first, then any dadbod query/result buffer carrying `b:db`); from the DB workspace
  returns to the code window you were in before. If no DB window is open it opens `:DBUI` and
  focuses the drawer.
- `<leader>qu` — `:DBUIToggle`: open/close the database drawer.
- `<leader>qo` — `:DBObjects` schema-object search.
- `<leader>qr` — summon the last finished query result: if the result window is still
  open it is focused (from any tab, current tab preferred); if the preview window was
  closed it is reopened from the recorded `.dbout` file. One clear informational notice
  appears when nothing has finished yet or a query is still running, and a warning names
  the file when the output temp file no longer exists on disk.
- Pressing `<leader>q` alone shows the `database` group (j/u/o/r) instead of firing an action.
- From the DB workspace, return to code with `<leader>qj`, the `L`/`H` buffer cycle, or `<C-o>`
  (walk back through the jumplist; `<C-i>` moves forward). `<C-6>` also toggles between the last
  two buffers.

Result output is table-friendly: `isql` runs with `-n -w` so the `n>` input prompts never pollute
the result buffer and wide columns stop wrapping at the 80-column default. `g:db_sybase_width`
tunes the column width (default `32000`). The dash separator lines isql emits are what let
vim-dadbod-ui fold and navigate result sets.

dadbod-ui notices ("Executing query...", completion and error notices) are routed through the
native Neovim notification system (`vim.notify`, displayed by Snacks) via
`g:db_ui_use_nvim_notify`, so the running query and code stay visible instead of an overlay at
the bottom-left. dadbod's own `DB: Query finished in …` echo on the native command line and the
query progress float are upstream vim-dadbod behavior and are not configurable from this repo
(see `specs/archive/2026-09-23-006-dbui-query-results/`).

Schema completion inside `*.sql` buffers comes from the dadbod blink provider
(`nvim/plugin/blink.lua`, enabled for the `sql` filetype). Table names complete after `.` or `_`.
Column completion is provided natively for SQL Server but not for Sybase or MongoDB; those
schemes degrade gracefully to tables only.

### `:DBObjects`

SSMS-like object search. `:DBObjects [name]` (tab-completes over registry names) resolves the
connection: explicit name → current buffer's dadbod URL (`b:db`) → fzf-lua picker over
`g:dbs`. On Sybase, every row is `kind  database  name` (prototype: `kind  name`); fuzzy-filter
by name as you type.

**What is listed (Sybase)** — `specs/010-dbobjects-listing-integrity/`:

- The listing covers **tables, views, stored procedures, user-defined functions and triggers**, and
  nothing else. Every row states which of those it is.
- `sysobjects.type` is `char(2)`, padded, so the kind is a **two-character** code — not one letter.
  The codes that matter here are `U` (table), `V` (view), `P` (stored procedure), `SF` (user-defined
  function) and `TR` (trigger); `XP` is an extended stored procedure and is surfaced as a
  procedure.
- The earlier filter tested one-letter patterns, which is why **functions and triggers silently
  never appeared**: `F` does not match the row `SF `, `X` does not match `XP `, and `TR` was not
  even part of the query. The same broken filter made a correctly-scoped `select … where type in
  ('TR')` look broken, and there was no object count to contradict the empty-looking result
  (issue [#92](https://github.com/aogallo/dotfiles/issues/92)).
- Every listing reconciles itself against the server's own count, in the header:
  `DB objects (main_db — tables, views, procedures, functions, triggers)  12 of 12 objects shown`.
  If the database holds objects this listing deliberately does not cover, the header says
  `partial: 3 of 240 objects shown, 237 not shown`; if the server sent no count at all, it says it
  may be incomplete rather than claiming to be whole.
- A `0 of 0` header (plus a one-line notice) is how "this database has no objects of these kinds"
  looks. It is deliberately different from "this database could not be read".

**Why the system catalogue is not enumerated** — `sp_help`, `systypes`, `syscomments`, `sysindexes`
and the rest of ASE's own `sys.*` tables are deliberately absent from the listing. Enumerating them
would add thousands of rows that no one is searching for, and several of them (`syscomments`,
`sysprotects`) carry the server's own text. This is a deliberate scope boundary, not an
accident: use direct-open below when you know the name.

**Opening an object by name** — the picker leads with `Open object by name…` whenever the active
scope is a **confirmed database**:

- It takes a **bare** object name (no `db.dbo.name`), and reads it from the confirmed database.
- It is offered **only** after the server has confirmed the database for this session. With no
  database in the connection the scope reads `login default` and the entry is **absent** — there is
  nothing trustworthy to search.
- It is the way to open an object of a kind the listing does not cover (a rule, a sequence, a
  system table), and the way to open something whose name you know and the fuzzy filter did not
  surface.
- A name that does not exist gets one actionable notice and no buffer.

**Database scope (Sybase)** — `specs/010-dbobjects-listing-integrity/`:

- The picker header always shows the **confirmed** scope: the database the server confirmed for
  this session, or `login default` when the URL carries none; the picker leads with a
  `Database: <scope> — change…` entry using the same label. Selecting it opens the database
  chooser: the databases the login can read (seeded with `[use current: <db>]`), or a typed
  database name.
- A chosen or typed database is **verified by the server** before anything is listed: the adapter
  asks for the name back and for it in `master..sysdatabases` in the same batch. Only a confirmed
  database becomes the scope, so the label never claims a database the session is not in.
- Picking a confirmed database rebuilds the connection URL with that database as its path
  (`db#adapter#sybase#with_database()`, preserving user/host/port/charset) and re-runs the listing
  inside it. The **default on every invocation is the connected database**.
- The scoped URL flows into source loading, buffer binding (`b:db`), and saved file names, so a
  procedure found in another database shows that database's source, **executes in that database**
  (never the connected one), and saves as `<owning-database>.<object>.sql`.
- Safe failures (`specs/010-dbobjects-listing-integrity/`): every failure mode — a database that
  does not exist, one that exists but the login cannot enter, an invalid typed name, a missing ASE
  client — raises **exactly one** actionable message and opens **no** picker, so a stale listing can
  never be mistaken for the database you asked for. Cancelling the chooser or the typed-name prompt
  is a pure no-op. The cross-database search across all databases (`%`) is explicitly out of scope.
- Server notes (e.g. `Changed database context to 'x'`) are surfaced once, deduplicated by text and
  capped at three samples; they never add a request and never inflate the row count.

- Table/view selection opens a new `sql` buffer with the ASE-safe List query
  `select top 200 * from <name>` (no `LIMIT`) ready to run via the `:%DB` flow.
- Procedure/function selection (Sybase only) loads the **full stored source** into a new editable
  `sql` buffer for edit-and-re-run. It is read straight from the catalog:
  `select convert(varchar(255), text) + '~' + case when text like '%' + char(10) then ' ' else '+' end
  from syscomments where id = object_id('<name>') order by number, colid2, colid`, with the 255-byte
  rows reassembled client-side (issue #88).
  - Why not `sp_helptext`: in legacy mode it answers with a `# Lines of Text` counter **and** the
    255-byte rows rendered as `convert(char(255) not null, text)`, so every opened object started with
    the counter, the row count, the `text` heading and a dashed separator, and one syscomments row
    became one buffer line — cutting long lines mid-token (`substring(@dat` / `o, @poscicion,1)`).
  - The `~` suffix marks where a syscomments row ends, and the character after it encodes whether the
    row ended on a real newline (`' '`) or mid-line (`'+'`) — that is what makes the reassembly
    byte-exact. A source line whose last characters are exactly `~` at a row boundary is the one
    known mis-read.
  - Objects whose text is hidden (`sp_hidetext`) or encrypted are detected before reading
    (`status & 1 = 1 or version is not null`); nothing is opened and one actionable notice names the
    likely causes (hidden text, missing `select` on `syscomments.text`, missing object, missing client).
  - `g:db_sybase_source_mode = 'showsql'` switches to the opt-in regenerated-SQL path
    (`exec sp_helptext '<name>', NULL, NULL, 'showsql,noparams'`, which never emits the
    `# Lines of Text` block and never chunks at 255 bytes). It needs ASE 15.0.2+ (`sp_showtext`);
    on older servers `Msg 2812` surfaces as the same "cannot read the source" notice and the default
    catalog mode is still the answer. Prefer the default `catalog` mode: it is the stored text, so
    what you save is what the server holds.
- After a procedure/function source opens, a **save dialog** always asks where to save the text to
  disk. The default is the directory where Neovim was started (`getcwd()` captured at plugin load,
  before any `:cd`); browse subdirectories or type a path on each save — a previously chosen folder
  is never remembered. Confirmed saves write one file named `<owning-database>.<object>.sql`
  (database-qualified so same-named procedures from different databases never collide; the
  single-DB listing falls back to `<object>.sql`). After every confirmed save a notification shows
  the full path of the written file (specs/archive/2026-09-24-007-fix-dbobjects-scope-save-dir/). If the file already
  exists, the user must explicitly choose overwrite or cancel; cancelling writes nothing and
  changes nothing (see `specs/archive/2026-09-23-002-procedure-save-dialog/` for the full contract).
- On SQL Server/MongoDB the picker uses dadbod's native `tables()` (tables/collections; no
  procedure source action). Missing client or missing objects shows a clear notice, never a crash.

### Database module map

Where the DB pieces live and what each one owns. Every function in these files carries the same
header (see [Documenting a function](#documenting-a-function)):

| File | Owns |
| --- | --- |
| `nvim/plugin/database.lua` | user commands (`:DBObjects`), `<leader>q` group wiring, startup `setup()` calls, startup-root capture |
| `nvim/lua/config/db_connections.lua` | the connection registry (`g:dbs`) and its reload on `dbui` buffers |
| `nvim/lua/config/db_objects.lua` | `:DBObjects` flow: listing, database-scope chooser, opening objects, the save dialog |
| `nvim/lua/config/db_context.lua` | the single answer to "which database is this buffer talking to": URL derivation, the `use`/`db..object` scan, the status-line label, and the pre-execution conflict warning |
| `nvim/lua/config/db_results.lua` | `<leader>qr` — summon the last finished query result from any window |
| `nvim/lua/config/db_jump.lua` | `<leader>qj` — toggle between the code buffer and the DB workspace |
| `nvim/lua/config/buffers.lua` | the buffer-visibility guard: gives an unlisted buffer its tab back when you return to it, and decides what is generated output that takes none |
| `nvim/lua/config/db_query_buffer.lua` | the query draft registry: display name, connection binding and in-memory text of a query buffer, so a closed query can be explicitly reopened |
| `nvim/autoload/db/adapter/sybase.vim` | the Sybase ASE adapter: client argv, batch handling, catalog queries, object source extraction |
| `nvim/lua/tests/*_smoke.lua` | offline smoke tests (temp `sqsh`/`isql` stubs, no server needed) |

Navigation recipes:

- **Why does my object open with `# Lines of Text` at the top, or with a line cut in half?** source
  extraction — `sybase.vim` `db#adapter#sybase#source()` and its `s:source_*`/`s:join_chunks()`
  helpers; user-visible behavior is in [`:DBObjects`](#dbobjects).
- **Why is the listing empty / wrong database?** `fetch_objects()` and the scope chooser
  (`choose_database()`, `apply_database_scope()`) in `db_objects.lua`; the query and the URL rewrite
  are in `sybase.vim` (`db#adapter#sybase#objects()`, `db#adapter#sybase#with_database()`).
- **Why did my save land in the wrong folder / overwrite a file?** `M.run_save_flow()`,
  `M.default_save_dir()`, `M.suggest_save_name()`, `M.needs_confirmation()` in `db_objects.lua`.
- **Why no connection list?** `M.load()` in `db_connections.lua` (registry path resolution, one
  warning per failure mode).
- **Why doesn't `<leader>qr`/`qj` do anything?** `db_results.lua` (result slot) and `db_jump.lua`
  (window search/toggle); both notify with the reason.

### Function traceability

DB-module behavior → the function that implements it → where it is specified:

| Behavior | Function | Spec / evidence |
| --- | --- | --- |
| Parse `sybase://` URLs, pick the client, build argv | `s:parsed()`, `s:client()`, `s:connect_args()`, `s:batch_flags()`, `s:script_flags()`, `s:batch_sep()` | `specs/archive/2026-09-23-001-sybase-nvim-client/`, `sybase_adapter_smoke.lua` |
| Portable database selection (`use <db>`, no `-D`) | `s:use_lines()`, `s:transform()`, `s:database()` | `specs/archive/2026-09-23-001-sybase-nvim-client/`, `sybase_adapter_smoke.lua` |
| Read a query's output without client framing | `s:run_query()`, `s:first_tokens()` | `sybase_adapter_smoke.lua`, `sybase_objects_smoke.lua` |
| List tables/views (dadbod `tables()`) | `db#adapter#sybase#tables()`, `s:object_kind()` | `specs/archive/2026-09-23-001-sybase-nvim-client/` |
| `:DBObjects` listing (tables/views/procedures/functions/triggers) | `db#adapter#sybase#objects()` → `fetch_objects()` → `reconcile()` → `build_listing()` → `M.open()` | issue [#92](https://github.com/aogallo/dotfiles/issues/92), `specs/010-dbobjects-listing-integrity/`, `sybase_objects_smoke.lua` |
| `char(2)` kind codes (`U`,`V`,`P`,`SF`,`TR`,`XP`) and the marker protocol | `s:covered_types`, `s:object_kinds()`, `s:object_kind()`, `s:type_in_list()`, `s:starts_with()`, `s:split_marker_row()`, `s:number_after()` | `specs/010-dbobjects-listing-integrity/contracts/sybase-listing-integrity.md`, `sybase_objects_smoke.lua` |
| Server-confirmed database scope | `db#adapter#sybase#confirm_database()` → `start_listing()` → `apply_database_scope()` | `specs/010-dbobjects-listing-integrity/data-model.md`, `db_objects_scope_smoke.lua` |
| One actionable message per failure, no stale listing | `report_failure()`, `surface_diagnostics()`, `prompt_for()` | issue #92, `specs/010-dbobjects-listing-integrity/spec.md` (FR-025–FR-029), `db_objects_scope_smoke.lua` |
| Open an object by name (requires a confirmed scope) | `open_by_name()`, `prompt_for()`, `start_listing()` | `specs/010-dbobjects-listing-integrity/` (FR-035–FR-037), `db_objects_scope_smoke.lua` |
| Database-scope chooser + safe failures | `db#adapter#sybase#complete_database()`, `db#adapter#sybase#with_database()`, `choose_database()`, `apply_database_scope()` | `specs/archive/2026-09-25-005-database-scope/`, `specs/archive/2026-09-24-007-fix-dbobjects-scope-save-dir/`, `specs/010-dbobjects-listing-integrity/`, `db_objects_scope_smoke.lua` |
| Full object source without client artifacts or 255-byte cuts | `db#adapter#sybase#source()`, `s:source_catalog()`, `s:join_chunks()`, `s:clean_result()`, `s:text_is_hidden()` | issue [#88](https://github.com/aogallo/dotfiles/issues/88), `specs/archive/2026-09-25-001-multidb-object-search/` (FR-013/FR-014), `sybase_objects_smoke.lua` |
| Opt-in regenerated-SQL source (`showsql`) | `s:source_showsql()`, `s:source_mode()` | issue #88, `nvim/README.md` [Customization boundaries](#customization-boundaries) |
| Table/view sample query buffer | `open_list_query()`, `open_buffer()` | `specs/archive/2026-09-25-005-database-scope/` |
| Save dialog: startup root, typed path, no silent overwrite | `M.run_save_flow()`, `pick_save_target()`, `resolve_typed_path()`, `M.needs_confirmation()`, `confirm_overwrite()`, `M.write_source()`, `M.suggest_save_name()` | `specs/archive/2026-09-23-002-procedure-save-dialog/`, `specs/archive/2026-09-24-007-fix-dbobjects-scope-save-dir/`, `db_objects_save_smoke.lua` |
| Connection registry load/reload | `M.load()`, `resolve_path()`, `warn()` | `specs/archive/2026-09-23-001-sybase-nvim-client/`, `db_connections_smoke.lua` |
| `<leader>qr` summon last result | `M.setup()`, `M.show()`, `focus_win_for()`, `on_pre()`, `on_post()` | `specs/archive/2026-09-23-006-dbui-query-results/`, `db_results_smoke.lua` |
| `<leader>qj` code ↔ DB workspace toggle | `M.jump()`, `M.find()`, `M.back()`, `open_drawer()`, `find_win()`, `is_drawer()`, `has_db_context()` | `specs/archive/2026-09-24-007-fix-dbobjects-scope-save-dir/`, `db_jump_smoke.lua`, `keymap_groups_smoke.lua` |
| Status-line database context: URL → database name | `M.database()`, `M.url_from_buffer()`, `M.url_database()` | `specs/009-trim-trailing-whitespace/` (FR-013), `db_context_smoke.lua` |
| Status-line database context: what the text would switch to | `M.switches()`, `strip_noise()` | `specs/009-trim-trailing-whitespace/` (FR-016, FR-017), `db_context_smoke.lua` |
| Status-line database context: rendered label and conflict flag | `M.label()`, `M.conflict()`, `M.switch_message()` | `specs/009-trim-trailing-whitespace/` (FR-018), `db_context_smoke.lua` |
| Pre-execution cross-database warning | `M.setup()` → `User */DBExecutePre` | `specs/009-trim-trailing-whitespace/` (FR-019, FR-020, FR-022), `db_context_smoke.lua` |
| Formatter chain per file type, with the whitespace fallback | `M.markdown()`, `has_signal()`, `M.markdown_project_markers` | `specs/009-trim-trailing-whitespace/` (FR-001–FR-008), `formatter_chains_smoke.lua` |
| One warning when no formatter is available, no duplicate notice | `save_will_format()`, `format_on_save`, `M.no_formatter_message()` | `specs/009-trim-trailing-whitespace/` (FR-009, FR-010), `no_formatter_warning_smoke.lua` |

### Client prerequisites

- macOS: `brew install sqsh` (Sybase). Optional: `sqlcmd` for SQL Server
  (`brew tap microsoft/mssql-release && brew install sqlcmd`, or
  `go install github.com/microsoft/go-sqlcmd@latest`) and `brew install mongosh` (MongoDB).
- Windows: SAP ASE client (`isql.exe`), SQL Server ODBC + `sqlcmd`, `mongosh`, on `PATH`. The
  adapter selects `isql` automatically on Windows. Neovim-on-Windows install is covered in
  `docs/windows-tooling-audit.md`.
- A missing client surfaces one actionable error naming the binary (e.g.
  `DB: 'sqsh' executable not found`); browsing and completion return empty lists instead of
  crashing.

### Customization boundaries

- `g:db_sybase_client` overrides the client per-machine: a string (binary name) or an argv list
  (e.g. `vim.g.db_sybase_client = { '/opt/sqsh/bin/sqsh' }`).
- `g:db_sybase_width` tunes the isql column width passed to `-w` (default `32000`). Not used by
  the sqsh client.
- `g:db_sybase_source_mode` picks how `:DBObjects` reads a procedure/function body: `'catalog'`
  (default — read `syscomments` and reassemble, byte-exact) or `'showsql'` (opt-in — regenerate the
  SQL through `sp_showtext`, needs ASE 15.0.2+). Any other value behaves like `catalog`.
- The procedure save dialog has **no configuration surface** by design: it always asks, defaults to
  the launch directory, and writes database-qualified names (spec `002-procedure-save-dialog`).
- dadbod-ui notification routing is handled by `g:db_ui_use_nvim_notify` (enabled here);
  setting `g:db_ui_disable_info_notifications` still silences the routine "Executing query..."
  info notices while errors/warnings keep their severity through `vim.notify`.
- `NVIM_DB_CONNECTIONS` overrides the registry path. Secrets live only in the ignored registry
  or environment variables; nothing in this repo carries credentials.

### Validation

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
# buffer visibility (spec 011, issue #96): offline, no server needed
nvim --headless -u NORC -c 'lua require("tests.buffer_visibility_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua assert(vim.g.db_ui_use_nvim_notify, "db_ui_use_nvim_notify not set"); vim.print("PASS notify-routing")' -c 'qa!'
# whitespace feature (spec 009): first two are offline, last two need the real configuration
nvim --headless -u NORC -c 'lua require("tests.formatter_chains_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.markdown_whitespace_smoke")' -c 'qa!'
nvim --headless -u nvim/init.lua -c 'lua require("tests.no_formatter_warning_smoke")' -c 'qa!'
# active buffer emphasis (spec 012, issue #95): needs the real configuration, because
# the values under test are defined by the tokyonight on_highlights hook
nvim --headless -u nvim/init.lua -c 'lua require("tests.highlight_emphasis_smoke")' -c 'qa!'
```

The last two skip with exit 0 when the formatting toolchain is not loadable, so the block stays
green on a machine without it. `no_formatter_warning_smoke` relies on `shfmt` being absent, so it
says `SKIP`-style information rather than passing quietly if that binary ever appears.

`highlight_emphasis_smoke` is the one suite that must run against `nvim/init.lua`: it measures
highlight groups that only exist once tokyonight and bufferline are loaded, so under `-u NORC` it
would read `nil` and pass for the wrong reason. It opens a scratch buffer first, because this
repository puts its plugin pack on the runtimepath lazily and the groups are absent until one is
opened. It self-checks its own contrast math against two standard WCAG values before any assertion
depends on it.

Live-server scenarios (execution, browser, interactive consoles, `:DBObjects` source loading)
are manual-only; see `specs/archive/2026-09-23-001-sybase-nvim-client/quickstart.md`.

#### Manual-only: `:DBObjects` against a real ASE server (spec 010)

The suites above stub the ASE client, so they cannot prove the kind codes are right. Run this by
hand against an instance that has objects in a **non-default** database.

Reproduce issue [#92](https://github.com/aogallo/dotfiles/issues/92) — before the fix, a trigger or a
user-defined function in another database was **absent from a populated listing with no message**:

1. Connect to a database that is not the one you work in.
2. `:DBObjects` → change scope to that database → search for a **trigger**, then a
   **user-defined function**. Before the fix both are missing; after the fix both are found.
3. Hand-run the issue's reference path to confirm the object exists and is readable.

Then check the rest of the contract:

| # | Action | Expected |
|---|--------|----------|
| 1 | Choose a database you can use | listing contains only that database's objects; the label names it |
| 2 | Choose a database you **cannot** use | one message; **no** listing of the other database |
| 3 | Type a database name that does not exist | one message, distinguishable from #2 |
| 4 | Choose a database with zero objects | `0 of 0 objects shown` — visibly not an error |
| 5 | Search for a **trigger** | found (impossible before the fix) |
| 6 | Search for a **user-defined function** | found (impossible before the fix) |
| 7 | `Open object by name…` with an uncovered kind (a rule, a sequence) | source opens, from the confirmed database |
| 8 | `Open object by name…` with a nonexistent name | one actionable notice, no buffer |
| 9 | Connection with no database in the URL | no `Open object by name…` entry; label reads `login default` |
| 10 | Cancel the chooser / the name prompt | pure no-op |
| 11 | Count the client invocations for one `:DBObjects` | **2** (confirmation batch + listing batch), or **1** when the scope is unchanged — and the **same** for 50 objects and for 50,000 |

Full checklist, including the two open questions (`TR` vs `IT`; whether `db_id()` conflates
"absent" with "not permitted"), in `specs/010-dbobjects-listing-integrity/quickstart.md` §4.

### Rollback / recovery

Revert the `nvim/` files and the `.gitignore` line for `nvim/db-connections.lua`. Deleting the
registry file (or unsetting `NVIM_DB_CONNECTIONS`) restores the previous empty state; saved
dadbod-ui connections under `db_ui_save_location` are never written by this feature. Removing the
gitignored registry removes your local credentials — keep them in the environment and re-seed
from `nvim/db-connections.example.lua`.

The procedure save dialog writes **user-owned files in user-chosen directories** (never inside the
repo); reverting the module just removes the dialog, and deleting any previously saved
`<database>.<object>.sql` files is manual/user-managed.

The `<leader>qr` summon and the dadbod-ui notification routing hold no state outside the Neovim
process and write nothing; reverting the config restores the previous overlay behavior and no
buffers, files, or saved state are left behind.

## Documenting a function

**Convention (required for new code, applied to all existing DB-module functions):** every function
starts with a short header, in the language of the file, using these fields in this order:

```lua
-- M.run_save_flow(row, lines): the full save dialog for one object source.
-- Called by: open_procedure_source() right after the source buffer opens
-- SQL: none
-- Args: row = picker row (name + database), lines = the opened source lines
-- Returns: nothing (asynchronous)
-- Side effects: always asks for a target, then writes once
function M.run_save_flow(row, lines)
```

```vim
" db#adapter#sybase#tables(url): table/view names for dadbod.
" Called by: vim-dadbod; db_objects.lua for non-Sybase schemes
" SQL: `select name from sysobjects where type in ('U','V') order by name`
" Args: url = URL string or parsed dict
" Returns: string[] names, [] when the client is missing
" Side effects: none (read-only)
function! db#adapter#sybase#tables(url) abort
```

Rules that make the header useful rather than decorative:

- **Purpose** is the first line: `name: what it does`, not a restatement of the name.
- **Called by** names real callers (module + function, or the plugin that calls you) — this is what
  makes dead code obvious.
- **SQL** is the exact statement(s) with the interpolation shown as `<name>`/`<url>`, or `none`. For
  Sybase work, write the statement you actually send, not an approximation.
- **Args** gives each parameter's meaning, including the nil/empty cases that change behavior.
- **Returns** gives the shape (`string[]`, `{ok=…}`, list of dicts) and what an empty/failed result
  means.
- **Side effects** covers notifications, files, buffers, windows, `vim.g`/`b:` state — and the absence
  of all of them when the function is read-only.
- Note real limits where they exist (`Known limits:`), e.g. the `~` row-boundary mis-read in
  `s:join_chunks()` or the ASE 15.0.2+ requirement of `s:source_showsql()`.

Test helpers in `nvim/lua/tests/` are exempt: they document the file's purpose and the harness at the
top instead of every helper.

## Local Overrides

Use environment variables for private or machine-specific settings:

| Variable | Purpose |
|----------|---------|
| `OBSIDIAN_NOTES_DIR` | Overrides the Obsidian workspace path. Defaults to `~/dev/notes`. |
| `GITLINKER_ENTERPRISE_HOST` | Enables enterprise GitLinker routing without committing a work-specific hostname. |

When these variables are absent, the shared configuration must continue to start without
requiring the private resource.

`setup/link-nvim-config.sh --apply` creates the default Obsidian notes directory if needed.
With no override, that directory is `~/dev/notes`.

## Obsidian Notes

Obsidian notes use `OBSIDIAN_NOTES_DIR` for the workspace path, falling back to
`~/dev/notes`. New notes created with `:Obsidian new {title}` derive the note ID and
Markdown filename from the provided title, so `:Obsidian new AWS CodePipeline` creates a
recognizable title-based filename instead of an opaque numeric ID.

Use `<leader>nn` (`New note`) to open `:Obsidian new ` and enter the note title from the
command line. The mapping is grouped under `<leader>n` as `notes` in Which-Key.

### Markdown Formatting in Notes Folders

Notes folders can stay lightweight. A plain Markdown directory, or an Obsidian-style vault
with Markdown files plus optional `.obsidian/` vault-local settings, is enough for basic
editing in Neovim. The shared formatter config does not require every notes folder to include
Node tooling, package manifests, or Prettier configuration.

Markdown uses project Prettier when the current file is under a portable project/config signal,
such as `package.json`, `.prettierrc*`, or `prettier.config.*`. Without those signals, Markdown
still attempts the shared Neovim Prettier formatter for normal Markdown cleanup, then falls
back to safe whitespace cleanup if Prettier is unavailable.

If a specific notes vault should use project-style Markdown formatting, add formatter config
to that vault intentionally. For example, adding a Prettier config or package manifest opts
that folder into the Prettier path; installing and managing formatter dependencies for that
vault remains optional and vault-specific.

When syncing notes across machines, keep secrets and machine-specific paths out of the vault.
Vault-local app settings such as `.obsidian/` are normal if you want to sync them, but package
manager state and formatter dependencies should only be added when the vault is deliberately
managed like a project.

Rollback is a normal repository revert of `nvim/plugin/markdown.lua`,
`nvim/plugin/editor.lua`, `nvim/plugin/conform.lua`, and this README. Existing notes created
in an Obsidian vault are user content and are not removed by reverting the configuration.
