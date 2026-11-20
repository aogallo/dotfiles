-- Keep IBM ESQL separate from SQL completion and database integrations.
vim.filetype.add {
    extension = {
        esql = 'esql',
        subflow = 'xml',
        msgflow = 'xml',
        wsdl = 'xml',
        xsd = 'xml',
        descriptor = 'xml',
    },
}

vim.api.nvim_create_autocmd('User', {
    group = vim.api.nvim_create_augroup('ace_treesitter', { clear = true }),
    pattern = 'TSUpdate',
    callback = function()
        require('config.ace').register_parser()
    end,
})
