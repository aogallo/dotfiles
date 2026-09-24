# Research: Database-Scope Feedback and Save Confirmation

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-24

## R1 — Why the scope can "return to the initial list" without an error (US1)

### Decision

Treat the silent/ambiguous scope transitions in `nvim/lua/config/db_objects.lua` as the defect, and make every
scope outcome explicit: one actionable notification + the picker stays on the last-good listing. The concrete
trigger the user reported (typed database name with `_`, no error seen, back to the initial list, SP not found)
is covered by reproducing the transitions below; the fix is the mechanism, not one specific cause.

### Rationale

`db_objects.lua` has exactly these scope-outcome paths (all read in context of spec 005):

1. `apply_database_scope` → `db#adapter#sybase#with_database(url, name)` returns `''` when the name is outside
   `[A-Za-z0-9_$#]` (`nvim/autoload/db/adapter/sybase.vim:181`). Branch: one `vim.notify(ERROR)` then
   `pick(rows, url)` — the picker reappears showing the **previous** (unscoped) list. This is the literal
   "vuelve al listado inicial". An underscore passes the charset, so this branch alone cannot explain a
   valid `_` name, but a name with any other character (`.`/`-`/space) hits it.
2. `apply_database_scope` → `fetch_objects(scoped)` returns an empty table. Branch: one `vim.notify(ERROR)` and
   **`return` without re-opening a picker** — the user is left with the scope chooser gone and no list. From the
   user's perspective this is also "went back / nothing happened", and a transient Snacks/fzf notify is easy to
   miss. This is the most likely silent path: the reported name is valid, but the scoped listing came back empty
   (server rejects the `use`, or `sysobjects` in that database reads empty for the login).
3. `apply_database_scope` succeeds and re-lists via `pick(scoped_rows, scoped)`. The picker reopens inside the
   scoped database — but the only in-picker signal is the raw URL embedded in the header prompt
   (`DB objects (<url>)`); there is no stable, human-readable scope indicator. If the SP genuinely does not
   exist in that database the user cannot distinguish "not scoped" from "not present".

### Alternatives considered

- **Relax the `with_database` charset** to accept dots/hyphens: rejected — dot/hyphen names were not reported,
  the URL-path semantics of such names are ambiguous (dots are legal in ASE identifiers but `?`/`/` still break
  URL parsing), and it would change the published 005 contract for an unverified trigger.
- **Persist a per-connection "last scope" in files/DirChanged state**: rejected — the constitution's
  simplicity/non-destructive gates favor stateless behavior; the URL already carries the scope.

### Learned

- `vim.notify` feedback is transient and easy to miss when the picker also disappears or reappears; feedback must
  be tied to an action the user can see (the picker staying, with a clear message) — not a lone toast.
- The scope chooser cancel path (`choose_database` → `pick(rows, url)`) already keeps the last-good list; the
  failure paths are the ones that diverge (vanish, or re-show without explaining why).

## R2 — Scope visibility: how the picker shows the active database (US1)

### Decision

Derive a readable scope label from the threaded URL and surface it in the object-listing header, reusing the
same display rule as the scope row: no path → `login default`, otherwise the database name. No extra state.

### Rationale

The scope row already renders `Database: <x> — change…` via `url_database(url)` + the `scope` item in `pick`
(`nvim/lua/config/db_objects.lua:351-377`). The object-list prompt currently embeds the raw URL, which is noisy
and shows `sybase://alice:p@h:5000/…` with credentials. A consistent readable label (login default vs chosen name)
gives the user a stable in-picker anchor on every transition, including successful re-list and failed scope
re-opens.

### Alternatives considered

- Statusline/global-per-db state: rejected (stateless goal, and scope is transient to the picker session).
- Editorial: keep raw URL only: rejected — does not resolve the "am I scoped?" ambiguity.

### Learned

The existing helpers (`url_database`, the scope-row `format_item`, `M.suggest_save_name`) already encode the
label rules; the header can reuse them without new parsing.

## R3 — Save confirmation without duplication (US2)

### Decision

Add a `vim.notify(...INFO)` with the full path at the single write point in `run_save_flow`, after
`M.write_source` returns `{ ok = true, path = ... }`. No change to directory defaults, overwrite guard, or
create-directory flow.

### Rationale

`run_save_flow`'s `save()` closure is the only place a file is written (both the fresh and the overwrite paths
call it) and `write_source` already returns the resolved absolute path (`db_objects.lua:138-145, 245-259`). One
notify there therefore fires exactly once per confirmed save and carries the true destination — proving the
single-write guarantee to the user with no duplication.

### Alternatives considered

- Notify from a wrapper at each of the two call sites: rejected — duplicate risk if a path is missed.
- Persist last directory / remember typed path: rejected by the clarified answer; the startup-root general view
  is intentional and must stay.

### Learned

The flow already writes to exactly one confirmed `dir` (`pick_save_target` → `on_done(dir)` → one
`write_source`); the "duplicate file left in the root" fear is unfounded and the notification makes that verifiable
end-to-end.

## R4 — Keymap group for `<leader>q` (US3)

### Decision

Add `{ '<leader>q', group = 'database' }` to the which-key prefix registry in `nvim/plugin/editor.lua` (after the
`packages` line), matching the existing group style (lines ~150-158). The four database keymaps already live in
`nvim/lua/config/keymaps.lua:37-40`.

### Rationale

The module README (`nvim/README.md:548`) already documents "Pressing `<leader>q` alone shows the `database`
group (j/u/o/r)"; the registry line was omitted from the 006 PR and remains uncommitted on `main`
(engram #1488). This closes the doc/code gap with a one-line, style-consistent addition.

### Alternatives considered

- None — the only alternative is leaving the gap.

### Learned

Which-key groups in this config are declared as `<leader>`-prefix entries with `group =` labels inside the
`leader` registry in `editor.lua`; actions themselves are separate `vim.keymap.set` calls in `keymaps.lua`.

## Consolidated decisions

- D-1 (US1): scope outcome is always explicit — exactly one actionable notification and the picker stays on the
  last-good listing (`pick(rows, last_url)`) on every scope failure; never a vanish, never a silent revert.
- D-2 (US1): object-list header shows a readable scope label (`login default` or the database name), reusing the
  existing display helpers; scope remains carried only by the URL (stateless).
- D-3 (US2): one save-confirmation notification at the single write point with the full resolved path; dialog
  defaults, overwrite guard, and single-write semantics unchanged.
- D-4 (US3): one which-key group line `{ '<leader>q', group = 'database' }` in `nvim/plugin/editor.lua`.
- D-5: no adapter (`sybase.vim`) changes; the 005 contracts (`with_database`, charset, objects/database rows) are
  reused unchanged.
- D-6: stateless — no files, no DirChanged state, no persisted last directory. Rollback is a plain revert of the
  `nvim/` changes.