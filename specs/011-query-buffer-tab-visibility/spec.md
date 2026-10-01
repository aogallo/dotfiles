# Feature Specification: Query Buffer Always Shows Its Tab

**Feature Branch**: `011-query-buffer-tab-visibility`

**Created**: 2026-09-30

**Status**: Draft

**Input**: User description: "quiero que resuelvas este issue https://github.com/aogallo/dotfiles/issues/96. basicamente lo que pasa es de que al cerrar todos los buffer a excepcion de uno y tengo un buffer de query abierto de los que no estan guardados todavia y doy <leader>j y selecciono el buffer por alguna razon no sale su tab de arriba. si le doy guardar en el tab de arriba se ve que sale un nombre pero se oculta"

> **Issue #96 (reported)**: The first time a query buffer is opened, its tab appears in the buffer
> row. Then the developer closes every buffer except one unrelated buffer (code or markdown);
> the closing works correctly. Reopening the same query, the tab does **not** appear — the buffer
> is in front of the user but has no tab. If the developer saves it, a name becomes visible but
> the tab stays hidden.
>
> **Root-cause class established during investigation** (traced to concrete code in
> [research.md](research.md); summarized here so the requirements below are traceable to a
> cause):
>
> 1. The buffer row shows only buffers that are still *registered in the editor's buffer list*.
>    Closing a buffer — by any close action, including "delete other buffers" and the per-tab
>    close icon — removes it from that list. This is why the tab row looked correct right after
>    every close: each buffer disappeared from the row exactly as the developer intended.
> 2. Returning to a buffer does not put it back into that list. Some routes into a buffer repair
>    the registration as a side effect and some do not, which is precisely the "for some reason"
>    in the report: the same reopen sometimes shows a tab and sometimes does not, depending on
>    the route and on whether the buffer's content survived the close.
> 3. A closed buffer that still exists but is no longer registered is also filtered out of the
>    buffer pickers by default. So the developer's only route back to it — the picker — is the
>    route most likely to leave it without a tab.
> 4. The query buffer is created with an explicit "hide when not displayed" marker. That marker
>    is what makes the picker label the entry as hidden, which is the second half of the report:
>    the developer sees a name and a hidden marker and concludes the buffer is broken. It also
>    means the buffer's language and its database binding can be unloaded from memory while the
>    buffer sits hidden.
> 5. The query buffer's name is a bare file name with no directory and the file does not exist
>    until it is saved. Because saving is the only thing that ever makes the name mean something,
>    it becomes the obvious thing to try — which is why "save it" is what the developer reached
>    for, and why saving still did not produce a tab.
> 6. The buffer row's own documentation claims the row auto-hides when only one buffer is open.
>    The current configuration cannot do that, so the documented contract and the real contract
>    disagree in the same area this issue is about.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A query buffer I come back to always has its tab (Priority: P1)

As a developer working with database queries in Neovim, I open a query, close everything else,
and come back to that query later — and its tab is there, exactly as it was the first time. I do
not have to save it, reopen it a second way, or work out why it disappeared. Any buffer I
deliberately opened has a tab whenever it is in front of me, no matter which route brought it
back.

**Why this priority**: This is the reported defect and nothing else matters until it is fixed.
The developer is left editing a query in a window that the interface does not acknowledge: no
tab, no close icon, nothing to return to. Worse, the buffer row is the developer's map of their
own work, so a buffer that vanishes from it is a buffer they can lose track of. The report even
contains the evidence that the buffer is alive — saving it produces a name — which proves the
failure is in the tab row's registration logic, not in the buffer.

**Independent Test**: Open a query, close every buffer except one, bring the query back, and
assert a tab exists. Repeat with each of the ways a buffer can be brought back — the buffer
picker, an explicit buffer-number jump, next/previous buffer cycling, clicking a remembered
entry, and a jump from a result — and assert a tab in every case. No other part of the
configuration needs to be inspected to verify this.

**Acceptance Scenarios**:

