local M = {}

--- Diagnostic severities.
M.diagnostics = {
    ERROR = '',
    WARN = '',
    HINT = '',
    INFO = '',
}

--- Notification severities and states.
M.notifications = {
    error = M.diagnostics.ERROR,
    warn = M.diagnostics.WARN,
    info = M.diagnostics.INFO,
    debug = '',
    trace = '…',
    progress = '…',
    success = '',
}

--- For folding.
M.arrows = {
    right = '',
    left = '',
    up = '',
    down = '',
}

--- LSP symbol kinds.
M.symbol_kinds = {
    Array = '󰅪',
    Class = '',
    Color = '󰏘',
    Constant = '󰏿',
    Constructor = '',
    Enum = '',
    EnumMember = '',
    Event = '',
    Field = '󰜢',
    File = '󰈙',
    Folder = '󰉋',
    Function = '󰆧',
    Interface = '',
    Keyword = '󰌋',
    Method = '󰆧',
    Module = '',
    Operator = '󰆕',
    Property = '󰜢',
    Reference = '󰈇',
    Snippet = '',
    Struct = '',
    Text = '',
    TypeParameter = '',
    Unit = '',
    Value = '',
    Variable = '󰀫',
}

--- Shared icons that don't really fit into a category.
M.misc = {
    bug = '',
    dashed_bar = '┊',
    ellipsis = '…',
    git = '',
    palette = '󰏘',
    robot = '󰚩',
    search = '',
    terminal = '',
    toolbox = '󰦬',
    vertical_bar = '│',
}

return M
