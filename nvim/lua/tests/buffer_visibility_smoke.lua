-- buffer_visibility smoke test.
-- Covers the buffer-visibility guard and the query draft registry
-- (specs/011-query-buffer-tab-visibility, issue #96). Every assertion is
-- written against the contracts in
-- specs/011-query-buffer-tab-visibility/contracts/query-buffer-visibility.md
-- and the numbered assertions of quickstart.md §4.1.
--
-- No database, no plugins, no server: every behavior here is local editor
-- state, so `-u NORC` is enough. Exits with code 1 via :cquit on the first
-- failed assertion.
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   helpers here carry a header with Purpose / Called by / SQL / Args /
--   Returns / Side effects, like the modules they exercise.

local M = {}

-- The two modules under test.
--
-- Loaded under pcall on purpose: a `require` that throws inside
-- `-c 'lua ...'` is reported by Neovim but still exits 0, so an unloadable
-- module would silently satisfy the "0 failures" gate (SC-012). Quitting here
-- turns that into a real failure.
local ok_modules, buffers, db_query_buffer = pcall(function()
    local guard = require 'config.buffers'
    local registry = require 'config.db_query_buffer'
    guard.setup()
    registry.setup()
    return guard, registry
end)

if not ok_modules then
    vim.print 'FAIL modules load'
    vim.print('  got:  ' .. tostring(buffers))
    vim.print '  want: config.buffers and config.db_query_buffer load and set up'
    vim.cmd 'cquit'
end

-- Notices raised while a case runs, so "emits no message" is assertable.
local original_notify = vim.notify
local notices = {}
vim.notify = function(msg, level, _opts)
    table.insert(notices, { msg = tostring(msg), level = level })
end

-- check(ok, name, got, want): record one assertion result.
-- Called by: every assertion in this suite
-- SQL: none
-- Args: ok = truthy when the assertion holds, name = what is being asserted,
--   got = the observed value (printed on failure), want = the expected value
-- Returns: nothing
-- Side effects: prints PASS, or prints FAIL plus got/want and quits with 1
local function check(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

-- clear_notices(): drop the notices collected so far.
-- Called by: every case that asserts about messages
-- SQL: none
-- Args: none
-- Returns: nothing
-- Side effects: empties the notices table
local function clear_notices()
    notices = {}
end

-- count_notices(): how many notices have been raised since the last clear.
-- Called by: the "emits no message" assertions
-- SQL: none
-- Args: none
-- Returns: the notice count
-- Side effects: none
local function count_notices()
    return #notices
end

-- scratch_buf(lines, opts): make a throwaway developer-opened buffer.
-- Called by: the guard cases that need a buffer to bring back
-- SQL: none
-- Args: lines = initial text, opts = {name = string, listed = boolean}
-- Returns: the buffer number
-- Side effects: creates a listed buffer, so it mimics a file the developer
--   opened deliberately
local function scratch_buf(lines, opts)
    opts = opts or {}
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { '' })
    if opts.name then
        vim.api.nvim_buf_set_name(bufnr, opts.name)
    end
    if opts.listed == false then
        vim.bo[bufnr].buflisted = false
    end
    return bufnr
end

-- ----------------------------------------------------------------------------
-- US1 — a query buffer I come back to always has its tab (quickstart §4.1 #1,
-- #2, #6, #7; FR-001..FR-004, FR-007). Plain buffers, no database.
-- ----------------------------------------------------------------------------

-- #1 (I-2, I-5; FR-004): a listed buffer entered repeatedly performs exactly one
-- listing write, so there is no per-redraw churn.
do
    local bufnr = scratch_buf { 'select 1' }
    vim.api.nvim_set_current_buf(bufnr)

    -- Count the writes by watching the autocmd the guard's own write fires.
    local writes = 0
    local group = vim.api.nvim_create_augroup('buffer_visibility_test_writes', { clear = true })
    vim.api.nvim_create_autocmd('OptionSet', {
        group = group,
        pattern = 'buflisted',
        callback = function()
            writes = writes + 1
        end,
    })

    -- Entering an already-listed buffer is the no-op path.
    for _ = 1, 5 do
        vim.api.nvim_set_current_buf(bufnr)
        vim.cmd 'doautocmd BufEnter'
        vim.cmd 'redraw'
    end
    vim.api.nvim_del_augroup_by_id(group)

    check(writes == 0, 'entering an already-listed buffer performs no listing write', writes, 0)
end

-- #2 (I-1; FR-001): an unlisted buffer with a window is listed on entry; a
-- buffer with no window is left alone.
do
    local shown = scratch_buf { 'select 1' }
    vim.api.nvim_set_current_buf(shown)
    vim.bo[shown].buflisted = false
    vim.cmd 'doautocmd BufEnter'
    check(vim.bo[shown].buflisted, 'an unlisted displayed buffer is listed on entry', vim.bo[shown].buflisted, true)

    local hidden = scratch_buf { 'select 2' }
    vim.bo[hidden].buflisted = false
    -- Never entered: there is no window showing it.
    check(
        not vim.bo[hidden].buflisted,
        'an unlisted buffer with no window is left alone',
        vim.bo[hidden].buflisted,
        false
    )
end

-- #6 (FR-003): after `bdelete!`, a `:buffer N` reopen lists the buffer again,
-- with no write to disk.
do
    local path = vim.fn.tempname() .. '.sql'
    local bufnr = scratch_buf({ 'select 3 /* unsaved */' }, { name = path })
    vim.api.nvim_set_current_buf(bufnr)
    vim.cmd('edit! ' .. vim.fn.fnameescape(path))

    -- Close it the way the report does, then bring it back by buffer number.
    vim.cmd('bdelete! ' .. bufnr)
    local reopened = vim.fn.bufnr(path)
    check(reopened > 0, 'the closed buffer still exists after bdelete!', reopened, '> 0')
    check(
        not vim.bo[reopened].buflisted,
        'the closed buffer is unlisted before the reopen',
        vim.bo[reopened].buflisted,
        false
    )

    vim.cmd('buffer ' .. reopened)
    vim.cmd 'redraw'
    check(
        vim.bo[reopened].buflisted,
        'the reopened buffer is listed again, before any save',
        vim.bo[reopened].buflisted,
        true
    )
    check(vim.fn.filereadable(path) == 0, 'the reopen created no file on disk', vim.fn.filereadable(path), 0)

    vim.cmd('bwipeout! ' .. reopened)
    os.remove(path)
end

-- #7 (FR-002): every reopen route converges on the same state.
do
    local routes = {
        ':buffer N',
        ':bnext',
        'nvim_set_current_buf',
        'nvim_win_set_buf',
    }
    local states = {}

    for index, route in ipairs(routes) do
        local target = scratch_buf({ 'select ' .. index }, { name = vim.fn.tempname() .. '.sql' })
        -- Two buffers, so :bnext has somewhere to go.
        scratch_buf { '-- filler ' .. index }
        vim.api.nvim_set_current_buf(target)
        vim.cmd('edit! ' .. vim.fn.fnameescape(vim.api.nvim_buf_get_name(target)))

        vim.cmd('bdelete! ' .. target)
        local back = vim.fn.bufnr(vim.api.nvim_buf_get_name(target))
        check(not vim.bo[back].buflisted, 'route ' .. route .. ' starts unlisted', vim.bo[back].buflisted, false)

        if route == ':buffer N' then
            vim.cmd('buffer ' .. back)
        elseif route == ':bnext' then
            vim.cmd 'bnext'
            -- bnext may land on any loaded buffer; go to ours if it did not.
            if vim.api.nvim_get_current_buf() ~= back then
                vim.cmd('buffer ' .. back)
            end
        elseif route == 'nvim_set_current_buf' then
            vim.api.nvim_set_current_buf(back)
        else
            vim.api.nvim_win_set_buf(0, back)
        end
        vim.cmd 'redraw'

        states[route] = vim.bo[back].buflisted
        check(states[route], 'route ' .. route .. ' ends with the buffer listed', states[route], true)
    end

    -- The point of the requirement: the routes agree.
    local distinct = {}
    for _, state in pairs(states) do
        distinct[#distinct + 1] = tostring(state)
    end
    table.sort(distinct)
    check(
        #vim.tbl_keys(states) == 4 and distinct[1] == distinct[#distinct],
        'every reopen route ends in the same state',
        distinct,
        'one identical state'
    )
end

-- ----------------------------------------------------------------------------
-- US2 — tell tabs apart; no E95; reclaim vs distinct names
-- (quickstart §4.1 #8, #9; FR-005, FR-008, FR-012)
-- ----------------------------------------------------------------------------

-- tail(name): the display label of a buffer name, as bufferline shows it.
-- Called by: the naming assertions
-- SQL: none
-- Args: name = a buffer name, which nvim_buf_set_name stored as an absolute path
-- Returns: the last path component
-- Side effects: none
local function tail(name)
    return vim.fn.fnamemodify(name, ':t')
end

-- #8 (R-0005; FR-005): open() twice for the same object never raises and
-- leaves exactly one listed buffer with the expected name.
do
    clear_notices()

    local lines = { 'select 1 from sysobjects' }
    local buf1 = db_query_buffer.open('sybase://local', 'sysobjects', lines, 'master')
    check(buf1 > 0, 'open creates a buffer', buf1, '> 0')
    check(
        tail(vim.api.nvim_buf_get_name(buf1)) == 'master.sysobjects.sql',
        'name is base for first open',
        tail(vim.api.nvim_buf_get_name(buf1)),
        'master.sysobjects.sql'
    )

    -- The defect this replaces: reopening the same query after closing it raised
    -- `Vim:E95: Buffer with this name already exists`, because the closed buffer
    -- still owned the name, and the unhandled error skipped filetype, b:db and
    -- focus -- leaving an unnamed `[No Name]` orphan tab.
    vim.cmd('bdelete! ' .. buf1)
    check(not vim.bo[buf1].buflisted, 'the closed query is unlisted', vim.bo[buf1].buflisted, false)

    local ok_second, buf2 = pcall(db_query_buffer.open, 'sybase://local', 'sysobjects', lines, 'master')
    check(ok_second, 'reopening the same query does not raise E95', buf2, 'no error')
    check(buf2 == buf1, 'second open reclaims the same buffer', buf2, buf1)
    check(
        tail(vim.api.nvim_buf_get_name(buf2)) == 'master.sysobjects.sql',
        'name remains the base after reclaim',
        tail(vim.api.nvim_buf_get_name(buf2)),
        'master.sysobjects.sql'
    )
    check(vim.bo[buf2].buflisted, 'reclaimed buffer is listed', vim.bo[buf2].buflisted, true)
    check(vim.bo[buf2].filetype == 'sql', 'reclaimed buffer keeps filetype=sql', vim.bo[buf2].filetype, 'sql')
    check(vim.b[buf2].db == 'sybase://local', 'reclaimed buffer keeps b:db', vim.b[buf2].db, 'sybase://local')
    check(count_notices() == 0, 'no notice raised on reclaim', count_notices(), 0)
    vim.cmd('bwipeout! ' .. buf2)
end

-- #9 (FR-012): open() while the previous query is still listed allocates a
-- distinct suffixed name and leaves the first buffer untouched.
do
    clear_notices()

    local lines1 = { 'select 1 from proc1' }
    local buf_a = db_query_buffer.open('sybase://local', 'proc1', lines1, 'master')
    check(vim.bo[buf_a].buflisted, 'buf_a is listed', vim.bo[buf_a].buflisted, true)
    local name_a = tail(vim.api.nvim_buf_get_name(buf_a))

    local lines2 = { 'select 2 from proc1' }
    local buf_b = db_query_buffer.open('sybase://local', 'proc1', lines2, 'master')
    check(buf_b ~= buf_a, 'second distinct open creates a different buffer', buf_b, buf_a)
    check(vim.bo[buf_a].buflisted, 'first buffer remains listed', vim.bo[buf_a].buflisted, true)
    check(vim.bo[buf_b].buflisted, 'second buffer is listed', vim.bo[buf_b].buflisted, true)
    local name_b = tail(vim.api.nvim_buf_get_name(buf_b))
    check(name_b ~= name_a, 'names are distinct', name_b, name_a)
    check(name_a == 'master.proc1.sql', 'first keeps base name', name_a, 'master.proc1.sql')
    check(
        name_b:match '^master%.proc1%.%d+%.sql$' ~= nil,
        'second gets a suffixed name',
        name_b,
        'master.proc1.<n>.sql'
    )

    -- The first buffer must be left exactly as the developer had it.
    local ca = vim.api.nvim_buf_get_lines(buf_a, 0, 1, false)
    check(ca[1] == lines1[1], 'first buffer content untouched', ca[1], lines1[1])

    vim.cmd('bwipeout! ' .. buf_a)
    vim.cmd('bwipeout! ' .. buf_b)
end

-- ----------------------------------------------------------------------------
-- US3 — a query buffer that comes back still works (quickstart §4.1 #10-#13;
-- FR-013..FR-016, FR-017 as amended by A-001)
-- ----------------------------------------------------------------------------

-- #10 (FR-013, FR-014): after bdelete!, an explicit reopen restores both the
-- typed text and the recorded connection, and the text is what was typed.
do
    clear_notices()
    local typed = { 'select 42 -- my query, never saved' }
    local buf = db_query_buffer.open('sybase://secret-host/db', 'myproc', { 'select 1' }, 'ventas')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, typed)

    vim.cmd('bdelete! ' .. buf)
    local back = vim.fn.bufnr(tail(vim.api.nvim_buf_get_name(buf)))
    -- Nothing may come back by itself (FR-022, A-001).
    check(not vim.bo[back].buflisted, 'the closed query stays unlisted until reopened', vim.bo[back].buflisted, false)

    vim.cmd('buffer ' .. back)
    vim.cmd 'redraw'
    check(vim.bo[back].buflisted, 'the explicit reopen lists it again', vim.bo[back].buflisted, true)

    local restored = vim.api.nvim_buf_get_lines(back, 0, 1, false)
    check(restored[1] == typed[1], 'the typed text came back', restored[1], typed[1])
    check(
        vim.b[back].db == 'sybase://secret-host/db',
        'the recorded connection came back',
        vim.b[back].db,
        'sybase://secret-host/db'
    )
    check(vim.bo[back].filetype == 'sql', 'the language came back', vim.bo[back].filetype, 'sql')
    vim.cmd('bwipeout! ' .. back)
end

-- #11 (data-model.md §3 invariant 3): a buffer that already holds text is never
-- overwritten by its snapshot.
do
    local buf = db_query_buffer.open('sybase://local', 'keepmine', { 'original' }, 'ventas')
    vim.cmd('bdelete! ' .. buf)
    local back = vim.fn.bufnr(tail(vim.api.nvim_buf_get_name(buf)))
    -- The developer types something new while the buffer is closed-but-listed.
    vim.bo[back].buflisted = true
    vim.api.nvim_buf_set_lines(back, 0, -1, false, { 'typed after the close' })
    vim.cmd('buffer ' .. back)
    local got = vim.api.nvim_buf_get_lines(back, 0, 1, false)
    check(
        got[1] == 'typed after the close',
        'live text is never overwritten by the snapshot',
        got[1],
        'typed after the close'
    )
    vim.cmd('bwipeout! ' .. back)
end

-- #12 (invariant 2) and #13 (FR-017, A-001): the close path itself never
-- restores anything, never notifies, and never writes a file.
do
    clear_notices()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local previous_cwd = vim.fn.getcwd()
    vim.cmd('cd ' .. vim.fn.fnameescape(dir))

    local buf = db_query_buffer.open('sybase://local', 'nodisk', { 'select 1' }, 'ventas')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved work' })
    vim.api.nvim_set_current_buf(buf)
    vim.cmd 'bdelete!'

    check(count_notices() == 0, 'the close raises no notice', count_notices(), 0)
    local entries = vim.fn.readdir(dir)
    check(#entries == 0, 'the close created no file on disk', entries, 'no entries')

    vim.cmd('cd ' .. vim.fn.fnameescape(previous_cwd))
    vim.fn.delete(dir, 'rf')
end

-- FR-016: the restored connection is the one recorded at open time, never one
-- re-resolved from the registry, so a re-pointed connection cannot silently
-- change which database a query acts on.
do
    local buf = db_query_buffer.open('sybase://recorded-host/first', 'repoint', { 'select 1' }, 'ventas')
    vim.cmd('bdelete! ' .. buf)
    local back = vim.fn.bufnr(tail(vim.api.nvim_buf_get_name(buf)))
    vim.cmd('buffer ' .. back)
    check(
        vim.b[back].db == 'sybase://recorded-host/first',
        'the restored connection is the recorded one, not a re-resolved one',
        vim.b[back].db,
        'sybase://recorded-host/first'
    )
    vim.cmd('bwipeout! ' .. back)
end

-- ----------------------------------------------------------------------------
-- US4 — tool output stays out of my way (quickstart §4.1 #4, #5, #14; FR-018)
-- ----------------------------------------------------------------------------

-- #4 (R-0009): the exclusion predicate recognizes the three rules of the
-- generated-output class, and does NOT classify a read-only ordinary file as
-- generated output -- states are not intents.
do
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local out_path = dir .. '/result.dbout'

    local out_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(out_buf, out_path)
    check(buffers.is_generated_output(out_buf), 'a .dbout buffer is generated output', true, true)

    local drawer = vim.api.nvim_create_buf(false, true)
    vim.bo[drawer].buftype = 'nofile'
    check(buffers.is_generated_output(drawer), 'a buftype=nofile drawer is generated output', true, true)

    local opted = scratch_buf { 'generated' }
    vim.b[opted].aogallo_no_tab = true
    check(buffers.is_generated_output(opted), 'an opted-out buffer is generated output', true, true)

    -- A developer's read-only file is not generated output.
    local readonly = scratch_buf { 'select 1' }
    vim.bo[readonly].readonly = true
    check(
        not buffers.is_generated_output(readonly),
        'a read-only ordinary file is NOT generated output',
        buffers.is_generated_output(readonly),
        false
    )

    vim.cmd('bwipeout! ' .. out_buf)
    vim.cmd('bwipeout! ' .. drawer)
    vim.cmd('bwipeout! ' .. opted)
    vim.cmd('bwipeout! ' .. readonly)
    vim.fn.delete(dir, 'rf')
end

-- #5 (I-4; FR-018): the guard never lists a generated-output buffer, in any of
-- those three forms.
do
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')

    local out_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(out_buf, dir .. '/leak.dbout')
    vim.api.nvim_set_current_buf(out_buf)
    vim.bo[out_buf].buflisted = false
    vim.cmd 'doautocmd BufEnter'
    check(not vim.bo[out_buf].buflisted, 'the guard does not list a .dbout buffer', vim.bo[out_buf].buflisted, false)

    local drawer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(drawer)
    vim.bo[drawer].buftype = 'nofile'
    vim.bo[drawer].buflisted = false
    vim.cmd 'doautocmd BufEnter'
    check(not vim.bo[drawer].buflisted, 'the guard does not list a drawer buffer', vim.bo[drawer].buflisted, false)

    vim.cmd('bwipeout! ' .. out_buf)
    vim.cmd('bwipeout! ' .. drawer)
    vim.fn.delete(dir, 'rf')
end

-- #14 (R-0008; FR-018): `db_results.show()` re-opening a dismissed result must
-- leave it unlisted, read-only and bufhidden=delete -- today the summon path
-- gives generated output a tab, which is the defect.
do
    clear_notices()
    local db_results = require 'config.db_results'
    db_results.setup()

    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local outfile = dir .. '/summoned.dbout'
    local handle = io.open(outfile, 'w')
    handle:write 'row one\nrow two\n'
    handle:close()

    -- Record it the way dadbod does: a `User` event fired with the pattern
    -- `<outfile>/DBExecutePost`, which the registered `*/DBExecutePost` autocmd
    -- matches. on_post() recovers the output file with `:h`, which strips that
    -- trailing event component.
    vim.api.nvim_exec_autocmds('User', { pattern = outfile .. '/DBExecutePost', modeline = false })
    check(
        vim.fn.filereadable(outfile) == 1,
        'the recorded result file is still readable',
        vim.fn.filereadable(outfile),
        1
    )

    -- Summon it.
    db_results.show()

    local shown = vim.fn.bufnr(outfile)
    check(shown > 0, 'the summon created the result buffer', shown, '> 0')
    check(not vim.bo[shown].buflisted, 'a summoned .dbout result takes no tab (FR-018)', vim.bo[shown].buflisted, false)
    check(vim.bo[shown].readonly, 'the summoned result stays read-only', vim.bo[shown].readonly, true)
    check(
        vim.bo[shown].bufhidden == 'delete',
        'the summoned result keeps bufhidden=delete',
        vim.bo[shown].bufhidden,
        'delete'
    )

    vim.cmd('bwipeout! ' .. shown)
    vim.fn.delete(dir, 'rf')
end

-- ----------------------------------------------------------------------------
-- US5 — the guard only ever adds; it never takes anything away (FR-021,
-- FR-022, FR-023; A-001)
-- ----------------------------------------------------------------------------

-- #3 (I-3, FR-021): entering any buffer must not unlist, unload or wipe
-- anything -- least of all a buffer the developer just closed.
do
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    local closed = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(closed, dir .. '/just-closed.sql')
    vim.api.nvim_buf_set_lines(closed, 0, -1, false, { 'select 7' })
    local closed_name = vim.api.nvim_buf_get_name(closed)

    vim.cmd('bdelete! ' .. closed)
    check(not vim.bo[closed].buflisted, 'the closed buffer starts unlisted', vim.bo[closed].buflisted, false)

    -- Enter everything else the developer could plausibly have open.
    local other = scratch_buf { 'select 8' }
    vim.api.nvim_set_current_buf(other)
    vim.cmd 'doautocmd BufEnter'
    vim.cmd 'doautocmd BufWinEnter'
    vim.cmd 'doautocmd TabEnter'
    vim.cmd 'doautocmd VimEnter'

    check(
        not vim.bo[closed].buflisted,
        'entering other buffers never re-lists the closed one',
        vim.bo[closed].buflisted,
        false
    )
    check(
        vim.api.nvim_buf_is_valid(closed),
        'the closed buffer was not wiped (the tab may come back)',
        vim.api.nvim_buf_is_valid(closed),
        true
    )

    -- The guard's only write is buflisted=false -> true. Prove it never writes
    -- anything else on an already-listed buffer.
    local listed = scratch_buf { 'select 9' }
    local ft, hidden, listed_before = vim.bo[listed].filetype, vim.bo[listed].bufhidden, vim.bo[listed].buflisted
    vim.api.nvim_set_current_buf(listed)
    vim.cmd 'doautocmd BufEnter'
    vim.cmd 'doautocmd BufWinEnter'
    vim.cmd 'doautocmd TabEnter'
    vim.cmd 'doautocmd VimEnter'
    check(
        vim.bo[listed].buflisted == listed_before,
        'a listed buffer stays listed',
        vim.bo[listed].buflisted,
        listed_before
    )
    check(vim.bo[listed].filetype == ft, 'the guard does not touch filetype', vim.bo[listed].filetype, ft)
    check(vim.bo[listed].bufhidden == hidden, 'the guard does not touch bufhidden', vim.bo[listed].bufhidden, hidden)
    check(
        vim.api.nvim_get_current_buf() == listed,
        'the guard never switches the current buffer',
        vim.api.nvim_get_current_buf(),
        listed
    )

    vim.cmd('bwipeout! ' .. listed)
    vim.cmd('bwipeout! ' .. other)
    vim.fn.delete(dir, 'rf')
end

-- FR-022: window switching does not revive a closed query, and a fresh Neovim
-- does not restore anything from disk.
do
    local typed = { 'select 11 -- only in memory' }
    local buf = db_query_buffer.open('sybase://local', 'memoryonly', typed, 'ventas')
    vim.cmd('bdelete! ' .. buf)

    -- Go to a different window, then come back to this one.
    vim.cmd 'new'
    vim.cmd 'doautocmd BufEnter'
    vim.cmd 'doautocmd BufWinEnter'
    vim.cmd 'doautocmd TabEnter'
    vim.cmd 'wincmd p'
    vim.cmd 'doautocmd BufEnter'
    check(
        not vim.bo[buf].buflisted,
        'switching windows does not revive a closed query (no symmetric list-sync)',
        vim.bo[buf].buflisted,
        false
    )
    vim.cmd 'close'

    -- A brand-new Neovim must know nothing: the draft lived only in this
    -- process's memory.
    local probe = 'lua io.write(tostring(vim.fn.bufnr("master.memoryonly.sql")))'
    local fresh = vim.trim(vim.fn.system { 'nvim', '--headless', '-u', 'NORC', '-c', probe, '-c', 'qa!' })
    check(fresh == '-1', 'a fresh Neovim has no record of the query', fresh, '-1')
    vim.cmd('bwipeout! ' .. buf)
end

-- FR-023 (quickstart #6): `auto_toggle_bufferline` behaves the same with one
-- buffer as with several -- a single listed buffer shows no bufferline row and
-- several do, purely from bufferline's own rule. This change adds no toggle.
do
    vim.cmd 'only'
    vim.cmd 'enew!'
    local single = scratch_buf { 'select 12' }
    vim.api.nvim_set_current_buf(single)
    vim.cmd 'doautocmd BufEnter'
    local single_listed = vim.bo[single].buflisted
    local single_count = #vim.api.nvim_list_bufs()

    -- Several listed buffers.
    local a, b = scratch_buf { 'a' }, scratch_buf { 'b' }
    vim.api.nvim_set_current_buf(a)
    vim.api.nvim_set_current_buf(b)
    vim.cmd 'doautocmd BufEnter'
    local multi_listed = vim.bo[b].buflisted

    check(single_listed, 'a single opened buffer is listed', single_listed, true)
    check(multi_listed, 'a buffer is listed with several open too', multi_listed, true)
    check(
        single_listed == multi_listed,
        'the row-visible rule is unchanged: listing does not depend on buffer count',
        single_listed == multi_listed,
        true
    )
    check(single_count > 0, 'the one-buffer case really had exactly one buffer', single_count, '1 buffer in play')

    vim.cmd('bwipeout! ' .. single)
    vim.cmd('bwipeout! ' .. a)
    vim.cmd('bwipeout! ' .. b)
end

-- Cleanup.
vim.notify = original_notify
vim.print 'All buffer_visibility smoke assertions passed'
