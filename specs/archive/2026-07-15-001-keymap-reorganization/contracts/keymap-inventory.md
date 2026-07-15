# Internal Contract: Keymap Inventory

This feature has no external API, CLI, network contract, or persisted data contract. The implementation contract is the approved keymap inventory below.

## Semantic Groups

| Prefix | Label | Domain |
|--------|-------|--------|
| `<leader>b` | buffers | Buffer selection, navigation, and cleanup |
| `<leader>c` | code | Diagnostics, formatting, LSP symbols, code/lint actions |
| `<leader>f` | files | File picker, recent files, explorer |
| `<leader>g` | git | Git hunks, blame, links, lazygit, diff views, history, conflicts |
| `<leader>p` | packages | Package update and lockfile synchronization |
| `<leader>s` | search | Grep, current-buffer search, help search, diagnostic list, resume |
| `<leader>u` | UI | Highlight inspection, preview/display toggles |
| `<leader>w` | windows | Reserved for future window actions |

## Required Migrations

| Source File | Mode | Current | Required | Action |
|-------------|------|---------|----------|--------|
| `nvim/lua/config/keymaps.lua` | normal | `gQ` | `<leader>cf` | Format whole buffer |
| `nvim/lua/config/keymaps.lua` | normal | `H` | `<leader>bp` | Previous buffer |
| `nvim/lua/config/keymaps.lua` | normal | `L` | `<leader>bn` | Next buffer |
| `nvim/lua/config/keymaps.lua` | normal | `<leader>ps` | `<leader>pl` | Sync packages to lockfile |
| `nvim/lua/lsp.lua` | normal | `<leader>fs` | `<leader>cs` | Document symbols |
| `nvim/lua/lsp.lua` | normal | `<leader>cl` | `<leader>cL` | Apply all ESLint/Stylelint fixes |
| `nvim/plugin/editor.lua` | normal | `<leader>e` | `<leader>fe` | Explorer |
| `nvim/plugin/fzf-lua.lua` | normal/visual | `<leader>f/` | `<leader>sb` | Search current buffer / visual lines |
| `nvim/plugin/fzf-lua.lua` | normal | `<leader>fb` | `<leader>bb` | Buffer picker |
| `nvim/plugin/fzf-lua.lua` | normal | `<leader>fc` | `<leader>uh` | Highlight picker |
| `nvim/plugin/fzf-lua.lua` | normal | `<leader>fd` | `<leader>sd` | Document diagnostics picker |
| `nvim/plugin/fzf-lua.lua` | normal/visual | `<leader>fg` | `<leader>sg` | Live grep / visual grep |
| `nvim/plugin/fzf-lua.lua` | normal | `<leader>fh` | `<leader>sh` | Help tags |
| `nvim/plugin/fzf-lua.lua` | normal | `<leader>f<` | `<leader>sr` | Resume last picker |
| `nvim/plugin/gitsigns.lua` | normal/visual | `<leader>gc` | `<leader>gy` | Yank git link |
| `nvim/plugin/gitsigns.lua` | normal/visual | `<leader>go` | `<leader>gO` | Open git link blame |
| `nvim/plugin/diffview.lua` | normal | `<leader>gf` | `<leader>gh` | File history |
| `nvim/plugin/diffview.lua` | panel-local normal | `<leader>G*` | `<leader>gx*` | Conflict actions |
| `nvim/plugin/markdown.lua` | normal | `<leader>cp` | `<leader>up` | Markdown preview toggle |

## Required Preservations

| Source Area | Mapping(s) | Reason |
|-------------|------------|--------|
| Base editing | `jk`, enhanced `<esc>`, `j`, `k`, `<C-d>`, `<C-u>`, `n`, `N`, visual `<`, visual `>` | Core editing ergonomics |
| Window navigation | `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` | Fast tmux-style navigation convention |
| Diagnostic navigation | `[e`, `]e` | Native previous/next pattern |
| Git hunk navigation | `[g`, `]g` | Native previous/next pattern |
| LSP navigation | `gd`, `gD`, `grr`, `gy`, `grc` | Common LSP navigation convention |
| Insert workflows | Completion and snippet insert-mode mappings | Plugin-local editing workflow |
| Diffview panels | Non-leader panel keys | Context-local modal UI behavior |

## Acceptance Rules

- Each required migration must have exactly one active final mapping for the same mode and scope.
- Which-key discovery must include every semantic group listed above.
- No old mapping in the Required Migrations table should remain active unless a task explicitly documents it as a temporary compatibility alias.
- Preserved mappings must remain unchanged.