1. **Given** a freshly opened query buffer showing its tab, **When** the developer closes every buffer except one unrelated buffer, **Then** the query buffer is no longer displayed and the remaining buffer is unchanged.
2. **Given** the state above, **When** the developer brings the query buffer back, **Then** the query buffer has a tab in the buffer row and that tab shows its name.
3. **Given** the state above, **When** the developer brings the query buffer back by any other supported route, **Then** the result is identical: one tab, same name, no extra steps.
4. **Given** a query buffer with unsaved edits, **When** the developer brings it back after closing everything else, **Then** the tab is present **before** the developer saves anything.
5. **Given** a query buffer whose content was discarded by a force-close, **When** the developer opens that same query again, **Then** it has a tab, and the buffer is distinguishable from the discarded one.
6. **Given** a query buffer in front of the developer, **When** the developer looks at the buffer row, **Then** exactly one tab corresponds to that buffer — never zero and never two.

---

### User Story 2 - I can tell what each tab is, and nothing looks broken (Priority: P1)

As a developer, the tab for my query shows the query's name, and the buffer picker entry for that
query does not carry a marker that makes it look absent, mislaid, or unloadable while I am
looking straight at it. If something about a buffer is genuinely worth telling me about, the
interface tells me in words rather than with a cryptic flag.

**Why this priority**: The report has two halves, and the second half — "a name shows up but it is
hidden" — is what converts a cosmetic omission into a mystery. The developer saw a name and a
hidden marker on a buffer they were editing, which reads as corruption. A label that marks a
live, displayed buffer as hidden is worse than no label at all: it actively misinforms. P1
alongside User Story 1 because both halves of the reported symptom are delivered by the same
underlying confusion, and fixing only the tab leaves the second half reported again.

**Independent Test**: Open a query, close everything else, bring it back, and inspect both the
buffer row and the buffer picker. Assert the tab and the picker entry agree on the name, and
assert no entry is marked hidden, missing, or otherwise absent for a buffer that is currently
displayed. Repeat for a query the developer has edited but not saved and for one that has been
saved.

**Acceptance Scenarios**:

1. **Given** a displayed query buffer, **When** the developer inspects its buffer-picker entry, **Then** the entry shows the same name as its tab and carries no "hidden" or "absent" marker.
2. **Given** a query buffer that is displayed, **When** the developer saves it, **Then** the tab and the picker entry are unchanged in name and marker; saving adds nothing that was missing before.
3. **Given** a query buffer and a saved file buffer, **When** the developer compares their buffer-picker entries, **Then** both are presented the same way — neither is marked absent.
4. **Given** any buffer the editor reports as genuinely unloadable, **When** it appears in the picker, **Then** it is distinguishable from a live buffer and the developer is not left to interpret a bare marker.

---

### User Story 3 - A query buffer that comes back still works (Priority: P2)

As a developer, when I come back to a query buffer I can keep working in it: it still knows it is
a query, it still knows which database it belongs to, and the database commands keep working
against that database. My unsaved edits are either still there or were discarded by a close I
asked for — never quietly rewritten or restored to an older state.

**Why this priority**: Showing the tab back is not enough if the buffer behind it has lost the
state that makes it usable. The query buffer's value is that it is bound to a specific database,
so a reload that drops that binding produces a query that runs against the wrong place or fails
in a way that looks like a database problem. Unsaved-edit integrity is called out separately
because the report begins with an unsaved buffer. P2 because User Story 1 already removes the
reported symptom; this removes the follow-on confusion that follows it.

**Independent Test**: Open a query, edit it without saving, close everything else, bring it back,
and assert the edits are intact, the buffer still behaves as a query, and its database binding
still points at the same database. Repeat the cycle five times. Separately, confirm that a
force-close still discards unsaved content rather than silently writing it anywhere.

**Acceptance Scenarios**:

1. **Given** an edited, unsaved query buffer, **When** the developer closes everything else and brings the buffer back, **Then** every edit is present exactly as it was left.
2. **Given** a query buffer bound to a database, **When** the developer brings it back after a close/reopen cycle, **Then** database commands issued in that buffer act on the same database as before.
3. **Given** a query buffer brought back after several close/reopen cycles, **When** the developer inspects it, **Then** it is still recognized as a query — same language, same editing behavior.
4. **Given** a query buffer with unsaved edits that the developer force-closes, **When** the close completes, **Then** the buffer is closed exactly as it is today — no tab, no entry in the buffer list, no file created, no prompt — and the text stays retrievable for the rest of the session, so reopening it shows the edits again. *(Amended by A-001.)*

