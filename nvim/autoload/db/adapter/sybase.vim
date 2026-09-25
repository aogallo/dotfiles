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

function! s:client() abort
  if exists('g:db_sybase_client')
    let c = g:db_sybase_client
    return type(c) == v:t_string ? [c] : copy(c)
  endif
  return has('win32') ? ['isql'] : ['sqsh']
endfunction

function! s:uses_sqsh() abort
  return s:client()[0] =~# 'sqsh'
endfunction

function! s:parsed(url) abort
  return type(a:url) == v:t_dict ? a:url : db#url#parse(a:url)
endfunction

function! s:server(url) abort
  let url = s:parsed(a:url)
  return get(url, 'host', '') . (has_key(url, 'port') ? ':' . url.port : '')
endfunction

function! s:database(url) abort
  let url = s:parsed(a:url)
  return get(url, 'path', '') =~# '^/\=$' ? '' : substitute(url.path, '^/', '', '')
endfunction

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

function! s:use_lines(url, batch) abort
  " First commands sent to the client: select the URL database so DB selection
  " never depends on a -D flag that some isql variants do not implement.
  let db = s:database(a:url)
  if empty(db)
    return a:batch
  endif
  return ['use ' . db, s:batch_sep(), ''] + a:batch
endfunction

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

function! s:display_width() abort
  return get(g:, 'db_sybase_width', '32000')
endfunction

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

function! db#adapter#sybase#canonicalize(url) abort
  return a:url
endfunction

function! db#adapter#sybase#interactive(url) abort
  return s:client() + s:connect_args(a:url) + s:batch_flags()
endfunction

function! db#adapter#sybase#input(url, in) abort
  return s:client() + s:connect_args(a:url) + s:batch_flags() + ['-i', s:transform(a:url, a:in)]
endfunction

function! s:script_flags() abort
  " sqlserver.vim uses -h-1/-W to suppress sqlcmd headers; here headers are
  " disabled per client: sqsh -h also drops the "(N rows affected)" trail,
  " ASE isql -b drops column headings.
  return s:uses_sqsh() ? ['-h'] : ['-b']
endfunction

function! s:batch_sep() abort
  " sqsh requires \go; bare `go' would be sent to the server.
  return s:uses_sqsh() ? '\go' : 'go'
endfunction

function! s:run_query(url, sql) abort
  let cmd = s:client() + s:connect_args(a:url) + s:batch_flags() + s:script_flags()
  " `set nocount on` suppresses "(N rows affected)" messages on both clients.
  let batch = s:use_lines(a:url, ['set nocount on', ''])
  let batch += split(a:sql, "\n", 1)
  call add(batch, s:batch_sep())
  return db#systemlist(cmd, batch)
endfunction

function! s:first_tokens(out) abort
  return map(filter(copy(a:out), 'v:val =~# "^\\s*\\S\\+\\s*$"'), 'matchstr(v:val, "\\S\\+")')
endfunction

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

function! db#adapter#sybase#tables(url) abort
  if !executable(s:client()[0])
    return []
  endif
  return s:first_tokens(s:run_query(a:url, "select name from sysobjects where type in ('U','V') order by name"))
endfunction

function! db#adapter#sybase#complete_database(url) abort
  if !executable(s:client()[0])
    return []
  endif
  " Connect without a -D so database discovery uses the login default database.
  let server = extend(copy(s:parsed(a:url)), {'path': '/'})
  return s:first_tokens(s:run_query(server, 'select name from sysdatabases order by name'))
endfunction

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

function! db#adapter#sybase#input_extension() abort
  return 'sql'
endfunction

function! db#adapter#sybase#output_extension() abort
  return 'dbout'
endfunction