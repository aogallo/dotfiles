local lspconfig_status, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status then
  return
end

local cmp_nvim_lsp_status, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not cmp_nvim_lsp_status then
  return
end

local typescript_status, typescript = pcall(require, "typescript")
if not typescript_status then
  return
end

local keymap = vim.keymap

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

local on_attach = function(client, bufnr)
  local options = { noremap = true, silent = true, buffer = bufnr }

  -- set keybinds
  keymap.set("n", "gf", "<cmd>Lspsaga lsp_finder<CR>", options)
  keymap.set("n", "<leader>gd", "<cmd>lua vim.lsp.buf.declaration()<CR>", options)
  keymap.set("n", "gd", "<cmd>Lspsaga peek_definition<CR>", options)
  keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", options)
  keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", options)
  keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", options)
  keymap.set("n", "<leader>dl", "<cmd>Lspsaga show_line_diagnostics<CR>", options)
  keymap.set("n", "<leader>dc", "<cmd>Lspsaga show_cursor_diagnostics<CR>", options)
  keymap.set("n", "<leader>dn", "<cmd>Lspsaga diagnostic_jump_next<CR>", options)
  keymap.set("n", "<leader>dp", "<cmd>Lspsaga diagnostic_jump_prev<CR>", options)
  keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", options)
  keymap.set("n", "<leader>o", "<cmd>LSoutlineToggle<CR>", options)

  if client.name == "tsserver" then
    keymap.set("n", "<leader>rf", ":TypescriptRenameFile<CR>", options)
  end

  -- formatting when the files saved
  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_command [[augroup Format]]
    vim.api.nvim_command [[autocmd! * <buffer>]]
    vim.api.nvim_command [[autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_seq_sync()]]
    vim.api.nvim_command [[augroup END]]
  end
end

-- used to enable autocomplation
local capabilities = require("cmp_nvim_lsp").default_capabilities()

lspconfig["html"].setup ({
  on_attach = on_attach,
	capabilities = capabilities,
})

lspconfig["pyright"].setup{
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig["cssls"].setup {
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig["tsserver"].setup{
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
