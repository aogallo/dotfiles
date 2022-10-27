require('allan.lsp.cmp')
require('allan.lsp.diagnostic_signs')
require('allan.lsp.language_servers')


--Add icon to diagnostic
vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    underline = true,
    -- This sets the spacing and the prefix
    virtual_text = {
      spacing = 4,
      prefix = ''
    }
  }
)
