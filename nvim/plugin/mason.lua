local add = require('vim-pack').add
local ensure_installed = {
    'bash-language-server',
    'css-lsp',
    'dockerfile-language-server',
    'dprint',
    'eslint-lsp',
    'gopls',
    'html-lsp',
    'json-lsp',
    'lua-language-server',
    'marksman',
    'prettier',
    'ruff',
    'sqls',
    'stylelint-lsp',
    'terraform-ls',
    'yaml-language-server',
}

add {
    {
        src = 'mason-org/mason.nvim',
        module_name = 'mason',
        opts = {
            PATH = 'prepend',
        },
        on_setup = function()
            if #vim.api.nvim_list_uis() == 0 then
                return
            end

            local registry = require 'mason-registry'

            local function install_missing()
                for _, name in pairs(ensure_installed) do
                    local ok, package = pcall(registry.get_package, name)
                    if ok and not package:is_installed() then
                        package:install()
                    end
                end
            end

            registry.refresh(install_missing)
        end,
    },
}
