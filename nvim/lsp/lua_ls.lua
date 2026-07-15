return {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    -- Sets the "workspace" to the directory where any of these files is found.
    root_markers = {
        '.luarc.json',
        '.luarc.jsonc',
        '.luacheckrc',
        '.stylua.toml',
        '.git',
    },
    settings = {
        Lua = {
            diagnostics = {
                globals = { 'Snacks' },
            },
            runtime = {
                version = 'LuaJIT',
            },
        },
    },
}
