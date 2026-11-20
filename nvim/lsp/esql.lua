-- Community IBM ESQL server; install explicitly, see docs/ace-windows.md.
return {
    cmd = require('config.ace').command 'esql-lsp',
    filetypes = { 'esql' },
    root_dir = require('config.ace').esql_root,
}
