-- Query draft registry: own the display name, the connection and the text of a
-- query buffer, so a buffer the developer closes and later brings back still
-- works (specs/011-query-buffer-tab-visibility, issue #96).
--
-- Why this module exists. Closing a query buffer with `:bdelete` destroys three
-- things at once, and all three were measured (R-0005, R-0006, R-0007):
--
--   1. It unloads the buffer, and buffer-local variables do not survive an
--      unload — `b:db` is gone, so `:DB` commands in the reopened query fall
--      back to whatever `:DBObjects` resolves. That can run a query against the
--      wrong database, which is worse than a missing tab (FR-014, SC-007).
--   2. It discards the text. The query's file does not exist until saved, so
--      reopening shows an empty buffer with the right name (FR-013).
--   3. The closed buffer still owns its display name. The next open creates a
--      second buffer and `nvim_buf_set_name` raises `Vim:E95: Buffer with this
--      name already exists`; the exception is unhandled, so filetype, `b:db`
--      and focus never run and the developer is left with an unnamed orphan tab
--      labelled `[No Name]` next to stale content (FR-005).
--
-- So this module keeps a session-local draft record per query buffer —
-- display name, connection URL, object, database, filetype, and a snapshot of
-- the text taken when the buffer leaves the buffer list — and re-applies them
-- when the buffer comes back.
--
-- Constraints, all deliberate:
--
--   * SESSION-LOCAL, NEVER PERSISTED. The URL may carry credentials, and the
--     text may be unsaved; neither is written anywhere (constitution VII, FR-017
--     as amended by A-001). Restarting Neovim discards every draft and the
--     developer re-opens the query, exactly as today.
--   * NO DISK WRITE, NO FILE CREATION, NO PROMPT, NO MESSAGE. A force-close must
--     not save the developer's work behind their back (FR-017, A-001).
--   * NO SELF-RESTORATION. Snapshotting is not restoring: the buffer stays
--     closed and unlisted until the developer explicitly brings it back
--     (FR-022, data-model.md invariant 2).
--   * A SNAPSHOT NEVER OVERWRITES LIVE TEXT. A buffer that already holds text
--     wins over its snapshot (data-model.md invariant 3).
--   * The connection restored is the one recorded at open time, never one
--     re-resolved from the registry, so a re-pointed connection cannot silently
--     change which database a query acts on (FR-016).
--
-- Name allocation never raises and never loops (data-model.md §1.1):
--   1. nobody owns the base name -> take it;
--   2. an *unlisted* buffer owns it (the closed-but-alive case) -> reclaim that
--      buffer instead of opening a second one, which removes the E95 class
--      instead of hiding one instance of it;
--   3. a *listed* buffer owns it (a live query the developer still has) ->
--      allocate the next free `<stem>.<n>.sql` so two open queries are
--      tellable apart (FR-012).
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function below carries a header with Purpose / Called by / SQL /
--   Args / Returns / Side effects. Required for new functions too.

local buffers = require 'config.buffers'

local M = {}

local setup_done = false

-- Draft records by buffer number, and by display name as the fallback key so a
-- wiped-and-recreated buffer is still recognised. Both keys are stored, per
-- data-model.md §1. A record never leaves this table: it is session memory.
local drafts_by_buf = {}
local drafts_by_name = {}

-- is_valid(bufnr): whether bufnr is a buffer that can still be inspected.
-- Called by: the snapshot and reopen paths
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: true when the buffer is valid
-- Side effects: none
local function is_valid(bufnr)
    return type(bufnr) == 'number' and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

-- base_name(object, database): the display name a query would like to have.
-- Called by: allocate_name()
-- SQL: none
-- Args: object = database object name, database = owning database label, may be
--   '' or nil
-- Returns: `<database>.<object>.sql`, or `<object>.sql` with no database
-- Side effects: none. Never contains credentials: the object and database labels
--   come from the catalog, not from the URL.
local function base_name(object, database)
    if database and database ~= '' then
        return database .. '.' .. object .. '.sql'
    end
    return object .. '.sql'
end

-- owner_of(name): the live buffer that already owns a display name, if any.
-- Called by: allocate_name()
-- SQL: none
-- Args: name = display name
-- Returns: the buffer number owning that exact name, or nil
-- Side effects: none
--
-- `nvim_buf_set_name` resolves a relative name against the current directory, so
-- a buffer named `master.proc1.sql` is stored as `/cwd/master.proc1.sql`.
-- Comparing against the raw argument would therefore never match, the closed
-- buffer would never be reclaimed, and open() would keep raising E95 — so the
-- candidate is resolved the same way before comparing.
local function owner_of(name)
    local wanted = vim.fn.fnamemodify(name, ':p')
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == wanted then
            return bufnr
        end
    end
    return nil
end

-- split_stem(base): split a display name into stem and extension.
-- Called by: allocate_name()
-- SQL: none
-- Args: base = a base display name
-- Returns: stem = the name without its `.sql` extension, ext = '.sql' or ''
-- Side effects: none
local function split_stem(base)
    local stem, ext = base:match '^(.*)(%.sql)$'
    if stem then
        return stem, ext
    end
    return base, ''
end

-- allocate_name(object, database): pick the display name for a query, reclaiming
--   a closed buffer's name when that is what owns it.
-- Called by: M.open()
-- SQL: none
-- Args: object = database object name, database = owning database label
-- Returns: name = the allocated display name, reclaim = the buffer number to
--   reuse, or nil when a new buffer must be created
-- Side effects: none. Never raises and never loops: the suffix scan is bounded by
--   the number of live buffers, since at most that many names can be taken
--   (data-model.md §1.1 rule 4).
local function allocate_name(object, database)
    local base = base_name(object, database)

    local function pick(name)
        local owner = owner_of(name)
        if not owner then
            return name, nil
        end
        if not vim.bo[owner].buflisted then
            -- Rule 2: closed but alive. Reclaim it rather than opening a second
            -- buffer with a colliding name.
            return name, owner
        end
        return nil
    end

    local name, reclaim = pick(base)
    if name then
        return name, reclaim
    end

    local stem, ext = split_stem(base)
    local live = #vim.api.nvim_list_bufs()
    for index = 2, live + 2 do
        local candidate = stem .. '.' .. index .. ext
        name, reclaim = pick(candidate)
        if name then
            return name, reclaim
        end
    end

    -- Unreachable: with at most `live` live buffers, at most `live` names can be
    -- taken, so the bounded scan above always finds a free one.
    return base, nil
end

-- remember(bufnr, fields): create or update the draft record for a buffer.
-- Called by: M.open()
-- SQL: none
-- Args: bufnr = buffer number, fields = display_name, url, object, database,
--   filetype
-- Returns: the stored record
-- Side effects: stores the record under both keys and drops any snapshot it
--   carried, because the caller's text is the authoritative current content
local function remember(bufnr, fields)
    local record = drafts_by_buf[bufnr] or {}
    record.bufnr = bufnr
    record.display_name = fields.display_name
    record.url = fields.url
    record.object = fields.object or ''
    record.database = fields.database or ''
    record.filetype = fields.filetype or 'sql'
    record.lines = nil
    record.snapshot_taken_at = nil
    drafts_by_buf[bufnr] = record
    drafts_by_name[fields.display_name] = record
    return record
end

-- M.open(url, object, lines, database) -> bufnr
-- Purpose: show a query's text in a SQL buffer that can be closed and brought
--   back without losing its name, connection or text, and without ever raising
--   E95 (contract §2.1).
-- Called by: db_objects.open_list_query(), db_objects.open_procedure_source()
-- SQL: none — the caller has already read the text; the buffer is bound to url
--   as b:db so later :DB commands reuse this connection and database
-- Args: url = connection URL, object = database object name, lines = buffer
--   text, database = owning database label for the display name (may be ''/nil)
-- Returns: the buffer number
-- Side effects: allocates or reclaims a buffer, writes the text, sets
--   `filetype=sql` and `b:db`, records the draft, ensures the buffer is listed
--   and focuses it. No disk write, no file creation, no prompt, no message, and
--   no change to any unrelated buffer, window or tab. A reclaimed buffer's
--   previous content is replaced, which is safe because query text is generated
--   from the catalog and re-derivable.
function M.open(url, object, lines, database)
    local name, reclaim = allocate_name(object, database)

    local bufnr
    if reclaim then
        bufnr = reclaim
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    else
        bufnr = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        -- Safe by construction: allocate_name() only returns a name no live
        -- buffer owns, so this cannot raise E95.
        vim.api.nvim_buf_set_name(bufnr, name)
    end

    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'sql')
    vim.b[bufnr].db = url

    -- A record whose buffer was wiped must never restore text into an unrelated
    -- buffer, so it is discarded when its name is allocated again
    -- (data-model.md §6).
    local stale = drafts_by_name[name]
    if stale and not is_valid(stale.bufnr) then
        drafts_by_name[name] = nil
    end
    remember(bufnr, {
        display_name = name,
        url = url,
        object = object,
        database = database,
        filetype = 'sql',
    })

    if not vim.bo[bufnr].buflisted then
        vim.bo[bufnr].buflisted = true
    end
    vim.cmd('buffer ' .. bufnr)
    return bufnr
