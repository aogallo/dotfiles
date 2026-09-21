" Sybase ASE adapter for vim-dadbod.
"
" URL scheme: sybase://[user[:password]@]host[:port]/[database][?charset=...]
"
" Client selection: sqsh on macOS (default), SAP ASE isql on Windows
" (has('win32')). Override with g:db_sybase_client (string or argv list).

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

function! s:connect_args(url) abort
  let url = s:parsed(a:url)
  let args = ['-S', s:server(a:url)]
  if has_key(url, 'user')
    let args += ['-U', url.user]
  endif
  if has_key(url, 'password')
    let args += ['-P', url.password]
  endif
  if get(url, 'path', '') !~# '^/\=$'
    let args += ['-D', substitute(url.path, '^/', '', '')]
  endif
  let charset = get(get(url, 'params', {}), 'charset', '')
  if !empty(charset)
    let args += ['-J', charset]
  endif
  return args
endfunction

function! s:batch_flags() abort
  if !s:uses_sqsh()
    return []
  endif
  " sqsh's batch separator is \go and a bare `go` line would otherwise be sent to
  " the server; force isql-style batched input handling (see s:transform()).
  return ['-L', 'semicolon_hack=false']
endfunction

function! s:transform(in) abort
  if !s:uses_sqsh()
    return a:in
  endif
  if !filereadable(a:in)
    " dadbod probes the client in db#connect() before the input temp file
    " exists; leave argv untouched so its executable() check raises the
    " standard actionable missing-client error instead of an E484 here.
    return a:in
  endif
  let copy = tempname()
  let lines = readfile(a:in, 'b')
  for i in range(len(lines))
    if lines[i] =~? '^\s*go\s*$'
      let lines[i] = '\go'
    endif
  endfor
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
  return s:client() + s:connect_args(a:url) + s:batch_flags() + ['-i', s:transform(a:in)]
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
  let batch = ['set nocount on', '']
  let batch += split(a:sql, "\n", 1)
  call add(batch, s:batch_sep())
  return db#systemlist(cmd, batch)
endfunction

" First non-whitespace token of every line that is exactly one token (headers
" are already off). Multi-word diagnostic lines ("Msg 2812, Level 16...",
" "Changed database context to 'master'.") are filtered out.
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

function! db#adapter#sybase#objects(url) abort
  if !executable(s:client()[0])
    return []
  endif
  let rows = []
  for line in s:run_query(a:url, "select name, type from sysobjects where type in ('U','V','P','F','X') order by name")
    let name = matchstr(line, '^\s*\zs\S\+\ze\s')
    let letter = matchstr(line, '^\s*\S\+\s\+\zs\S\+\ze')
    if name !=# '' && letter =~# '^[UVPFX]$'
      call add(rows, {'name': name, 'kind': s:object_kind(letter)})
    endif
  endfor
  return rows
endfunction

function! db#adapter#sybase#source(url, name) abort
  if !executable(s:client()[0])
    return []
  endif
  " Only ever interpolate a single-quote-escaped name (contract: never raw input).
  let safe = substitute(a:name, "'", "''", 'g')
  return s:run_query(a:url, 'exec sp_helptext ''' . safe . '''')
endfunction

function! db#adapter#sybase#input_extension() abort
  return 'sql'
endfunction

function! db#adapter#sybase#output_extension() abort
  return 'dbout'
endfunction