# Research: Procedure Save Dialog

Phase 0 output. Resolves the interaction and data decisions for the save flow added to
`:DBObjects` in `nvim/lua/config/db_objects.lua`.

## Decision: Target picker = directory browser over `vim.fs.dir` + a typed-path fallback

**Rationale** (FR-001/FR-004): the dialog must let the user (a) confirm or browse available
directories and (b) type an arbitrary path. The module already routes input through
`vim.ui.select` (fzf-lua is its handler — `nvim/plugin` wires it), so a navigable directory list
fits the existing interaction with zero new machinery:

- Present `vim.fs.dir(path)` entries that are directories (writable) as choices, plus two control
  entries: `..` (parent) and an explicit `use this directory` accept for the currently browsed
  path, and `type a path…` which opens `vim.ui.input` seeded with the current browsed path.
- Entering a subdirectory descends; selecting `type a path…` accepts any string (relative paths
  resolve against the startup root). This covers both FR-004 requirements with one small loop
  around APIs already in Neovim 0.11.
- `vim.fs.dir(path)` and `vim.fs.parents(path)` (0.11) give OS-correct listing/traversal with no
  absolute-path assumptions (Portability gate).

**Alternatives considered**:
- Pure `vim.ui.input` with the default path edited by hand — satisfies "type a path" but not
  "pick from available directories" (FR-004); rejected as an incomplete UX for non-typists.
- fzf-lua `files` picker for directory navigation — fzf-lua has no dedicated directory picker;
  driving `files` for a single folder selection fights the plugin and adds a distant dependency on
  its file-mode; rejected (Simplicity).
- `vim.fs.joinpath` + `vim.fs.basename` handled by Neovim — adopted as the path primitives.

## Decision: Default target = startup root captured at plugin source time

**Rationale** (FR-002/FR-003): the user asked for "the root where I started nvim", explicitly not
the last-used directory. `db_objects.lua` is required lazily inside the `:DBObjects` command
callback (`plugin/database.lua`), so its first `getcwd()` could already be a different cwd. The
faithful capture point is **plugin source time**: `plugin/database.lua` reads `getcwd()` once at
plugin load (startup, before any `:cd`) into a module-local of `db_objects` (a small `M.setup()`
called from the plugin, or shipped via a global that `db_objects` reads). This value is readonly
and used as the dialog's initial path on every invocation. Cwd changes later in the session do not
move the default, matching the "startup" wording; a previously chosen directory is never offered
as default (SC-002).

**Alternatives considered**:
- `getcwd()` re-evaluated per dialog — drifts with `:cd`/autocd projects; not the "startup root"
  the user asked for; rejected.
- Remembering last-chosen directory — explicitly rejected by the user (FR-003/SC-002).

## Decision: File name = `<owning-database>.<object-name>.sql`

**Rationale** (FR-006/SC-005): the predecessor feature (`001-multidb-object-search`) gives each
result row an owning database; qualifying the saved file by owning database plus object name keeps
same-named procedures from different databases separate in one folder and matches the
database-qualified buffer-naming convention planned in 001. When the database is unknown (row
without a database field, e.g. the pre-001 single-DB listing), the fallback is `<object-name>.sql`.

**Alternatives considered**:
- Plain `<object-name>.sql` — collisions across databases (the user's accumulation concern);
  rejected.
- Timestamp prefixes — pollute names, impede finding a given procedure; rejected (no stated need).

## Decision: Overwrite protection = pre-check + explicit two-option confirm

**Rationale** (FR-007/SC-003, constitution III): before writing, `vim.fn.filereadable(path)` is
checked; if a file exists, the user chooses between `keep existing (no overwrite)` and
`overwrite` via the same `vim.ui.select` mechanism. `keep existing` cancels the save with no side
effects; `overwrite` replaces the file. No auto-rename, no archive, no silent replacement.

**Alternatives considered**:
- Auto-suffix (`name.1.sql`) — changes filenames without the user choosing; rejected.
- Backup-and-replace — overkill for procedure text and adds recovery surface; rejected.

## Decision: Write = `vim.fn.writefile(lines, path)`, content = the exact source lines

**Rationale** (FR-005/SC-001): the module already holds the procedure's exact source as `lines`
(the output of `source()`, byte-exact per the predecessor contract); `writefile(lines, path)`
writes exactly those lines, so the saved file equals what the buffer shows and what
`syscomments` produced — no mid-token breaks, no truncation, no content transformation (FR-005).
A failed write (unwritable target/missing dir without permission) raises a Vim error caught by the
module and surfaced as one actionable `vim.notify` (FR-009).

**Alternatives considered**: `io.open(path,'w')` — works, but is redundant with Neovim's own
`writefile` error behavior; rejected for consistency.

## Decision: Hook placement — after procedure source opens, always

**Rationale** (FR-001/FR-010/SC-004): in the existing `open_row` procedure branch, after
`open_procedure_source` opens the buffer, the save dialog runs every time; cancelling leaves the
buffer (and everything else) exactly as before. Tables/views keep their list-query behavior
unchanged. This is the "window after selecting" the user described, additive to the current flow
(assumption documented in spec).

**Alternatives considered**: a separate user command (`:DBSave`) — more surfaces to document and
not what the user asked ("después de darle :dbobjects"); rejected.

## Key facts verified

- `vim.fs.dir(path)` lists entries with an `type` field; filtering `type == 'directory'` gives
  navigable subdirectories (native, Neovim 0.10+).
- `vim.fn.writefile(list, path)` writes `list` joined with `\n`; for the source text produced by
  the reassembly (which ends in a real newline), the file matches the buffer lines.
- fzf-lua is already the active `vim.ui.select` backend in this config, so `vim.ui.select` is the
  module's existing picker channel — reuse, not a new UI layer.