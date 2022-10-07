-- Setup lspconfig.
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
--capabilities.textDocument.completion.completionItem.snippetSupport = true
--Format on save
-- vim.lsp.buf.formatting_seq_sync()
local on_attach = function(client, bufnr)
if client.server_capabilities.document_formatting then
  vim.api.nvim_commnad[[augroup Format]]
  vim.api.nvim_commnad[[autocmd! * <buffer>]]
  vim.api.nvim_commnad[[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
  vim.api.nvim_commnad[[augroup END]]
end
end

-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
require'lspconfig'.html.setup {
  on_attach = on_attach,
	capabilities = capabilities,
}
require'lspconfig'.pyright.setup{
  on_attach = on_attach,
  capabilities = capabilities,
}
require'lspconfig'.cssls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
require'lspconfig'.tsserver.setup{
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = {
    'typescriptreact',
    'typescript',
    'javascriptreact',
    'javascript',
    'typescript.tsx'
  }
}


local lspconfig = require'lspconfig'
local configs = require'lspconfig.configs'


if not configs.ls_emmet then
  configs.ls_emmet = {
    default_config = {
      cmd = { 'ls_emmet', '--stdio' };
      filetypes = {
        'html',
        'css',
        'scss',
        'javascript',
        'typescript',
        'javascriptreact',
        'typescriptreact',
        'sass',
      };
      root_dir = function(fname)
        return vim.loop.cwd()
      end;
      settings = {};
    };
  }
end

lspconfig.ls_emmet.setup { capabilities = capabilities }
