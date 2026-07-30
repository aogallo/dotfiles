local M = {}

local uv = vim.uv or vim.loop

local function notify(message, level)
    local ok, notifications = pcall(require, 'notifications')
    if ok then
        notifications.notify(message, level or 'info', { title = 'PackClean', source = 'Packages' })
    else
        vim.notify(message, vim.log.levels[(level or 'info'):upper()] or vim.log.levels.INFO, { title = 'PackClean' })
    end
end

local function module_root()
    local source = debug.getinfo(1, 'S').source:sub(2)
    return vim.fs.dirname(vim.fs.dirname(source))
end

local function lockfile_path()
    return vim.fs.joinpath(module_root(), 'nvim-pack-lock.json')
end

local function plugin_name_from_source(source)
    if not source then
        return nil
    end

    return source:gsub('%.git$', ''):match '([^/]+)$'
end

local function normalize_path(path)
    if not path or path == '' then
        return nil
    end

    return vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
end

local function realpath(path)
    local normalized = normalize_path(path)
    if not normalized then
        return nil
    end

    return vim.fs.normalize(uv.fs_realpath(normalized) or normalized)
end

local function path_exists(path)
    return path and uv.fs_stat(path) ~= nil
end

local function add_unique(list, seen, path)
    local resolved = realpath(path)
    if resolved and not seen[resolved] then
        seen[resolved] = true
        table.insert(list, resolved)
    end
end

local function parent_package_root(path)
    local normalized = normalize_path(path)
    if not normalized then
        return nil
    end

    local parent = vim.fs.dirname(normalized)
    if parent:match '/pack/[^/]+/start$' or parent:match '/pack/[^/]+/opt$' then
        return parent
    end

    return nil
end

function M.package_roots(managed_plugins)
    local roots = {}
    local seen = {}

    for _, kind in ipairs { 'start', 'opt' } do
        add_unique(roots, seen, vim.fs.joinpath(vim.fn.stdpath 'data', 'site', 'pack', 'core', kind))
    end

    for _, plugin in ipairs(managed_plugins or {}) do
        add_unique(roots, seen, parent_package_root(plugin.path))
    end

    return roots
end

local function is_subpath(path, root)
    local resolved_path = realpath(path)
    local resolved_root = realpath(root)

    if
        resolved_path
        and resolved_root
        and (resolved_path == resolved_root or vim.startswith(resolved_path, resolved_root .. '/'))
    then
        return true
    end

    path = normalize_path(path)
    root = normalize_path(root)

    if not path or not root then
        return false
    end

    return path == root or vim.startswith(path, root .. '/')
end

function M.validate_path(path, roots)
    local resolved = realpath(path)
    if not resolved then
        return false, nil, 'missing path'
    end

    for _, root in ipairs(roots or {}) do
        if is_subpath(resolved, root) then
            return true, resolved
        end
    end

    return false, resolved, 'outside allowed package roots'
end

function M.read_lockfile(path)
    path = path or lockfile_path()

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or not lines or #lines == 0 then
        return { plugins = {} }, path
    end

    local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))
    if not ok_decode or type(decoded) ~= 'table' then
        return { plugins = {} }, path
    end

    decoded.plugins = decoded.plugins or {}
    return decoded, path
end

local function encode_lockfile(lockfile)
    local lines = { '{', '  "plugins": {' }
    local names = vim.tbl_keys(lockfile.plugins or {})
    table.sort(names)

    for index, name in ipairs(names) do
        local entry = lockfile.plugins[name] or {}
        local suffix = index == #names and '' or ','
        table.insert(lines, string.format('    %s: {', vim.json.encode(name)))
        table.insert(lines, string.format('      "rev": %s,', vim.json.encode(entry.rev or entry.revision or '')))
        table.insert(lines, string.format('      "src": %s', vim.json.encode(entry.src or entry.source or '')))
        table.insert(lines, '    }' .. suffix)
    end

    table.insert(lines, '  }')
    table.insert(lines, '}')
    return lines
end

