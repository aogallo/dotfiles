local icons = require 'icons'

local M = {}

local starting_directory = vim.fn.fnamemodify(vim.fn.getcwd(), ':p'):gsub('/$', '')

-- Do not show the command that produced the quickfix list
vim.g.qf_disable_statusline = 1

--- Keeps track the highlight groups
--- @type table<string, boolean>
local statusline_hls = {}

---@param hl string
---return string
function M.get_or_create_hl(hl)
    local hl_name = 'Statusline' .. hl

    if not statusline_hls[hl] then
        local bg_hl = vim.api.nvim_get_hl(0, { name = 'StatusLine' })
        local fg_hl = vim.api.nvim_get_hl(0, { name = hl })
        vim.api.nvim_set_hl(0, hl_name, { bg = ('#%06x'):format(bg_hl.bg), fg = ('#%06x'):format(fg_hl.fg) })
        statusline_hls[hl] = true
    end

    return hl_name
end

--- Current mode.
---@return string
function M.mode_component()
    -- Note that: \19 = ^S and \22 = ^V.
    local mode_to_str = {
        ['n'] = 'NORMAL',
        ['no'] = 'OP-PENDING',
        ['nov'] = 'OP-PENDING',
        ['noV'] = 'OP-PENDING',
        ['no\22'] = 'OP-PENDING',
        ['niI'] = 'NORMAL',
        ['niR'] = 'NORMAL',
        ['niV'] = 'NORMAL',
        ['nt'] = 'NORMAL',
        ['ntT'] = 'NORMAL',
        ['v'] = 'VISUAL',
        ['vs'] = 'VISUAL',
        ['V'] = 'VISUAL',
        ['Vs'] = 'VISUAL',
        ['\22'] = 'VISUAL',
        ['\22s'] = 'VISUAL',
        ['s'] = 'SELECT',
        ['S'] = 'SELECT',
        ['\19'] = 'SELECT',
        ['i'] = 'INSERT',
        ['ic'] = 'INSERT',
        ['ix'] = 'INSERT',
        ['R'] = 'REPLACE',
        ['Rc'] = 'REPLACE',
        ['Rx'] = 'REPLACE',
        ['Rv'] = 'VIRT REPLACE',
        ['Rvc'] = 'VIRT REPLACE',
        ['Rvx'] = 'VIRT REPLACE',
        ['c'] = 'COMMAND',
        ['cv'] = 'VIM EX',
        ['ce'] = 'EX',
        ['r'] = 'PROMPT',
        ['rm'] = 'MORE',
        ['r?'] = 'CONFIRM',
        ['!'] = 'SHELL',
        ['t'] = 'TERMINAL',
    }

    -- Get the respective string to display
    local mode = mode_to_str[vim.api.nvim_get_mode().mode] or 'UNKNOWN'
    local hl = 'Other'
    if mode:find 'NORMAL' then
        hl = 'Normal'
    elseif mode:find 'PENDING' then
        hl = 'Pending'
    elseif mode:find 'VISUAL' then
        hl = 'Visual'
    elseif mode:find 'INSERT' or mode:find 'SELECT' then
        hl = 'Insert'
    elseif mode:find 'COMMAND' or mode:find 'TERMINAL' or mode:find 'EX' then
        hl = 'Command'
    end

    return table.concat {
        string.format('%%#StatuslineModeSeparator%s# ', hl),
        string.format('%%#StatuslineMode%s#%s', hl, mode),
        string.format(' %%#StatuslineModeSeparator%s#', hl),
    }
end

--- Git status
---@return string
function M.git_component()
    local head = vim.b.gitsigns_head
    if not head or head == '' then
        return ''
    end

    local component = string.format(' %s', head)

    local num_hunks = #(require('gitsigns').get_hunks() or {})
    if num_hunks > 0 then
        component = component .. string.format(' ~%d', num_hunks)
    end

    return component
end

--- The current debugging status
---@return string?
function M.dap_component()
    if not package.loaded['dap'] or require('dap').status() == '' then
        return nil
    end
    return string.format('%%#%s#%s  %s', M.get_or_create_hl 'Special', icons.misc.bug, require('dap').status())
end

--- The buffer's filetype.
---@return string
function M.filetype_component()
    local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

    local special_icons = {
        DiffviewFileHistory = { icons.misc.git, 'Number' },
        DiffviewFiles = { icons.misc.git, 'Number' },
        ['ccc-ui'] = { icons.misc.palette, 'Comment' },
        ['dap-view'] = { icons.misc.bug, 'Special' },
        ['grug-far'] = { icons.misc.search, 'Constant' },
        ['nvim-pack'] = { icons.symbol_kinds.Method, 'Special' },
        fzf = { icons.misc.terminal, 'Special' },
        gitcommit = { icons.misc.git, 'Number' },
        gitrebase = { icons.misc.git, 'Number' },
        minifiles = { icons.symbol_kinds.Folder, 'Directory' },
        qf = { icons.misc.search, 'Conditional' },
    }

    local filetype = vim.bo.filetype
    if filetype == '' then
        filetype = '[No Name]'
    end

    local icon, icon_hl = '', 'Normal'
    if special_icons[filetype] then
        icon, icon_hl = unpack(special_icons[filetype])
    elseif has_devicons then
        local buf_name = vim.api.nvim_buf_get_name(0)
        local name, ext = vim.fn.fnamemodify(buf_name, ':t'), vim.fn.fnamemodify(buf_name, ':e')

        icon, icon_hl = devicons.get_icon(name, ext)
        if not icon then
            icon, icon_hl = devicons.get_icon_by_filetype(filetype, { default = true })
        end
    end
    icon_hl = M.get_or_create_hl(icon_hl)
    return string.format('%%#%s#%s %%#StatuslineTitle#%s', icon_hl, icon, filetype)
