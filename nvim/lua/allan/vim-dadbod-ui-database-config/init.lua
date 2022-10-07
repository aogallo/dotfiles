--local o = vim.o
 
--o.dbs = {
--  'mysql-local': 'mysql://cpauser:9by5IT#%j52rp7Bxgex7I$@localhost/contadorescpa'
--}

--o.db_ui_show_help = 0
vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_force_echo_notificacion = 1
vim.g.db_ui_show_database_icon= 1


-- opening it in a new tab 
vim.keymap.set('n', '<leader><leader>db', ':tab DBUI<cr>', {})

-- just close the tab, but context related of the keybinding 
vim.keymap.set('n', '<leader><leader>tq', ':tabclose<cr>')