function M.write_lockfile(lockfile, path)
    path = path or lockfile_path()
    vim.fn.writefile(encode_lockfile(lockfile), path)
end

local function pack_get()
    local ok, plugins = pcall(vim.pack.get)
    if ok and type(plugins) == 'table' then
        return plugins
    end

    return {}
end

local function plugin_identity(plugin)
    local spec = plugin.spec or {}
    local name = spec.name or plugin.name or plugin_name_from_source(spec.src) or plugin_name_from_source(plugin.src)
    local source = spec.src or plugin.src

    return name, source
end

local function lockfile_entry_for(lock_plugins, name, source)
    if name and lock_plugins[name] then
        return name, lock_plugins[name]
    end

    for lock_name, entry in pairs(lock_plugins) do
        if source and entry.src == source then
            return lock_name, entry
        end
    end

    return nil, nil
end

local function add_candidate(candidates, seen, candidate)
    local key = table.concat({ candidate.candidate_type or '', candidate.name or '', candidate.path or '' }, '|')
    if seen[key] then
        return
    end

    seen[key] = true
    table.insert(candidates, candidate)
end

local function scan_disk_only(root, state, candidates, seen)
    if not path_exists(root) then
        return
    end

    local handle = uv.fs_scandir(root)
    if not handle then
        return
    end

    while true do
        local name, kind = uv.fs_scandir_next(handle)
        if not name then
            break
        end

        if kind == 'directory' then
            local path = vim.fs.joinpath(root, name)
            local resolved = realpath(path)
            local lock_name = lockfile_entry_for(state.lock_plugins, name)

            state.installed_names[name] = true

            if not state.managed_paths[resolved] and not state.active_names[name] then
                add_candidate(candidates, seen, {
                    name = name,
                    path = resolved,
                    active = false,
                    installed = true,
                    lockfile_present = lock_name ~= nil,
                    candidate_type = 'disk-only',
                    reason = 'Installed under a managed package root but absent from active vim.pack state.',
                })
            end
        end
    end
end

function M.collect_candidates()
    local managed_plugins = pack_get()
    local lockfile = M.read_lockfile()
    local roots = M.package_roots(managed_plugins)
    local candidates = {}
    local seen = {}
    local state = {
        active_names = {},
        active_sources = {},
        installed_names = {},
        lock_plugins = lockfile.plugins or {},
        managed_paths = {},
    }

    for _, plugin in ipairs(managed_plugins) do
        local name, source = plugin_identity(plugin)
        local resolved = realpath(plugin.path)

        if resolved then
            state.managed_paths[resolved] = true
        end

        if plugin.active then
            if name then
                state.active_names[name] = true
            end
            if source then
                state.active_sources[source] = true
            end
        else
            local lock_name = lockfile_entry_for(state.lock_plugins, name, source)
            local installed = path_exists(resolved)
            add_candidate(candidates, seen, {
                name = name,
                source = source,
                path = resolved,
                active = false,
                installed = installed,
                lockfile_present = lock_name ~= nil,
                lockfile_name = lock_name,
                candidate_type = installed and 'inactive-managed' or 'missing',
                reason = installed and 'Managed by vim.pack but inactive in the current session.'
                    or 'Managed by vim.pack but the plugin directory is missing.',
            })
        end

        if name and path_exists(resolved) then
            state.installed_names[name] = true
        end
    end

    for _, root in ipairs(roots) do
        scan_disk_only(root, state, candidates, seen)
    end

    for name, entry in pairs(state.lock_plugins) do
        local source = entry.src or entry.source
        local active = state.active_names[name] or state.active_sources[source]
        local installed = state.installed_names[name]

        if not active and not installed then
            add_candidate(candidates, seen, {
                name = name,
                source = source,
                active = false,
                installed = false,
                lockfile_present = true,
                lockfile_name = name,
                candidate_type = 'lockfile-only',
                reason = 'Present in nvim-pack-lock.json but absent from active vim.pack state.',
            })
        end
    end

    table.sort(candidates, function(left, right)
        return (left.name or '') < (right.name or '')
    end)

    return candidates, roots
