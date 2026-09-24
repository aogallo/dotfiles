# Data Model: Procedure Save Dialog

Phase 1 output. Defines the entities and the dialog state machine for saving a procedure selected
through `:DBObjects`. No persistent storage is introduced; saved files are user-owned artifacts.

## Entities

### Procedure Selection

The chosen row from the `:DBObjects` picker.

- **Attributes**: `kind` (procedure/function branch only); `name` (object name); `database`
  (owning database, carried by the predecessor `001-multidb-object-search` row shape; may be absent
  on the single-DB listing fallback); `lines` (the byte-exact source text loaded for this object).
- **Validation**: save flow runs only when `kind ∈ {procedure, function}` alias `P/F/X` and
  `lines` is non-empty; otherwise the existing behavior stands (table/view list-query; unreadable
  source → the existing notice, no dialog, no empty save — FR-010 + FR-010 predecessor).

### Startup Root

The directory where Neovim was started.

- **Attributes**: `path` — `getcwd()` read once at plugin source time (before any `:cd`), passed to
  `db_objects.setup(root)`, held read-only by the module.
- **Validation**: exists at capture (it is the launch cwd); never updated during the session; never
  derived from a previously chosen save directory (FR-002/FR-003).

### Save Target Directory

The destination chosen in the dialog for one save.

- **Attributes**: `path` — either the current default (startup root), a browsed subdirectory
  (descended to during selection), or a typed path; relative typed paths are resolved against the
  startup root (FR-004).
- **State transitions**:

  1. Dialog opens at `Startup Root`.
  2. User selects an available subdirectory → descends (new current directory, list rebuilt).
  3. User selects `..` → ascends one level.
  4. User selects `use this directory` → accepts the current directory.
  5. User selects `type a path…` → `vim.ui.input`; on accept, the path is normalized (relative →
     startup-root-resolved, tilde-expanded, trailing `~` artifacts removed by `vim.fs.normalize`).
  6. If the typed path does not exist → offer explicit `create directory` (then transition to
     accepted) or cancel (no side effects).
  7. `ESC`/cancel at any step → nil, dialog removed, nothing written or changed (FR-008/SC-004).

- **Validation**: chosen path is a directory or is explicitly created by the user; never treated as
  a file.

### Saved Procedure File

The single output of one save.

- **Attributes**: `name` — `<database>.<object-name>.sql`, or `<object-name>.sql` when the row has
  no `database`; `dir` — the accepted Save Target Directory; `path = dir/name`; `content` — the
  exact source `lines` (FR-005).
- **Validation**: before writing, `filereadable(path)`; if a file exists, an explicit
  `overwrite | keep existing` choice is required (FR-007). `writefile` failure → one actionable
  error, Neovim keeps running (FR-009).
- **Ownership**: user-owned file in a user-chosen directory; outside repository governance
  (constitution V).

## Relationships

- Procedure Selection (procedure kind + lines) → triggers one Save Target Directory dialog (every
  time — FR-003).
- Save Target Directory (accepted) + selected name → Saved Procedure File.
- Startup Root → initial value of Save Target Directory on every save (FR-002).

## Validation rules by requirement

- FR-002/003: default = Startup Root always; no memory of previous choices — enforced by the
  read-only Startup Root and the dialog always opening there.
- FR-004: browse (available subdirectories) + typed path, relative resolved against Startup Root.
- FR-005: content = exact `lines`; smoke-tested with a roundtrip.
- FR-006: name = `<database>.<object>.sql` (collision-free across databases).
- FR-007: `filereadable` pre-check + explicit overwrite choice; SC-003.
- FR-008: cancel is a full no-op at every transition; SC-004.
- FR-009: write errors surfaced as one actionable message.