# Contract: Query Buffer Visibility

**Feature**: [011-query-buffer-tab-visibility](../spec.md) · **Plan**: [plan.md](../plan.md) ·
**Data model**: [data-model.md](../data-model.md) · **Research**: [research.md](../research.md)

Two module boundaries are contractual — the generic buffer-visibility guard and the database query
draft registry — plus one user-visible contract (the buffer-picker marker vocabulary FR-011
requires). This file is what both implementations and both test suites are written against.

Naming follows the repo's documentation convention (`nvim/README.md`, "Documenting a function"):
every function carries **Purpose / Called by / SQL / Args / Returns / Side effects**, and SQL is
always stated, always `none` in this feature.

---

## 1. `nvim/lua/config/buffers.lua` — buffer visibility guard (NEW)

Editor-level. Knows nothing about databases, so FR-001 holds for *any* developer-opened buffer
(R-0001). Loaded independently of the database plugins.

### 1.1 `M.setup()`

| | |
|---|---|
| **Called by** | `nvim/plugin/editor.lua` at plugin source time (sibling of the existing `require 'config.db_connections'`) |
| **SQL** | none |
| **Args / Returns** | none |
| **Side effects** | creates augroup `aogallo/buffer_visibility` (cleared) and registers `BufEnter`, `BufWinEnter`, `TabEnter`, `VimEnter` with `pattern = '*'`. Idempotent via a `setup_done` flag, matching `db_results.setup()`. |

**Contract**

- Every callback MUST return immediately unless the entered buffer is valid, is displayed in a
  window, and is currently **unlisted** (R-0002, R-0003).
- MUST NOT register a listener for `BufAdd` — re-listing fires `BufAdd` (measured, R-0003), so
  listening for it invites re-entrancy.
- MUST NOT unlist, unload, wipe, or delete anything. Ever.
- MUST NOT set a message, a notification, or a status change.
- MUST NOT require any database module (module boundary, FR-026).

### 1.2 `M.is_generated_output(bufnr)` → boolean

| | |
|---|---|
| **SQL** | none |
| **Args** | `bufnr` — buffer number |
| **Returns** | `true` when the buffer belongs to the generated-output class ([data-model.md](../data-model.md) §5), `false` otherwise |
| **Side effects** | none — pure predicate, safe to call from tests without an editor setup |

**Contract** — `true` if **any** of:

1. the buffer's name ends in `.dbout`;
2. `'buftype'` is non-empty (DBUI drawer, quickfix, help, prompt);
3. the buffer-local opt-out flag is set.

**MUST NOT** classify a buffer as generated output merely because it is read-only, unmodified,
unloaded, or unlisted — those are states, not intents (R-0009).

### 1.3 `M.register_reopen_handler(fn)`

| | |
|---|---|
| **SQL** | none |
| **Args** | `fn(bufnr)` — called for a buffer that has just been brought back and re-listed, **before** any restore work |
| **Returns** | nothing |
| **Side effects** | appends to the handler list |

**Contract**

- Handlers are invoked only on the T4 path in
  [data-model.md](../data-model.md) §3 — that is, when a buffer has actually been re-listed by this
  feature. Never on the T3 no-op path, never for generated output.
- Handler order is registration order. A handler MUST NOT throw; a failure MUST NOT prevent the
  remaining handlers from running.
- Registering after `setup()` is supported and takes effect immediately.

### 1.4 Behavior contract (invariants, testable without the API)

| # | Invariant |
|---|-----------|
| I-1 | A displayed, valid, non-generated buffer that is unlisted is listed. |
| I-2 | A buffer that is already listed is never touched. |
| I-3 | No buffer is ever unlisted, unloaded, or wiped by this module. |
| I-4 | A generated-output buffer is never listed by this module. |
| I-5 | Entering the same buffer N times performs at most one option write. |
| I-6 | No message is emitted and no user command is defined by this module. |

---

## 2. `nvim/lua/config/db_query_buffer.lua` — query draft registry (NEW)

Database-level. Owns the display name, the connection, and the text that a close destroys
(R-0005, R-0006, R-0007).

### 2.1 `M.open(url, object, lines, database)`

| | |
|---|---|
| **Called by** | `db_objects.open_list_query()` and `db_objects.open_procedure_source()` (replacing the local `open_buffer` at `db_objects.lua:254-263`) |
| **SQL** | none — the caller has already read the text |
| **Args** | `url` — connection URL; `object` — database object name; `lines` — buffer text; `database` — owning database label, may be `''`/nil |
| **Returns** | the buffer number |
| **Side effects** | allocates or reclaims a buffer, writes its text, sets `filetype` and the connection, records the draft, ensures it is listed, focuses it |

**Contract**

- MUST NOT raise `E95` under any input. When the target display name is already owned, the
  allocation rules in [data-model.md](../data-model.md) §1.1 apply: reclaim the unlisted owner, or
  allocate the next free suffixed name when the owner is listed (R-0005).
