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

" --- Row markers (contract specs/010-dbobjects-listing-integrity/contracts/
" --- sybase-listing-integrity.md §1) --------------------------------------------
"
" Every query this adapter parses for the listing/confirmation path emits a
" marker-prefixed row, so a data row can never be confused with client framing
" (a heading, a dashed separator, a `(N rows affected)` trailer) or with a
" server diagnostic (`Msg 2812, Level 16, …`).
let s:marker_object = 'DOBJ~'
let s:marker_count = 'DCNT~'
let s:marker_database = 'DDB~'
let s:marker_exists = 'DEX~'

" Do NOT compare these with a Vim pattern. A bare `~` in a pattern is not a
" literal tilde — in magic mode it means "the latest substitute string", and it
" happily matches the empty string, so `^DOBJ~` never matches `DOBJ~name` and
" `.*\ze~\S\+$` matches nothing at all. The helpers below use s:starts_with()
" and s:split_marker_row() instead, which is plain string handling.

" --- sysobjects.type is char(2) (issue #92 root cause) -------------------------
"
" SAP ASE stores sysobjects.type as a two-character column, so the values are
" `U` (user table), `V` (view), `P` (procedure), `SF` (scalar / user-defined
" function), `TR` (trigger), `IT` (instead-of trigger) and `XP` (extended
" stored procedure). Matching that column on a SINGLE character is what made
" :DBObjects hide objects: 'F' matches only rare SQLJ functions, so ordinary
" user-defined functions never appeared, 'X' never matches the two-character
" 'XP', so extended procedures were unlistable, and 'TR' was never queried at
" all, so NO trigger was ever listable. Never narrow this list to one letter.
let s:covered_types = ['U', 'V', 'P', 'SF', 'TR', 'XP']

" s:object_kinds: trimmed sysobjects.type -> plain-language picker kind.
" Contract §1.5. An unmapped type is carried through verbatim, never dropped.
let s:object_kinds = {
      \ 'U': 'table',
      \ 'V': 'view',
      \ 'P': 'procedure',
      \ 'SF': 'function',
      \ 'XP': 'function',
      \ 'TR': 'trigger',
      \ 'IT': 'trigger',
      \ }

" s:starts_with(text, marker): does this trimmed line carry this marker?
" Called by: s:parse_listing(), db#adapter#sybase#confirm_database()
" SQL: none
" Args: text = a trimmed output line, marker = one of the marker constants
" Returns: boolean
" Side effects: none
function! s:starts_with(text, marker) abort
  return stridx(a:text, a:marker) == 0
endfunction

" s:split_marker_row(text): DOBJ~<name>~<type> -> [name, type].
" Called by: s:parse_listing()
" SQL: none
" Args: text = a trimmed line already known to start with s:marker_object
" Returns: [name, type] — the split is at the LAST tilde, because an ASE object
"   name may itself contain one; either element is '' when absent, which the
"   caller records rather than dropping silently
" Side effects: none
function! s:split_marker_row(text) abort
  let body = strpart(a:text, strlen(s:marker_object))
  if body ==# ''
    return ['', '']
  endif
  for i in reverse(range(strlen(body) - 1))
    if strpart(body, i, 1) ==# '~'
      return [strpart(body, 0, i), strpart(body, i + 1)]
    endif
  endfor
  return [body, '']
endfunction

" s:number_after(text, marker): the integer a marker-prefixed line carries.
" Called by: s:parse_listing(), db#adapter#sybase#confirm_database()
" SQL: none
" Args: text = a trimmed output line, marker = one of the marker constants
" Returns: number, or -1 when the line does not carry a plain integer — so a
"   garbled count is treated as "no count given" instead of being read as 0
" Side effects: none
function! s:number_after(text, marker) abort
  let rest = strpart(a:text, strlen(a:marker))
  return matchstr(rest, '^\d\+$') ==# '' ? -1 : str2nr(rest)
endfunction

" s:type_in_list(): the `in (…)` filter built from s:covered_types.
" Called by: db#adapter#sybase#objects()
" SQL: none (assembles the fragment both listing statements share)
" Args: none
" Returns: string — `('U','V','P','SF','TR','XP')`
" Side effects: none
function! s:type_in_list() abort
  let quoted = []
  for t in s:covered_types
    call add(quoted, "'" . t . "'")
  endfor
  return '(' . join(quoted, ',') . ')'
endfunction

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

" s:object_kind(type): sysobjects.type -> picker kind (contract §1.5).
" Called by: s:parse_listing()
" SQL: none
" Args: type = sysobjects.type exactly as the server reported it — char(2), so
"   it arrives blank-padded ('U ', 'SF', …) and MUST be trimmed before matching
" Returns: 'table' | 'view' | 'procedure' | 'function' | 'trigger' for the
"   mapped types; the trimmed type itself when unmapped (FR-011) — never '' and
"   never a default that hides the object
" Side effects: none
function! s:object_kind(type) abort
  let key = substitute(a:type, '^\s*\|\s\+$', '', 'g')
  return get(s:object_kinds, key, key)
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

