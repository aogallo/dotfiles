-- Check the integration entry point without plugins, a UI, or filesystem writes.
local function check_runtime(runtime, accepted)
    local observed, writes, commands = nil, 0, {}
    local fake_vim = {
        env = { NEOTEST_RUNTIME = runtime },
        fn = {
            getcwd = function()
                return '/repo'
            end,
            writefile = function()
                writes = writes + 1
            end,
        },
        split = function(message)
            return { message }
        end,
        opt = {
            rtp = {
                prepend = function()
                    error 'RUNTIME_ACCEPTED'
                end,
            },
        },
        api = {
            nvim_err_writeln = function(message)
                observed = message
            end,
        },
        cmd = function(command)
            commands[#commands + 1] = command
        end,
    }
    local chunk = assert(loadfile 'nvim/lua/tests/go_testing_integration.lua')
    setfenv(chunk, setmetatable({ vim = fake_vim, print = function() end }, { __index = _G }))
    chunk()
    local expected = accepted and 'RUNTIME_ACCEPTED' or 'NEOTEST_RUNTIME must be absolute'
    assert(observed and observed:find(expected, 1, true), runtime .. ': expected ' .. expected)
    assert(writes == 1, 'only the diagnostic log may be written; no fixture writes')
    assert(commands[1] == 'cquit 1' and commands[2] == 'qa!', 'preserve failure exit commands')
end

check_runtime('/tmp/neotest', true)
check_runtime('C:/runtime', true)
check_runtime('C:\\runtime', true)
check_runtime('\\\\server\\share\\runtime', true)
check_runtime('//server/share/runtime', true)
check_runtime('relative/runtime', false)
check_runtime('C:runtime', false)
check_runtime('\\runtime', false)
check_runtime('', false)
print 'PASS POSIX, Windows drive and UNC runtime paths; relative paths rejected before setup'

local inventory = table.concat(vim.fn.readfile 'nvim/dependencies.tsv', '\n')
for _, name in ipairs { 'goimports', 'golines' } do
    assert(
        inventory:find('|' .. name .. '|no|mason|MasonInstall ' .. name .. '|nvim/plugin/conform.lua', 1, true),
        name .. ' inventory entry'
    )
end
print 'PASS Mason Go formatter inventory'
