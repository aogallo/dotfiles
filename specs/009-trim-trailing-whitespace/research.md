# Phase 0 Research: Trailing Whitespace Cleanup + Database Context Indicator

**Branch**: `009-trim-trailing-whitespace` | **Date**: 2026-09-25 | **Spec**: [spec.md](spec.md)

Every `NEEDS CLARIFICATION` item in the plan's Technical Context was resolved against the actual
source of the dependencies in this checkout. Each decision below records the evidence, so a later
session does not have to re-derive it.

## Evidence gathered before deciding

| Question | Where it was verified | Result |
| --- | --- | --- |
| How does the formatter chain pick formatters? | `conform.nvim/lua/conform/init.lua:345` `resolve_formatters` | Only *available* formatters are collected; `stop_after_first` breaks **after the first available** one, so a missing main formatter does not disable the rest of the chain. |
| What happens when nothing is available? | `conform.nvim/lua/conform/init.lua:535-553` | `log[warn/debug]` plus, when `notify_no_formatters` is set, a notification naming the filetype. |
| Is that notification repeated on later saves? | `conform.nvim/lua/conform/init.lua:381, 545, 550` | No. `has_notified_ft_no_formatters` is module-level, so the message fires once per filetype per session and is silent afterwards. |
| Which markdown chains exist? | `nvim/plugin/conform.lua:31-37` | Project signal: `{ 'prettier', lsp_format = 'fallback' }` — no whitespace step. No project signal: `{ 'markdown_prettier', 'trim_whitespace', 'trim_newlines', stop_after_first = true }`. |
| Where does the database name come from? | `nvim/lua/config/db_objects.lua:98-111, 132-141` | `url_database(url)` reads the URL path segment; `url_from_buffer(buf)` accepts `b:db` as string or `{ conn = … }` / `{ db_url = … }` table. |
| Where is the connection's database actually used? | `nvim/autoload/db/adapter/sybase.vim:77, 114` | `s:database()` reads the same URL path and `s:use_lines()` prepends `use <db>` to every call, so the URL path and the executing database agree by construction. |
| Is there a pre-execution hook to reuse? | `nvim/lua/config/db_results.lua:58-68` and `vim-dadbod/autoload/db.vim` (`doautocmd User {output}/DBExecutePre`) | Yes. The event fires immediately before the job starts, while the query buffer is still current. |
| Which filetype do query buffers use? | `nvim/lua/config/db_jump.lua:39`, dadbod buffer handling | Query and procedure-source buffers are `sql`; the explorer drawer and result buffers are `dbui`. |
| Is `require 'conform'` available in the offline smoke harness? | `nvim --headless -u NORC -c 'lua print(vim.o.runtimepath)'` | No. The plugin is only placed on the runtimepath by the repo's own `plugin/conform.lua` at boot, so offline tests must not depend on it. |

## Decision 1: Make both markdown chains capable of trimming

**Decision**: The project-signal branch returns
`{ 'prettier', 'trim_whitespace', 'trim_newlines', timeout_ms = 500, lsp_format = 'fallback', stop_after_first = true }`.

**Rationale**: It is the only change that makes FR-007 true for every Markdown document. Keeping
`stop_after_first = true` is essential: with it, the whitespace steps are the fallback and never
run alongside the main formatter, which is what preserves the two-space hard breaks (FR-004) in the
normal case.

**Alternatives considered**:
- *Custom hard-break-aware trim* — would satisfy FR-004 and FR-007 simultaneously, but adds a
  formatter and a Markdown-aware whitespace rule. Rejected: it reintroduces the second mechanism
  FR-009 forbids, in a more expensive form.
- *Leave the project branch untouched* — rejected: it is the defect US2 scenario 2 describes.

**Accepted trade-off** (must be stated in the plan and the README): when the main formatter is
unavailable, the fallback trims trailing whitespace bluntly and therefore flattens every hard break
in that document, including the meaningful mid-paragraph ones that the formatter itself would have
preserved. This is already the behavior of the no-project-signal chain today, so the change makes
the two chains consistent rather than introducing a new failure mode. It means FR-004 holds only
while the main formatter is available, and — per the second correction recorded in the spec's
investigation table — even then only for a break that is followed by more text in its paragraph.
That qualification is recorded as a spec note rather than silently implemented.

## Decision 2: Guarantee a visible message on every failing save

**Decision**: Set `notify_no_formatters = false` in `nvim/plugin/conform.lua` and add one
notification-only `BufWritePre` autocmd, in its own augroup, guarded by the same conditions as
`format_on_save` (skip when `vim.g.minifiles_active`, when `vim.g.skip_formatting` is set, and for
non-file buffers). It uses `require('conform').list_formatters_to_run(bufnr)` and notifies naming the
filetype when the returned formatter list is empty and no LSP formatter will run.

**Rationale**: It is the only way to satisfy the second half of FR-008, because conform's
one-per-session suppression is internal state with no option to reset it. Disabling conform's own
notification is what prevents a duplicate message on the first failure.

**Alternatives considered**:
- *Accept the once-per-session silence* — rejected: the spec requires the failure to keep being
  visible, and a persistent failure is exactly the case that matters.
- *Patch or vendor conform.nvim* — rejected: it breaks the lockfile, adds a maintenance surface,
  and violates the reproducibility gate.
- *Warn once per session ourselves* — rejected: it is the behavior we are trying to remove.

**No violation of FR-009**: the autocmd only reports. It performs no cleanup, so it cannot race the
formatting path.