end

---@param path string
---@return string
local function statusline_escape(path)
    return path:gsub('%%', '%%%%'):gsub('[\r\n]', ' ')
end

---@param buftype string
---@param filetype string
---@param name string
---@return string?
local function special_buffer_label(buftype, filetype, name)
    if buftype == '' then
        return nil
    end

    if buftype == 'quickfix' then
        return 'Quickfix'
    end

    if buftype == 'help' then
        return string.format('Help: %s', vim.fn.fnamemodify(name, ':t:r'))
    end

    if buftype == 'terminal' then
        return 'Terminal'
    end

    if filetype ~= '' then
        return string.format('%s buffer', filetype)
    end

    return string.format('%s buffer', buftype)
end

---@param path string
---@return string
local function path_from_starting_directory(path)
    local absolute_path = vim.fn.fnamemodify(path, ':p')
    local base = starting_directory .. '/'

    if vim.startswith(absolute_path, base) then
        return absolute_path:sub(#base + 1)
    end

    local home_path = vim.fn.fnamemodify(absolute_path, ':~')
    if home_path ~= absolute_path then
        return home_path
    end

    return string.format(
        '…/%s/%s',
        vim.fn.fnamemodify(absolute_path, ':h:t'),
        vim.fn.fnamemodify(absolute_path, ':t')
    )
end

---@param path string
---@return string
local function width_aware_path(path)
    local width = vim.api.nvim_win_get_width(0)
    local max_width = math.min(80, math.max(24, math.floor(width * 0.45)))

    if #path <= max_width then
        return path
    end

    local segments = vim.split(path, '/', { plain = true, trimempty = true })
    for count = math.min(4, #segments), 2, -1 do
        local tail = table.concat(vim.list_slice(segments, #segments - count + 1), '/')
        local candidate = count < #segments and string.format('…/%s', tail) or tail
        if #candidate <= max_width then
            return candidate
        end
    end

    local filename = vim.fn.fnamemodify(path, ':t')
    local parent = vim.fn.fnamemodify(path, ':h')
    local shortened = parent ~= '.' and string.format('%s/%s', vim.fn.pathshorten(parent), filename) or filename

    if #shortened <= max_width then
        return shortened
    end

    local parent_name = vim.fn.fnamemodify(parent, ':t')
    local parent_filename = parent_name ~= '' and string.format('…/%s/%s', parent_name, filename) or filename

    if #parent_filename <= max_width then
        return parent_filename
    end

    return filename
end

--- Return the file name
---@return string
function M.file_component()
    local name = vim.api.nvim_buf_get_name(0)
    local buftype = vim.bo.buftype
    local filetype = vim.bo.filetype
    local label = special_buffer_label(buftype, filetype, name)

    if not label then
        label = name == '' and '[No Name]' or width_aware_path(path_from_starting_directory(name))
    end

    local indicators = {}
    if vim.bo.modified then
        table.insert(indicators, '●')
    end
    if vim.bo.readonly or not vim.bo.modifiable then
        table.insert(indicators, '')
    end

    local state = #indicators > 0 and string.format(' %%#StatuslineItalic#%s', table.concat(indicators, '')) or ''

    return string.format('%%<%%#StatuslineTitle#%s%s', statusline_escape(label), state)
end

--- File-content encoding for the current buffer.
---@return string
function M.encoding_component()
    local encoding = vim.opt.fileencoding:get()
    return encoding ~= '' and string.format('%%#StatuslineModeSeparatorOther# %s', encoding) or ''
end

--- The current line, total line count, and column position.
---@return string
function M.position_component()
    local line = vim.fn.line '.'
    local line_count = vim.api.nvim_buf_line_count(0)
    local col = vim.fn.virtcol '.'

    return table.concat {
        '%#StatuslineItalic#l: ',
        string.format('%%#StatuslineTitle#%d', line),
        string.format('%%#StatuslineItalic#/%d c: %d', line_count, col),
    }
end

--- Renders the statusline.
---@return string
function M.render()
    ---@param components string[]
    ---@return string
    local function concat_components(components)
        return vim.iter(components):skip(1):fold(components[1], function(acc, component)
            return #component > 0 and string.format('%s    %s', acc, component) or acc
        end)
    end

    return table.concat {
        concat_components {
            M.mode_component(),
            M.git_component(),
            M.file_component(),
            M.dap_component() or '',
        },
        '%#StatusLine#%=',
        concat_components {
            vim.diagnostic.status(),
            M.filetype_component(),
            M.encoding_component(),
            M.position_component(),
        },
    }
end

vim.o.statusline = "%!v:lua.require'statusline'.render()"

return M
