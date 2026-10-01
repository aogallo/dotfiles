# Quickstart: Validating the Query Buffer Tab Fix

**Feature**: [011-query-buffer-tab-visibility](spec.md) · **Plan**: [plan.md](plan.md) ·
**Contract**: [contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md) ·
**Data model**: [data-model.md](data-model.md)

How to prove issue #96 is fixed. Sections 1–4 are automated and MUST pass before the change is
complete (FR-029, SC-012). Section 5 is **manual-only** — it needs a developer's eyes and a real
session, so it is listed as a known manual-only operation in `nvim/README.md`.

No database server is required for any automated check. Every defect this feature fixes is local
editor state, which is why the suite can run offline.

---

## 1. Prerequisites

- Neovim ≥ 0.9 on `PATH` as `nvim` (developed and verified against 0.12.1)
- `stylua` for the formatting gate
- No ASE server, no `sqsh`/`isql`, no credentials, no environment variable

---

## 2. Baseline — reproduce the defect before changing anything

Run this **before** touching code. It is the red proof that the defect exists and it pins the
measured numbers the implementation is judged against.

Save as `/tmp/h96-repro.lua` and run `nvim --headless -u NORC -l /tmp/h96-repro.lua`:

```lua
-- Repro for issue #96: close every buffer but one, then bring the query back.
local out = {}
local function p(s) table.insert(out, s) end

-- Faithful copy of nvim/lua/config/db_objects.lua:254-263
local function open_buffer(url, name, lines, database)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, database .. '.' .. name .. '.sql')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'sql')
  vim.b[buf].db = url
  vim.cmd('buffer ' .. buf)
  return buf
end

local keep = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(keep, 'code.md')
vim.cmd('buffer ' .. keep)

local q = open_buffer('sqsh://host/db', 'dbo_proc', { 'select 1 /* mine */' }, 'ventas')
p('1 first open        listed=' .. tostring(vim.bo[q].buflisted))            -- expect true

-- <leader>bo -> Snacks.bufdelete.other -> bdelete! on every listed buffer but this one
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  if b ~= keep and vim.bo[b].buflisted then vim.cmd('bdelete! ' .. b) end
end
p('2 after close others listed=' .. tostring(vim.bo[q].buflisted)
  .. '  b:db=' .. vim.inspect(vim.b[q].db)                                     -- expect false / nil

vim.cmd('buffer ' .. q)   -- reopen, exactly what :buffer N / a picker click does
p('3 after reopen      listed=' .. tostring(vim.bo[q].buflisted)              -- DEFECT: false
  .. '  lines=' .. #vim.api.nvim_buf_get_lines(q, 0, -1, false)
  .. '  first=' .. vim.inspect(vim.api.nvim_buf_get_lines(q, 0, -1, false)[1]))

local ok, err = pcall(open_buffer, 'sqsh://host/db', 'dbo_proc', { 'select 2' }, 'ventas')
p('4 reopen same query ok=' .. tostring(ok) .. '  err=' .. tostring(err))   -- DEFECT: E95
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  p('   buf ' .. b .. ' listed=' .. tostring(vim.bo[b].buflisted)
    .. ' name=' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ':t'))
end

local dbout = vim.fn.tempname() .. '.dbout'
vim.fn.writefile({ 'c1' }, dbout)
vim.cmd('pedit ' .. dbout)
p('5 .dbout via :pedit listed=' .. tostring(vim.bo[vim.fn.bufnr(dbout)].buflisted))

vim.fn.writefile(out, '/tmp/h96-repro.txt')
vim.cmd 'qa!'
```

```sh
nvim --headless -u NORC -l /tmp/h96-repro.lua && cat /tmp/h96-repro.txt
```

**Measured baseline (2026-09-30, Neovim 0.12.1) — this is the "before" the fix must change:**

```text
1 first open        listed=true
2 after close others listed=false  b:db=nil
3 after reopen      listed=false  lines=1  first=""
4 reopen same query ok=false  err=...:10: Vim:E95: Buffer with this name already exists
   buf 1 listed=true name=code.md
   buf 2 listed=false name=ventas.dbo_proc.sql
   buf 3 listed=true name=          <- the unnamed orphan that owns the tab
5 .dbout via :pedit listed=true     <- generated output leaking into the tab row
```

Lines 3, 4 and 5 are the defect. After the change, §4 asserts the opposite of every one of them.

---

## 3. Baseline — existing suites (must stay green)

```sh
cd "$DOTFILES"
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_context_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.formatter_chains_smoke")' -c 'qa!'
```

**Expected**: every command exits `0`. Record the assertion counts — they are the baseline for §4.

---

## 4. Automated validation after the change (required before completion)

### 4.1 New suite

```sh
nvim --headless -u NORC -c 'lua require("tests.buffer_visibility_smoke")' -c 'qa!'
```

`nvim/lua/tests/buffer_visibility_smoke.lua` must assert, against the contracts in
[contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md):

