-- Manual installation:
--   Download the standalone bundle from:
--   https://github.com/aws-cloudformation/cloudformation-languageserver/releases
--
--   mkdir -p ~/.local/share/cfn-lsp/
--   unzip <zip name> -d ~/.local/share/cfn-lsp/
--
-- Override the server path with CFN_LSP_SERVER when testing another local bundle.

local default_server = vim.fn.expand '~/.local/share/cfn-lsp/cfn-lsp-server-standalone.js'
local server_path = vim.env.CFN_LSP_SERVER or default_server

local cfn_filename_patterns = {
    '%.cfn%.yml$',
    '%.cfn%.yaml$',
    '%.cloudformation%.yml$',
    '%.cloudformation%.yaml$',
    '%.template%.yml$',
    '%.template%.yaml$',
    'cloudformation.*%.yml$',
    'cloudformation.*%.yaml$',
    'cfn.*%.yml$',
    'cfn.*%.yaml$',
    'template%.yml$',
    'template%.yaml$',
}

local sam_filename_patterns = {
    'sam.*%.yml$',
    'sam.*%.yaml$',
    'template%.yml$',
    'template%.yaml$',
}

local function path_matches(path, patterns)
    local name = vim.fn.fnamemodify(path, ':t'):lower()
    for _, pattern in ipairs(patterns) do
        if name:match(pattern) then
            return true
        end
    end
    return false
end

local function read_head(bufnr)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return {}
    end

    local line_count = math.min(vim.api.nvim_buf_line_count(bufnr), 120)
    return vim.api.nvim_buf_get_lines(bufnr, 0, line_count, false)
end

local function classify_template(bufnr)
    local path = vim.api.nvim_buf_get_name(bufnr)
    local is_cfn_filename = path_matches(path, cfn_filename_patterns)
    local is_sam_filename = path_matches(path, sam_filename_patterns)
    local has_resources = false
    local has_cfn_marker = false

    for _, line in ipairs(read_head(bufnr)) do
        if
            line:match '^%s*#%s*cfn%-lsp:%s*cloudformation%s*$'
            or line:match '^%s*#%s*aws%-template:%s*cloudformation%s*$'
        then
            return 'cloudformation'
        end

        if line:match '^%s*#%s*cfn%-lsp:%s*sam%s*$' or line:match '^%s*#%s*aws%-template:%s*sam%s*$' then
            return 'sam'
        end

        if line:match '^%s*Transform:%s*AWS::Serverless%-2016%-10%-31%s*$' or line:match 'AWS::Serverless::' then
            return 'sam'
        end

        if
            line:match '^%s*AWSTemplateFormatVersion:'
            or line:match '^%s*Description:'
            or line:match '^%s*Parameters:'
            or line:match '^%s*Mappings:'
            or line:match '^%s*Conditions:'
            or line:match '^%s*Outputs:'
        then
            has_cfn_marker = true
        end

        if line:match '^%s*Resources:%s*$' then
            has_resources = true
        end

        if line:match 'AWS::[%w]+::[%w]+' then
            has_cfn_marker = true
        end
    end

    if has_resources and has_cfn_marker then
        return 'cloudformation'
    end

    if has_resources and (is_cfn_filename or is_sam_filename) then
        return 'cloudformation'
    end

    if is_cfn_filename then
        return 'cloudformation'
    end

    return nil
end

local function server_available()
    return vim.fn.executable 'node' == 1 and vim.fn.filereadable(server_path) == 1
end

return {
    cmd = {
        'node',
        server_path,
        '--stdio',
    },
    enabled = server_available,
    filetypes = { 'yaml', 'yml', 'json' },
    root_dir = function(bufnr, on_dir)
        local context = classify_template(bufnr)
        if not context then
            return
        end

        vim.b[bufnr].aws_template_context = context
        on_dir(vim.fs.root(bufnr, { '.git' }) or vim.fn.getcwd())
    end,
    initializationOptions = {
        aws = {
            clientInfo = {
                extension = {
                    name = 'neovim-cfn-lsp',
                },
            },
        },
    },
    settings = {
        aws = {
            telemetry = false,
        },
    },
}
