local notification_icons = require('icons').notifications

local M = {}

local severity_to_level = {
    trace = vim.log.levels.TRACE,
    debug = vim.log.levels.DEBUG,
    info = vim.log.levels.INFO,
    progress = vim.log.levels.INFO,
    warn = vim.log.levels.WARN,
    warning = vim.log.levels.WARN,
    error = vim.log.levels.ERROR,
}

local level_to_severity = {
    [vim.log.levels.TRACE] = 'trace',
    [vim.log.levels.DEBUG] = 'debug',
    [vim.log.levels.INFO] = 'info',
    [vim.log.levels.WARN] = 'warn',
    [vim.log.levels.ERROR] = 'error',
}

local severity_titles = {
    trace = 'Trace',
    debug = 'Debug',
    info = 'Info',
    progress = 'Progress',
    warn = 'Warning',
    error = 'Error',
}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

function M.normalize_severity(severity)
    if type(severity) == 'number' then
        return level_to_severity[severity] or 'info', severity
    end

    local normalized = tostring(severity or 'info'):lower()
    if normalized == 'warning' then
        normalized = 'warn'
    end

    return severity_to_level[normalized] and normalized or 'info', severity_to_level[normalized] or vim.log.levels.INFO
end

-- Keep the call sites' severity/source conventions without owning a second
-- history or replacing vim.notify. Snacks stores the complete notification.
---@param message any
---@param severity? string|integer
---@param opts? table
function M.notify(message, severity, opts)
    opts = vim.tbl_deep_extend('force', {}, opts or {})
    local normalized, level = M.normalize_severity(severity or opts.severity)
    local text = tostring(message or '')
    if opts.details and opts.details ~= text then
        text = text .. '\n' .. tostring(opts.details)
    end
    opts.title = opts.title or opts.source or severity_titles[normalized]
    opts.icon = opts.icon or (notification_icons[normalized] or notification_icons.info) .. ' '
    opts.details = nil
    opts.source = nil
    opts.severity = nil

    local ok, result = pcall(vim.notify, text, level, opts)
    if not ok then
        vim.api.nvim_echo({ { text, level >= vim.log.levels.ERROR and 'ErrorMsg' or 'WarningMsg' } }, true, {})
        return nil
    end
    return result
end

function M.command_failure(action, err)
    local details = debug.traceback(tostring(err), 2)
    local reason = trim(tostring(err)):gsub('\n.*$', '')
    local summary = ('%s failed: %s'):format(action or 'Command', reason)

    return M.notify(summary, 'error', {
        title = action or 'Command failed',
        source = 'Command',
        details = details,
    })
end

function M.wrap_action(action, callback)
    return function(...)
        local args = { ... }
        local ok, result = xpcall(function()
            return { callback(unpack(args)) }
        end, debug.traceback)

        if not ok then
            M.command_failure(action, result)
            return nil
        end

        return unpack(result)
    end
end

return M
