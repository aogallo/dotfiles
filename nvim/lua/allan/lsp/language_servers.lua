-- Setup lspconfig.
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
--capabilities.textDocument.completion.completionItem.snippetSupport = true

-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
require'lspconfig'.html.setup {
	capabilities = capabilities,
}
require'lspconfig'.pyright.setup{
  capabilities = capabilities,
}
require'lspconfig'.cssls.setup {
  capabilities = capabilities,
}
require'lspconfig'.tsserver.setup{
  capabilities = capabilities,
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
