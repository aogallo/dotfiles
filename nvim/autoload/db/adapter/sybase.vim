" Sybase ASE adapter for vim-dadbod.
"
" URL scheme: sybase://[user[:password]@]host[:port]/[database][?charset=...]
"
" Client selection: sqsh on macOS (default), SAP ASE isql on Windows
" (has('win32')). Override with g:db_sybase_client (string or argv list).
"
" Database selection is portable: instead of relying on the client-specific -D
" argument (SAP ASE isql accepts it, but FreeTDS/portable isql builds reject it
" with `unknown option D`), the URL database is selected with a `use <db>` line
" at the start of every batch. That works with any ASE client.
"
" DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
"   every function below carries a header with Purpose / Called by / SQL /
"   Args / Returns / Side effects. Required for new functions too.

" s:client(): which client binary/argv prefix to run.
" Called by: every function that spawns the client; db#connect() probe
" SQL: none
" Args: none
" Returns: string[] argv prefix — g:db_sybase_client (string or list) when set,
"   else ['isql'] on Windows, ['sqsh'] elsewhere
" Side effects: none
" s:client(): which client binary/argv prefix to run.
" Called by: every function that spawns the client; db#connect() probe
" SQL: none
" Args: none
" Returns: string[] argv prefix — g:db_sybase_client (string or list) when set,
"   else ['isql'] on Windows, ['sqsh'] elsewhere
" Side effects: none
function! s:client() abort
  if exists('g:db_sybase_client')
    let c = g:db_sybase_client
    return type(c) == v:t_string ? [c] : copy(c)
  endif
  return has('win32') ? ['isql'] : ['sqsh']
endfunction

" s:uses_sqsh(): are we driving sqsh rather than isql?
" Called by: s:batch_flags(), s:transform(), s:script_flags(), s:batch_sep()
" SQL: none
" Args: none
" Returns: boolean
" Side effects: none
function! s:uses_sqsh() abort
  return s:client()[0] =~# 'sqsh'
endfunction

" s:parsed(url): normalize a URL into a dict.
" Called by: s:server(), s:database(), s:connect_args(), s:transform(),
"   db#adapter#sybase#with_database()
" SQL: none
" Args: url = URL string or an already-parsed dict (tests pass dicts)
" Returns: dict with scheme/user/password/host/port/path/params
" Side effects: none
function! s:parsed(url) abort
  return type(a:url) == v:t_dict ? a:url : db#url#parse(a:url)
endfunction

" s:server(url): the `host[:port]` the client connects to.
" Called by: s:connect_args(), db#adapter#sybase#with_database()
" SQL: none
" Args: url = URL string or parsed dict
" Returns: string — 'host' or 'host:port' (port omitted when absent)
" Side effects: none
function! s:server(url) abort
  let url = s:parsed(a:url)
  return get(url, 'host', '') . (has_key(url, 'port') ? ':' . url.port : '')
endfunction

" s:database(url): the database selected by the URL path.
" Called by: s:use_lines(), s:transform(), db#adapter#sybase#objects()
" SQL: none
" Args: url = URL string or parsed dict
" Returns: string database name, or '' when the URL selects none
" Side effects: none
function! s:database(url) abort
  let url = s:parsed(a:url)
  return get(url, 'path', '') =~# '^/\=$' ? '' : substitute(url.path, '^/', '', '')
endfunction

" s:connect_args(url): the per-connection client arguments.
" Called by: db#adapter#sybase#interactive(), db#adapter#sybase#input(),
"   s:run_query()
" SQL: none
" Args: url = URL string or parsed dict
" Returns: string[] — ['-S', server] plus -U/-P for credentials and -J for
"   ?charset=…; the database is NOT passed here (see s:use_lines())
" Side effects: none
function! s:connect_args(url) abort
  let url = s:parsed(a:url)
  let args = ['-S', s:server(a:url)]
  if has_key(url, 'user')
    let args += ['-U', url.user]
  endif
  if has_key(url, 'password')
    let args += ['-P', url.password]
  endif
  let charset = get(get(url, 'params', {}), 'charset', '')
  if !empty(charset)
    let args += ['-J', charset]
  endif
  return args
endfunction

