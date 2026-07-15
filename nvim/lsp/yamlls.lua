-- Install with: pnpm add -g yaml-language-server

---@type vim.lsp.Config
return {
    cmd = { 'yaml-language-server', '--stdio' },
    filetypes = { 'yml', 'yaml' },
    settings = {
        yaml = {
            -- Using the schemastore plugin for schemas.
            schemastore = { enable = false, url = '' },
            schemas = require('schemastore').yaml.schemas(),
        },
    },
}
