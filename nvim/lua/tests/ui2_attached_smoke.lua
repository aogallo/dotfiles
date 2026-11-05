-- Exercise UI2 with a real attached UI: headless alone skips UI2.enable().
-- nvim --headless -u NONE -i NONE -l nvim/lua/tests/ui2_attached_smoke.lua
-- A raw RPC client consumes redraw notifications; a Neovim RPC peer does not.
local responses, next_id = {}, 0
local unpacker = vim.mpack.Unpacker()
local child = vim.system({ vim.v.progpath, '--embed', '-u', 'NONE', '-i', 'NONE', '-n' }, {
    stdin = true,
    stdout = function(_, data)
        if not data then
            return
        end
        local offset = 1
        while offset <= #data do
            local message
            message, offset = unpacker(data, offset)
            if message and message[1] == 1 then
                responses[message[2]] = message
            end
        end
    end,
})
local function request(method, ...)
    next_id = next_id + 1
    local id = next_id
    child:write(vim.mpack.encode { 0, id, method, { ... } })
    assert(
        vim.wait(5000, function()
            return responses[id] ~= nil
        end, 5),
        'RPC timeout: ' .. method
    )
    local response = responses[id]
    responses[id] = nil
    assert(response[3] == vim.NIL, vim.inspect(response[3]))
    return response[4]
end
local function lua(code, ...)
    return request('nvim_exec_lua', code, { ... })
end
local function settle()
    lua 'vim.wait(30, function() return false end)'
end
local function check(ok, name)
    assert(ok, name)
    io.stdout:write('PASS ' .. name .. '\n')
end
local ok, err = xpcall(function()
    request('nvim_ui_attach', 120, 40, { rgb = true, ext_linegrid = true })
    lua('vim.opt.rtp:prepend(...)', vim.fn.getcwd() .. '/nvim')
    for _, command in ipairs {
        "vim.cmd.packadd('snacks.nvim')",
        "require('snacks').setup({ notifier = { enabled = true } })",
        "require('config.options')",
        "require('config.keymaps')",
        "require('config.autocmds')",
        "require('config.ui')",
    } do
        local loaded = lua('return {pcall(function() ' .. command .. ' end)}')
        assert(loaded[1], command .. ': ' .. vim.inspect(loaded[2]))
    end
    settle()
    local original = request 'nvim_get_current_win'
    lua [[vim.api.nvim_echo({{'Native editor message'}}, true, {})]]
    settle()
    check(request 'nvim_get_current_win' == original, 'ordinary native messages keep editor focus')
    lua [[require('notifications').notify('Full notification\nSecond line', 'warn', {id='ui-check'})]]
    settle()
    check(request 'nvim_get_current_win' == original, 'Snacks notification does not steal editor focus')
    local entry = lua [[
        for _, item in ipairs(Snacks.notifier.get_history()) do
            if item.id == 'ui-check' then return {item.msg, item.level} end
        end
    ]]
    check(
        entry and entry[1] == 'Full notification\nSecond line' and entry[2] == 'warn',
        'attached Snacks preserves full notification text'
    )
    local messages = request('nvim_exec2', 'messages', { output = true }).output
    check(messages:find('Native editor message', 1, true) ~= nil, 'native history records editor messages')
    check(not messages:find('Full notification', 1, true), 'Snacks notifications are not duplicated in native history')
    local count = lua 'return #Snacks.notifier.get_history()'
    lua [[vim.api.nvim_exec_autocmds('CmdlineLeave', {pattern=':'})]]
    settle()
    check(lua 'return #Snacks.notifier.get_history()' == count, 'leaving cmdline does not recapture native messages')

    for _, width in ipairs { 80, 120, 160 } do
        request('nvim_ui_try_resize', width, 40)
        request('nvim_command', 'messages')
        settle()
        local pager = lua [[
            return {vim.bo.filetype, vim.api.nvim_win_get_height(0),
                table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')}
        ]]
        check(
            pager[1] == 'pager' and pager[2] <= 24 and pager[3]:find('Native editor message', 1, true),
            'native pager opens with bounded height at ' .. width .. ' columns'
        )
        request('nvim_input', 'q')
        settle()
        check(request 'nvim_get_current_win' == original, 'q returns to editor at ' .. width .. ' columns')
    end
end, function(error)
    return vim.inspect(error) .. '\n' .. debug.traceback()
end)
child:write(vim.mpack.encode { 2, 'nvim_command', { 'qa!' } })
local result = child:wait(1000)
if result.code ~= 0 then
    ok, err = false, 'Embedded Neovim failed: ' .. tostring(result.stderr)
end
if not ok then
    io.stderr:write(err .. '\n')
    vim.cmd 'cquit 1'
end
io.stdout:write 'All attached UI2 smoke assertions passed\n'
vim.cmd 'qa!'