" s:use_lines(url, batch): prepend the `use <db>` prologue to a batch.
" Called by: s:run_query()
" Args: url = URL string or parsed dict, batch = string[] statements
" Returns: string[] — batch unchanged when the URL has no database, else
"   ['use <db>', batch separator, ''] + batch
" SQL: `use <database>` (portable selection: the client-specific -D flag is
"   rejected by some isql builds)
" Side effects: none
function! s:use_lines(url, batch) abort
  " First commands sent to the client: select the URL database so DB selection
  " never depends on a -D flag that some isql variants do not implement.
  let db = s:database(a:url)
  if empty(db)
    return a:batch
  endif
  return ['use ' . db, s:batch_sep(), ''] + a:batch
endfunction

" s:batch_flags(): client flags that shape batch behavior.
" Called by: db#adapter#sybase#interactive(), db#adapter#sybase#input(),
"   s:run_query()
" Args: none
" Returns: string[] — sqsh: ['-L', 'semicolon_hack=false'] (isql-style \go batch
"   handling); isql: ['-n', '-w', width] (no input prompts, wide output)
" SQL: none
" Side effects: none
function! s:batch_flags() abort
  if !s:uses_sqsh()
    " isql: `-n` suppresses the n> input prompts polluting the result buffer,
    " `-w <width>` widens the 80-column default so wide rows stop wrapping.
    return ['-n', '-w', s:display_width()]
  endif
  " sqsh's batch separator is \go and a bare `go` line would otherwise be sent to
  " the server; force isql-style batched input handling (see s:transform()).
  return ['-L', 'semicolon_hack=false']
endfunction

" s:display_width(): output width for isql.
" Called by: s:batch_flags()
" SQL: none
" Args: none
" Returns: string width — g:db_sybase_width, default '32000' (the 80-column
"   default wraps wide result rows)
" Side effects: none
function! s:display_width() abort
  return get(g:, 'db_sybase_width', '32000')
endfunction

" s:transform(url, in): rewrite dadbod's input file for this client.
" Called by: db#adapter#sybase#input()
" SQL: none in this function; it injects `use <db>` into the script
" Args: url = URL string or parsed dict, in = path of dadbod's input file
" Returns: path to a rewritten temp file, or `in` unchanged when nothing has to
"   change (and when `in` is not readable yet — dadbod probes the client before
"   creating it, and its own error must surface instead of an E484)
" Side effects: writes the temp file; maps bare `go` to `\go` under sqsh
function! s:transform(url, in) abort
  if !filereadable(a:in)
    " dadbod probes the client in db#connect() before the input temp file
    " exists; leave argv untouched so its executable() check raises the
    " standard actionable missing-client error instead of an E484 here.
    return a:in
  endif
  let db = s:database(a:url)
  if !s:uses_sqsh() && empty(db)
    return a:in
  endif
  let copy = tempname()
  let lines = readfile(a:in, 'b')
  if !empty(db)
    " Select the URL database from inside the script (no -D dependency).
    call insert(lines, 'use ' . db)
  endif
  if s:uses_sqsh()
    for i in range(len(lines))
      if lines[i] =~? '^\s*go\s*$'
        let lines[i] = '\go'
      endif
    endfor
  endif
  call writefile(lines, copy, 'b')
  return copy
endfunction

" db#adapter#sybase#canonicalize(url): dadbod hook, nothing to rewrite.
" Called by: vim-dadbod
" SQL: none
" Args: url = URL string
" Returns: the URL unchanged
" Side effects: none
function! db#adapter#sybase#canonicalize(url) abort
  return a:url
endfunction

" db#adapter#sybase#interactive(url): argv for an interactive session.
" Called by: vim-dadbod (:DB command, terminal buffer)
" SQL: none
" Args: url = URL string or parsed dict
" Returns: string[] — client + connect args + batch flags
" Side effects: none (dadbod spawns the client with it)
function! db#adapter#sybase#interactive(url) abort
  return s:client() + s:connect_args(a:url) + s:batch_flags()
endfunction

" db#adapter#sybase#input(url, in): argv for a script run.
" Called by: vim-dadbod
" SQL: none
" Args: url = URL string or parsed dict, in = path of dadbod's input file
" Returns: string[] — client + connect args + batch flags + ['-i', transformed]
" Side effects: writes the transformed input file (s:transform())
function! db#adapter#sybase#input(url, in) abort
  return s:client() + s:connect_args(a:url) + s:batch_flags() + ['-i', s:transform(a:url, a:in)]
endfunction

