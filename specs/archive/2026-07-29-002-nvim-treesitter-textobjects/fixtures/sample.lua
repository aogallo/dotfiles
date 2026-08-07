local M = {}

-- Default labels validate comment textobjects and nested tables.
local labels = {
    primary = 'Save',
    secondary = 'Cancel',
}

local function decorate_label(label, prefix, suffix)
    local function normalize(value)
        return vim.trim(value):lower()
    end

    if label == labels.primary then
        return prefix .. normalize(label) .. suffix
    end

    return normalize(label)
end

function M.render_button(label, opts)
    opts = opts or {}

    return {
        text = decorate_label(label, opts.prefix or '[', opts.suffix or ']'),
        disabled = opts.disabled == true,
    }
end

return M
