# Research: Database Completion Never Blocks Editing

**Feature**: `013-db-completion-gate` | **Date**: 2026-10-05 | **Plan**: [plan.md](plan.md)

Every finding below was read from the installed sources on this machine, not from documentation.
Plugin sources live under `~/.local/share/nvim/site/pack/core/opt/` and are named by repository so
they are portable references. Repository files are given as `nvim/…`.

Legend: **D-####** = decision, **R-####** = measured fact the decision rests on.

---

## The defect, measured

### R-0001 — The provider runs on filetype alone

`vim_dadbod_completion/blink.lua:21-24`:

```lua
function M:enabled()
  local filetypes = { "sql", "mysql", "plsql" }
  return vim.tbl_contains(filetypes, vim.bo.filetype)
end
```

`b:db` is never consulted. The repository enables the source for SQL buffers at
`nvim/plugin/blink.lua:107`, so in any `.sql` buffer — connected or not — the source runs.

### R-0002 — It is called synchronously, on every keystroke

`vim_dadbod_completion/blink.lua:26,56`:

```lua
local results = vim.api.nvim_call_function('vim_dadbod_completion#omni', { 0, input })
```

`nvim_call_function` is synchronous. There is no `jobstart`, no `vim.schedule`, nothing
deferred. Note also `findstart` is always `0`: the engine computes the word boundary itself, so
every typed word reaches `omni()`.

### R-0003 — `omni()` connects before it has anything to offer

`autoload/vim_dadbod_completion.vim:35-37` → `:163` (`fetch`) → `:405` (`db#connect`).
`vim-dadbod/autoload/db.vim:333-376` runs the client through `s:systemlist()` and **throws** on
failure:

- `:349-351` — `throw "DB: '" . exec . "' executable not found"`
- `:360` — `call('s:systemlist', filter)`
- `:372-375` — `if !exit_status return url` … `throw 'DB exec error: '.join(out, "\n")`

### R-0004 — The retry guard is downstream of the connect. This is the loop.

`autoload/vim_dadbod_completion.vim`:

```
:35-37   if !has_key(s:buffers, bufnr)
:            call vim_dadbod_completion#fetch(bufnr(''))     <- guard tests this
:         endif
...
:405             let db = db#connect(db#resolve(db))          <- blocks / throws
...
:190-192  if !has_key(s:buffers, a:bufnr)
:             let s:buffers[a:bufnr] = {}                     <- guard satisfied HERE
:         endif
```

`s:save_to_cache` writes the record the guard tests for at line 190-192, and it is only reached
after `s:get_buffer_db_info` (line 405) returns. A connection that fails or hangs therefore never
satisfies the guard, and the next keystroke restarts the whole sequence. **This is the reported
symptom.**

A second client invocation follows once the connect succeeds:
`autoload/vim_dadbod_completion.vim:227-234` calls `db#adapter#call(a:db, 'tables', …)`.

### R-0005 — A second, silent failure mode

`autoload/vim_dadbod_completion.vim:184-187`: `s:save_to_cache` returns at line 185-187 *before*
writing `s:buffers[bufnr]` when the buffer has no database. So a `.sql` buffer with no connection
also fails the guard on every keystroke and re-runs `fetch()` — harmless (no connection is
attempted) but pure waste. FR-003 and FR-014 cover this case.

### R-0006 — Each attempt also forces a full redraw and echoes to the message area

`autoload/vim_dadbod_completion.vim:404,406` bracket the connect with
`vim_dadbod_completion#utils#msg('Connecting to db…')`, and
`autoload/vim_dadbod_completion/utils.vim:6-12` is:

```vim
redraw!
echom printf('[dadbod completion] %s', a:msg)
```

So a keystroke that fails to connect does not merely block — it forces a full screen redraw and
writes `[dadbod completion] Connecting to db…` into the message area, repeated for every
keystroke. This is the third visible symptom of the same defect and explains the "editor keeps
flickering/jumping while I type" report. A global knob exists
(`g:vim_dadbod_completion_disable_notifications`, read at `utils.vim:1`), but it is not used here:
it would mute the message without stopping the block or the redraw, which is the actual
requirement. Once the gate is closed, this message can only appear during the single deliberate
determination.

### R-0007 — The buffer the repository binds is exactly the one that triggers it

