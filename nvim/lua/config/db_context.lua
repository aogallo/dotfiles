-- Which database is a buffer talking to (specs/009-trim-trailing-whitespace, US4).
--
-- One place that answers "what database does this buffer use", so the status
-- line and the query path can never disagree (FR-025). The URL-to-database
-- derivation moved here from db_objects.lua because the status line needs it
-- too, and duplicating the parsing is exactly how the two would drift.
--
-- The derivation is deliberately the adapter's own rule: for a `sybase://`
-- URL the database is the path segment after host[:port], which is what
-- `db#adapter#sybase#s:database()` returns and what `s:use_lines()` prepends
-- as `use <db>` on every call. A URL can carry credentials, so nothing here
-- ever returns or renders the whole URL.
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function below carries a header with Purpose / Called by / SQL /
--   Args / Returns / Side effects. Required for new functions too.

local M = {}

-- M.is_sybase(url): does this URL use the custom Sybase adapter?
-- Called by: M.url_database(), and db_objects.lua (fetch_objects(), pick())
-- SQL: none
-- Args: url = connection URL string
-- Returns: boolean
-- Side effects: none
function M.is_sybase(url)
    return (url:match '^([^:]+)://' or '') == 'sybase'
end

-- M.url_database(url): owning database implied by a URL.
-- Called by: M.url_from_buffer()'s callers, db_objects.lua (scope label,
--   picker), the status-line component, and the tests
-- SQL: none (the path segment after host[:port], mirroring the adapter's
--   s:database() so the label and the row data always agree)
-- Args: url = connection URL string
-- Returns: database name, or nil for a non-Sybase URL / no path / empty path
-- Side effects: none
function M.url_database(url)
    if not M.is_sybase(url) then
        return nil
    end
    local rest = url:match '^sybase://[^/]*/(.*)$'
    if not rest then
        return nil
    end
    -- The path ends at '?' or at '#', because that is where the URL parser
    -- this derivation mirrors ends it: db#url#parse() treats '#' as the
    -- fragment delimiter, so '…/tmp$#db' is the database 'tmp$' plus a
    -- fragment. Reading past it here would name a database the connection
    -- never selects.
    local db = rest:match '^([^?#]*)'
    if db == '' then
        return nil
    end
    return db
end

-- M.url_from_buffer(buf): the connection a buffer is bound to.
-- Called by: db_objects.lua (default_url()), the status-line component, the
--   pre-execution check, and the tests
-- SQL: none
-- Args: buf = buffer number
-- Returns: URL string, or nil when the buffer has no usable b:db context
--   (accepts both the string form and the {conn=…}/{db_url=…} table forms)
-- Side effects: none
function M.url_from_buffer(buf)
    local bdb = vim.b[buf].db
    if type(bdb) == 'string' then
        return bdb
    end
    if type(bdb) == 'table' then
        return bdb.conn or bdb.db_url
    end
    return nil
end

-- M.database(buf): the database a buffer's connection declares.
-- Called by: the status-line component, the pre-execution check, and the tests
-- SQL: none
-- Args: buf = buffer number
-- Returns: database name, or nil when the buffer has no connection or the URL
--   carries no database
-- Side effects: none
function M.database(buf)
    local url = M.url_from_buffer(buf)
    if not url then
        return nil
    end
    return M.url_database(url)
end

--- text signals ---------------------------------------------------------

-- A Sybase identifier, which is what `use` and a two-part name are written with.
-- `$` and `#` are legal in the middle of one, so the class allows them after
-- the first character. A name may not start with `$` or `#`, which keeps
-- `#temp` and `$identity` from being read as the owner half. `-` is included
-- because these databases are named with hyphens (`use base-a`), and a `use`
-- statement takes no expression for the hyphen to be ambiguous with; the
-- two-part pattern below is the only place it could read as an operator, and
-- `db..object` appears nowhere else in SQL.
local IDENT = '[%a_][%w_$#-]*'
-- Two dots, not one: `db..object` crosses databases, `schema.object` does not
-- and is the ordinary way to write a table, so a single dot would report a
-- conflict on almost every query. The dots are unescaped so `db..obj`,
-- `db .. obj` and `db. .obj` all count.
-- The owner half is a database name and must not start with `$` or `#`. The
-- object half may: `db..#temp` is still a cross-database reference, and the
-- warning on that nonsense SQL costs nothing. The halves are captured because
-- `match` takes the match from the left, so the first return value would be the
-- whole tail rather than the owner.
local TWO_PART = '(' .. IDENT .. ')%s*%.%s*%.%s*([%a_$#][%w_$#-]*)'

