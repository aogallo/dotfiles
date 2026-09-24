-- Which-key database group smoke test (specs/007-fix-dbobjects-scope-save-dir,
-- quickstart automated check). Asserts the `<leader>q` → `database` group is
-- declared in the which-key prefix registry in nvim/plugin/editor.lua and the
-- four database action maps remain registered in nvim/lua/config/keymaps.lua
-- (FR-010 / contract §4):
--   - registry: editor.lua carries the group line matching the repo's group
--     style (e.g. { '<leader>b', group = 'buffers' })
--   - actions: loading config.keymaps registers <leader>qj/qu/qo/qr unchanged
-- No live UI is touched. Exits with code 1 via :cquit on any assertion failure.

local function fail(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

--- keymap registry check (FR-010, contract §4) -----------------------------

-- The which-key <leader>-prefix groups live declaratively in
-- nvim/plugin/editor.lua (the `wk.add` block under folke/which-key.nvim's
-- on_setup). Load that file and assert the `database` group entry exists.
local editor_path = vim.fn.expand '~/.config/nvim/plugin/editor.lua'
local editor = table.concat(vim.fn.readfile(editor_path), '\n')
fail(editor ~= '', 'reads nvim/plugin/editor.lua source', editor_path, '<file contents>')
fail(
    editor:find("<leader>q', group = 'database'", 1, true) ~= nil,
    'editor.lua registers <leader>q as the database group',
    editor,
    "<leader>q', group = 'database'"
)

-- The four database action maps live in nvim/lua/config/keymaps.lua; they must
-- remain after loading the module (behavior unchanged, FR-010). <leader> is
-- stored expanded by vim.keymap.set, so normalize it to the runtime key.
require 'config.keymaps'
local registered = {}
for _, m in ipairs(vim.api.nvim_get_keymap 'n') do
    registered[m.lhs] = true
end
local leader = vim.g.mapleader or '\\'
local function expand(key)
    return key:gsub('<leader>', leader)
end
for _, key in ipairs { '<leader>qj', '<leader>qu', '<leader>qo', '<leader>qr' } do
    fail(
        registered[expand(key)] == true,
        'database action ' .. key .. ' remains registered',
        registered[expand(key)],
        true
    )
end

vim.print 'All keymap group smoke assertions passed'