`nvim/lua/config/db_query_buffer.lua:230` and `:313` set `vim.b[bufnr].db = url` as a **string**,
which is what `autoload/vim_dadbod_completion.vim:396-403` looks for in its `w:, t:, b:, g:` scan,
before `db#connect(db#resolve(db))` at `:405`. So every query buffer this repository opens is a
live instance of the defect. Note also that `db#resolve` (`vim-dadbod/autoload/db.vim:122-124`)
canonicalizes the string before it is used, so `b:db` itself is the input, not the canonical form —
which is why the connection key is defined in [data-model.md](data-model.md) §2.

This repository writes `b:db` from a single construction site
(`nvim/lua/config/db_query_buffer.lua:230`), so the string for a given connection is canonical by
construction — the property the connection key relies on.

---

## The gate mechanism

### R-0010 — The engine has a supported, live, per-provider enable hook

`blink.cmp` `lua/blink/cmp/sources/lib/provider/init.lua:50-65`:

```lua
function source:enabled()
  if vim.in_fast_event() then return false end
  local user_enabled = self.config.enabled
  if user_enabled ~= nil then
    if type(user_enabled) == 'function' then return user_enabled() end
    return user_enabled
  end
  if self.module.enabled == nil then return true end
  return self.module:enabled()
end
```

`enabled` is a declared field of the provider config
(`lua/blink/cmp/sources/lib/provider/config.lua:6`, read at `:35`), it is consulted **before** any
module behavior, and it is evaluated per request in three places:

- `lua/blink/cmp/sources/lib/init.lua:101` — building the enabled set
- `lua/blink/cmp/sources/lib/tree.lua:29` — filtering the per-context source tree
- `lua/blink/cmp/sources/lib/init.lua:132-136` — composing trigger characters

Setting it to a function therefore makes it a live gate rather than a boot-time flag: flipping the
switch takes effect on the next keystroke with no reload.

### R-0011 — Two constraints the gate function must honor

1. `user_enabled()` is called with **zero arguments** (`provider/init.lua:59`). The gate cannot be
   handed the context; it must find the buffer itself.
2. `provider/init.lua:52-53` returns `false` during fast events, and the comment explains why:
   implementations that call buffer/window APIs there crash with `E5560`.

So the gate must read **module-local Lua state only** and touch no Vim API. Buffer→URL mapping is
therefore pre-computed on autocmds and cached in a plain table.

### R-0012 — The alternative mechanism, and why it is worse

`lua/blink/cmp/sources/lib/init.lua:74-76` also accepts a function for
`config.sources.per_filetype[filetype]`, so dropping the source id from the list would also gate
it. Rejected: removing the id changes the set handed to `context.providers` and changes what
`get_trigger_characters()` composes from (`init.lua:132-136`), which is exactly the fidelity
SC-010 forbids. Gating the provider in place keeps its configuration byte-identical.

---

## The determination

### R-0020 — The upstream cache is fillable from outside, through the plugin's own API

`autoload/vim_dadbod_completion.vim:163-182` defines `vim_dadbod_completion#fetch(bufnr)` as a
**public autoload function**, and it is what the plugin itself calls to (re)load the current
buffer (`:153-161` `clear_cache`). Calling it once, deliberately, from the repository:

- populates `s:buffers[bufnr]` (`:190-192`) → the guard at `:35` is satisfied
  → **`:405` becomes unreachable** → suggestion generation can no longer connect;
- populates `s:cache[url].tables` (`:227-234`);
- and for schemes that declare one, kicks the column / function / schema jobs
  (`:236-249`), which run through `vim_dadbod_completion#job#run` → `jobstart`
  (`autoload/vim_dadbod_completion/job.vim:38-48`) and are therefore already non-blocking.

The filetype guard at `:176-178` means the call is a no-op outside SQL/dBUI buffers.

### R-0021 — What `fetch()` costs, and when

`fetch` → `s:get_buffer_db_info` → `db#connect` is **synchronous** and blocks for the duration of
a client invocation. On an unreachable server that is a network timeout.

This is not a regression: today the *first keystroke* of such a buffer blocks identically, and
every keystroke after it blocks again. The change moves a cost that is per-keystroke today to a
single cost per buffer open. It does not eliminate it.

### R-0022 — A repository-owned provider would have to be a fork

Reproducing the upstream suggestion set means reproducing `s:quote_results`, the quoting rules per
scheme, `alias_parser`, the reserved-word list, and the per-scheme `column_query` /
`count_column_query` / `schemas_query` / `functions_query` family
(`autoload/vim_dadbod_completion/schemas.vim:1-140`) — plus the `columns_by_table` scoping and its
re-trigger dance (`:306-339`). `s:cache` and `s:buffers` are script-local, so nothing can be
seeded from outside except through `fetch()`. A replacement provider is therefore strictly a
reimplementation, with the divergence risk that implies for SC-010.

