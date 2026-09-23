# Contract: Connection Registry

**Owner**: Neovim module — loader `nvim/lua/config/db_connections.lua`, template
`nvim/db-connections.example.lua`
**Consumers**: the loader → dadbod-ui (`g:dbs`), vim-dadbod-completion, user
**Related spec**: FR-004/005/006/007/011/016, US2

## Source Location

1. If `NVIM_DB_CONNECTIONS` env var is set and points to a readable file → that file.
2. Otherwise default: `stdpath('config')/db-connections.lua`
   (`~/.config/nvim/db-connections.lua`, which is the repo-linked config dir).
3. Missing file → empty registry; Neovim starts normally; DB browser shows no connections with
   guidance (FR-006 edge case).

The path is resolved at startup. The default file `nvim/db-connections.lua` is gitignored
(`.gitignore` entry), so the registry is portable across machines and never pushes secrets.

## File Format

A Lua module returning a name → URL map:

```lua
return {
  sybase_prod = 'sybase://user:$SYBASE_PASS@ase-host/app_db?charset=iso_1',
  sqlserver_dev = 'sqlserver://dev-user:sqlsrv@sql-dev:1433/AppDb',
  mongo_local = 'mongodb://localhost:27017/app_db',
}
```

- Keys are connection display names (unique).
- Values are dadbod URLs for the supported schemes (`sybase://`, `sqlserver://`, `mongodb://`).
- Credentials may be `$ENV_VAR` placeholders — dadbod expands them at connect time; the
  registry file then contains no secrets even if it were exposed.
- Values may alternatively be `function() → url_string` (dadbod-ui supports callables) for
  lazily-resolved secrets.

## Loader Behavior

1. Resolve path (env var → default).
2. `loadfile` + execute; on parse error, warn once with the file path and continue with an
   empty registry (never crash startup).
3. Assign the result to `g:dbs` (dadbod-ui's connection source).
4. Override: a value previously set in `g:dbs` by the user is replaced by the registry (the
   registry is the single source of truth per FR-004).

## Refresh Semantics (FR-006)

- Changes to the registry file require no Neovim restart: run `:DBUI` and press `R` (redraw)
  after editing the file, or restart to reload.
- No caching of connection data beyond dadbod-ui's normal redraw.

## Example Template

`nvim/db-connections.example.lua` is the committed, secret-free template: same format, all
values replaced with placeholders and comments. The user copies it to `nvim/db-connections.lua`
(or any `NVIM_DB_CONNECTIONS` path) and fills real values locally.

## Security & Hygiene (FR-007)

- `nvim/db-connections.lua` and any user registry path outside the repo are never committed.
- `db-connections.example.lua` contains zero real credentials.
- Password-bearing URLs SHOULD use `$ENV_VAR` placeholders; embedding plaintext passwords is
  allowed only in the gitignored local file.

## Rollback / Recovery (FR-016)

- Deleting the registry file (or unsetting `NVIM_DB_CONNECTIONS`) restores prior behavior:
  `g:dbs` becomes empty and dadbod-ui shows no registry connections.
- No registry-related state is written anywhere else; removing it cannot corrupt existing
  saved dadbod-ui connections or queries.