| # | Assertion | Requirement |
|---|-----------|-------------|
| 1 | a listed buffer entered repeatedly performs exactly one write (I-2, I-5) | FR-004 |
| 2 | an unlisted buffer with a window is listed after entry (I-1) | FR-001 |
| 3 | entering never unlists, unloads or wipes any buffer (I-3) | FR-021, FR-022 |
| 4 | `is_generated_output` is true for a `.dbout` buffer, a `buftype=nofile` drawer, and an opt-out buffer — and **false** for a read-only ordinary file (R-0009) | FR-018 |
| 5 | a generated-output buffer is never listed by the guard (I-4) | FR-018 |
| 6 | reopening a buffer after `bdelete!` lists it, **without any save** (FR-003) | FR-001, FR-003 |
| 7 | each reopen route ends in the same state: `:buffer N`, `:bnext`, `nvim_set_current_buf`, `nvim_win_set_buf`, `left_mouse_command`'s `buffer %d` (FR-002) | FR-002 |
| 8 | `open()` twice for the same object never raises and leaves exactly one listed buffer with the right name (R-0005) | FR-005, FR-012 |
| 9 | `open()` while the previous query is still listed allocates a distinct, distinguishable name and leaves the first buffer untouched (FR-012) | FR-012 |
| 10 | after `bdelete!`, reopening restores the text **and** the connection, and the text matches what was typed before the close (R-0006, R-0007) | FR-013, FR-014 |
| 11 | a buffer that still holds text is never overwritten by its snapshot (data model invariant 3) | FR-013 |
| 12 | the snapshot path never restores listing, focuses anything, or emits a notice (invariant 2) | FR-017 |
| 13 | a force-closed query creates no file on disk | FR-017 |
| 14 | `DbOut` reopen via `:pedit` stays unlisted after the `db_results` correction | FR-018 |

### 4.2 Extended suite

```sh
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
```

`db_results_smoke.lua` gains one case: after `show()` re-opens a dismissed result, the buffer is
still unlisted, still read-only, and still `bufhidden=delete` (R-0008). Its existing five cases must
be unchanged.

### 4.3 Full re-run

Re-run the whole of §3 plus §4.1 and §4.2 after the change. **0 failures** (SC-012).

---

## 5. Manual validation (manual-only — cannot be automated here)

Needs the developer's own session and eyes. Every step is reproducible without a database server
except 5.1, which can use any SQL file instead.

### 5.1 The reported sequence, end to end

1. `:DBObjects` → choose a procedure (or open any `.sql` file as a query buffer).
2. Edit the buffer and **do not save**.
3. `<leader>bo` (delete other buffers) — the reported trigger.
4. Reopen the query by each route in turn: `<leader>bb`, `:buffer N`, `<S-h>`/`<S-l>`,
   bufferline's left-click.
5. **Check at every step**: exactly one tab with the query's name; the text still has your edit;
   a database command in that buffer still targets the same database; **no save was needed**.

**Confirm with the developer which key they actually pressed.** `<leader>j` is not mapped in this
repository ([research.md](research.md) R-0012); `<leader>bb` is the buffer picker. The implementation
does not depend on the answer (FR-002) — this is so the report is reproduced exactly.

### 5.2 Which half of "a name shows up but it hides" applies

Run step 3, then reopen the query, then inspect `<leader>bb` and the tab row, then save.

- **Reading A** — the tab appears and then disappears: fixed by re-listing on entry.
- **Reading B** — the picker entry shows a name with a hidden marker: fixed by the same re-listing
  plus the `.dbout` correction (R-0008).

Record which one was observed. Both are covered; this step exists so the requirement is *measured*
rather than assumed ([research.md](research.md) R-0004).

### 5.3 Regression checks by hand

| Check | Expected |
|-------|----------|
| Run a query, look at the tab row | no tab for the result output |
| `<leader>qr` after closing the result window | result is focused, still no tab |
| Open the DBUI drawer and its results | no tab for either |
| Close a buffer, then keep working | it stays closed; nothing resurfaces |
| Force-close a modified buffer | content discarded, nothing written, no prompt |
| Repeat the whole cycle 10 times | no growth in tab count, no stale names |

### 5.4 Documentation check

Read each claim in the "Statusline and Bufferline" section of `nvim/README.md` and confirm it
matches what you just observed — in particular the auto-hide claim that is false today (R-0011,
FR-024). **0 discrepancies** (SC-013).

---

## 6. Troubleshooting: symptom → cause

| Symptom | Cause | Where |
|---------|-------|-------|
| Query buffer is displayed, no tab | the close cleared its listing and the reopen route did not restore it | R-0001 → contracts §1 |
| Tab labelled `[No Name]` beside stale text | reopening the same query raised `E95`, so filetype, binding and focus never ran | R-0005 → contracts §2.1 |
| Reopened query is empty | the close unloaded the buffer and its file does not exist until saved | R-0007 → contracts §2.2 |
| Query runs against the wrong database after a reopen | the close destroyed `b:db` | R-0006 → contracts §2.2 |
| A query result got a tab after `<leader>qr` | `:pedit` created a listed buffer without dadbod's settings | R-0008 → contracts §3 |
| `h` marker next to a buffer in the picker | the buffer is loaded but not displayed — a true statement, not an error | R-0004 → contract §4 |

---

## 7. Known manual-only operations

- §5.1–5.4 in full: a developer's session is required; only the assertions listed in §4 are automated.
- The developer's confirmation of which key opens the buffer picker (R-0012).
- Reading A vs Reading B in §5.2.