---

### User Story 4 - Tool output stays out of my way (Priority: P2)

As a developer, the read-only output the database tooling generates — query results, result
tables — keeps its current treatment: it does not occupy a tab in my buffer row and does not
push my own work around. The fix for "my query has no tab" must not turn every result into a tab.

**Why this priority**: The defect was fixed in this repository's own query buffers, and the
tempting way to fix it is to make everything visible. That would bury the developer in result
tabs every time they query, which is the opposite of what they asked for. Protecting the
existing, intentional distinction between "my query" and "tool output" is what keeps this fix
from becoming a new annoyance. P2 because it is a regression guard on the fix rather than part
of the reported symptom.

**Independent Test**: Run a query and confirm the result output still takes no tab and does not
appear in the developer's buffer list. Then confirm the User Story 1 cycle still works for the
query buffer in the same session. Repeat for a result that is scrolled, closed, and regenerated.

**Acceptance Scenarios**:

1. **Given** a query is executed, **When** the result output appears, **Then** it takes no tab in the buffer row, exactly as today.
2. **Given** result output is present, **When** the developer inspects the buffer row, **Then** the row contains the developer's own buffers and no generated output.
3. **Given** a query with both a query buffer and result output, **When** the developer closes all but one buffer, **Then** only the developer's own buffers are affected and the output behaves as today.

---

### User Story 5 - What I closed stays closed, and the docs stop lying (Priority: P3)

As a developer, closing buffers behaves exactly as it does today: buffers I closed stay closed,
nothing resurfaces without me asking for it, and closing one buffer does not close or reopen
another. And the documentation for this area describes the behavior I actually get, so I do not
chase a description of an auto-hiding tab row that never hides.

**Why this priority**: "The buffers close correctly" is the part of the report that already
works, and it is the part a fix like this can quietly break — a repair that re-registers buffers
too eagerly can resurrect closed work. Keeping the close semantics frozen is what makes the fix
safe to ship. The documentation correction rides along because it is in the same area and is
already known to be wrong. P3 because nothing here is broken for the developer today; it is the
guard rail that keeps User Story 1 from being "fixed" at the expense of everything else.

**Independent Test**: Close buffers by each close route available — delete other buffers, the
per-tab close icon, an explicit buffer-number close, and window-local close — and assert after
each that no closed buffer reappears without user action and that no unrelated buffer was
affected. Separately, compare the documented buffer-row behavior against what actually happens
with one buffer and with two.

**Acceptance Scenarios**:

1. **Given** several open buffers, **When** the developer closes one of them by any close route, **Then** only that buffer is affected and no other buffer appears or disappears.
2. **Given** a buffer the developer closed, **When** the developer continues working without asking for it back, **Then** it stays closed.
3. **Given** a buffer the developer closed and then explicitly reopens, **When** it is reopened, **Then** it appears in the buffer row and the buffer picker, and is clearly distinguishable from a buffer that was never closed.
4. **Given** the buffer-row documentation, **When** a reader checks each claim against actual behavior, **Then** 0 claims are contradicted, including the claim about the row hiding itself when one buffer is open.

### Edge Cases

- Reopening the same buffer through every available route: the buffer picker, an explicit
  buffer-number jump, next/previous cycling, clicking a remembered entry, and a jump from a result
  or quickfix list. All of them must produce the same outcome.
- Reopening a buffer whose content was already discarded by a force-close — the reopen creates a
  new buffer; it must be distinguishable from the old one and must still get a tab.
- Two or more query buffers closed and reopened in the same session, including two whose display
  names could collide (same object in two databases).
- A query buffer that is never displayed after being created, then displayed much later.
- A query buffer opened while another query buffer is already open and displayed.
- A query buffer that the developer renames before saving, and one renamed after saving.
- A query buffer whose database connection has since been closed or re-pointed — the buffer must
  not display a binding to a connection that no longer exists, and must not be silently rebound.