### R-0023 — The probe question, settled

The plan originally left open whether usability would be established with
`db#adapter#sybase#confirm_database()` (an extra read-only invocation, answering "does this named
database exist") or something lighter. Settled in favour of **the pre-warm itself**: it already
calls `db#connect`, so a successful pre-warm *is* the proof that the connection is usable, and it
yields the table list at the same time. `confirm_database()` answers a different question that
suggestion generation does not ask, and using it would add a second client invocation per
determination for no additional information. Nothing about it is lost: the listing feature keeps
its own confirmation path untouched
(`nvim/lua/config/db_objects.lua:911`).

### R-0024 — Re-establishing usability after a query

FR-018 requires a successful query to restore the connection. dadbod emits `User */DBExecutePre`
immediately before starting the job, and `*/DBExecutePost` after (the pattern already used by
`nvim/lua/config/db_context.lua:356` and `nvim/lua/config/db_results.lua`). There is no success
verdict on either event, so listening for "success" is not available. Instead the pre-warm is
re-run on `DBExecutePre` **for connections currently marked unusable**: the developer has just
asked to run a query against that connection, so one determination is expected. Its own
`db#connect` is the verdict, which gives FR-019 exactly — a still-dead connection throws there,
stays unusable, and the query goes on to report the database's own error. The cost of this extra
invocation is only paid on the recovery path.

---

## Notices and labelling

### R-0030 — The repository's notice module and its credential rule

`nvim/lua/notifications.lua:129` `M.notify(message, severity, opts)`, used from
`nvim/lua/config/db_context.lua:372` as
`require('notifications').notify(message, vim.log.levels.WARN, { source = 'DB' })`.

`nvim/lua/config/db_context.lua:38-56` `url_database(url)` returns only the database name and is
documented at `:278-281` as the deliberate rule: "Nothing here can produce a URL: the only value
that reaches the label is a database name." Every string this feature shows is built the same way,
which is how FR-029 is satisfied rather than asserted.

### R-0031 — which-key labels must be re-registered, not merely declared

The `database` group is registered at `nvim/plugin/editor.lua:185` as
`{ '<leader>q', group = 'database' }`; the individual bindings are plain keymaps at
`nvim/lua/config/keymaps.lua:36-40`. A `desc` is captured when the keymap is set, so a stateful
label requires re-registering the binding on each change
(`require('which-key').add{ … }`). This is what FR-009 needs.

---

## Pre-existing discrepancy found, deliberately NOT fixed

### R-0040 — `trigger_characters` in this repository's options is inert

`nvim/plugin/blink.lua:113` passes `opts = { trigger_characters = { '.', '_' } }`. That option is
never read:

- `blink.cmp` `provider/init.lua:43` calls `require(config.module).new(config.opts or {}, config)`,
  and upstream's `M.new()` (`vim_dadbod_completion/blink.lua:13-15`) takes no parameters and
  discards them;
- trigger characters come from the module method instead —
  `provider/init.lua:67-70` → `vim_dadbod_completion/blink.lua:17-19` → `{ '"', '`', '[', ']', '.' }`.

So the effective trigger set today is the plugin's five characters, not this repository's two.
Correcting it would change suggestion behavior, which SC-010 forbids in this feature. It is
recorded here so it is a known, deliberate deferral rather than an oversight, and so a future
change does not "discover" it as a bug in this feature.

---

## Decisions

### D-0001 — Gate the provider through its `enabled` option, not the filetype source list

**Decision**: add `enabled = function() return require('config.db_completion').enabled() end` to
the `vim_dadbod_completion` provider options in `nvim/plugin/blink.lua`.

**Rationale**: R-0010 shows it is a supported, live, per-request hook read before any module
behavior; R-0012 shows the alternative mutates the source set and the trigger-character
composition, which SC-010 forbids. Gating in place also means the switch needs no reload, no
`which-key` re-registration for correctness, and no change to what happens when it is on.

**Alternatives considered**: the `per_filetype` function (R-0012); wrapping `vim_dadbod_completion#omni`
in a repository function — rejected, it would have to live inside the plugin or monkey-patch an
autoload function, both of which are worse than a supported option.

### D-0002 — The gate reads module-local state only and calls no Vim API

**Decision**: `M.enabled()` performs a table lookup and nothing else. The buffer→URL mapping is
maintained by `FileType`/`BufEnter` autocmds that write into that table.

**Rationale**: R-0011. A gate that called `nvim_get_current_buf()` would be evaluated in fast
event contexts where the engine has already documented that such calls crash.

**Alternatives considered**: reading the current buffer inside the gate — rejected, it fails in
fast events; passing the context — impossible, the hook is called with no arguments.

### D-0003 — Establish usability by calling the plugin's public `fetch(bufnr)`, not by replacing the provider

**Decision**: the repository calls `vim_dadbod_completion#fetch(bufnr)` once, deliberately, from
its own trigger points.

**Rationale**: R-0020 makes this sufficient to make `:405` unreachable from the typing path, and
it fills the *whole* upstream cache including the per-scheme column/schema/function jobs.
R-0022 shows the alternative is a reimplementation with SC-010 divergence risk.

**Alternatives considered**: a repository-owned provider (R-0022); seeding `s:cache` directly —
impossible, script-local; calling `db#connect` ourselves before each completion — that is the
defect.

### D-0004 — One deliberate determination per trigger point, never from suggestion generation

**Decision**: trigger points are: a SQL/DBUI buffer acquiring a connection; the
`:DBCompletionRefresh` command; and `DBExecutePre` for a connection currently marked unusable.
Each is at most one attempt, guarded by the per-connection ledger, and none is reachable from
`omni()`.

**Rationale**: R-0021 sets the cost honestly (one blocking client invocation per buffer open,
instead of one per keystroke), and D-0004 bounds it to a small fixed set of deliberate moments.
R-0023 settles the probe question in favour of the pre-warm, so no second query path is
introduced.

**Alternatives considered**: an asynchronous `jobstart` probe before the synchronous pre-warm — it
removes the buffer-open freeze but needs its own argv assembly and probe SQL, duplicating
knowledge the adapter already owns, and it does **not** remove the synchronous `db#connect` that
still runs afterwards on the healthy path; so it adds a second code path without eliminating the
blocking one. Deferred as a possible later improvement, with the limitation documented rather than
hidden.

### D-0005 — Gate closed for every state except `usable`

**Decision**: the gate returns true only when the switch is on **and** the current buffer's
connection is in state `usable`.

**Rationale**: FR-001 requires suggestion generation to be incapable of connecting. A gate that
opens on "not known to be bad" would reopen the window between a buffer acquiring `b:db` and the
determination completing. FR-016 requires `undetermined` to be distinct from `usable`, and FR-002
requires failing closed. See [data-model.md](data-model.md) §3 for the state machine and
[contracts/db-completion-gate.md](contracts/db-completion-gate.md) §2 for the observable contract.

**Alternatives considered**: opening the gate optimistically and closing it on failure — rejected,
it is the same race that produces the current loop, only slower.

### D-0006 — Switch state is session-local and starts on

**Decision**: a module-local boolean, initialized `true`, exposed through `<leader>qc` and
`:DBCompletionToggle`, with the `which-key` label re-registered on every change and exactly one
notice per change.

**Rationale**: FR-011 requires the starting state to be documented and not persisted; FR-008 and
R-0031 define the notice and label obligations. Starting on keeps US5/SC-010 intact for anyone
whose database is healthy — a feature that began by disabling completion would be a behavior change
nobody asked for.

**Alternatives considered**: persisting the preference — rejected, it needs a writable settings
location, and FR-020/FR-033 keep this feature free of writes.

### D-0007 — Recovery re-establishes usability by re-running the determination

**Decision**: `:DBCompletionRefresh` and a `DBExecutePre` on an unusable connection each re-run the
determination; a successful determination restores `usable`, a failure keeps `unusable` and reports
the database's failure once.

**Rationale**: R-0024. There is no success verdict available on dad's user events, so the
determination is the verdict — which yields FR-018 and FR-019 from one mechanism.

**Alternatives considered**: parsing the query result buffer to decide — rejected, it is a second,
fragile source of truth and would need per-adapter output parsing.

### D-0008 — No notice ever contains a URL

**Decision**: every message is composed from `db_context.url_database(url)`, and the module never
renders a URL.

**Rationale**: R-0030. A `sybase://` URL can carry a password, so this is the difference between a
usable error message and a credential leak into a notification history. FR-029 makes it a
requirement and the new smoke test asserts it.

---

## Open questions

None. The three scope questions were answered by the developer before specification
([spec.md](spec.md) §Clarifications) and the design questions raised during planning — the probe
mechanism (R-0023), the fill mechanism (D-0003) and the gate mechanism (D-0001) — are settled
above with their rejected alternatives recorded. No `[NEEDS CLARIFICATION]` marker remains.