-- Neovim 0.12 UI2 owns editor messages; Snacks owns vim.notify separately.
require('vim._core.ui2').enable {
    msg = {
        target = 'msg',
        targets = {
            emsg = 'msg',
            echoerr = 'msg',
            lua_error = 'pager',
            rpc_error = 'pager',
            list_cmd = 'pager',
            verbose = 'pager',
            shell_cmd = 'pager',
            shell_err = 'pager',
            shell_out = 'pager',
            shell_ret = 'pager',
            progress = 'msg',
            search_cmd = 'cmd',
            search_count = 'cmd',
            completion = 'cmd',
        },
        msg = {
            height = 0.3,
            timeout = 4000,
        },
        pager = {
            height = 0.6,
        },
    },
}