end

-- on_reopen(bufnr): reopen handler registered with the visibility guard.
-- Called by: buffers.lua, on the re-list path only (contract §1.3)
-- SQL: none
-- Args: bufnr = the buffer that has just been re-listed
-- Returns: nothing
-- Side effects: delegates to M.reopen when it exists. The indirection lets the
--   guard be registered once, while the restore behavior is added and tested on
--   its own.
local function on_reopen(bufnr)
    if M.reopen then
        M.reopen(bufnr)
    end
end

-- M.snapshot(bufnr)
-- Purpose: keep the text of a query buffer that is about to be unloaded, so an
--   explicit reopen can show it again (FR-013, contract §2.3).
-- Called by: the `BufUnload` autocmd registered in M.setup()
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: nothing
-- Side effects: stores the buffer's current lines in its draft record,
--   overwriting any older snapshot. Never restores listing, never focuses
--   anything, never emits a message (FR-022, data-model.md invariant 2), and is
--   a no-op for a buffer with no draft record.
--
-- Registered on `BufUnload`, not `BufDelete`, because that is the last moment
-- the text still exists: `bdelete` unloads the buffer and the text is gone from
-- the buffer's own storage afterwards (measured, R-0007).
function M.snapshot(bufnr)
    local record = drafts_by_buf[bufnr]
    if not record or not is_valid(bufnr) then
        return
    end
    record.lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    record.snapshot_taken_at = vim.loop and vim.loop.now() or nil
