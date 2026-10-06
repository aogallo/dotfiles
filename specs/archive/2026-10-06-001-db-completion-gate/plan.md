# Implementation Plan: Database Completion Never Blocks Editing

**Branch**: `013-db-completion-gate` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/archive/2026-10-06-001-db-completion-gate/spec.md`

## Summary

Schema completion inside SQL buffers currently reaches the database on **every keystroke**, and
because the upstream cache's per-buffer record is only written *after* the connection attempt, a
failed or hanging connection never satisfies the retry guard — so every keystroke restarts a
blocking client spawn and raises an error, which freezes the editor and stops the developer from
running their query.

The fix is a gate, not a timeout. A new repository-owned module,
`nvim/lua/config/db_completion.lua`, decides whether the database completion source is allowed to
run at all, and it decides from module-local state alone: closed until a connection has been
positively established, open only for connections that are known usable, and permanently closed
for connections known to be unusable until the developer asks for a fresh attempt. The gate is
wired through the completion engine's own supported per-provider `enabled` function, so the
provider itself stays configured exactly as it is today and only its enabled state changes. The
establishment of usability is a single deliberate pre-warm of the upstream cache, invoked by the
repository at a non-typing moment (buffer open, refresh command, or a query the developer chose to
run), never from suggestion generation.

## Technical Context

**Language/Version**: Lua (LuaJIT) / Neovim 0.12+; Vimscript for the existing Sybase adapter.
No new language.

**Primary Dependencies**: `saghen/blink.cmp` v2 (completion engine),
`kristijanhusak/vim-dadbod-completion` (schema source, unmodified), `tpope/vim-dadbod`,
`folke/which-key.nvim` (keymap label). All already installed; **no new dependency** (FR-028).

**Storage**: None. All state is in-memory and per session — no file is written, nothing persists
across restarts (FR-011, FR-021).

**Testing**: Offline Neovim smoke tests in the repository's established style —
`nvim --headless -u NORC -c 'lua require("tests.<name>_smoke")' -c 'qa!'`, with the database client
stubbed at `db#systemlist` exactly as `sybase_objects_smoke.lua` already does. No server, no real
client binary (FR-031).

**Target Platform**: macOS (Apple Silicon and Intel) primary; Windows supported where practical.
The gate is client-agnostic and must hold for both `sqsh` (macOS) and `isql` (Windows) (FR-026).

**Project Type**: Editor configuration module inside a portable dotfiles repository.

**Performance Goals**: The suggestion path performs **zero** client invocations and **zero**
network round trips (SC-001, SC-002, SC-011). This is a hard requirement, not a target: the gate
is evaluated from a table lookup and the guarded code path is unreachable.

**Constraints**: The gate function is invoked from fast-event contexts and receives no arguments
(D-0002), so it MUST NOT call any Vim API. Provider behavior on a healthy connection MUST remain
byte-identical (SC-010), so the upstream provider module, its options and its trigger characters
MUST NOT be altered.

**Scale/Scope**: One new module, one provider option change, one keymap, one command, one test
file. ~6 behavior groups across 35 FRs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | How this plan satisfies it |
|---|---|
| **Portability** | The gate is pure Lua table state; no paths, no platform branching. The client selection stays inside the existing adapter, which already handles `sqsh`/`isql` per platform. FR-026. |
| **Idempotency** | Re-sourcing `plugin/database.lua` re-registers the gate and command behind an existing `setup_done`-style guard, matching `db_context.setup()` (`nvim/lua/config/db_context.lua:349`). Toggling twice returns to the starting state. No accumulated side effects. |
| **Non-destructive safety** | The module only ever decides *whether a source runs*. It never edits buffer text, filetype, or `b:db`, and never writes to disk (FR-020, FR-033). |
| **Modularity** | Confined to the Neovim module. No other module is touched, and nothing outside Neovim is required to be installed (FR-027). |
| **Source of truth** | One new repository file under `nvim/lua/config/`, beside its siblings `db_context.lua`, `db_objects.lua`, `db_results.lua`. No generated files, no local overrides, no secrets (FR-029). |
| **Dependencies** | No new dependency (FR-028). Three already-declared plugins are used through documented configuration surfaces; each is cited with file and line in [research.md](research.md). |
| **Security** | Every human-facing string is built from `db_context.url_database(url)` — a database name — never the URL, which can carry credentials. This mirrors the existing rule in `db_context.lua:278-281` (FR-029). |
| **Verification** | Three new offline smoke tests (`db_completion_smoke`, `db_completion_gate_healthy_smoke`, `db_completion_toggle_smoke`) plus every existing suite: `sybase_adapter_smoke`, `sybase_objects_smoke`, `db_context_smoke`, `db_objects_scope_smoke`, `db_objects_save_smoke`, `db_connections_smoke`, `db_results_smoke`, `db_jump_smoke`, `buffer_visibility_smoke`, `keymap_groups_smoke`, `formatter_chains_smoke`, `markdown_whitespace_smoke`, `no_formatter_warning_smoke`, plus `stylua --check nvim` and `nvim --headless -u nvim/init.lua '+quitall'` (FR-030). |
| **Installer UX** | Not applicable: this change adds no installer step, no generated output and no new command surface beyond one editor command whose failure modes are reported as notices. |
| **Recovery** | The switch returns to its documented starting state on restart (FR-011). The unusable-per-connection ledger is session-only, so a bad connection cannot persist a broken state across restarts. No file is written, so there is nothing to restore or unlink. |
| **Maintainability** | The simplest mechanism that satisfies FR-001: a boolean gate plus a four-value state machine, reusing the engine's existing `enabled` hook and the plugin's existing public pre-warm function. No fork, no wrapper provider, no duplicate query path. See [research.md](research.md) D-0001 and D-0003 for the rejected alternatives. |
| **Documentation** | `nvim/README.md` updated in the same change: the switch and its key, the starting state, automatic disabling, the recovery actions, and a troubleshooting entry for "the editor freezes when I type SQL" (FR-032). |
| **Module README** | `nvim/README.md` is the module README and is covered above. It already documents completion at the "Database Client" section, which is where the corrections land. |
| **Spec navigation** | `tasks.md` (next command) will carry a marker legend and link each user-story phase to its `spec.md` heading (FR-035). |
| **Branch/PR discipline** | Work is on `013-db-completion-gate`, created from `main` at `5f108f7`. Commits will use conventional messages. Before the PR: verify this spec's scope fit and ask the developer whether it should be closed as the completed solution (FR-034). |

