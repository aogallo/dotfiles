local add = require('vim-pack').add
local ensure_installed = { 'eslint-lsp', 'html-lsp', 'css-lsp', 'json-lsp', 'marksman', 'terraform-ls', 'prettier' }

add {
    {
        src = 'mason-org/mason.nvim',
        module_name = 'mason',
        opts = {
            PATH = 'prepend',
        },
        on_setup = function()
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
