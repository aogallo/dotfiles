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

Notifications, captured editor messages, command/keymap failures, and LSP progress use the
shared helper in `lua/notifications.lua`. The helper keeps visible messages concise, stores
full details in session history where available, and falls back safely when Snacks UI pieces
are not loaded.

Use `<leader>un` to open notification/message history. The mapping prefers Snacks native
notifier history when available, falls back to the helper's custom Snacks picker for
internal-only captured entries, and finally opens a quickfix-backed session history if
Snacks is unavailable.

Manual validation for notification changes is documented in
`specs/002-unify-notifications/quickstart.md`. Diagnostics UI is intentionally out of scope
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
