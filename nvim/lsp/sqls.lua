-- Install with: go install github.com/sqls-server/sqls@latest

---@type vim.lsp.Config
return {
    cmd = { 'sqls' },
    filetypes = { 'sql', 'mysql', 'plsql' },
    root_markers = { '.sqllsrc.json', '.git' },
}