## Decision 3: One module owns "which database is this buffer talking to"

**Decision**: Create `nvim/lua/config/db_context.lua` and move `url_database()` and
`url_from_buffer()` into it. `db_objects.lua` requires the new module and drops its local copies;
nothing else changes in that file. `db_context` adds the buffer-facing API (`database`, `switches`,
`label`, `conflict`, `setup`) on top of those two functions.

**Rationale**: FR-025 requires the status line and the query path to derive the name from one source.
Duplicating the URL parsing in the new module would create exactly the drift the requirement forbids.
Putting the new logic in `db_objects.lua` was rejected because that file is 601 lines of dialog,
picker and save-flow logic; a lualine component should not have to require it.

**Alternatives considered**:
- *A second module, `db_scope`, for the URL helpers* — rejected: one cohesive module is simpler than
  two that must be kept in sync, and there is only one consumer besides `db_objects`.
- *Read `b:db` ad hoc in the lualine component* — rejected: duplicated parsing, violates FR-025.

## Decision 4: Which buffers the component appears on

**Decision**: The component renders only for `filetype = sql` buffers. For those it shows the
connection database, a conflict mark, or a visible "no database" marker. Every other filetype
renders nothing.

**Rationale**: Satisfies the Q4 clarification ("every SQL buffer"), keeps the indicator off buffers
where a database is meaningless, and excludes the `dbui` filetype, which is both the explorer drawer
and the result buffer — FR-024.

**Alternatives considered**:
- *Render whenever `b:db` exists, whatever the filetype* — rejected: an object browser or any
  plugin buffer could set that variable and would then show a database label that does not apply.
- *Render on all filetypes with a "no database" marker* — rejected: a permanent status-line element
  on every window for a database-only concern.

## Decision 5: How context switches are detected in the buffer text

**Decision**: A hand-written line scanner in `db_context` that, for each line, removes the SQL
comment forms (`--` to end of line, and `/* … */` state carried across lines) and single-quoted
string literals, then matches `use <name>` and `<name>..<object>` on what is left. The reported
switch is the **last** `use` in the buffer when one exists, otherwise the first `db..object` name.
Names are read with a character class that allows `$` and `#`.

**Rationale**: It is deterministic, needs no parser, and is fully exercisable by an offline smoke
test with canned buffer text — which SC-007 and SC-008 require. Sequential execution makes the last
`use` the one that decides, which the spec states.

**Alternatives considered**:
- *Treesitter query for SQL* — more accurate on nested or unusual quoting, but it needs the SQL
  parser loaded, cannot run in the offline harness, and is a large amount of machinery for two
  patterns. Rejected for this scope.
- *Whole-buffer regex only* — rejected: it reports `use` and `db..object` inside comments and
  strings, which FR-023 forbids.

## Decision 6: One pre-execution listener, owned by the new module

**Decision**: `db_context.setup()` registers its own `User */DBExecutePre` callback (guarded by a
`setup_done` flag, matching `db_results.setup()`), and `nvim/plugin/database.lua` calls it next to
the existing `db_objects.setup()` and `db_results.setup()` calls. `db_results` is left untouched.

**Rationale**: FR-022 is satisfied — the existing event is reused and no new trigger is introduced —
while the modularity gate is respected: each module owns its own listener instead of one module
reaching into another's internals. The event fires once per execution, which is what "a single
message per execution" (SC-010) requires.

**Alternatives considered**:
- *Call the check from `db_results.on_pre()`* — rejected: it would make the result-summoning module
  depend on the indicator, and would be reached only if that module happened to load.
- *Hook the execution command directly* — rejected: that is a new trigger and duplicates
  knowledge dadbod already publishes as an event.

## Decision 7: What the component and the message say

**Decision**: The component label is the connection database alone in the clean case
(`DB ventas`), the connection database followed by the switch name when one is detected
(`DB ventas ⚠ base-a`), and a fixed marker when the buffer has no connection. The message at
execution time is a single warning naming the connection's database and the switch that was found.

**Rationale**: The connection database must stay visible next to the mark (FR-017), and the label is
short enough not to push the rest of the status line around.

**Security consequence**: neither the label nor the message may contain the connection URL, only the
database name. A URL can carry credentials; the status line is rendered in shared or recorded
sessions.

**Alternatives considered**:
- *Show the full URL* — rejected on the security gate.
- *Show the server host alongside the database* — rejected: explicitly out of scope in the spec.

## Decision 8: Where the chain selection lives, so it can be verified

**Decision**: Move `markdown_project_markers` and `markdown_formatters()` out of
`nvim/plugin/conform.lua` into a new `nvim/lua/config/formatter_chains.lua` exposing
`M.markdown(bufnr)`, and have `plugin/conform.lua` require it. The behavior is unchanged.

**Rationale**: `plugin/conform.lua` is only on the runtimepath after the repo's own plugin file runs,
which installs plugins, so `require 'conform'` fails in the offline harness (verified above). Its
chain-selection functions are locals, so no offline test can reach them. SC-003 requires verifying
the fallback for documents that a project configuration routes elsewhere, and that is impossible
while the logic is a local inside a file that cannot be loaded offline.

**Alternatives considered**:
- *Source `plugin/conform.lua` in the test with a stubbed plugin installer* — rejected: the functions
  are locals and would still be unreachable, and the test would depend on the file's boot-time
  side effects.
- *Assert the chains by reading the source file as text* — rejected: it would keep verifying the
  text of the file rather than the behavior, and would break on any harmless reformatting.

