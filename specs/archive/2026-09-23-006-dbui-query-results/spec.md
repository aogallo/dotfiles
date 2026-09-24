# Feature Specification: DBUI Query Result Reopen and Notification Routing

**Feature Branch**: `006-dbui-query-results`

**Created**: 2026-09-23

**Status**: Closed (archived 2026-09-23; see `verify-report.md`)

**Input**: User description: "si ejecuto otro query ya no veo el buffer de salida y no se como volverle a decir a dbui que muestre el buffer de salida" (clarificado: se mantiene el comportamiento actual del popup al cerrar buffers de codigo; el pedido es un atajo para convocar la ultima salida + llevarse las notificaciones de dadbod-ui a las notificaciones nativas de Neovim).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Summon the last query result (Priority: P1)

The developer ran a query, the result appeared in the output window, and then they navigated away or the output window was closed/hidden. When they want to see the result again, one key (`<leader>qr`, in the existing `database` keymap group) brings the last executed query result back into view from anywhere — even if the output preview window was closed, and even if the DB workspace lives in another tab. The key never changes how queries execute or how the result window behaves while visible.

**Why this priority**: This is the reported defect — after executing a query the developer can lose the output window and has no way to tell dadbod-ui to bring it back.

**Independent Test**: Can be fully tested by executing a query, navigating away from the result window (or closing it), pressing `<leader>qr`, and confirming the result reappears and takes focus; a second scenario with no prior query confirms a single clear notice and no side effects.

**Acceptance Scenarios**:

1. **Given** a query whose result window is open but not focused, **When** the developer presses `<leader>qr`, **Then** the result window is focused.
2. **Given** a query whose result window was closed, **When** the developer presses `<leader>qr`, **Then** the stored result file is reopened in an output window and shown.
3. **Given** a query that ran in a different tab, **When** the developer presses `<leader>qr`, **Then** the result window is focused regardless of which tab it lives in.
4. **Given** no query has run yet in the session, **When** the developer presses `<leader>qr`, **Then** exactly one clear informational notice appears and nothing else changes.
5. **Given** a query still running (output not finished), **When** the developer presses `<leader>qr`, **Then** the action is a no-op with a clear notice and no stale or empty result is opened.

---

### User Story 2 - dadbod-ui notifications through native Neovim notifications (Priority: P2)

While a query runs, dadbod-ui shows "Executing query..." and related floats at the bottom-left of the editor, which covers the query or code being worked on. After this feature, dadbod-ui execution notices (info, warning, error) are routed through the native Neovim notification system (already displayed by Snacks in this configuration), appearing in the notification area instead of overlaying the editor, so the query and code stay visible while the query is running.

**Why this priority**: The developer runs a query and continues reading code while it executes; the overlay currently hides the very content they need.

**Independent Test**: Can be fully tested by executing a query and confirming the "Executing query..." and completion notices appear in the native notification area (top-right) rather than as an overlay over the bottom-left of the editor; errors still surface with the same severity mapping.

**Acceptance Scenarios**:

1. **Given** a query starts with async execution, **When** the "Executing query..." notice fires, **Then** it appears as a native Neovim notification and the query/code area is not overlaid.
2. **Given** a query completes or fails, **When** dadbod-ui emits a completion or error notice, **Then** it appears as a native Neovim notification with the correct severity (info/error).
3. **Given** a headless or minimal session, **When** the config loads, **Then** the option is set without error and no new dependency is required.

---

### Edge Cases