- MUST set the connection on the buffer it returns, and MUST record it in the draft record, so the
  binding survives the unload a close performs (FR-014).
- MUST NOT write to disk, MUST NOT create a file, MUST NOT prompt (FR-017 as amended by A-001).
- MUST leave existing listed buffers' content untouched when it allocates a suffixed name (FR-012).
- MUST leave every unrelated buffer, window and tab unchanged.

### 2.2 `M.reopen(bufnr)`

| | |
|---|---|
| **Called by** | `buffers.lua` as a registered reopen handler (§1.3) |
| **SQL** | none |
| **Args** | `bufnr` |
| **Returns** | nothing |
| **Side effects** | restores `filetype`, the recorded connection, and — only when the buffer currently holds no text — the recorded text |

**Contract**

- MUST restore the text **only** when the buffer is empty. A buffer that holds text is never
  overwritten by its snapshot (invariant 3 of §3 in the data model).
- MUST restore the connection recorded at open time and MUST NOT re-resolve it from the current
  registry, so a re-pointed connection cannot silently change which database a query acts on
  (FR-016).
- MUST be a no-op when no draft record matches the buffer.
- MUST NOT list the buffer — by the time this runs, `buffers.lua` has already done so (§1.3). A
  second write would break I-5.
- MUST NOT emit a message.

### 2.3 `M.snapshot(bufnr)`

| | |
|---|---|
| **Called by** | `db_query_buffer.setup()`, on the event that fires when a buffer leaves the buffer list |
| **SQL** | none |
| **Args / Returns** | `bufnr`; nothing |
| **Side effects** | stores the buffer's current lines in its draft record |

**Contract**

- MUST NOT restore listing, focus anything, or emit a message (FR-022).
- MUST overwrite the previous snapshot with the newer text.
- MUST be a no-op for a buffer with no draft record.

### 2.4 `M.setup()`

| | |
|---|---|
| **Called by** | `nvim/plugin/database.lua`, beside the existing `db_objects.setup()` / `db_results.setup()` / `db_context.setup()` calls |
| **SQL** | none |
| **Side effects** | registers itself as a reopen handler with `buffers.lua`, and registers the snapshot autocmd |

**Contract**: idempotent; adds no user command; adds no keymap (R-0012).

---

## 3. `db_results.show()` — corrected summon path (MODIFIED)

| | |
|---|---|
| **SQL** | none (unchanged — it only reads a recorded output file) |
| **Change** | after `:pedit` on a dismissed `.dbout` file, re-apply dadbod's own buffer-local settings — `nobuflisted bufhidden=delete readonly nomodifiable` — before focusing, so the summon path matches the original render path (R-0008) |
| **Unchanged** | the three existing notices, the focus behavior, the single per-session slot, and the `User */DBExecutePre|Post` autocmds |

**Contract**: FR-018 says generated output takes no tab; today the summon path gives it one. This is
the fix, not a behavior change to the developer-facing flow — the developer still gets the same
focused result window.

---

## 4. User-visible contract: what the interface promises

Stated in terms a developer can check without reading Lua.

| Promise | Check |
|---------|-------|
| A buffer you opened has a tab whenever it is in front of you | open a query, close everything else, bring it back by any route → one tab, same name |
| A tab is never needed as a precondition for anything | the tab is present **before** any save |
| Generated output never occupies a tab | run a query; summon its result after closing its window → no tab in either path |
| No displayed buffer is labelled absent | inspect the buffer picker while a query is displayed → no `h`/hidden/unloaded marker on it |
| Closing is final | a buffer you closed stays closed until you explicitly bring it back |
| The picker and the tab agree | compare the name in the tab row with the name in `<leader>bb` |

**Marker vocabulary** (FR-011 requires this to be defined, not guessed): the picker marks a buffer
`h` when it is loaded but not currently displayed — a true statement about the buffer, not an error.
A buffer with no marker is displayed and loaded. Buffers produced by this feature never carry a
marker while they are the buffer in front of the developer. This paragraph is mirrored in
`nvim/README.md` (FR-030).

---

## 5. Rejected interfaces

| Rejected | Why |
|----------|-----|
| Bufferline option | none exists; full option list inspected (R-0001) |
| Monkey-patching `bufferline.utils.is_valid` | private plugin helper; breaks silently on update (R-0001) |
| A `BufAdd` listener | fires on our own write; re-entrancy for no coverage (R-0003) |
| A symmetric list-sync routine | can unlist or revive buffers as a side effect of switching windows (R-0002) |
| Changing `'buflisted'` from every reopen route | routes are plugin-owned and unbounded (R-0001) |
| Hiding instead of closing | redefines "close"; violates FR-017/FR-022 |
| Persisting drafts to disk | credentials and unsaved text on disk (constitution VII, FR-017) |
| New keymap | `<leader>j` is unmapped here and the fix is route-independent (R-0012, FR-002) |