" s:script_flags(): flags that suppress client output framing.
" Called by: s:run_query()
" SQL: none
" Args: none
" Returns: string[] — sqsh ['-h'] (also drops "(N rows affected)"), isql ['-b']
"   (drops column headings)
" Side effects: none
function! s:script_flags() abort
  " sqlserver.vim uses -h-1/-W to suppress sqlcmd headers; here headers are
  " disabled per client: sqsh -h also drops the "(N rows affected)" trail,
  " ASE isql -b drops column headings.
  return s:uses_sqsh() ? ['-h'] : ['-b']
endfunction

" s:batch_sep(): the client's batch terminator.
" Called by: s:use_lines(), s:run_query()
" SQL: none
" Args: none
" Returns: string — '\go' for sqsh (a bare `go` would be sent to the server),
"   'go' for isql
" Side effects: none
function! s:batch_sep() abort
  " sqsh requires \go; bare `go' would be sent to the server.
  return s:uses_sqsh() ? '\go' : 'go'
endfunction

" s:run_query(url, sql): run one read-only query and return its output lines.
" Called by: db#adapter#sybase#tables(), db#adapter#sybase#objects(),
"   db#adapter#sybase#complete_database(), s:text_is_hidden(),
"   s:source_catalog(), s:source_showsql()
" SQL: whatever the caller passes, preceded by `set nocount on` (drops the
"   "(N rows affected)" trailer) and the `use <db>` prologue
" Args: url = URL string or parsed dict, sql = one or more statements
" Returns: string[] — raw client output lines (server diagnostics included; the
"   caller decides what to keep, e.g. s:first_tokens() / s:clean_result())
" Side effects: spawns the client synchronously via db#systemlist()
function! s:run_query(url, sql) abort
  let cmd = s:client() + s:connect_args(a:url) + s:batch_flags() + s:script_flags()
  " `set nocount on` suppresses "(N rows affected)" messages on both clients.
  let batch = s:use_lines(a:url, ['set nocount on', ''])
  let batch += split(a:sql, "\n", 1)
  call add(batch, s:batch_sep())
  return db#systemlist(cmd, batch)
endfunction

" First non-whitespace token of every line that is exactly one token (headers
" are already off). Multi-word diagnostic lines ("Msg 2812, Level 16...",
" "Changed database context to 'master'.") are filtered out.
" s:first_tokens(out): keep only real single-token result lines.
" Called by: db#adapter#sybase#tables(), db#adapter#sybase#complete_database()
" SQL: none
" Args: out = raw output lines from s:run_query()
" Returns: string[] — the first whitespace-delimited token of every line that
"   holds exactly one token; multi-word diagnostics ("Msg 2812, Level 16…",
"   "Changed database context to 'master'.") are dropped
" Side effects: none
function! s:first_tokens(out) abort
  return map(filter(copy(a:out), 'v:val =~# "^\\s*\\S\\+\\s*$"'), 'matchstr(v:val, "\\S\\+")')
endfunction

" s:object_kind(letter): sysobjects type letter -> picker kind.
" Called by: db#adapter#sybase#objects()
" SQL: none
" Args: letter = single sysobjects.type letter (P, F, X, V, U, …)
" Returns: 'procedure' | 'function' | 'view' | 'table'
" Side effects: none
function! s:object_kind(letter) abort
  if a:letter ==# 'P'
    return 'procedure'
  elseif a:letter ==# 'F' || a:letter ==# 'X'
    return 'function'
  elseif a:letter ==# 'V'
    return 'view'
  endif
  return 'table'
endfunction

" db#adapter#sybase#tables(url): table/view names for dadbod.
" Called by: vim-dadbod; db_objects.lua for non-Sybase schemes
" SQL: `select name from sysobjects where type in ('U','V') order by name`
" Args: url = URL string or parsed dict
" Returns: string[] names, [] when the client is missing
" Side effects: none (read-only)
function! db#adapter#sybase#tables(url) abort
  if !executable(s:client()[0])
    return []
  endif
  return s:first_tokens(s:run_query(a:url, "select name from sysobjects where type in ('U','V') order by name"))
endfunction

" db#adapter#sybase#complete_database(url): databases the login can read.
" Called by: db_objects.lua choose_database() (the database-scope chooser)
" SQL: `select name from sysdatabases order by name`, run against the login
"   default database (the URL path is forced to '/', no -D)
" Args: url = URL string or parsed dict (credentials/host reused)
" Returns: string[] names, [] when the client is missing
" Side effects: none (read-only)
function! db#adapter#sybase#complete_database(url) abort
  if !executable(s:client()[0])
    return []
  endif
  " Connect without a -D so database discovery uses the login default database.
  let server = extend(copy(s:parsed(a:url)), {'path': '/'})
  return s:first_tokens(s:run_query(server, 'select name from sysdatabases order by name'))
