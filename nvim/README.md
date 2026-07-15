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
