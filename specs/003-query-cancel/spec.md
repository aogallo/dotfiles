# Feature Specification: Query Cancel

**Feature Branch**: `003-query-cancel`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "quiero ver si el scrip actual se puede cancelar ya que tarda mucho y me gustaria cancelarlo. auqnque cierre la salida del query se cancela? ... estoy en un query que abri de dbui y quisiera en ese buffer cancelar la invocaccion que hizo" (clarificado: cancelar desde el buffer de entrada/resultados con `:DBCancel`, `<leader>qc` y `<C-c>`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cancel a running query from the buffer you are working in (Priority: P1)

The developer runs a heavy script from a database buffer (opened through dbui or `:DB`) that takes a long time. Today the only cancel path is the `<C-c>` mapped inside the results window, so from the input buffer there is no way to stop the invocation. After this feature, one action — a command `:DBCancel`, the keybinding `<leader>qc`, or `<C-c>` — stops the running query from any buffer in the same tab (input buffer, results window, or any other window), with clear feedback that the query was cancelled.

**Why this priority**: This is the reported defect — long-running queries cannot be interrupted from where the developer is (the dbui input buffer), leaving them waiting indefinitely.

**Independent Test**: Can be fully tested by launching a long-running query from a dbui buffer, then pressing `<leader>qc` from that same buffer while it runs, and confirming the result window closes/updates with a cancelled indication and the prompt is usable again.

**Acceptance Scenarios**:

1. **Given** a query is running from the current tab, **When** the developer runs `:DBCancel` or presses `<leader>qc`/`<C-c>` from the input buffer, **Then** the underlying query process stops and a clear "query cancelled" indication appears.
2. **Given** the same running query, **When** the developer issues the cancel action from any other buffer of the same tab, **Then** the same cancel behavior occurs (position in the window layout does not matter).
3. **Given** the results window is focused and a query is running, **When** the developer presses `<C-c>`, **Then** the query is cancelled exactly as today (the existing results-window behavior is preserved).
4. **Given** the tab's query already finished, **When** the developer issues the cancel action, **Then** nothing happens and control is returned without error.

---

### User Story 2 - Closing the query output window cancels the invocation (Priority: P1)

The developer asked whether closing the query output closes/cancels the query. Today it does not: the client keeps running in the background and the session ends with a "(no window?)" leftover. After this feature, removing or closing the results window of a query that is still running cancels that query, so the developer's mental model ("close the output = stop it") becomes true. Closing the window after the query has already finished keeps behaving like today.

**Why this priority**: This matches the developer's expectation expressed in the request ("aunque cierre la salida del query, se cancela?") and prevents orphan processes from continuing to run after the user thinks they stopped the work.

**Independent Test**: Can be fully tested by launching a long-running query and closing its results window while it runs, then confirming the underlying process stops and no "(no window?)" message appears.

**Acceptance Scenarios**:

1. **Given** a query is running and its results window is open, **When** the developer closes or wipes that window, **Then** the running query is cancelled and no background process survives.
2. **Given** the results window of an already-completed query, **When** the developer closes it, **Then** the query is not altered and no error is raised (current behavior preserved).
3. **Given** a cancelled-by-window-close query, **When** the developer checks the results state, **Then** it shows a cancelled indication, not a "finished" or "(no window?)" leftover.

---

### User Story 3 - Clean state after cancellation and safe no-op (Priority: P2)

Cancelling leaves the tab in a usable state: a cancelled query releases the "query already running" guard so the developer can re-run the same buffer (or `R`) immediately. If nothing is running, the cancel action is a safe no-op with a short notice, never an error. Cancelling one tab never affects queries in other tabs.

**Why this priority**: A cancel path that poisons the next run is worse than no cancel; this story guarantees the feature is safe to use repeatedly, per the repo's idempotent and non-destructive principles.

**Independent Test**: Can be fully tested by cancelling a running query and immediately re-running the same buffer, then issuing the cancel action with no query running in another tab.

**Acceptance Scenarios**:

1. **Given** a query was just cancelled, **When** the developer re-runs the same buffer or presses `R` on the results window, **Then** a new query starts immediately without an "already running" error.
2. **Given** no query is running in the current tab, **When** the developer issues the cancel action, **Then** a short no-op notice appears, no error is raised, and no state changes.
3. **Given** a query running in another tab, **When** the developer cancels in the current tab, **Then** only the current tab's query is affected and the other tab's query continues.

---

### Edge Cases

- **No query running**: cancel is a no-op with a clear notice; no error, no state change.
- **Query already finished**: closing the results window or cancelling does nothing harmful; existing behavior preserved.
- **Two queries in the same tab (bang mode `:DB!`)**: the cancel action applies to the most recent invocation of the tab; behavior documented, never ambiguous.
- **Cancel exactly as the query finishes**: a last-moment cancel is reported either as cancelled or finished, never as both; no crash, no leftover job.
- **Vim (Windows) vs Neovim (macOS) job APIs**: the stop mechanism must behave identically for the user on both platforms.
- **Missing client / failed job start**: cancel with nothing to stop is a safe no-op.
- **Rollback**: removing the documented keybinding, command, and autocmd restores the previous dadbod behaviors exactly (results-window `<C-c>`, no auto-cancel on close).
- **Out of scope (documented limitation)**: the synchronous object-source loading path used by `:DBObjects` blocks the editor and cannot be cancelled by this feature; converting it to a cancellable background flow is a separate follow-up, not part of this feature.
- **Repeated runs / partial failures / tab teardown**: cancelling and re-launching repeatedly must not accumulate stale jobs or duplicate results windows.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The developer MUST be able to cancel the running DB query of the current tab from any buffer in that tab (input buffer, results window, or any other window) with a single action.
- **FR-002**: A dedicated `:DBCancel` user command MUST be provided and MUST stop the current tab's running query or report a clear no-op when none is running.
- **FR-003**: The keybinding `<leader>qc` MUST cancel the query and MUST support the 60% keyboard constraint (lowercase-only after `<leader>`; `<leader>d` is reserved for other use).
- **FR-004**: `<C-c>` MUST cancel the query from both the results window (existing behavior preserved) and the dbui/input buffer, so cancel is identical wherever the developer is.
- **FR-005**: Closing or wiping the results window of a query that is still running MUST cancel that query; no background process MAY survive the window close.
- **FR-006**: Closing the results window of an already-finished query MUST behave exactly as today (no error, no side effects).
- **FR-007**: Status feedback MUST distinguish "query cancelled" from "query finished" and MUST NOT leave a misleading "(no window?)" or "finished" message on a cancelled query.
- **FR-008**: A cancelled query MUST release the tab's query guard so an immediate re-run (same buffer, `:DB`, or `R`) starts without an "already running" error.
- **FR-009**: Cancelling MUST affect only the current tab's most recent invocation; queries in other tabs MUST be unaffected.
- **FR-010**: The cancel behavior MUST be equivalent on macOS (Neovim job API) and Windows (Vim job API), reusing the platform's existing job-stop mechanics.
- **FR-011**: The feature MUST NOT alter the normal non-cancelled `:DB`/dbui flow, the results window layout or buffer options (readonly, bufhidden), or the reload (`R`) behavior.
- **FR-012**: The change MUST pass headless startup, lint/format checks, and the existing database smoke tests before completion.
- **FR-013**: The Neovim module README MUST document the cancel command and keybindings, the close-window cancellation behavior, platform parity, the "no query running" no-op, the out-of-scope synchronous object-source limitation, and rollback (removing the command, mapping, and autocmd).
- **FR-014**: The change MUST be scoped to the Neovim module; no other tool module may be required to install, update, or remove it.
- **FR-015**: Implementation MUST be developed on a feature branch with conventional commits and submitted through a pull request; the PR MUST verify whether the active specification (this one or a predecessor) is related and should be closed.
- **FR-016**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification and include a marker legend.

### Key Entities *(include if feature involves data)*

- **DB Query Invocation**: the running query backed by the editor's job mechanism; carries running/cancelled/finished state, belongs to one tab, and is linked to its results file and window.
- **Query Results Window**: the readonly output buffer for an invocation; closing it while the query runs triggers cancellation; closing it after completion is a no-op.
- **Tab Query State**: the tab-scoped handle to the most recent invocation; the cancel action uses it to stop the query from any buffer and to release the re-run guard.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A running query can be stopped from the input buffer, the results window, or any other buffer of the same tab in one action, and the developer always sees a clear cancelled indication.
- **SC-002**: Closing the results window of a running query cancels it in 100% of tested cases, and zero query processes survive the window close.
- **SC-003**: After cancellation, an immediate re-run of the same buffer starts without any "already running" error in 100% of tests (the tab is never left poisoned).
- **SC-004**: With no query running, the cancel action is a safe no-op noticed by the user — no error, no state change — in 100% of tested cases.
- **SC-005**: Cancelling in one tab never interrupts a query running in another tab in 100% of tests.
- **SC-006**: Headless startup, lint/format checks, and existing database smoke tests pass; the module README documents usage, platform parity, the close-window behavior, the out-of-scope limitation, and rollback.

## Assumptions

- Cancelling means stopping the query client process via the editor's job API (SIG interrupt/kill at the OS level); a server-side `KILL`/cancel is NOT performed and is out of scope.
- The cancel action targets the current tab's most recent invocation, matching how dadbod tracks the last preview buffer per tab.
- `<leader>qc` was explicitly chosen by the developer for the 60% keyboard (lowercase-only after `<leader>`; `<leader>d` reserved). `:DBCancel` and `<C-c>` are provided as equivalents.
- Closing the output window cancels only while the query is still running; post-completion behavior is unchanged.
- "From any buffer in the tab" includes the input buffer and results window; other tabs are independent.
- The synchronous object-source load used by `:DBObjects` cannot be cancelled by this feature; async conversion is a documented follow-up, not part of this feature.
- The feature reuses the database tooling's existing stop mechanism and does not introduce new dependencies or stored state.