endfunction

" db#adapter#sybase#with_database(url, database): same URL, new database.
" Called by: db_objects.lua apply_database_scope()
" SQL: none (URL rewrite; the next query then runs inside the new database)
" Args: url = URL string or parsed dict, database = target database name
" Returns: the rewritten `sybase://…/<database>` URL preserving scheme, user,
"   password, host, port and query params, or '' when the name is outside
"   [A-Za-z0-9_$#] (so `%` and injection stay out of scope)
" Side effects: none
function! db#adapter#sybase#with_database(url, database) abort
  " Contract (specs/archive/2026-09-25-005-database-scope, contracts/sybase-db-scope.md §1.1).
  " Return a connection URL whose path is /<database>, preserving scheme, user,
  " password, host, port, and query params. Only the Sybase-safe identifier
  " charset is accepted: anything else (including `%`, so the cross-database
  " scan stays out of scope) returns '' for the caller to surface an error.
  if a:database !~# '^[A-Za-z0-9_$#]\+$'
    return ''
  endif
  let url = s:parsed(a:url)
  let auth = ''
  if has_key(url, 'user')
    let auth .= url.user
    if has_key(url, 'password')
      let auth .= ':' . url.password
    endif
    let auth .= '@'
  endif
  let server = get(url, 'host', '') . (has_key(url, 'port') ? ':' . url.port : '')
  let qs = ''
  if !empty(get(url, 'params', {}))
    let pairs = map(items(url.params), 'v:val[0] . "=" . v:val[1]')
    let qs = '?' . join(pairs, '&')
  endif
  return 'sybase://' . auth . server . '/' . a:database . qs
endfunction

" db#adapter#sybase#objects(url): the :DBObjects listing of one database.
" Called by: db_objects.lua fetch_objects() through vim.fn
" SQL: `select name, type from sysobjects where type in ('U','V','P','F','X')
"   order by name`, run in the URL's database
" Args: url = URL string or parsed dict
" Returns: list of {name, kind, database} dicts (kind via s:object_kind()),
"   [] when the client is missing
" Side effects: none (read-only)
function! db#adapter#sybase#objects(url) abort
  if !executable(s:client()[0])
    return []
  endif
  let db = s:database(a:url)
  let rows = []
  for line in s:run_query(a:url, "select name, type from sysobjects where type in ('U','V','P','F','X') order by name")
    let name = matchstr(line, '^\s*\zs\S\+\ze\s')
    let letter = matchstr(line, '^\s*\S\+\s\+\zs\S\+\ze')
    if name !=# '' && letter =~# '^[UVPFX]$'
      call add(rows, {'name': name, 'kind': s:object_kind(letter), 'database': db})
    endif
  endfor
  return rows
endfunction

" --- Object source (db#adapter#sybase#source) ---------------------------------
"
" `sp_helptext` (legacy mode) answers with TWO result sets: a
" `select "# Lines of Text" = count(*)` counter and then the 255-byte syscomments
" rows rendered as `convert(char(255) not null, text)`. That is what put
" "# Lines of Text", the row count, the `text` heading and the dashed separator
" at the top of every opened object, and what broke long lines mid-token (one
" syscomments row == one output line). The helpers below read the catalog
" directly and reassemble the chunks; `showsql` mode keeps the user's
" `sp_helptext <name>, NULL, NULL, 'showsql,noparams'` idea as an opt-in.

" s:source_mode() — which source extraction db#adapter#sybase#source() uses.
" Called by: db#adapter#sybase#source()
" SQL: none (reads g:db_sybase_source_mode)
" Args: none
" Returns: 'catalog' (default) | 'showsql' | any other value behaves as 'catalog'
" Side effects: none
function! s:source_mode() abort
  return get(g:, 'db_sybase_source_mode', 'catalog')
endfunction

