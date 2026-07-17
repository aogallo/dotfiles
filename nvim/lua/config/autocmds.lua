vim.api.nvim_create_autocmd('BufReadPost', {
    group = vim.api.nvim_create_augroup('aogallo/last_location', { clear = true }),
    desc = 'Go to the last location when opening a buffer',
    callback = function(args)
        local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
        local line_count = vim.api.nvim_buf_line_count(args.buf)
        if mark[1] > 0 and mark[1] <= line_count then
            vim.cmd 'normal! g`"zz'
        end
    end,
})

local line_numbers_group = vim.api.nvim_create_augroup('aogallo/toggle_line_numbers', {})
vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'InsertLeave', 'CmdlineLeave', 'WinEnter' }, {
    group = line_numbers_group,
    desc = 'Toggle relative line numbers on',
    callback = function()
        if vim.wo.nu and not vim.startswith(vim.api.nvim_get_mode().mode, 'i') then
            vim.wo.relativenumber = true
        end
    end,
})

vim.api.nvim_create_autocmd({ 'BufLeave', 'FocusLost', 'InsertEnter', 'CmdlineEnter', 'WinLeave' }, {
    group = line_numbers_group,
    desc = 'Toggle relative line numbers off',
    callback = function(args)
        if vim.wo.nu then
            vim.wo.relativenumber = false
        end

        -- Redraw here to avoid having to first write something for the line numbers to update.
        if args.event == 'CmdlineEnter' then
            if not vim.tbl_contains({ '@', '-' }, vim.v.event.cmdtype) then
                vim.cmd.redraw()
            end
        end
    end,
})

vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('aogallo/treesitter_folding', { clear = true }),
    desc = 'Enable Treesitter folding',
    callback = function(args)
        local bufnr = args.buf

        -- Enable Treesitter folding when not in huge files and when Treesitter
        -- is working.
        if vim.bo[bufnr].filetype ~= 'bigfile' and pcall(vim.treesitter.start, bufnr) then
            vim.api.nvim_buf_call(bufnr, function()
                vim.wo[0][0].foldmethod = 'expr'
                vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
                vim.cmd.normal 'zx'
            end)
        end
    end,
})

vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('aogallo/highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

local message_capture_group = vim.api.nvim_create_augroup('aogallo/unified_message_capture', { clear = true })
local last_captured_messages = {}

local function is_notification_lifecycle_error(message)
    return message:match '^E716: Key not present in Dictionary: "collapsed"$'
        or message:match '^E803: ID not found: %d+$'
end

local function capture_v_message(name, severity)
    local message = tostring(vim.v[name] or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if message == '' or last_captured_messages[name] == message then
        return false
    end

    last_captured_messages[name] = message
    if severity == 'error' and is_notification_lifecycle_error(message) then
        vim.v[name] = ''
        return false
    end

    require('notifications').capture_message(message, severity, {
        title = 'Editor message',
        source = 'Messages',
        details = message,
        visible = severity ~= 'info',
    })
    return true
end

vim.api.nvim_create_autocmd('CmdlineLeave', {
    group = message_capture_group,
    desc = 'Capture command-line messages in unified notification history',
    callback = function()
        vim.schedule(function()
            local captured = capture_v_message('errmsg', 'error')
                or capture_v_message('warningmsg', 'warn')
                or capture_v_message('statusmsg', 'info')
            if captured and vim.api.nvim_get_mode().mode ~= 'c' then
                pcall(vim.cmd, 'redraw!')
            end
        end)
    end,
})

vim.api.nvim_create_user_command('PackClean', function()
    local notifications = require 'notifications'
    local inactive = vim.iter(vim.pack.get())
        :filter(function(x)
            return not x.active
        end)
        :map(function(x)
            return x.spec.name
        end)
        :totable()

    if #inactive == 0 then
        notifications.notify('No inactive plugins to remove', 'info', { title = 'PackClean', source = 'Packages' })
        return
    end

    vim.pack.del(inactive)
    notifications.notify(
        'Removed: ' .. table.concat(inactive, ', '),
        'info',
        { title = 'PackClean', source = 'Packages' }
    )
end, { desc = 'Remove plugins not in vim.pack.add() specs' })