- A saved query buffer that the developer later deletes from disk and then brings back.
- A modified query buffer at the moment the developer closes everything else — the report's exact
  starting state.
- Withholding unsaved changes (`:bd` without `!`) on a modified buffer: the close is refused and
  the buffer keeps its tab, exactly as today.
- Force-closing with unsaved changes: the content is discarded as today, and this feature must not
  change that into a write or into a confirmation prompt.
- Read-only generated output must remain tab-less in every case above (User Story 4).
- A buffer with no name at all, and a buffer whose name is a bare file name with no directory —
  both must still get a tab.
- Starting Neovim with several files on the command line, then applying the full close/reopen cycle.
- Applying the close/reopen cycle repeatedly — 10 or more times in one session — with no
  degradation in tab count, buffer names, or picker entries.
- The buffer row's single-buffer vs multi-buffer visibility must keep its current behavior; this
  feature does not redesign it.

## Requirements *(mandatory)*

### Functional Requirements

**Tab presence (User Story 1)**

- **FR-001**: Any buffer the developer deliberately opened MUST have a tab in the buffer row
  whenever it is displayed, no matter how many times it has been closed and brought back.
- **FR-002**: Returning a buffer to the foreground — by any supported route: the buffer picker, an
  explicit buffer-number jump, next/previous cycling, a click on a remembered entry, or a jump
  from another buffer or list — MUST result in that buffer having a tab. The outcome MUST NOT
  depend on which route was used.
- **FR-003**: A query buffer MUST have its tab **before** it is saved. Saving MUST NOT be a
  precondition for, or a remedy for, a missing tab.
- **FR-004**: A displayed buffer MUST have exactly one tab — never zero and never a duplicate.
- **FR-005**: Opening a query for the first time and bringing the same query back MUST produce the
  same buffer-row state, including the same tab name and the same set of tabs.
- **FR-006**: A query buffer reopened after its content was discarded MUST be distinguishable from
  the discarded one and MUST have a tab.
- **FR-007**: The requirement MUST hold regardless of how many unrelated buffers were open or
  closed in between, including the case where exactly one buffer remained open throughout.

**Identification and honest labelling (User Story 2)**

- **FR-008**: A tab and the corresponding buffer-picker entry for the same buffer MUST show the
  same name.
- **FR-009**: A buffer that is currently displayed MUST NOT be labelled as hidden, absent,
  unloaded, or otherwise unavailable in the buffer picker.
- **FR-010**: Saving a query buffer MUST NOT change its tab name, its picker entry name, or its
  picker marker compared to its unsaved state, other than the effect of the new file location.
- **FR-011**: Where the interface does need to distinguish a buffer's state, it MUST do so with a
  marker that is defined in the module documentation, rather than relying on the developer
  interpreting a bare flag.
- **FR-012**: A query buffer's name MUST be informative enough to tell two open query buffers
  apart, including two queries of the same object name from different databases, and including a
  buffer the developer has not yet saved.

**The buffer keeps its identity and content (User Story 3)**

- **FR-013**: A query buffer that has been closed and brought back MUST retain its content
  exactly, including every unsaved edit.
- **FR-014**: A query buffer that has been closed and brought back MUST retain the state that
  makes it usable as a query — its language and its database binding — so database commands
  issued in it act on the same database as before.
- **FR-015**: The behavior MUST hold across repeated close/reopen cycles within one session, not
  only for the first cycle.
- **FR-016**: When a query buffer's database connection has been closed or re-pointed since the
  buffer was created, the buffer MUST NOT silently bind to a different connection or database, and
  MUST make the situation apparent rather than acting as though the original binding were intact.