end

local function remove_path(candidate, roots)
    local safe, resolved, reason = M.validate_path(candidate.path, roots)
    if not safe then
        return 'blocked', reason or 'outside allowed package roots'
    end

    if not path_exists(resolved) then
        return 'not_found', 'path not found'
    end

    if candidate.candidate_type == 'inactive-managed' then
        local ok, err = pcall(vim.pack.del, { candidate.name })
        if not ok then
            return 'errors', tostring(err)
        end
    else
        local ok, err = pcall(vim.fs.rm, resolved, { recursive = true, force = false })
        if not ok then
            return 'errors', tostring(err)
        end
    end

    return 'removed', 'disk'
end

function M.execute(candidates, opts)
    opts = opts or {}
    local roots = opts.roots or M.package_roots(pack_get())
    local lockfile, path = M.read_lockfile(opts.lockfile_path)
    local report = { removed = {}, skipped = {}, blocked = {}, not_found = {}, errors = {} }
    local lockfile_changed = false

    if not opts.confirmed then
        for _, candidate in ipairs(candidates or {}) do
            table.insert(report.skipped, (candidate.name or '<unknown>') .. ' (confirmation required)')
        end
        return report
    end

    for _, candidate in ipairs(candidates or {}) do
        local name = candidate.name or '<unknown>'

        if candidate.active then
            table.insert(report.blocked, name .. ' (active plugin)')
        else
            local result, detail
            if candidate.path then
                result, detail = remove_path(candidate, roots)
            end

            local lockfile_name = candidate.lockfile_name
                or lockfile_entry_for(lockfile.plugins or {}, candidate.name, candidate.source)
            if
                lockfile_name
                and not candidate.active
                and lockfile.plugins[lockfile_name]
                and result ~= 'blocked'
                and result ~= 'errors'
            then
                lockfile.plugins[lockfile_name] = nil
                lockfile_changed = true
                if result == nil or result == 'removed' then
                    result = 'removed'
                    detail = detail == 'disk' and 'disk, lockfile' or 'lockfile'
                end
            end

            result = result or 'skipped'
            detail = detail or 'no cleanup action available'
            table.insert(report[result], name .. ' (' .. detail .. ')')
        end
    end

    if lockfile_changed then
        local ok, err = pcall(M.write_lockfile, lockfile, path)
        if not ok then
            table.insert(report.errors, 'lockfile (' .. tostring(err) .. ')')
        end
    end

    return report
end

local function format_candidates(candidates)
    local lines = {}

    for _, candidate in ipairs(candidates) do
        table.insert(
            lines,
            string.format(
                '- %s [%s, active=%s, installed=%s, lockfile=%s]\n  %s%s',
                candidate.name or '<unknown>',
                candidate.candidate_type or 'unknown',
                tostring(candidate.active),
                tostring(candidate.installed),
                candidate.lockfile_present and 'present' or 'absent',
                candidate.path and ('Path: ' .. candidate.path .. '\n  ') or '',
                candidate.reason or 'No reason provided.'
            )
        )
    end

    return table.concat(lines, '\n')
end

