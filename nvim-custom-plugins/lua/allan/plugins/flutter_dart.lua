vim.api.nvim_command [[let dart_html_in_string=v:true]]
-- formatting on save file
vim.g.dart_format_on_save = 1
vim.g.dart_style_guide = 2

-- vim.g.lsc_server_commands = { "dart" = "dart_language_server" }
-- vim.api.nvim_command [[let g:lsc_server_commands = {'dart': 'dart_language_server'}]]

-- Use all the defaults (recommended):
-- vim.api.nvim_command [[let g:lsc_auto_map = v:true]]

-- Apply the defaults with a few overrides:
-- vim.api.nvim_command [[let g:lsc_auto_map = {'defaults': v:true, 'FindReferences': '<leader>r'}]]

-- Setting a value to a blank string leaves that command unmapped:
-- vim.api.nvim_command [[let g:lsc_auto_map = {'defaults': v:true, 'FindImplementations': ''}]]

-- " ... or set only the commands you want mapped without defaults.
-- " Complete default mappings are:
-- vim.api.nvim_command [[ let g:lsc_auto_map = { 'GoToDefinition': '<C-]>', 'GoToDefinitionSplit': ['<C-W>]', '<C-W><C-]>'], 'FindReferences': 'gr', 'NextReference': '<C-n>', 'PreviousReference': '<C-p>', 'FindImplementations': 'gI', 'FindCodeActions': 'ga', 'Rename': 'gR', 'ShowHover': v:true, 'DocumentSymbol': 'go', 'WorkspaceSymbol': 'gS', 'SignatureHelp': 'gm', 'Completion': 'completefunc', } ]]