**Post-design re-evaluation**: unchanged. The Phase 1 design added no dependency, no path, and no
new write path, so every gate verdict above holds. One gate gained detail: Verification now also
covers the "no connection during suggestion generation" invariant with an instrumented
`db#systemlist` stub that counts invocations, which is what proves SC-002 and SC-011
([quickstart.md](quickstart.md) §3).

**Complexity Tracking**: no violations, no exceptions.

## Project Structure

### Documentation (this feature)

```text
specs/archive/2026-10-06-001-db-completion-gate/
├── plan.md                       # This file
├── spec.md                       # /speckit.specify output
├── research.md                   # Phase 0 — mechanism evidence and decisions
├── data-model.md                 # Phase 1 — connection state machine and entities
├── contracts/
│   └── db-completion-gate.md     # Phase 1 — the gate's observable contract
├── quickstart.md                 # Phase 1 — runnable validation
├── checklists/
│   └── requirements.md           # /speckit.specify quality checklist
└── tasks.md                      # /speckit.tasks — NOT created by /speckit.plan
```

### Source Code (repository root)

Only the Neovim module is touched. `nvim/lua/config/` is flat today, so the new module goes beside
its siblings.

```text
nvim/
├── plugin/
│   ├── blink.lua                 # MODIFIED — provider gains the `enabled` gate option
│   └── database.lua              # MODIFIED — calls db_completion.setup(); declares the commands
├── lua/
│   ├── config/
│   │   ├── db_completion.lua     # NEW — the whole feature
│   │   ├── db_context.lua        # READ ONLY — reused for url_database (label safety)
│   │   ├── keymaps.lua           # MODIFIED — one `<leader>qc` binding
│   │   └── db_results.lua        # READ ONLY — reference for the User-event pattern
│   └── tests/
│       ├── db_completion_smoke.lua              # NEW — gate truth table + zero invocations
│       ├── db_completion_gate_healthy_smoke.lua # NEW — SC-010 equivalence vs the bare provider
│       └── db_completion_toggle_smoke.lua       # NEW — toggle, refresh, recovery, label
├── autoload/db/adapter/sybase.vim # UNCHANGED — the client boundary stays where it is
└── README.md                     # MODIFIED — switch, starting state, troubleshooting
```

**Structure Decision**: keep the flat `nvim/lua/config/` layout — one new module file, no package
directory, because the existing database modules are siblings and the feature is one concern.
`setup()` and the two commands are declared from `plugin/database.lua` rather than from the module
itself, matching how `db_context`, `db_objects` and `db_results` are wired in this configuration,
and giving the `:DBCompletion*` commands the same load-time presence as `:DBObjects` and
`:DBQuery`. `db_completion.lua` is the only new source file; everything else is a small edit to two
existing files plus the README.

## Verification Surface

The invariant this feature must make true is *the suggestion path performs zero client
invocations*. It is verifiable without a server because the existing tests already replace
`db#systemlist` with a stub — the same seam every Sybase adapter call goes through. The new test
counts stub invocations across a simulated typing burst, which is the direct measurement behind
SC-002 and SC-011.

The second invariant — that a healthy connection still behaves exactly as before — is verified by
running the same buffer through the gated and the ungated provider and comparing suggestion lists,
rather than by comparing against a recorded snapshot, so the assertion cannot drift out of date with
the plugin. See [quickstart.md](quickstart.md) §1–§3.

## Risks

| Risk | Mitigation |
|---|---|
| The gate must not change behavior on a healthy connection (SC-010). | The upstream provider module and its options stay byte-identical; only the documented `enabled` provider option is added. Verified: `enabled` is a declared field of the provider config (`provider/config.lua:6`) read before any module behavior. |
| The pre-warm re-enables a connection on a query that then fails (FR-019). | The warm's own `db#connect` is the determination. A dead connection throws there, so it stays unusable and the query reports the database's own error separately. |
| A buffer-open pre-warm blocks on a dead server. | Not a regression: today the *first keystroke* in such a buffer blocks identically. It moves the cost from per-keystroke to once per buffer open. Recorded as a known limit in [research.md](research.md) D-0004 with the async alternative. |
| Closing the gate while the warm is pending could let a keystroke through. | FR-016's `undetermined` state is distinct from `usable`, and the gate is closed in both non-usable states, so `pending` is closed by construction rather than by timing. |