end

-- M.reopen(bufnr)
-- Purpose: restore what the close destroyed — language, connection, and the
--   text if the buffer has none (FR-013, FR-014, FR-016; contract §2.2).
-- Called by: buffers.lua, as a registered reopen handler, on the re-list path
-- SQL: none
-- Args: bufnr = the buffer that has just been re-listed
-- Returns: nothing
-- Side effects: sets `filetype`, sets `b:db` to the **recorded** URL, and
--   restores the snapshotted text only when the buffer currently holds none.
--   Never lists the buffer — the guard already did, and a second write would
--   break I-5. Never re-resolves the URL from the registry, so a re-pointed
--   connection cannot silently change which database a query acts on (FR-016).
--   Never emits a message, and is a no-op with no matching draft record.
function M.reopen(bufnr)
    local record = drafts_by_buf[bufnr] or drafts_by_name[tail(vim.api.nvim_buf_get_name(bufnr))]
    if not record or not is_valid(bufnr) then
        return
    end

    vim.bo[bufnr].filetype = record.filetype or 'sql'
    if record.url then
        vim.b[bufnr].db = record.url
    end

    -- Invariant 3: a buffer that holds text always wins over its snapshot. Only
    -- an empty buffer is filled in.
    if record.lines and #record.lines > 0 then
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local current = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local is_empty = line_count <= 1 and (current[1] == nil or current[1] == '')
        if is_empty then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, record.lines)
        end
    end
end

-- M.setup(): register with the visibility guard (idempotent).
-- Purpose: let the guard tell this module when it has re-listed a query buffer,
--   and snapshot the text before a close destroys it (contract §2.4).
-- Called by: nvim/plugin/database.lua at plugin source time
-- SQL: none
-- Args: none
-- Returns: nothing (a second call is a no-op via setup_done)
-- Side effects: registers one reopen handler and one `BufUnload` autocmd. Adds
--   no user command and no keymap (R-0012).
function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    buffers.register_reopen_handler(on_reopen)
    vim.api.nvim_create_autocmd('BufUnload', {
        group = vim.api.nvim_create_augroup('aogallo/db_query_draft', { clear = true }),
        pattern = '*',
        callback = function(args)
            M.snapshot(args.buf)
        end,
        desc = 'db_query_buffer: snapshot a query buffer before it is unloaded',
    })
end

return M