" s:parse_listing(out): raw listing output -> the contract §1.2 shape.
" Called by: db#adapter#sybase#objects()
" SQL: none (parses what the listing batch produced)
" Args: out = raw client output lines from the listing batch
" Returns: dict with
"   rows        = list of {name, kind, database} (database = the db_name() the
"                 batch reported, so a row never carries a guessed owner)
"   reported    = count from the DCNT~ row, 0 when that row is absent
"   excluded    = reported objects that did not become rows (0 when unknown)
"   diagnostics = list of {text, severity, reason?}; severity 'error' for a
"                 server `Msg …` line, 'info' for every other line the client
"                 framed (reason: no_marker | malformed_marker |
"                 missing_type). Nothing is discarded silently (FR-022)
"   count_known = true when the DCNT~ row arrived; false marks the listing
"                 partial, since a total it cannot prove is not a complete one
" Side effects: none
" Why marker-only parsing: the previous parser read any line shaped like two
" tokens and filtered the rest away with s:first_tokens(), which is exactly why
" every `Msg …` diagnostic — and every warning that the switch had failed —
" vanished instead of being reported (contract §1.6).
function! s:parse_listing(out) abort
  let rows = []
  let diagnostics = []
  let database = ''
  let reported = -1
  for line in a:out
    let text = substitute(line, '^\s*\|\s\+$', '', 'g')
    if text ==# ''
      continue
    endif
    if s:starts_with(text, s:marker_count)
      let n = s:number_after(text, s:marker_count)
      if n >= 0
        let reported = n
      endif
      continue
    endif
    if s:starts_with(text, s:marker_database)
      let database = strpart(text, strlen(s:marker_database))
      continue
    endif
    if s:starts_with(text, s:marker_object)
      " DOBJ~<name>~<type>, split at the LAST tilde (see s:split_marker_row()).
      let [name, type] = s:split_marker_row(text)
      if type ==# ''
        call add(diagnostics, {'text': text, 'severity': 'info', 'reason': 'missing_type'})
      elseif name ==# ''
        call add(diagnostics, {'text': text, 'severity': 'info', 'reason': 'malformed_marker'})
      else
        call add(rows, {'name': name, 'kind': s:object_kind(type), 'database': database})
      endif
      continue
    endif
    if text =~# '^Msg \d\+\s*,\s*Level \d\+'
      call add(diagnostics, {'text': text, 'severity': 'error'})
      continue
    endif
    " Client framing (headings, `-----` separators, `(N rows affected)`,
    " `Changed database context to 'X'.`, blank-ish noise) is recorded too, so
    " a line we could not read is never indistinguishable from one we dropped
    " on purpose (FR-012).
    call add(diagnostics, {'text': text, 'severity': 'info', 'reason': 'no_marker'})
  endfor
  " `database` is known only once the first DOBJ~ row has been seen; rows parsed
  " before the DDB~ row in the same batch would otherwise be unstamped.
  for row in rows
    if row.database ==# ''
      let row.database = database
    endif
  endfor
  let known = reported >= 0
  if !known
    let reported = 0
  endif
  let excluded = known && reported > len(rows) ? reported - len(rows) : 0
  " v:true/v:false, not 0/1: a Vim number crosses into Lua as a number, and a
  " Lua 0 is TRUTHY, so a plain `known` would make the picker treat an unprovable
  " total as a known one.
  return {'rows': rows, 'reported': reported, 'excluded': excluded,
        \ 'diagnostics': diagnostics, 'count_known': known ? v:true : v:false}
endfunction

" db#adapter#sybase#objects(url): the :DBObjects listing of one database.
" Called by: db_objects.lua fetch_objects() through vim.fn
" SQL: three statements in ONE batch (one client invocation):
"   `select 'DDB~' + db_name()` — the database actually in effect, so a row is
"   never labelled with a database the server did not confirm;
"   `select 'DOBJ~' + name + '~' + convert(char(2), type) from sysobjects where
"   type in ('U','V','P','SF','TR','XP') order by name` — char(2) kept as the
"   server stores it (see the sysobjects.type note at the top of this file);
"   `select 'DCNT~' + count(*) …` over the same predicate.
" Args: url = URL string or parsed dict
" Returns: dict {rows, reported, excluded, diagnostics, count_known} per contract
"   §1.2 (**breaking**: it was a bare list); every field is empty/zero when the
"   client is missing, so the caller reports the missing prerequisite once
" Side effects: none (read-only)
function! db#adapter#sybase#objects(url) abort
  if !executable(s:client()[0])
    return {'rows': [], 'reported': 0, 'excluded': 0, 'diagnostics': [], 'count_known': v:false}
  endif
  let sql = "select '" . s:marker_database . "' + db_name()"
        \ . "\nselect '" . s:marker_object . "' + name + '~' + convert(char(2), type) from sysobjects where type in "
        \ . s:type_in_list() . ' order by name'
        \ . "\nselect '" . s:marker_count . "' + convert(varchar(10), count(*)) from sysobjects where type in "
        \ . s:type_in_list()
  return s:parse_listing(s:run_query(a:url, sql))