- **FR-017**: Force-closing a modified buffer MUST NOT write its unsaved content anywhere, MUST NOT
  create a file, and MUST NOT introduce a confirmation prompt. It MUST leave the buffer closed — out
  of the buffer list, without a tab — and it MUST NOT restore the buffer, its tab or its listing on
  its own. Within the same session the text MAY remain retrievable in memory, so that a later
  **explicit** developer action (any reopen route) shows the query again with its unsaved edits, as
  FR-013 requires. This feature MUST NOT change close semantics.
  *(Amended by A-001 — see [Clarifications](#clarifications), approved 2026-09-30.)*

**Generated output stays out of the row (User Story 4)**

- **FR-018**: Read-only output generated by the database tooling — query results and result
  tables — MUST continue to take no tab in the buffer row and MUST NOT be added to the developer's
  buffer list by this change.
- **FR-019**: The distinction MUST be by intent, not by accident: buffers the developer opened get
  tabs, generated output does not, and both remain true simultaneously in one session.
- **FR-020**: Closing the developer's buffers MUST NOT change how generated output is treated.

**Close semantics and documentation (User Story 5)**

- **FR-021**: Closing a buffer MUST NOT cause any other buffer to appear, disappear, or change
  name.
- **FR-022**: A closed buffer MUST stay closed until the developer explicitly brings it back.
- **FR-023**: The buffer row's visibility behavior with one buffer versus several buffers MUST
  remain as it is today; this feature MUST NOT introduce or remove a tab row that appears or
  disappears based on buffer count.
- **FR-024**: The Neovim module `README.md` MUST be corrected where it describes the buffer row's
  behavior, including the claim that the row hides itself when only one buffer is open, so the
  documented contract matches the implemented contract.

**Repository obligations (constitution)**

- **FR-025**: The change MUST contain no user-specific absolute paths and MUST behave the same on
  Apple Silicon and Intel (constitution I).
- **FR-026**: The change MUST be confined to the Neovim module and MUST NOT require unrelated
  tools or modules to be present, changed, or updated (constitution IV).
- **FR-027**: The change MUST NOT introduce a new dependency; where an existing capability needs a
  configuration flag or a hook, it MUST be declared in the change and documented (constitution VI).
- **FR-028**: No credential, token, private key, or real local secret may appear in the change or
  in its documentation (constitution VII).
- **FR-029**: The change MUST pass the existing Neovim smoke tests, MUST add coverage for the
  close/reopen cycle, for every reopen route, for a modified unsaved query buffer, and for the
  generated-output exclusion, and MUST NOT be marked complete with a failing check (constitution
  VIII).
- **FR-030**: The Neovim module `README.md` MUST be updated in the same change, covering the buffer
  row's behavior, the buffer-picker markers, and the troubleshooting entry for "my query buffer
  has no tab" (constitutions XII, XIV).
- **FR-031**: Implementation MUST be developed on a feature branch, committed with conventional
  commit messages, and submitted through a pull request that links this issue; before the pull
  request is created, this specification MUST be checked for scope fit and the contributor MUST be
  asked whether it should be closed as the completed solution (constitution XIII).
- **FR-032**: Spec artifacts MUST remain navigable by relative Markdown links, and every
  user-story task phase MUST link back to the matching heading in this specification
  (constitution XV).

### Out of Scope

- **Redesigning when the buffer row itself appears or disappears.** The row's show/hide behavior
  stays as it is; FR-023 only prevents this change from altering it, and FR-024 corrects the
  documentation. Issue #96 is about a *buffer's tab* being absent, not about the row being absent.
- **Adding tab features to generated query output.** Result buffers stay tab-less on purpose
  (FR-018). This is the deliberate line between "my query" and "tool output".
- **Buffer grouping, sorting modes, per-directory tabs, pinning, and other buffer-row display
  features.** None were requested and none bear on the defect.
- **Changing force-close semantics for unsaved buffers.** A force-close still discards the buffer from
  the session — no prompt, no write, nothing rescued, FR-017 freezes that. The single thing this
  feature adds is that the text stays retrievable **in memory for the rest of the session** if the
  developer later reopens the buffer explicitly (A-001). Making force-close prompt, or persisting
  drafts across sessions, is a separate and larger change to a destructive operation and stays out of
  scope.
- **New keymaps.** The reported `<leader>j` does not match any mapping in this repository; the
  buffer picker is reached through the existing `<leader>b` domain. The requirements are written
  route-independently (FR-002) precisely so that adding a mapping is not required to fix this.
- **Restoring closed buffers as a feature** (a session-restore or buffer-persistence capability).
  FR-022 requires closed buffers to stay closed; bringing one back is an explicit developer
  action, as it is today.
- **The `:DBObjects` listing, scope, and save-flow behavior** governed by
  `specs/010-dbobjects-listing-integrity/`. This feature MUST NOT regress those tests; it changes
  no catalog, scope, or server behavior.

### Key Entities

- **User-opened buffer**: a buffer the developer deliberately created, opened, or brought back —
  a query buffer or an ordinary file. Every user-opened buffer that is displayed has a tab. This
  is the population the defect affects.
- **Generated output buffer**: read-only result content the tooling produces on execution. It is
  not a user-opened buffer and takes no tab. The two populations are separated by intent, not by
  convenience.
- **Tab entry**: one buffer's representation in the buffer row, carrying a name. The invariant is
  one displayed user-opened buffer to exactly one tab.
- **Reopen route**: how a buffer returns to the foreground — picker, buffer-number jump, cycling,
  click, or jump from another list. All routes MUST produce the same buffer-row outcome; the
  route must not be observable in the result.
- **Buffer label**: the name shown for a buffer in the tab and in the picker. The tab and the
  picker MUST agree, and no displayed buffer may carry a marker that presents it as unavailable.
- **Registration state**: whether a buffer currently counts as part of the developer's buffer
  list. It is the attribute the defect turns off, and it MUST NOT be the thing that decides
  whether a displayed user-opened buffer has a tab.
- **Database binding**: the connection and database a query buffer acts against. It MUST survive
  a close/reopen cycle and MUST NOT be silently re-pointed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across a test pass that repeats the close-all-but-one then reopen cycle through
  every supported reopen route, 100% of reopened user-opened buffers have a tab.
- **SC-002**: 0 user-opened buffers are displayed without a tab, measured across at least 20
  close/reopen cycles in one session.
- **SC-003**: 0 duplicates: in every measured state, each displayed user-opened buffer has exactly
  one tab.
- **SC-004**: 0 cases where the tab name and the buffer-picker name for the same buffer disagree.
- **SC-005**: 0 displayed buffers carry a hidden, absent, or unloadable marker in the buffer
  picker.
- **SC-006**: 0 unsaved edits lost across 20 close/reopen cycles of a modified query buffer within a
  single session (retrievable in memory per FR-017 as amended by A-001; nothing is written to disk).
- **SC-007**: In 20 consecutive measurements, a query buffer's database binding after a
  close/reopen cycle is identical to its binding before the cycle — 0 unintended rebindings.
- **SC-008**: 0 generated-output buffers gain a tab; the count of tabs in the buffer row is
  identical before and after this change for any session that runs queries.
- **SC-009**: In 20 close-and-continue trials, 0 closed buffers resurface without an explicit
  developer action, and 0 unrelated buffers are affected by a close.
- **SC-010**: A developer never needs to save a query buffer to see its tab: in 20 consecutive
  trials of the reported sequence, the tab is present at every point where saving would have been
  the next action.
- **SC-011**: Opening a query and bringing it back takes the same number of interactions as the
  first open — at most 2 beyond opening the picker — on 10 consecutive attempts.
- **SC-012**: Every pre-existing Neovim smoke test continues to pass, and the new coverage for the
  close/reopen cycle, each reopen route, unsaved modified buffers, and generated-output exclusion
  passes, with 0 failures.
- **SC-013**: 0 discrepancies between the module `README.md` claims about the buffer row and
  actual behavior, found by review of each claim.

## Assumptions

- **"Close every buffer except one" is the `delete other buffers` action, and it behaves
  correctly today.** The report says so explicitly, and FR-021/FR-022 exist to keep it that way
  rather than to change it.
- **The reported key `<leader>j` does not exist in this repository.** The buffer picker is reached
  through `<leader>bb`; other close and navigation keys sit under `<leader>b`. Because the exact
  key the developer pressed could not be confirmed, FR-002 is written to hold for every reopen
  route rather than for one mapping — which is also the more durable fix.
- **The bug is in buffer registration, not in the tab row's visibility.** The row is present
  throughout (the report's own evidence: saving produces a visible name). So the requirement is
  that a displayed user-opened buffer has a tab, not that the row appears.
- **A buffer that is deliberately opened and then closed is expected to lose its tab.** That is
  the close action working. The defect is only that bringing it back does not restore the tab.
- **Unsaved query content being discarded by an explicit force-close is acceptable to the
  developer**, who chose the force-close. This feature freezes that behavior (FR-017) rather than
  changing a destructive operation.
- **The database connection binding of a query buffer matters and must survive.** The query buffer
  is valuable because it is bound to a specific database; a reload that drops that binding would
  trade a visible defect for a quieter one.
- **Generated query output is deliberately excluded from the buffer row** — that is why it is set
  up the way it is today, and it is treated as a constraint to protect, not a related defect.
- Both kinds of query buffer in use are covered: the repository's own database-object query
  buffers and the database UI plugin's query buffers. The requirements are expressed in terms of
  "a query buffer the developer opened", so neither is singled out.
- No new dependency is introduced and no keymap is added; existing capabilities are configured or
  extended as needed (FR-027).
- Existing behavior that is correct today — window navigation, close-icon behavior, buffer
  ordering, and the `:DBObjects` features from
  `specs/010-dbobjects-listing-integrity/` — is preserved unchanged and covered by regression
  tests.

## Clarifications

### Defaults chosen during specification — 2026-09-30

No blocking question remained after investigation, because every open point had a default that
the repository itself already established. The defaults are recorded here so they can be
overridden at review rather than discovered later.

- **Q1 (scope of the fix — query buffers only, or any buffer the developer opened?)** — *Answer*:
  any buffer the developer deliberately opened. **Rationale**: the defect is a general registration
  problem; restricting the fix to query buffers would leave the same bug reachable through a
  different file type, and the existing close actions are content-agnostic. *Alternative
  rejected*: a query-buffer-only patch, which is smaller but leaves the underlying bug intact.
- **Q2 (should generated query output also get a tab?)** — *Answer*: no. **Rationale**: it is
  unlisted by design and adding tabs for results would bury the developer in output tabs, which is
  the opposite of the request. Recorded as FR-018 and User Story 4 so the fix cannot regress it.
- **Q3 (should force-closing an unsaved query buffer prompt or preserve the content?)** —
  *Answer*: no change to close semantics. **Rationale**: it changes a destructive operation's
  semantics, which is a separate feature with its own risk review; the developer chose the
  force-close and reported only the missing tab. Recorded as Out of Scope and frozen by FR-017.

### Amendment A-001 — 2026-09-30 (approved by the developer)

**Question raised during planning**: FR-013/US3-1/SC-006 (a query buffer that has been closed and
brought back MUST retain its content, including every unsaved edit) and FR-017/US3-4 as originally
worded (force-close MUST continue to discard its unsaved content) cannot both hold, because
`:bdelete` unloads the buffer and the text is gone at close time — measured in
[research.md](research.md) R-0007. No implementation can satisfy the pair as written.

**Decision**: FR-017 and US3-4 are reworded, and SC-006 is scoped to a session. A force-close MUST
NOT write the content anywhere, MUST NOT create a file, MUST NOT prompt, MUST leave the buffer closed
and unlisted, and MUST NOT restore anything by itself — but the text MAY remain retrievable in memory
for the rest of the session so that an **explicit** developer reopen shows the query again, per
FR-013.

**Rationale given by the developer**: approved 2026-09-30 after being shown both outcomes —
reopening an edited query returns the text, versus reopening it returns an empty buffer with the
right name. The user's decision with a force-close is "get it out of my way now, without putting my
text on disk", and both clauses stay true under the amendment. The rejected alternative was to
narrow FR-013 to saved content only, which ships the empty-buffer regression knowingly.

**Effect on the spec**: FR-017, US3-4, SC-006 and the "Out of Scope" entry are amended and marked;
FR-013 is unchanged. [plan.md](plan.md) records the same amendment with its status, and
[data-model.md](data-model.md) §3 invariant 2 and [contracts/query-buffer-visibility.md](contracts/query-buffer-visibility.md) §2.2 already implement the amended reading.