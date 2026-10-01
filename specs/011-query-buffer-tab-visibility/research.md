# Research: Query Buffer Always Shows Its Tab

**Feature**: [`011-query-buffer-tab-visibility`](spec.md) · **Date**: 2026-09-30 · **Issue**:
[#96](https://github.com/aogallo/dotfiles/issues/96)

Every finding below was verified against Neovim 0.12.1 and the plugins installed in this
checkout, and every behavioral claim about the editor was measured with a headless probe rather
than inferred from documentation. The probes are reproduced in
[quickstart.md](quickstart.md) so a reviewer can re-run them.

## Evidence base

| Source | What was used |
|--------|---------------|
| `nvim/plugin/editor.lua:220-234` | the whole bufferline option surface in this repo (8 options) |
| `nvim/lua/config/db_objects.lua:254-263` | `open_buffer()`, the query-buffer factory |
| `nvim/plugin/fzf-lua.lua:193`, `nvim/plugin/editor.lua:119` | `<leader>bb` (picker), `<leader>bo` (delete others) |
| `nvim/lua/config/db_results.lua:94-126` | `<leader>qr` summon path (`:pedit` on a `.dbout` file) |
| bufferline.nvim (installed) | `utils/init.lua:146-151` (`is_valid`), `bufferline.lua:205` (tabline expression), `config.lua:632-672` (full option list) |
| fzf-lua (installed) | `providers/buffers.lua:54` (unlisted filter), `:170` (`h` marker), `actions.lua:192` (re-list workaround) |
| snacks.nvim (installed) | `bufdelete.lua:37-41, 91, 106-114` (`bdelete!` per listed buffer) |
| vim-dadbod (installed) | `db.vim:410` (`nobuflisted bufhidden=delete`), `:540-545` (`:pedit`) |
| Neovim runtime docs | `options.txt:1213-1220` (`'buflisted'`), `autocmd.txt:231-236` (`BufAdd`) |
| headless probes | `/tmp/h96-probe.lua`, `/tmp/h96-probe2.lua`, `/tmp/h96-probe3.lua` — results quoted inline |

## Findings

### R-0001 — Closing a buffer takes it out of the buffer list, and coming back does not put it back

**Measured** (`probe.lua` H1, `probe2.lua` §1-2):

```text
listed-before-close true      listed-after-bdelete false    still-valid true   loaded false
listed-after-reopen (via :buffer N) false
```

`:help 'buflisted'` states it outright: *"This option is reset by Vim for buffers that are only used
to remember a file name or marks… But not when moving to a buffer with `:buffer`."* `bufferline`'s
only filter is `utils/init.lua:150` → `return buf.listed == 1`, and the option list at
`config.lua:632-672` contains **no** setting that relaxes it.

**Why the report says "for some reason"** — reopen routes genuinely differ, measured in
`probe3.lua` A vs D:

| Route | Re-lists the buffer? | Why |
|-------|----------------------|-----|
| `:buffer N` (buffer-number jump, `bnext`/`bprev` under `:bnext`) | **no** | Neovim does not set the flag on `:buffer` |
| `:edit <name>` | **yes** | edits a *name*, which creates/re-lists a buffer |
| fzf-lua picker (`<leader>bb`) | **yes** | `actions.lua:192` sets `vim.bo[bufnr].buflisted = true` as an explicit workaround |
| bufferline left-click (`buffer %d`) | **no** | same `:buffer` route |
| `b <bufnr>` / `nvim_set_current_buf` | **no** | no name involved |

So the same buffer, closed once, comes back with or without a tab depending on the route — which
is exactly the "por alguna razón" in the report and the reason the user could not reproduce it
deterministically.

**Decision**: add a repository-owned guard that guarantees the invariant *"a displayed,
developer-opened buffer is in the buffer list"*, independent of route, by re-listing on entry.

**Rationale**: it is the only place that covers all five routes plus any route a plugin adds later,
and it fixes the bufferline tab and both pickers' unlisted filters at the same time
(`providers/buffers.lua:54` filters unlisted buffers out of the list, so the user's only route back
was also the route most likely to leave it tab-less).

**Alternatives considered**:

- *Patch `bufferline.utils.is_valid` from the repo.* Rejected: it monkey-patches a plugin's private
  helper, breaks silently on any plugin update, and couples the module to a specific plugin rev.
- *Add a bufferline option.* Rejected: none exists (option list inspected in full).
- *Re-map every reopen route.* Rejected: the route list is owned by plugins and unbounded; the next
  picker would reopen the bug.
- *Stop unlisting on close (replace close with hide).* Rejected: it would make "closed" a lie, keep
  every closed query in the tab row, and violate FR-022/FR-023.

---

### R-0002 — The guard is additive only: it re-lists, it never unlists

**Decision**: the guard's only mutation is `buflisted = false → true`. It never sets a listed buffer
to unlisted.

**Rationale**: the buffer list is also the close-action's work list — `snacks/bufdelete.lua:37-41`
iterates `if vim.bo[b].buflisted` — so any unlisting would remove a buffer from the set the user can
close, and any bulk re-listing could resurrect work the developer deliberately closed (FR-022,
FR-023).

**Alternatives considered**: a symmetric "keep the list in sync" routine (rejected: it can close or
revive buffers as a side effect of switching windows).

---

### R-0003 — Where the guard listens: `BufEnter`, `BufWinEnter`, `TabEnter`, `VimEnter`

**Decision**: one augroup with those four events; every callback is a no-op unless the entered
buffer is currently unlisted.

**Rationale**: the reported route (`:buffer N`, picker, click) only fires `BufEnter`; a buffer shown
in a split opened by `:split`/`:pedit`/`win_execute` can be displayed without `BufEnter` firing in
the caller's context (`BufWinEnter` covers it); `TabEnter` covers tab-local entry; `VimEnter` covers
buffers passed on the command line. The common case is a single `vim.bo[bufnr].buflisted` read,
which is why four events are affordable.

**Alternatives considered**:

- *`BufAdd`* — rejected: `autocmd.txt:232` and the measurement in `probe.lua` H3 confirm that
  re-listing fires `BufAdd`, so listening to it invites re-entrancy for no coverage gain (the tab
  appears on the next redraw regardless).
- *`BufReadPost` / `BufNewFile` / `BufRead`* — rejected: these never fire for an existing buffer
  being revisited, which is precisely the reported case.
- *`BufWinLeave` / `BufDelete`* — rejected: there is no window at that point to show a tab in.

**Note on rendering**: `bufferline.lua:205` sets `vim.o.tabline = "%!v:lua.nvim_bufferline()"`, an
expression re-evaluated on every redraw, so no refresh call is needed — once the buffer is listed,
the tab appears on the next redraw.

---

### R-0004 — `bufhidden = 'hide'` on query buffers is inert here; leave it alone

**Measured** (`probe.lua` H4): with `vim.o.hidden` on, leaving the window keeps a `bufhidden=hide`
buffer **loaded** and its `b:` variables intact (`b:db` survived, `hidden=0`). `'hidden'` defaults
to on in Neovim and `nvim/lua/config/options.lua` never changes it (probe: `hidden-option true`).

**Decision**: do not touch `bufhidden` in this change. It is a no-op for every requirement here,
and touching it would widen the diff without moving any acceptance scenario.

**Alternatives considered**: removing it as dead configuration (rejected *for now* — it is not dead
if `'hidden'` is ever turned off, and this change has no reason to touch `'hidden'`). It was
investigated as the source of the `h` marker the user reports and **ruled out**: that marker tracks
`getbufinfo().hidden` for a loaded-but-not-displayed buffer, which is a true statement about the
buffer, not a bug.

---

### R-0005 — Second defect: reopening the *same query* raises `E95` and silently produces no query

**Measured** (`probe2.lua` §3) — a faithful replay of `db_objects.open_buffer()`:

```text
3 re-open ok false   err  ...:10: Vim:E95: Buffer with this name already exists
3 current buf name ventas.dbo_proc.sql   q listed false
3 buf 1 listed true  name code.md
3 buf 2 listed false name ventas.dbo_proc.sql
3 buf 3 listed true  name ''            <-- a listed, unnamed, never-focused orphan
```

After the close, the buffer still exists and still owns the name `ventas.dbo_proc.sql`. The next
`open_buffer()` creates a new listed buffer and then calls `nvim_buf_set_name` at
`db_objects.lua:258`, which **raises `E95`** because the name is taken. The exception is unhandled,
so `db_objects.lua:259-262` never run: `bufhidden`, `filetype`, `b:db` and the final
`vim.cmd('buffer ' .. buf)` are all skipped. The developer is left with

1. an **orphan listed buffer with no name** — a tab labelled `[No Name]`,
2. the *old* unlisted buffer still in the window, showing the previous text,
3. no filetype and no connection binding on anything,
4. an uncaught error whose text depends on the call path.

This is a second, independent explanation for "vuelvo a abrir el mismo query y no aparece" and for
"se ve que sale un nombre pero se oculta": the developer sees an unnamed tab and a stale body.

**Decision**: `open_buffer` reclaims the abandoned buffer that already holds the target display name
instead of creating a new one. Concretely:

- name held by an **unlisted** buffer → reuse it: clear its lines, set the display name (already
  correct), `filetype`, `b:db`, ensure listed, focus it;
- name held by a **listed** buffer (a live query the developer still has) → allocate a distinct
  display name (`<database>.<name>.2.sql`, `.3.sql`, …) so both tabs are identifiable, which also
  serves FR-012.

**Rationale**: the text of a query buffer is generated from the catalog, so re-deriving it costs
nothing; reusing the buffer keeps exactly one tab and one name, and it removes the `E95` class
entirely instead of hiding one instance of it.

**Alternatives considered**:

- *`pcall` around `set_name` plus an error notification* — rejected: the developer still ends up
  with no query buffer and no tab, i.e. the reported symptom with an extra message.
- *Always generate a unique name* — rejected: two tabs with `<db>.<name>.sql` and
  `<db>.<name>.2.sql` in the common case where the first one was closed, for no benefit.
- *`:bwipeout!` the stale buffer, then create fresh* — rejected: if that stale buffer is the one
  currently displayed (which is exactly what happens when the flow is re-run), the wipe blanks the
  developer's window mid-action, and the tab position/identity is churned for nothing.
- *Use `:badd`-style unique naming upstream of `nvim_buf_set_name`* — same as "always unique",
  rejected above.

---

### R-0006 — Third defect: the query's database binding is destroyed by the close

**Measured** (`probe2.lua` §1, `probe3.lua`): `bdelete!` unloads the buffer, and buffer-local
variables do not survive an unload — `b:db nil` immediately after the close.

**Consequence**: after any close/reopen cycle the buffer is an ordinary `sql` text buffer with no
connection. `:DB` commands in it fall back to whatever `:DBObjects` resolves, so a query can be run
against the wrong database — a worse failure than a missing tab, and exactly what FR-014 and
SC-007 forbid.

**Decision**: keep a session-local draft record per query buffer (display name, connection URL,
filetype) in the database module and re-apply `filetype` and `b:db` when the buffer is brought back.

**Rationale**: buffer-local variables are the existing mechanism this module already uses
(`b:db` at `db_objects.lua:261`, read by `db_context` and `db_connections`), so re-applying them is
the same contract, not a new one. A session-local record is needed because the unload destroys the
buffer-local state that would otherwise be the source of truth.

**Alternatives considered**:

- *Encode the connection in the buffer name* — rejected: names are already the developer-facing label
  (FR-012), the URL contains credentials that must never be shown (constitution VII), and the name
  must stay stable for the tab label.
- *Ask the developer to re-run `:DBObjects <connection>` each time* — rejected: it puts the work the
  configuration already knows back onto the user, and is not recoverable by any route that is not
  the original open.
- *Persist drafts to disk* — rejected twice: constitution VII (credentials on disk) and FR-017 (no
  writes for unsaved content).

---

### R-0007 — Fourth defect: the query text does not survive the close either

**Measured** (`probe3.lua`, four variants — close-while-current, close-from-another-buffer, with and
without `bufhidden=hide`, `:buffer N` and `:edit name`):

```text
A before-close     listed true  loaded true   lines 1  first "select 1 /* mine */"
A after-close      listed false loaded false  lines 0  first nil
A after-reopen     listed false loaded true   lines 1  first ""
```

Unloading a buffer discards its text (`'hidden'` only controls *hiding*, not *unloading*), and on
reopen Neovim tries to read the buffer's file — which does not exist for an unsaved query — so the
developer gets an **empty** buffer with the right name. The reported "for some reason it doesn't
show up" has a second, content-level explanation: what comes back may be an empty buffer.

**Decision**: snapshot the buffer's lines into the same session-local draft record when the buffer is
unloaded, and restore them on re-entry when the buffer is empty. Nothing is written to disk.

**Rationale**: without this, FR-013 is unsatisfiable and the feature would hand the developer an
empty buffer with a tab — a worse bug than the one being fixed.

**Alternatives considered**:

- *Give the query buffer a real path under `stdpath('cache')` at creation* — rejected: it writes the
  generated query to disk as a side effect of merely viewing an object (surprising, needs cleanup,
  and still loses the developer's later edits since only the generated text would be on disk).
- *Change the close actions to hide instead of unload* — rejected: it redefines "close" and violates
  FR-017/FR-022.
- *Accept content loss and amend FR-013 down* — rejected: silently handing back an empty query buffer
  is precisely the class of defect the issue is about.

---

### R-0008 — The `.dbout` summon path leaks generated output into the tab row (FR-018 premise is wrong)

**Measured / read**: dadbod renders results over `setlocal nowrap nolist readonly nomodifiable
nobuflisted bufhidden=delete` (`db.vim:410`) — unlisted by design, so no tab. But `db_results.show()`
re-opens a dismissed result with a bare `:pedit` (`db_results.lua:120`) and never re-applies those
settings, and `:pedit` creates a **listed** buffer. So after `<leader>qr` on a result whose window was
closed, the generated output **does** get a tab today.

**Decision**: (1) the exclusion predicate must recognise `.dbout` buffers by name regardless of
listing, and (2) `db_results.show()` must re-apply dadbod's buffer-local settings after `:pedit`,
so the summon path matches the original path.

**Rationale**: FR-018 and User Story 4 require generated output to keep taking no tab. The intent is
clearly right, but its "as today" premise is only true for the original render path — so the plan
has to make both paths agree, otherwise the new re-listing guard would turn a rare leak into a
persistent one (any `.dbout` buffer that reached the list would be re-listed forever after).

**Alternatives considered**: relying on the exclusion predicate alone (insufficient — the buffer is
listed, so the guard would keep it listed and it would show a tab) and simply excluding it from
re-listing (also insufficient — it already has a tab).

---

### R-0009 — Excluding generated output: three explicit rules, not a structural guess

**Decision**: `is_generated_output(bufnr)` is true when any of:

1. the buffer's name ends in `.dbout` (the module's own documented vocabulary,
   `db_results.lua:4`);
2. the buffer has a non-empty `'buftype'` — covers the DBUI drawer (`buftype=nofile bufhidden=wipe
   nobuflisted`, `db_ui/drawer.vim:38`), quickfix, help and prompt buffers (measured in `probe2.lua`
   §5);
3. the buffer opts out explicitly via a buffer-local flag, for a generated buffer that is not
   covered by 1 or 2.

**Rationale**: rule 2 alone is too broad in the other direction (a terminal or prompt buffer the
developer opened would never get a tab back), and rules 1-2 alone leave no extension point. An
explicit opt-out is the same shape already used by `db_results` (a single per-session slot), so it
is idiomatic here.

**Alternatives considered**: matching on `readonly and not modifiable` (rejected: it would exclude
any read-only file the developer opens), and matching only on `nobuflisted` (rejected: that is the
symptom being fixed, not a category).

---

### R-0010 — Spec amendment A-001: FR-017 vs FR-013

R-0007 exposes a contradiction in the approved [spec.md](spec.md) that no amount of implementation
can satisfy as written:

- **FR-013 / US1-4 / SC-006**: a query buffer that has been closed and brought back MUST retain its
  content, including every unsaved edit.
- **FR-017 / US3-4**: force-closing a modified buffer MUST continue to discard its unsaved content.

Both cannot hold: with `bdelete` unloading the buffer, the text is gone at close time. The resolution
proposed here keeps the user's decision intact and only removes the accident:

> **A-001** — FR-017 and US3-4 are reworded to: force-closing MUST NOT write the content anywhere,
> MUST NOT create a file, MUST NOT restore a tab by itself, and MUST NOT re-insert the buffer into the
> buffer list. Within the same session the text MAY remain retrievable in memory so that a later
> **explicit** developer action (any reopen route) shows the query again, per FR-013.

**Rationale**: what the developer asked for with a force-close is "get it out of my way now, without
putting my text on disk". Both clauses stay true under A-001. Under the original wording the only
way to satisfy FR-013 would be to violate FR-017, and the reverse would ship the empty-buffer
regression from R-0007.

**Status**: **approved by the developer on 2026-09-30** and applied to
[spec.md](spec.md) — FR-017, US3-4, SC-006, the "Out of Scope" entry, and a new
[Clarifications](spec.md#clarifications) entry. The implementation must follow the amended reading:
no self-restoration, no write, and text retrievable only through an explicit developer action.

---

### R-0011 — Documentation: the bufferline auto-hide claim is false

**Read**: `nvim/README.md:83` states the buffer row *"auto-hides when only one buffer is open"*, and
`nvim/plugin/editor.lua:230` sets `auto_toggle_bufferline = true`. But `always_show_bufferline`
defaults to `true` (`config.lua:663`), so `bufferline.lua:124-131` **never registers** the
`BufAdd`/`TabEnter` toggle autocmds and `bufferline.lua:206` forces `showtabline = 2`. Measured in a
headless session: `showtabline 2` with a single buffer.

**Decision**: correct the README in this change (FR-024) and leave the bufferline options untouched —
adding `always_show_bufferline = false` would start *hiding* the row where it never hid before,
which is a UX regression for a developer whose whole complaint is not seeing their buffer.

---

### R-0012 — The reported key does not exist in this repository

**Read**: no `<leader>j` mapping anywhere in `nvim/` (0 hits for `leader>j`). The buffer picker is
`<leader>bb` (`fzf-lua.lua:193`); `<leader>bo` is delete-others (`editor.lua:119`); `<leader>bx` is
plain `:bdelete` (`keymaps.lua:34`); `<S-h>`/`<S-l>` are overridden to `:bprev`/`:bnext`
(`keymaps.lua:32-33`), which are exactly the routes that **do not** re-list.

**Decision**: implement route-independently (already FR-002) and add **no** keymap. Record the
mismatch as an Assumptions entry so the quickstart reproduces the report with the keys that exist.

**Rationale**: the fix must not depend on knowing which key the developer pressed, and R-0001 shows
the route is not even the determining factor — the plugin's picker repairs the flag and `:buffer`
does not.

---

## Resolved unknowns

| Unknown | Resolution |
|---------|------------|
| Which bufferline option shows unlisted buffers? | None exists — full option list inspected (`config.lua:632-672`) |
| Does the picker hide unlisted buffers? | Yes (`fzf-lua providers/buffers.lua:54`, Snacks `picker/source/buffers.lua:17`), so the fix must re-list, not re-render |
| Why does it sometimes work? | Route-dependent re-listing (R-0001) plus the `E95` orphan (R-0005) |
| Is `bufhidden=hide` the cause? | No — inert while `'hidden'` is on; measured (R-0004) |
| Is the `h` marker the cause? | No — it reports a true loaded-but-hidden state (R-0004) |
| Does the query text survive a close? | No — unloaded, discarded, reopened empty (R-0007) |
| Does `b:db` survive a close? | No — `b:` variables do not survive an unload (R-0006) |
| Does a `.dbout` result take a tab? | Original path: no. `<leader>qr` summon path: **yes**, today (R-0008) |
| Is a tab refresh call needed after re-listing? | No — the tabline is a redraw-time expression (`bufferline.lua:205`) |
| Does re-listing fire `BufAdd`? | Yes (`autocmd.txt:232`, measured) — which is why the guard does not listen for it (R-0003) |

## Handoff to Phase 1

- Entities → [data-model.md](data-model.md): the draft record, the visibility guard, the exclusion
  classes, and the state transitions that R-0001/R-0005/R-0007 create.
- Interfaces → [contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md): the two
  module surfaces, their invariants, and the buffer-picker marker documentation FR-011 requires.
- Validation → [quickstart.md](quickstart.md): the re-runnable probes, the smoke-test commands, and
  the manual reproduction of issue #96 end to end.
- Amendment **A-001** (R-0010) was **approved on 2026-09-30** and applied to [spec.md](spec.md); the
  design above already matches the amended contract, so no Phase 1 artifact changed.