- **No query executed yet in the session**: summoning shows exactly one info notice; no buffer, window, or file is created.
- **Result window closed (preview window gone)**: the buffer is wiped by dadbod (`bufhidden=delete`) but the output temp file persists on disk; summoning reopens that file.
- **Output file no longer exists on disk**: summoning surfaces one clear notice and shows nothing else (no empty/error buffer).
- **Query still running**: `DBExecutePost` has not fired, so nothing is recorded; summoning is a no-op with a notice and never waits or blocks.
- **Multiple queries in a row**: the last finished query wins (dadbod semantics); summoning always targets the latest result, never an older one.
- **Multiple tabs**: the result window may live in any tab; summoning prefers the current tab and otherwise finds the window across tabs.
- **DBUI drawer open**: summoning does not disturb the drawer or query buffers beyond focusing/creating the result window.
- **Repeated keypresses (idempotency)**: pressing `<leader>qr` repeatedly just refocuses/reopens the same result; no duplicate buffers or windows accumulate per session.
- **Info-notification noise**: existing `g:db_ui_disable_info_notifications` still silences the routine "Executing query..." info if the developer opts in.
- **Native dadbod status echo**: dadbod's own `DB: Query finished in …` echo on the native command line is not configurable in vim-dadbod and remains a documented limitation; the change removes the dadbod-ui floating overlay only.
- **Non-interactive / headless validation**: the new smoke test exercises record + summon with a temporary output file, with no live database required.
- **Rollback**: reverting the Neovim-module changes restores the previous overlay behavior; no buffers, files, or saved state are left behind.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After any query that reaches the finished state, the module MUST record the result (output file and its window, per dadbod's `User */DBExecutePost` autocmd) without altering dadbod execution behavior.
- **FR-002**: The developer MUST be able to summon the last recorded query result with a single keymap grouped under the existing `database` maps, from any tab and window.
- **FR-003**: When the result window is open but not focused, summoning MUST focus it (across tabs, preferring the current tab).
- **FR-004**: When the result window was closed, summoning MUST reopen the recorded output file so the result is visible again.
- **FR-005**: When no query has finished in the session, summoning MUST show exactly one clear informational notice and MUST NOT create buffers, windows, or files.
- **FR-006**: While a query is still running, summoning MUST be a safe no-op with a clear notice; it MUST NOT open an empty or stale result and MUST NOT block.
- **FR-007**: Only the latest finished query result is summoned (dadbod semantics); older results remain reachable through the existing DBUI drawer "Query results" list, which the change MUST NOT alter.
- **FR-008**: Re-opening a result from disk MUST handle a missing output file with exactly one clear notice instead of an empty or error buffer.
- **FR-009**: dadbod-ui notifications (info, warning, error, including "Executing query...") MUST be delivered through the native Neovim notification system (`vim.notify`), so they do not overlay the bottom-left editor area.
- **FR-010**: Notification routing MUST be enabled by configuration only (the upstream `g:db_ui_use_nvim_notify` option), with no new dependency and no change to dadbod/dadbod-ui source.
- **FR-011**: The existing `g:db_ui_disable_info_notifications` behavior MUST continue to work to silence routine info notices if the developer opts in.
- **FR-012**: The change MUST be scoped to the Neovim module; no other tool module may be required to install, update, or remove it (modularity).
- **FR-013**: The change MUST NOT introduce secrets, user-specific absolute paths, or machine assumptions; it MUST be portable Neovim Lua using the existing dadbod autocmds and APIs (portability, security).
- **FR-014**: Headless startup, `stylua --check nvim`, and the existing database smoke tests MUST pass; a new `db_results` smoke test MUST cover record + summon with a temporary output file (verification).
- **FR-015**: `nvim/README.md` MUST document the `<leader>qr` behavior, the notification routing, the native dadbod echo limitation, and rollback (documentation / module README).
- **FR-016**: Implementation MUST be developed on a feature branch with conventional commits and submitted through a pull request; the PR MUST verify whether the active specification (this one) should be closed (branch/PR workflow).

### Key Entities *(include if feature involves data)*

- **Last Query Result Record**: the single per-session slot that tracks the most recent finished query output — its output file path and, when present, the window showing it. It is updated on every dadbod `DBExecutePost` (latest wins) and consumed by the summon action.
- **Query Result Window**: the output window dadbod creates for a query result; the summon action either focuses it or recreates it from the recorded output file when it was closed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of summon scenarios (no prior query, running query, closed result window, open result window elsewhere, missing output file) produce the specified outcome with at most one clear notice when a notice applies.
- **SC-002**: After the change, 100% of executed queries whose notices fire show them through the native Neovim notification system; zero dadbod-ui floating overlays appear over the editor.
- **SC-003**: 100% of regression checks confirm unchanged query execution and result-window behavior (the change adds a summon path and notice routing only).
- **SC-004**: Validation gates pass on the first run after merge: headless nvim startup, `stylua --check nvim`, existing database smoke tests, and the new `db_results` smoke test.

## Assumptions

- "Re-show the output" means the LAST finished query's result, matching current dadbod semantics; historical results remain available through the existing DBUI drawer "Query results" list.
- dadbod's own `DB: Query finished in …` echo on the native command line is not configurable in vim-dadbod and stays as a documented limitation; the feature removes dadbod-ui's floating overlay only.
- The result window keeps dadbod's preview-window lifecycle (`nobuflisted`, `bufhidden=delete`); this feature summons/reopens it but does not change those semantics (the "persistent results" option was explicitly not chosen).
- Snacks notifier is the active `vim.notify` handler in this configuration (the repository's visible-notification provider), so routing dadbod-ui notices through `g:db_ui_use_nvim_notify` lands them in the native notification area.
- `g:db_ui_use_nvim_notify` is supported only on Neovim; the shared config targets Neovim only.
- The query progress float (transient "Execute query" indicator) stays as-is; disabling it later is a separate opt-in knob and out of scope here.
- The pending which-key `<leader>q` group registration in `nvim/plugin/editor.lua` is expected; the new `<leader>qr` map belongs to the same `database` group.