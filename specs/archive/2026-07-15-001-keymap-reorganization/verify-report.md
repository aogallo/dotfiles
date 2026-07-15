# Verification Report: Neovim Keymap Reorganization

## Moved Mappings

| Source | Old | New | Status |
|--------|-----|-----|--------|
| `nvim/lua/config/keymaps.lua` | `gQ` | `<leader>cf` | Updated |
| `nvim/lua/config/keymaps.lua` | `H` | `<leader>bp` | Updated |
| `nvim/lua/config/keymaps.lua` | `L` | `<leader>bn` | Updated |
| `nvim/lua/config/keymaps.lua` | `<leader>ps` | `<leader>pl` | Updated |
| `nvim/lua/lsp.lua` | `<leader>fs` | `<leader>cs` | Updated |
| `nvim/lua/lsp.lua` | `<leader>cl` | `<leader>cL` | Updated |
| `nvim/plugin/editor.lua` | `<leader>e` | `<leader>fe` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>f/` | `<leader>sb` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>fb` | `<leader>bb` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>fc` | `<leader>uh` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>fd` | `<leader>sd` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>fg` | `<leader>sg` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>fh` | `<leader>sh` | Updated |
| `nvim/plugin/fzf-lua.lua` | `<leader>f<` | `<leader>sr` | Updated |
| `nvim/plugin/gitsigns.lua` | `<leader>gc` | `<leader>gy` | Updated |
| `nvim/plugin/gitsigns.lua` | `<leader>go` | `<leader>gO` | Updated |
| `nvim/plugin/diffview.lua` | `<leader>gf` | `<leader>gh` | Updated |
| `nvim/plugin/diffview.lua` | `<leader>G*` | `<leader>gx*` | Updated |
| `nvim/plugin/markdown.lua` | `<leader>cp` | `<leader>up` | Updated |

## Preserved Mappings

- Base editing and movement mappings remain unchanged: `jk`, enhanced `<esc>`, `j`, `k`, `<C-d>`, `<C-u>`, `n`, `N`, visual `<`, visual `>`, visual paste, and `<C-h>/<C-j>/<C-k>/<C-l>` window navigation.
- Diagnostic and LSP native-style mappings remain unchanged: `[e`, `]e`, `gd`, `gD`, `grr`, `gy`, and `grc`.
- Git hunk navigation remains unchanged: `[g` and `]g`.
- Diffview non-leader panel-local mappings remain unchanged.

## Validation Results

### Configuration Load

Command:

```bash
XDG_CONFIG_HOME="/Users/allan/dotfiles" nvim --headless +qa
```

Result: passed with no output or startup errors.

### Duplicate Mapping Inspection

Command inspected active normal and visual mappings after startup using `vim.api.nvim_get_keymap()` and `vim.g.mapleader`.

Result: `duplicates=none` for active leader mappings in normal and visual modes.

### Semantic Leader Group Count

Command inspected active normal and visual leader mappings after startup and counted mappings whose first key after `<leader>` is one of `b`, `c`, `f`, `g`, `p`, `s`, `u`, or `w`.

Result: `leader_semantic=26/26 100.0%`, which satisfies the 90% requirement.

### Which-Key and Smoke Checks

- Which-key source registration now includes: buffers, code, files, git, packages, search, UI, and windows.
- Headless mapping inspection confirmed migrated global mappings are registered at their final destinations.
- Interactive which-key discovery was manually validated by the user in the dotfiles project and in a separate Python/React project.
- Manual validation confirmed the semantic leader groups are discoverable in real UI usage.

### Secrets and Portability Check

Searches over affected Neovim Lua files found no new `/Users/`, `/home/`, token, secret, password, or API key patterns.

## Rollback Path

Revert only the Neovim keymap-related files changed by this feature plus this verification artifact and `tasks.md` if needed. No installer rollback or external cleanup is required.