endfunction

" db#adapter#sybase#confirm_database(url): which database is really in effect.
" Called by: db_objects.lua apply_database_scope() through vim.fn
" SQL: ONE batch — the `use <db>` prologue (s:use_lines()) followed by
"   `select 'DDB~' + db_name()` (the switch's own answer) and
"   `select 'DEX~' + count(*) from master..sysdatabases where name = '<db>'`
"   (the server-wide existence probe, which distinguishes a typo from a login
"   that is not permitted in that database — db_id() conflates the two)
" Args: url = URL string or parsed dict
" Returns: dict {requested, confirmed, result, exists, reason}
"   result  = 'confirmed' | 'rejected_absent' | 'rejected_forbidden'
"             | 'indeterminate' (the probe produced no usable marker, so nothing
"             can be concluded) | 'no_database' (the URL carries none) |
"             'not_attempted' (the client is missing; returned so the caller
"             reports it once instead of raising)
"   confirmed = the server-reported name when result = 'confirmed', else ''
"   exists  = 1 / 0 from the probe, '' while the probe is unreadable or no
"             database was requested. POLYMORPHIC: a Number once a marker sets
"             it, the String '' otherwise, and '' coerces to 0 — so it MUST be
"             selected on type(), never compared to a number (R-0006)
"   reason  = a short explanation of what happened; '' only for 'confirmed',
"             non-empty for every not-established outcome (FR-016, FR-017)
" Side effects: one client invocation (read-only)
" Deliberately NOT done: parsing `Changed database context to 'X'.` (sqsh emits
" it, isql does not) and inferring success from the absence of an error. A
" `use` that was rejected simply leaves the session on the login default, and
" that default's objects are then labelled with the requested name — the exact
" wrong-database listing issue #92 reports (R-0003).
function! db#adapter#sybase#confirm_database(url) abort
  let requested = s:database(a:url)
  if requested ==# ''
    return {'requested': '', 'confirmed': '', 'result': 'no_database', 'exists': '',
          \ 'reason': 'the connection URL names no database'}
  endif
  if !executable(s:client()[0])
    return {'requested': requested, 'confirmed': '', 'result': 'not_attempted', 'exists': '',
          \ 'reason': 'the database client is not installed or not on PATH for this connection'}
  endif
  let safe = substitute(requested, "'", "''", 'g')
  let sql = "select '" . s:marker_database . "' + db_name()"
        \ . "\nselect '" . s:marker_exists . "' + convert(char(2), count(*)) from master..sysdatabases where name = '"
        \ . safe . "'"
  let actual = ''
  let exists = ''
  for line in s:run_query(a:url, sql)
    let text = substitute(line, '^\s*\|\s\+$', '', 'g')
    if s:starts_with(text, s:marker_database)
      let actual = strpart(text, strlen(s:marker_database))
    elseif s:starts_with(text, s:marker_exists)
      let n = s:number_after(text, s:marker_exists)
      if n >= 0
        let exists = n
      endif
    endif
  endfor
  if actual !=# '' && tolower(actual) ==# tolower(requested)
    return {'requested': requested, 'confirmed': actual, 'result': 'confirmed',
          \ 'exists': exists ==# '' ? 1 : exists, 'reason': ''}
  endif
  " Not in effect. The probe is polymorphic — a Number once a marker set it, the
  " String '' while it stayed unreadable. Vimscript coerces '' to 0, so
  " `exists == 0` reports an unreadable probe as `rejected_absent`: a database
  " asserted not to exist because the check never ran (R-0006). Select on
  " type() so the unreadable probe becomes its own outcome and asserts nothing
  " (FR-015, FR-017).
  if type(exists) == v:t_string
    return {'requested': requested, 'confirmed': '', 'result': 'indeterminate',
          \ 'exists': exists,
          \ 'reason': "the existence probe returned no readable result for '" . requested . "'"}
  endif
  " exists = 1 means the server knows the database and this login could not
  " enter it; exists = 0 means there is no such database.
  return {'requested': requested, 'confirmed': '',
        \ 'result': exists == 0 ? 'rejected_absent' : 'rejected_forbidden',
        \ 'exists': exists,
        \ 'reason': exists == 0
        \   ? "master..sysdatabases does not list '" . requested . "'"
        \   : "the switch to '" . requested . "' did not take effect although the server knows it"}
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