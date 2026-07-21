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

Mason-backed entries are reported with instructions instead of being installed by the shell
script. This keeps the bootstrap non-surprising until Mason installation is promoted to its
own explicit work unit.

Treesitter parser installation is also explicit and does not block normal startup. After
installing or updating plugins, use these Neovim commands when parser work is needed:

```vim
:TSInstallConfigured
:TSUpdateConfigured
```

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