" s:clean_result(out) — strip the client/server framing from a result set.
" Called by: s:source_catalog(), s:source_showsql()
" SQL: none
" Args: out = raw lines from s:run_query()
" Returns: string[] — the result rows only, or [] when the output carries a
"   server error (`Msg <n>, Level <n>`) so the caller shows one notice instead
"   of a garbled buffer
" Side effects: none
" Known limit: a line made only of 3+ `-`/`=` characters is always treated as
"   client framing; such a line cannot occur in valid SQL.
function! s:clean_result(out) abort
  let lines = []
  let i = 0
  while i < len(a:out)
    let line = a:out[i]
    if line =~# '^\s*Msg \d\+\s*,\s*Level \d\+'
      return []
    endif
    if line =~# '^\s*#\s*[Ll]ines of [Tt]ext\s*$'
      let i += 1
      while i < len(a:out) && (a:out[i] =~# '^\s*[-=]\{3,}\s*$' || a:out[i] =~# '^\s*\d\+\s*$')
        let i += 1
      endwhile
      continue
    endif
    if line =~# '^\s*[-=]\{3,}\s*$' || line =~# '^\s*\d\+ rows\? affected\s*$'
      let i += 1
      continue
    endif
    " Column heading (`text`, `number`, …) + the separator row under it.
    if i + 1 < len(a:out) && a:out[i + 1] =~# '^\s*[-=]\{3,}\s*$' && line =~# '^\s*[A-Za-z_]\+\s*$'
      let i += 2
      continue
    endif
    call add(lines, line)
    let i += 1
  endwhile
  return lines
endfunction

" s:trim_edges(lines) — drop leading/trailing blank lines from a source.
" Called by: s:join_chunks(), s:source_showsql()
" SQL: none
" Args: lines = string[]
" Returns: string[] — same list without blank framing at either end
" Side effects: none
function! s:trim_edges(lines) abort
  let lines = copy(a:lines)
  while !empty(lines) && lines[0] =~# '^\s*$'
    call remove(lines, 0)
  endwhile
  while !empty(lines) && lines[-1] =~# '^\s*$'
    call remove(lines, -1)
  endwhile
  return lines
endfunction

" s:join_chunks(out) — reassemble syscomments rows into the object's source.
" Called by: s:source_catalog()
" SQL: none (reassembles the rows selected by s:source_catalog())
" Args: out = rows of `select convert(varchar(255), text) + '~' + case when text
"   like '%' + char(10) then ' ' else '+' end from syscomments ... order by
"   number, colid2, colid`, one row per output block of lines
" Returns: string[] — the source split on REAL line breaks
" Side effects: none
" Why the two-character sentinel: a syscomments row is a 255-char slice of the
"   object's text, so it may end mid-line. The real line breaks are the newlines
"   inside the text, and the client prints each row's newlines as line breaks of
"   its own. The suffix appended to every row therefore encodes what the client
"   cannot show us: a row whose text ends with char(10) renders `~ ` alone on the
"   last output line (its trailing newline is already in the text, so that marker
"   line is dropped), while a row cut mid-line renders the marker glued to the
"   partial line as `~+` (no newline there, so the next output line continues the
"   same source line). Reassembling the text stream and splitting it once at the
"   end reproduces the stored source byte for byte.
"   Known limits: a source line whose last characters are exactly `~` (at a row
"   boundary) is mistaken for the marker and dropped; a lone CR line ending is
"   not treated as a break.
function! s:join_chunks(out) abort
  let text = ''
  for line in a:out
    let t = substitute(line, '\s\+$', '', '')
    if t ==# '~'
      continue
    endif
    if t =~# '\~+$'
      " Row cut mid-line: drop the `~+` marker and leave the line open.
      let text .= strpart(t, 0, strlen(t) - 2)
      continue
    endif
    let text .= t . "\n"
  endfor
  let lines = split(text, "\n", 1)
  for i in range(len(lines))
    let lines[i] = substitute(lines[i], '\r$', '', '')
  endfor
  return s:trim_edges(lines)
endfunction

" s:text_is_hidden(url, safe_name) — is the object's text hidden/encrypted?
" Called by: s:source_catalog()
" SQL: `select case when count(*) > 0 then 'HIDDEN' else 'OK' end from syscomments
"   where id = object_id('<name>') and (status & 1 = 1 or version is not null)`
"   (status 1 = SYSCOM_TEXT_HIDDEN, non-null version = encrypted)
" Args: url = sybase URL (its path selects the database), safe_name =
"   single-quote-escaped object name
" Returns: 1 when the text cannot be read, 0 otherwise (including "no rows",
"   which the caller reports as an unreadable/missing object)
" Side effects: none
" NOTE: a labelled result, not a bare count — a stray numeric client line (row
"   count when `set nocount on` did not apply) must not be read as "hidden".
function! s:text_is_hidden(url, safe_name) abort
  let sql = "select case when count(*) > 0 then 'HIDDEN' else 'OK' end from syscomments where id = object_id('" . a:safe_name . "') and (status & 1 = 1 or version is not null)"
  for line in s:run_query(a:url, sql)
    if substitute(line, '^\s*\|\s\+$', '', 'g') ==# 'HIDDEN'
      return 1
    endif
  endfor
  return 0
endfunction

" s:source_catalog(url, safe_name) — source read straight from syscomments.
" Called by: db#adapter#sybase#source() (default mode)
" SQL: `select convert(varchar(255), text) + '~' + case when text like '%' +
"   char(10) then ' ' else '+' end from syscomments where id = object_id('<name>')
"   order by number, colid2, colid` (the clustered index order, so grouped
"   procedures concatenate in definition order; the suffix tells the client-side
"   joiner whether the row ended on a real newline)
" Args: url = sybase URL, safe_name = single-quote-escaped object name
" Returns: string[] — the object's source lines; [] when the text is
"   hidden/encrypted, the object is absent, or the query failed
" Side effects: none
function! s:source_catalog(url, safe_name) abort
  if s:text_is_hidden(a:url, a:safe_name)
    return []
  endif
  let sql = "select convert(varchar(255), text) + '~' + case when text like '%' + char(10) then ' ' else '+' end from syscomments where id = object_id('" . a:safe_name . "') order by number, colid2, colid"
  return s:join_chunks(s:clean_result(s:run_query(a:url, sql)))
endfunction

" s:source_showsql(url, safe_name) — opt-in regenerated-SQL source.
" Called by: db#adapter#sybase#source() when g:db_sybase_source_mode='showsql'
" SQL: `exec sp_helptext '<name>', NULL, NULL, 'showsql,noparams'`
"   (`showsql` makes sp_helptext delegate to sp_showtext, so the
"   "# Lines of Text" counter is never emitted; `noparams` drops the generated
"   parameter block). Requires ASE 15.0.2+.
" Args: url = sybase URL, safe_name = single-quote-escaped object name
" Returns: string[] — regenerated SQL lines; [] on error (e.g. Msg 2812 when
"   sp_showtext does not exist, or Msg 18406 when the text is hidden)
" Side effects: none
" Known limit: the SQL is regenerated/formatted, not the stored text, so the
"   saved file can differ from the catalog's original formatting; prefer the
"   default 'catalog' mode for byte-exact source.
function! s:source_showsql(url, safe_name) abort
  let sql = "exec sp_helptext '" . a:safe_name . "', NULL, NULL, 'showsql,noparams'"
  return s:trim_edges(s:clean_result(s:run_query(a:url, sql)))
endfunction

" db#adapter#sybase#source(url, name) — full definition text of one object.
" Called by: db_objects.lua open_procedure_source() via vim.fn
" SQL: catalog mode → `select convert(varchar(255), text) + '~' + case when text
"   like '%' + char(10) then ' ' else '+' end from syscomments where id =
"   object_id('<name>') order by number, colid2, colid` (preceded by the
"   hidden/encrypted check); showsql mode → `exec sp_helptext '<name>', NULL,
"   NULL, 'showsql,noparams'`
" Args: url = sybase:// URL (its path is the database the object must live in),
"   name = object name (single quotes are escaped before interpolation)
" Returns: string[] — the source, one entry per real line, with no client
"   banners/headings/counts and no 255-byte mid-token cuts; [] for a missing
"   client, a missing object, hidden/encrypted text, or a failed query
" Side effects: none (pure read of the current database's catalog)
function! db#adapter#sybase#source(url, name) abort
  if !executable(s:client()[0])
    return []
  endif
  " Only ever interpolate a single-quote-escaped name (contract: never raw input).
  let safe = substitute(a:name, "'", "''", 'g')
  if s:source_mode() ==# 'showsql'
    return s:source_showsql(a:url, safe)
  endif
  return s:source_catalog(a:url, safe)
endfunction

" db#adapter#sybase#input_extension(): file extension for input scripts.
" Called by: vim-dadbod
" SQL: none
" Args: none
" Returns: string — 'sql'
" Side effects: none
function! db#adapter#sybase#input_extension() abort
  return 'sql'
endfunction

" db#adapter#sybase#output_extension(): file extension for query output.
" Called by: vim-dadbod
" SQL: none
" Args: none
" Returns: string — 'txt'
" Side effects: none
function! db#adapter#sybase#output_extension() abort
  return 'dbout'
endfunction