-- strip_noise(lines): the buffer with comments and literals removed, so a `use`
-- inside either is not read as a statement.
-- Called by: M.switches()
-- SQL: none
-- Args: lines = the buffer's lines
-- Returns: a new list of strings, one per input line, with the noise replaced by
--   spaces so positions stay comparable
-- Side effects: none
--
-- Block-comment state carries across lines, and a line that opens a comment and
-- never closes it keeps the rest of the buffer commented: the alternative is
-- reporting a switch the editor never executes.
local function strip_noise(lines)
    local out = {}
    local in_block = false
    for i, line in ipairs(lines) do
        local kept = {}
        local j = 1
        local n = #line
        while j <= n do
            if in_block then
                local _, close_end = line:find('%*/', j)
                if close_end then
                    in_block = false
                    j = close_end + 1
                else
                    j = n + 1
                end
            else
                -- Earliest of the three ways a line can stop being code. Taking
                -- the earliest is what makes a quote inside a comment harmless.
                local candidates = {}
                for _, probe in ipairs { { '/%*', 'block' }, { "'", 'string' }, { '%-%-', 'comment' } } do
                    local from, to = line:find(probe[1], j, probe[1] == "'")
                    if from then
                        candidates[#candidates + 1] = { from, to, probe[2] }
                    end
                end
                table.sort(candidates, function(a, b)
                    return a[1] < b[1]
                end)
                local first = candidates[1]
                if not first then
                    for k = j, n do
                        kept[k] = line:sub(k, k)
                    end
                    j = n + 1
                else
                    -- Exactly the marker's own characters are blanked, which is
                    -- why the found end offset is used rather than the length of
                    -- the pattern that found it.
                    for k = first[1], first[2] do
                        kept[k] = ' '
                    end
                    if first[3] == 'block' then
                        -- Past the `/*` just consumed; `first[2]` is its last `/`.
                        local _, close_end = line:find('%*/', first[2] + 1, true)
                        if close_end then
                            j = close_end + 1
                        else
                            in_block = true
                            j = n + 1
                        end
                    elseif first[3] == 'string' then
                        local _, close_end = line:find("'", first[2] + 1, true)
                        j = close_end and close_end + 1 or n + 1
                    else
                        j = n + 1
                    end
                end
            end
        end
        out[i] = table.concat(kept)
    end
    return out
end

-- M.switches(buf): the context switch the buffer's text declares.
-- Called by: M.label(), M.conflict(), the pre-execution check, and the tests
-- SQL: none
-- Args: buf = buffer number
-- Returns: nil, or { kind = 'use' | 'object', name = string, owner = string }.
--   The LAST `use` wins, because that is the statement the adapter ends up
--   sending; when there is no `use`, the FIRST two-part name is reported,
--   because that is the first statement that would touch another database.
-- Side effects: none
--
-- `name` is what a person reads, and for a two-part name it carries the object
-- too. `owner` is only the database it names, because that is the half a
-- conflict is decided on: `ventas..t1` on a `ventas` connection stays put.
function M.switches(buf)
    local lines = strip_noise(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    local last_use, first_object = nil, nil
    for _, line in ipairs(lines) do
        local used = line:match('^[%s]*[Uu][Ss][Ee]%s+(' .. IDENT .. ')')
        if used then
            last_use = { kind = 'use', name = used, owner = used }
        elseif not first_object then
            local owner, object = line:match(TWO_PART .. '$')
            if owner and object then
                first_object = { kind = 'object', name = owner .. '..' .. object, owner = owner }
            end
        end
    end
    return last_use or first_object
end

-- conflicting_switch(buf): the switch, but only when it leaves this database.
-- Called by: M.label(), M.conflict(), and M.switch_message()
-- SQL: none
-- Args: buf = buffer number
-- Returns: nil, or the switch table from M.switches()
-- Side effects: none
--
-- A switch that names the database the connection already points at is not a
-- conflict, and after a scope change it is the normal case: the buffer still
-- reads `use base-a` and the connection has just become `base-a`. Comparing
-- case-insensitively matches how the server treats the name, and only after a
-- case-fold, because the two are reported as written.
local function conflicting_switch(buf)
    local switch = M.switches(buf)
    if not switch then
        return nil
    end
    local database = M.database(buf)
    if not database then
        return nil
    end
    if switch.owner:lower() == database:lower() then
        return nil
    end
    return switch
end

--- presentation ---------------------------------------------------------

-- M.label(buf): the status-line text for a buffer.
-- Called by: the component in nvim/plugin/editor.lua, and the tests
-- SQL: none
-- Args: buf = buffer number
-- Returns: '' for any filetype other than `sql` (the element is absent, not
--   blank, and not a name check by buffer name), otherwise 'DB <database>',
--   'DB <database> <mark> <switch>', or 'DB —' when the buffer has no
--   connection or its URL carries no database
-- Side effects: none
--
-- The database shown is always the one the connection declares. The mark sits
-- beside it and never replaces it, so the two can be read independently
-- (contract §2 rules 1 and 2). Nothing here can produce a URL: the only value
-- that reaches the label is a database name.
function M.label(buf)
    if vim.bo[buf].filetype ~= 'sql' then
        return ''
    end
    local database = M.database(buf)
    if not database then
        return 'DB —'
    end
    local switch = conflicting_switch(buf)
    if not switch then
        return 'DB ' .. database
    end
    return ('DB %s ⚠ %s'):format(database, switch.name)
end

-- M.conflict(buf): does this buffer's text switch the database?
-- Called by: the component (to pick a highlight), the pre-execution check, and
--   the tests
-- SQL: none
-- Args: buf = buffer number
-- Returns: boolean
-- Side effects: none
function M.conflict(buf)
    if vim.bo[buf].filetype ~= 'sql' then
        return false
    end
    return conflicting_switch(buf) ~= nil
end

-- M.switch_message(buf): the pre-execution warning text.
-- Called by: M.setup()'s listener, and the tests
-- SQL: none
-- Args: buf = buffer number
-- Returns: nil when the buffer is not `sql`, when the text does not switch
--   context, or when the text switches to the database the connection already
--   points at (there is nothing to warn about), otherwise the warning naming
--   both the connection database and the reported switch
-- Side effects: none
--
-- The filetype is checked here as well as in M.conflict() because this is the
-- function the listener trusts: `b:db` outlives a `:set ft=` and a buffer that
-- stopped being SQL must stop being warned about.
function M.switch_message(buf)
    if vim.bo[buf].filetype ~= 'sql' then
        return nil
    end
    local switch = conflicting_switch(buf)
    if not switch then
        return nil
    end
    return ('DB query runs on "%s", but the text switches to "%s". Check the statement before executing.'):format(
        M.database(buf),
        switch.name
    )
end

-- M.setup(): register the pre-execution check.
-- Called by: nvim/plugin/database.lua at plugin source time
-- SQL: none
-- Args: none
-- Returns: nothing
-- Side effects: registers one User */DBExecutePre listener, once
--
-- The event is the one the query tool already emits, so no new trigger is
-- registered and db_results.lua is untouched (FR-022, constitution IV). The
-- listener only reads the buffer and notifies: it never modifies the text, so
-- the statement that runs is the statement the user wrote.
local setup_done = false

function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    vim.api.nvim_create_autocmd('User', {
        pattern = '*/DBExecutePre',
        callback = function()
            local buf = vim.api.nvim_get_current_buf()
            local message = M.switch_message(buf)
            if not message then
                return
            end
            require('notifications').notify(message, vim.log.levels.WARN, { source = 'DB' })
        end,
        desc = 'db_context: warn when a query would run on another database',
    })
end

return M