local function format_report(report)
    local lines = {}

    for _, section in ipairs { 'removed', 'skipped', 'blocked', 'not_found', 'errors' } do
        local items = report[section] or {}
        table.insert(lines, section .. ': ' .. (#items == 0 and 'none' or table.concat(items, ', ')))
    end

    return table.concat(lines, '\n')
end

local function candidate_state(candidate)
    return candidate.active and 'active' or 'inactive'
end

local function lockfile_state(candidate)
    return candidate.lockfile_present and 'present' or 'absent'
end

local function candidate_text(candidate)
    return table.concat({
        candidate.name or '<unknown>',
        candidate.path or '<lockfile only>',
        candidate_state(candidate),
        lockfile_state(candidate),
        candidate.reason or 'No reason provided.',
    }, ' ')
end

local function candidate_preview(candidate)
    return table.concat({
        '# ' .. (candidate.name or '<unknown>'),
        '',
        '- Type: ' .. (candidate.candidate_type or 'unknown'),
        '- Path: ' .. (candidate.path or '<lockfile only>'),
        '- Active: ' .. candidate_state(candidate),
        '- Installed: ' .. tostring(candidate.installed),
        '- Lockfile: ' .. lockfile_state(candidate),
        '- Source: ' .. (candidate.source or '<unknown>'),
        '',
        'Reason: ' .. (candidate.reason or 'No reason provided.'),
        '',
        'Safety: deletion still requires explicit confirmation and path-boundary validation.',
    }, '\n')
end

local function picker_item(candidate, index)
    return {
        idx = index,
        text = candidate_text(candidate),
        item = candidate,
        preview = {
            text = candidate_preview(candidate),
            ft = 'markdown',
        },
    }
end

local function format_picker_item(item)
    local candidate = item.item or item
    return {
        { candidate.name or '<unknown>', 'SnacksPickerFile' },
        { '  ' },
        { candidate.candidate_type or 'unknown', 'SnacksPickerComment' },
        { '  ' },
        { candidate_state(candidate), candidate.active and 'DiagnosticWarn' or 'DiagnosticOk' },
        { '  lockfile=' },
        { lockfile_state(candidate), candidate.lockfile_present and 'DiagnosticWarn' or 'Comment' },
        { '  ' },
        { candidate.path or '<lockfile only>', 'SnacksPickerPathHidden' },
        { '  ' },
        { candidate.reason or 'No reason provided.', 'Comment' },
    }
end

local function confirm_and_execute(selected, roots)
    if #selected == 0 then
        notify('No PackClean candidates selected.', 'info')
        return
    end

    vim.ui.input(
        { prompt = string.format('Clean %d selected PackClean candidate(s)? Type yes to confirm: ', #selected) },
        function(input)
            if input ~= 'yes' then
                notify(format_report(M.execute(selected, { roots = roots, confirmed = false })), 'info')
                return
            end

            notify(format_report(M.execute(selected, { roots = roots, confirmed = true })), 'info')
        end
    )
end

local function open_snacks_picker(candidates, roots)
    local snacks = rawget(_G, 'Snacks')
    if not (snacks and snacks.picker and snacks.picker.pick) then
        return false
    end

    local items = vim.iter(candidates)
        :enumerate()
        :map(function(index, candidate)
            return picker_item(candidate, index)
        end)
        :totable()

    local ok = pcall(snacks.picker.pick, {
        title = 'PackClean',
        finder = items,
        format = format_picker_item,
        preview = 'preview',
        confirm = function(picker)
            local selected = vim.iter(picker:selected { fallback = true })
                :map(function(item)
                    return item.item or item
                end)
                :totable()
            picker:close()
            vim.schedule(function()
                confirm_and_execute(selected, roots)
            end)
        end,
    })

    if not ok then
        return false
    end

    notify(
        'PackClean review opened. Use <Tab> to select candidates, <C-a> to select all, and <CR> to review confirmation.',
        'info'
    )
    return true
end

local function open_fallback(candidates, roots)
    notify(
        'Snacks picker is unavailable; using vim.ui.input fallback. Review candidates below before confirming.\n'
            .. format_candidates(candidates),
        'warn'
    )
    vim.ui.input({ prompt = 'Clean all listed PackClean candidates? Type yes to confirm: ' }, function(input)
        if input ~= 'yes' then
            notify(format_report(M.execute(candidates, { roots = roots, confirmed = false })), 'info')
            return
        end

        notify(format_report(M.execute(candidates, { roots = roots, confirmed = true })), 'info')
    end)
end

function M.open()
    local candidates, roots = M.collect_candidates()
    if #candidates == 0 then
        notify('No plugin cleanup candidates found.', 'info')
        return
    end

    if open_snacks_picker(candidates, roots) then
        return
    end

    open_fallback(candidates, roots)
end

M._format_report = format_report
M._format_candidates = format_candidates
M._lockfile_path = lockfile_path

return M
