local notification_icons = require('icons').notifications

local M = {}

local history = {}
local active = {}

local HISTORY_LIMIT = 200
local DEDUPE_MS = 1500
local SUMMARY_LIMIT = 120

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

local function now()
    return vim.uv and vim.uv.now() or math.floor(vim.fn.reltimefloat(vim.fn.reltime()) * 1000)
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

local function summarize(message, details)
    local text = trim(message)
    local full = trim(details or message)
    local summary = vim.split(text, '\n', { plain = true, trimempty = true })[1] or text

    if #summary > SUMMARY_LIMIT then
        summary = summary:sub(1, SUMMARY_LIMIT - 1) .. '…'
    end

    if full == '' then
        full = summary
    end

    return summary, full
end

local function history_key(entry)
    return table.concat({ entry.source or '', entry.title or '', entry.severity, entry.summary }, '\n')
end

local function remember(entry)
    local key = entry.id or history_key(entry)
    local timestamp = now()

    entry.timestamp = timestamp
    entry.display_time = os.date '%H:%M'
    entry.icon = entry.icon or notification_icons[entry.severity] or notification_icons.info
    entry.key = key

    if entry.id and active[entry.id] then
        history[active[entry.id]] = entry
        return entry
    end

    for _, current in ipairs(history) do
        if current.key == key and timestamp - current.timestamp <= DEDUPE_MS then
            current.count = (current.count or 1) + 1
            current.timestamp = timestamp
            current.details = entry.details
            current.summary = entry.summary
            current.message = entry.message
            return current
        end
    end

    table.insert(history, 1, entry)
    if entry.id then
        active[entry.id] = 1
    end

    for id, index in pairs(active) do
        if id ~= entry.id then
            active[id] = index + 1
        end
    end

    while #history > HISTORY_LIMIT do
        local removed = table.remove(history)
        if removed and removed.id then
            active[removed.id] = nil
        end
    end

    return entry
end

---@param message any
---@param severity? string|integer
---@param opts? table
function M.notify(message, severity, opts)
    opts = vim.tbl_deep_extend('force', {}, opts or {})
    local normalized, level = M.normalize_severity(severity or opts.severity)
    local summary, details = summarize(message, opts.details)
    local source = opts.source or opts.title
    local title = opts.title or source or severity_titles[normalized]
    local entry = remember {
        id = opts.id,
        message = trim(message),
        summary = summary,
        details = details,
        severity = normalized,
        source = source,
        title = title,
        visible = opts.visible ~= false,
    }

    if not entry.visible then
        return entry
    end

    local notify_opts = vim.tbl_deep_extend('force', {}, opts, {
        title = title,
        icon = opts.icon or (notification_icons[normalized] or notification_icons.info) .. ' ',
    })
    notify_opts.details = nil
    notify_opts.notification = nil
    notify_opts.opts = nil
    notify_opts.severity = nil
    notify_opts.source = nil

    local ok = pcall(vim.notify, summary, level, notify_opts)
    if not ok then
        pcall(vim.api.nvim_echo, { { summary, 'WarningMsg' } }, true, {})
    end

    return entry
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

function M.capture_message(message, severity, opts)
    opts = opts or {}
    opts.source = opts.source or 'Messages'

    return M.notify(message, severity, opts)
end

local function history_items()
    return vim.iter(history)
        :map(function(entry)
            local count = entry.count and entry.count > 1 and (' ×' .. entry.count) or ''
            local time = entry.display_time or '--:--'
            local source = entry.source or entry.title or 'Notification'
            local text = ('%s %s %-7s %s %s%s'):format(
                time,
                entry.icon or '',
                entry.severity:upper(),
                source,
                entry.summary,
                count
            )

            return {
                text = text,
                severity = entry.severity,
                title = source,
                preview_title = source,
                preview = {
                    text = entry.details or entry.message or entry.summary,
                    ft = 'text',
                    loc = false,
                },
            }
        end)
        :totable()
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

function M.open_history()
    local snacks = rawget(_G, 'Snacks')
    local items = history_items()

    if snacks and snacks.notifier and snacks.notifier.show_history then
        local ok, snacks_history = pcall(function()
            return snacks.notifier.get_history and snacks.notifier.get_history() or {}
        end)

        if ok and #snacks_history > 0 then
            return snacks.notifier.show_history()
        end
    end

    if snacks and snacks.picker and #items > 0 then
        local ok, picker = pcall(snacks.picker.pick, {
            title = 'Notifications',
            finder = items,
            format = 'text',
            preview = 'preview',
            confirm = 'close',
        })
        if ok then
            return picker
        end
    end

    if snacks and snacks.notifier and snacks.notifier.show_history then
        return snacks.notifier.show_history()
    end

    if snacks and snacks.picker and snacks.picker.notifications then
        return snacks.picker.notifications()
    end

    if #history == 0 then
        return M.notify('No notifications or messages captured yet', 'info', { title = 'Notifications' })
    end

    local lines = vim.iter(items)
        :map(function(item)
            return item.text
        end)
        :totable()

    vim.fn.setqflist({}, ' ', { title = 'Notifications', lines = lines })
    vim.cmd.copen()
end

function M.history()
    return history
end

return M
