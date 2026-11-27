local add = require('vim-pack').add
local on_plugin_update = require('vim-pack').on_plugin_update

local parses = {
    'bash',
    'c',
    'cpp',
    'dart',
    'dockerfile',
    'dot',
    'fish',
    'gitcommit',
    'go',
    'graphql',
    'html',
    'hyprlang',
    'java',
    'javascript',
    'json',
    'json5',
    'lua',
    'markdown',
    'markdown_inline',
    'python',
    'query',
    'rasi',
    'regex',
    'rust',
    'scss',
    'sql',
    'toml',
    'tsx',
    'typescript',
    'vim',
    'vimdoc',
    'yaml',
    'terraform',
    'hcl',
}

local function add_treesitter_runtimepath()
    -- Main-branch nvim-treesitter ships queries under `runtime/`, which isn't
    -- on rtp by default. Prepend it so highlights/folds/indents are visible to
    -- `vim.treesitter.start`.
    local init = vim.api.nvim_get_runtime_file('lua/nvim-treesitter/init.lua', false)[1]
    if init then
        vim.opt.runtimepath:prepend(vim.fn.fnamemodify(init, ':h:h:h') .. '/runtime')
    end
end

local function install_parsers()
    require('nvim-treesitter').install(parses):wait(300000)
end

local function update_parsers()
    install_parsers()
    require('nvim-treesitter').update():wait(300000)
end

local incremental_selection = {
    bufnr = nil,
    nodes = {},
}

local function reset_incremental_selection(bufnr)
    incremental_selection.bufnr = bufnr
    incremental_selection.nodes = {}
end

local function get_node_at_cursor()
    local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = false })
    if ok then
        return node
    end
end

local function select_node(node)
    if not node then
        return
    end

    local start_row, start_col, end_row, end_col = node:range()
    local end_mark_col = end_col
    if end_mark_col == 0 then
        end_mark_col = 1
    end

    vim.fn.setpos("'<", { 0, start_row + 1, start_col + 1, 0 })
    vim.fn.setpos("'>", { 0, end_row + 1, end_mark_col, 0 })
    vim.cmd 'normal! gv'
end

local function start_incremental_selection()
    local bufnr = vim.api.nvim_get_current_buf()
    reset_incremental_selection(bufnr)

    local node = get_node_at_cursor()
    if not node then
        return
    end

    incremental_selection.nodes = { node }
    select_node(node)
end

local function expand_incremental_selection()
    local bufnr = vim.api.nvim_get_current_buf()
    if incremental_selection.bufnr ~= bufnr or #incremental_selection.nodes == 0 then
        start_incremental_selection()
        return
    end

    local node = incremental_selection.nodes[#incremental_selection.nodes]:parent()
    if not node then
        return
    end

    table.insert(incremental_selection.nodes, node)
    select_node(node)
end

local function shrink_incremental_selection()
    local bufnr = vim.api.nvim_get_current_buf()
    if incremental_selection.bufnr ~= bufnr or #incremental_selection.nodes < 2 then
        return
    end

    table.remove(incremental_selection.nodes)
    select_node(incremental_selection.nodes[#incremental_selection.nodes])
end

local function select_textobject(capture, query_group)
    return function()
        require('nvim-treesitter-textobjects.select').select_textobject(capture, query_group or 'textobjects')
    end
end

local function goto_textobject(direction, capture, query_group)
    return function()
        require('nvim-treesitter-textobjects.move')[direction](capture, query_group or 'textobjects')
    end
end

local function configure_textobjects()
    vim.keymap.set({ 'x', 'o' }, 'af', select_textobject '@function.outer', { desc = 'Select outer function' })
    vim.keymap.set({ 'x', 'o' }, 'if', select_textobject '@function.inner', { desc = 'Select inner function' })
    vim.keymap.set({ 'x', 'o' }, 'ac', select_textobject '@class.outer', { desc = 'Select outer class/type' })
    vim.keymap.set({ 'x', 'o' }, 'ic', select_textobject '@class.inner', { desc = 'Select inner class/type' })
    vim.keymap.set({ 'x', 'o' }, 'ao', select_textobject '@comment.outer', { desc = 'Select outer comment' })
    vim.keymap.set({ 'x', 'o' }, 'as', select_textobject('@local.scope', 'locals'), { desc = 'Select local scope' })

    vim.keymap.set({ 'n', 'x' }, '<leader>vs', start_incremental_selection, { desc = 'Start Treesitter selection' })
    vim.keymap.set({ 'n', 'x' }, '<leader>ve', expand_incremental_selection, { desc = 'Expand Treesitter selection' })
    vim.keymap.set('x', '<leader>vr', shrink_incremental_selection, { desc = 'Shrink Treesitter selection' })

    vim.keymap.set({ 'n', 'x', 'o' }, ']f', goto_textobject('goto_next_start', '@function.outer'), {
        desc = 'Next function start',
    })
    vim.keymap.set({ 'n', 'x', 'o' }, '[f', goto_textobject('goto_previous_start', '@function.outer'), {
        desc = 'Previous function start',
    })
    vim.keymap.set({ 'n', 'x', 'o' }, ']t', goto_textobject('goto_next_start', '@class.outer'), {
        desc = 'Next class/type start',
    })
    vim.keymap.set({ 'n', 'x', 'o' }, '[t', goto_textobject('goto_previous_start', '@class.outer'), {
        desc = 'Previous class/type start',
    })
end

-- Highlight, edit, and navigate code.
add {
    {
        src = 'nvim-treesitter/nvim-treesitter',
        on_setup = function()
            add_treesitter_runtimepath()

            vim.api.nvim_create_user_command('TSInstallConfigured', install_parsers, {
                desc = 'Install configured Treesitter parsers',
            })
            vim.api.nvim_create_user_command('TSUpdateConfigured', update_parsers, {
                desc = 'Update configured Treesitter parsers',
            })
        end,
    },
    {
        src = 'nvim-treesitter/nvim-treesitter-context',
        module_name = 'treesitter-context',
        opts = {
            max_lines = 3,
            multiline_threshold = 1,
            min_window_height = 20,
        },
        on_setup = function()
            vim.keymap.set('n', '[c', function()
                if vim.wo.diff then
                    return '[c'
                else
                    vim.schedule(function()
                        require('treesitter-context').go_to_context()
                    end)
                    return '<Ignore>'
                end
            end, { desc = 'Jump to upper context', expr = true })
        end,
    },
    {
        src = 'nvim-treesitter/nvim-treesitter-textobjects',
        opts = {
            move = {
                set_jumps = true,
            },
            select = {
                include_surrounding_whitespace = false,
                lookahead = true,
                selection_modes = {
                    ['@class.outer'] = 'V',
                    ['@comment.outer'] = 'V',
                    ['@function.outer'] = 'V',
                },
            },
        },
        on_setup = configure_textobjects,
    },
}

on_plugin_update('nvim-treesitter', function()
    update_parsers()
end)
