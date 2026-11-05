-- Run from the repository root with:
-- nvim --headless -u NONE -i NONE --cmd 'set rtp^=./nvim' -l nvim/lua/tests/ui2_snacks_smoke.lua
-- Uses the installed Snacks package, without loading unrelated plugins or updating packages.
local failures = 0
local function check(ok, name)
    io.stdout:write((ok and 'PASS ' or 'FAIL ') .. name .. '\n')
    failures = failures + (ok and 0 or 1)
end

vim.cmd.packadd 'snacks.nvim'
local snacks = require 'snacks'
local spec
package.loaded['vim-pack'] = {
    add = function(specs)
        for _, candidate in ipairs(specs) do
            if candidate.src == 'folke/snacks.nvim' then
                spec = candidate
            end
        end
    end,
    add_on_event = function() end,
}
local cmd = vim.cmd
vim.cmd = setmetatable({}, {
    __index = cmd,
    __call = function(_, command)
        if command ~= 'colorscheme tokyonight' then
            return cmd(command)
        end
    end,
})
dofile 'nvim/plugin/editor.lua'
vim.cmd = cmd
snacks.setup { notifier = spec.opts.notifier, picker = { enabled = true } }
spec.on_setup()
vim.wait(20, function()
    return false
end)

local notifications = require 'notifications'
local full = string.rep('Long notification ', 12) .. '\nSecond line: complete details'
notifications.notify(full, 'warning', { id = 'full-message', source = 'Test' })
local function find(id)
    for _, entry in ipairs(snacks.notifier.get_history()) do
        if entry.id == id then
            return entry
        end
    end
end
local entry = find 'full-message'
check(entry and entry.msg == full, 'Snacks retains full multiline notifications without truncation')
check(entry and entry.level == 'warn' and entry.title == 'Test', 'severity and source survive the adapter')
notifications.notify('working', 'progress', { id = 'progress-test', icon = 'P' })
notifications.notify('finished', 'progress', { id = 'progress-test', icon = 'P' })
entry = find 'progress-test'
check(entry and entry.msg == 'finished' and entry.icon == 'P', 'progress updates keep their id and icon')
check(
    notifications.history == nil and notifications.capture_message == nil,
    'no parallel history or message capture API remains'
)
check(vim.notify == snacks.notifier.notify, 'Snacks owns vim.notify without a self-healing wrapper')
check(spec.opts.notifier.level == vim.log.levels.INFO, 'debug and trace are not displayed by default')

notifications.notify('Quiet debug details', 'debug', { id = 'debug-test' })
check(find 'debug-test' ~= nil, 'filtered debug notifications remain in Snacks history')
local action = notifications.wrap_action('Test action', function(value)
    return value, 'second'
end)
local first, second = action 'first'
check(first == 'first' and second == 'second', 'wrapped successful actions preserve arguments and results')
local before = #snacks.notifier.get_history()
notifications.wrap_action('Test failure', function()
    error 'failure details'
end)()
local errors = vim.tbl_filter(function(item)
    return item.title == 'Test failure'
        and item.level == 'error'
        and item.msg:find('failure details', 1, true)
        and item.msg:find('stack traceback', 1, true)
end, snacks.notifier.get_history())
check(#errors == 1 and #snacks.notifier.get_history() == before + 1, 'wrapped failures report one full traceback')

local history_opened = false
local show_history = snacks.notifier.show_history
snacks.notifier.show_history = function()
    history_opened = true
end
local leader = vim.g.mapleader or '\\'
local history_map = vim.fn.maparg(leader .. 'un', 'n', false, true)
if history_map.callback then
    history_map.callback()
end
snacks.notifier.show_history = show_history
check(history_opened, 'notification history key opens Snacks history directly')

require 'config.autocmds'
local captures = vim.tbl_filter(function(autocmd)
    return autocmd.group_name == 'aogallo/unified_message_capture'
end, vim.api.nvim_get_autocmds { event = 'CmdlineLeave' })
check(#captures == 0, 'native editor messages are not recaptured into notifications')

require 'config.options'
require 'config.keymaps'
for key, layout in pairs { ss = 'col', sv = 'row' } do
    vim.cmd 'silent! only'
    local buf = vim.api.nvim_get_current_buf()
    local mapping = vim.fn.maparg(key, 'n', false, true)
    if mapping.rhs then
        vim.api.nvim_feedkeys(vim.keycode(mapping.rhs), 'nx', false)
    end
    local tree = vim.fn.winlayout()
    check(tree[1] == layout and #vim.api.nvim_tabpage_list_wins(0) == 2, key .. ' creates the requested split')
    check(vim.api.nvim_get_current_buf() == buf, key .. ' preserves the current buffer')
end
vim.cmd 'silent! only'
local messages_map = vim.fn.maparg(vim.g.mapleader .. 'um', 'n', false, true)
check(
    messages_map.rhs and messages_map.rhs:lower() == '<cmd>messages<cr>',
    'editor message history has its own native keymap'
)
check(vim.fn.maparg('<C-h>', 'n') == '<C-W>h', 'existing window navigation remains available')

local ui_ok = pcall(require, 'config.ui')
check(ui_ok, 'UI2 configuration loads')
if ui_ok then
    local cfg = require('vim._core.ui2').cfg.msg
    check(cfg.target == 'msg' and cfg.targets.progress == 'msg', 'ordinary messages and progress stay ephemeral')
    check(cfg.targets.lua_error == 'pager' and cfg.targets.rpc_error == 'pager', 'tracebacks use the pager')
    check(cfg.targets.emsg == 'msg' and cfg.targets.echoerr == 'msg', 'ordinary errors do not steal focus')
    check(
        cfg.targets.search_count == 'cmd' and cfg.targets.completion == 'cmd',
        'search and completion stay in the command area'
    )
    check(
        cfg.msg.height == 0.3 and cfg.msg.timeout == 4000 and cfg.pager.height == 0.6,
        'message and pager dimensions are bounded'
    )
end

if failures > 0 then
    io.stderr:write(('%d UI2/Snacks assertions failed\n'):format(failures))
    vim.cmd 'cquit 1'
end
io.stdout:write 'All UI2/Snacks smoke assertions passed\n'
vim.cmd 'qa!'
