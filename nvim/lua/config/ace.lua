-- Portable ACE editor support. Never writes Eclipse project metadata.
local M = {}

local function env(name)
    local value = vim.env[name]
    return value and value ~= '' and value or nil
end

-- Windows npm/Mason launchers are .cmd shims rather than native executables.
function M.command(name)
    return vim.fn.has 'win32' == 1 and { 'cmd.exe', '/c', name } or { name }
end

function M.java()
    local variables = {}
    for _, name in ipairs { 'JCN_HOME', 'COMMON_CLASSES_HOME' } do
        if env(name) then
            variables[#variables + 1] = name .. '=' .. env(name)
        end
    end
    local runtimes = {}
    if env 'ACE_JAVA_HOME' and env 'ACE_JAVA_VERSION' then
        runtimes[1] = { name = env 'ACE_JAVA_VERSION', path = env 'ACE_JAVA_HOME', default = true }
    end
    return {
        cmd = function(dispatchers, config)
            -- before_init runs after spawn: select -data in the RPC launcher instead.
            -- Hash the full root: identically named projects must not share an index.
            local root = config.root_dir or vim.fn.getcwd()
            root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
            local workspace = vim.fs.joinpath(vim.fn.stdpath 'cache', 'jdtls', vim.fn.sha256(root))
            local command = M.command 'jdtls'
            vim.list_extend(command, { '-data', workspace })
            return vim.lsp.rpc.start(command, dispatchers, {
                cwd = config.cmd_cwd or config.root_dir,
                env = config.cmd_env,
                detached = config.detached,
            })
        end,
        cmd_env = env 'JDTLS_JAVA_HOME' and { JAVA_HOME = env 'JDTLS_JAVA_HOME' } or nil,
        filetypes = { 'java' },
        root_markers = { '.project', 'pom.xml', 'build.gradle', 'build.gradle.kts', '.git' },
        settings = {
            java = {
                classpath = { variables = variables },
                configuration = { runtimes = runtimes },
            },
        },
    }
end

function M.esql_root(bufnr, on_dir)
    on_dir(vim.fs.root(bufnr, { '.project', '.git' }) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
end

function M.register_parser()
    -- Main-branch API; upstream's ESQL example uses the incompatible legacy API.
    require('nvim-treesitter.parsers').esql = {
        install_info = {
            url = 'https://github.com/nils-gg/esql-lsp',
            revision = 'b773cbf8a090083cb9a4b9eb813836f828111b4e',
            location = 'tree-sitter-esql',
            queries = 'tree-sitter-esql/queries',
        },
    }
    vim.treesitter.language.register('esql', 'esql')
end

return M
