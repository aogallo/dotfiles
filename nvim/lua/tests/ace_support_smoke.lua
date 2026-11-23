-- Offline public configuration contract; never starts a server or loads personal init.
local function check()
    vim.opt.rtp:prepend(vim.fn.getcwd() .. '/nvim')
    local temp = vim.fn.tempname()
    vim.fn.mkdir(temp .. '/applicationJava', 'p')
    vim.fn.mkdir(temp .. '/other/applicationJava', 'p')
    vim.fn.mkdir(temp .. '/flows', 'p')
    temp = vim.uv.fs_realpath(temp)
    local function run()
        vim.env.JCN_HOME = 'C:/Program Files/IBM/ACE/12/server/jplugin'
        vim.env.COMMON_CLASSES_HOME = 'C:/IBM/common/classes'
        vim.env.JDTLS_JAVA_HOME = 'C:/Java/jdk-25'
        vim.env.ACE_JAVA_HOME = 'C:/IBM/ACE/jre'
        vim.env.ACE_JAVA_VERSION = 'JavaSE-1.8'
        dofile 'nvim/plugin/ace.lua'
        assert(vim.filetype.match { filename = 'compute.esql' } == 'esql', 'dedicated ESQL filetype')
        for _, extension in ipairs { 'subflow', 'msgflow', 'wsdl', 'xsd', 'descriptor' } do
            assert(vim.filetype.match { filename = 'sample.' .. extension } == 'xml', extension .. ' is XML')
        end
        assert(vim.filetype.match { filename = 'sample.sql' } == 'sql', 'SQL unchanged')
        assert(vim.filetype.match { filename = 'Sample.java' } == 'java', 'Java unchanged')
        local java = dofile 'nvim/lsp/jdtls.lua'
        assert(vim.deep_equal(java.filetypes, { 'java' }), 'Java only')
        assert(java.cmd_env.JAVA_HOME == vim.env.JDTLS_JAVA_HOME, 'separate server JDK')
        assert(
            vim.deep_equal(java.settings.java.classpath.variables, {
                'JCN_HOME=' .. vim.env.JCN_HOME,
                'COMMON_CLASSES_HOME=' .. vim.env.COMMON_CLASSES_HOME,
            }),
            'Eclipse classpath variables use NAME=path, preserving spaces'
        )
        local runtime = java.settings.java.configuration.runtimes[1]
        assert(runtime.name == 'JavaSE-1.8' and runtime.path == vim.env.ACE_JAVA_HOME, 'explicit target runtime')
        local start = vim.lsp.rpc.start
        local launched, launch_options
        vim.lsp.rpc.start = function(command, _, options)
            launched, launch_options = command, options
            return 'test-rpc'
        end
        local first = vim.deepcopy(java)
        first.root_dir = temp .. '/applicationJava'
        assert(type(first.cmd) == 'function', 'workspace must be selected before RPC process starts')
        assert(first.cmd({}, first) == 'test-rpc', 'launch returns RPC client')
        assert(launch_options.env.JAVA_HOME == vim.env.JDTLS_JAVA_HOME, 'launch uses server JDK')
        assert(launch_options.cwd == first.root_dir, 'launch uses project directory')
        assert(launched[#launched - 1] == '-data', 'dedicated JDT workspace')
        local data = launched[#launched]
        assert(data ~= first.root_dir and not data:find(first.root_dir, 1, true), 'index outside sources')
        local second = vim.deepcopy(java)
        second.root_dir = temp .. '/other/applicationJava'
        second.cmd({}, second)
        assert(launched[#launched] ~= data, 'same project basename cannot share index')
        vim.lsp.rpc.start = start
        assert(not vim.uv.fs_stat(data), 'building launch config does not create state')
        vim.env.ACE_JAVA_HOME, vim.env.ACE_JAVA_VERSION = nil, nil
        vim.env.JCN_HOME, vim.env.COMMON_CLASSES_HOME, vim.env.JDTLS_JAVA_HOME = nil, nil, nil
        local plain = dofile 'nvim/lsp/jdtls.lua'
        assert(#plain.settings.java.classpath.variables == 0, 'IBM variables optional')
        assert(#plain.settings.java.configuration.runtimes == 0, 'no guessed ACE Java version')
        assert(plain.cmd_env == nil, 'ordinary Java keeps inherited server environment')
        local esql = dofile 'nvim/lsp/esql.lua'
        assert(vim.deep_equal(esql.filetypes, { 'esql' }), 'ESQL never attaches to SQL')
        local buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, temp .. '/flows/compute.esql')
        local resolved
        esql.root_dir(buf, function(dir)
            resolved = dir
        end)
        assert(
            resolved == temp .. '/flows',
            'ESQL starts without Git or project metadata: ' .. tostring(resolved) .. ' vs ' .. temp .. '/flows'
        )
        vim.api.nvim_buf_delete(buf, { force = true })
        local xml = dofile 'nvim/lsp/lemminx.lua'
        assert(vim.deep_equal(xml.filetypes, { 'xml' }), 'XML only')
        assert(xml.settings.xml.downloadExternalResources == false, 'no automatic remote schemas')
        local parsers = {}
        package.loaded['nvim-treesitter.parsers'] = parsers
        local ace = require 'config.ace'
        local has = vim.fn.has
        vim.fn.has = function(feature)
            return feature == 'win32' and 1 or has(feature)
        end
        assert(vim.deep_equal(ace.command 'jdtls', { 'cmd.exe', '/c', 'jdtls' }), 'Windows Mason shim')
        assert(vim.deep_equal(ace.command 'esql-lsp', { 'cmd.exe', '/c', 'esql-lsp' }), 'Windows npm shim')
        vim.fn.has = has
        ace.register_parser()
        assert(parsers.esql.install_info.location == 'tree-sitter-esql', 'monorepo grammar path')
        assert(parsers.esql.install_info.queries == 'tree-sitter-esql/queries', 'queries relative to repository')
        assert(#parsers.esql.install_info.revision == 40, 'grammar pinned')
        package.loaded['nvim-treesitter.parsers'] = {}
        vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })
        assert(package.loaded['nvim-treesitter.parsers'].esql, 'registration survives parser reload')
        local specs
        package.loaded['vim-pack'] = {
            add = function(value)
                specs = value
            end,
            on_plugin_update = function() end,
        }
        dofile 'nvim/plugin/treesitter.lua'
        specs[1].on_setup()
        local installed
        package.loaded['nvim-treesitter'] = {
            install = function(list)
                installed = list
                return { wait = function() end }
            end,
        }
        vim.cmd 'TSInstallConfigured'
        for _, language in ipairs { 'java', 'sql', 'go', 'xml', 'esql' } do
            assert(vim.tbl_contains(installed, language), 'configured parser ' .. language)
        end
        local sql = dofile 'nvim/lsp/sqls.lua'
        assert(vim.deep_equal(sql.filetypes, { 'sql', 'mysql', 'plsql' }), 'SQL LSP unchanged')
    end
    local ok, err = pcall(run)
    vim.fn.delete(temp, 'rf')
    assert(ok, err)
    print 'PASS ACE filetypes, Java launch/classpath/runtime/workspaces, ESQL roots, XML and parser registration'
end
local ok, err = pcall(check)
if not ok then
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd 'cquit 1'
end
vim.cmd 'qa!'
