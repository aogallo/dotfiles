# Feature Specification: Line Number and Active Buffer Emphasis

**Feature Branch**: `012-line-number-buffer-highlights`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "https://github.com/aogallo/dotfiles/issues/95 este es para modificar el color de los buffer activos en el bufferline"

> **Issue #95 (reported)**, in the developer's own words:
>
> 1. *"Los números relativos de la columna izquierda resalten un poco más. Quedo a veces moverme y no logro ver
>    bien los números."* — the relative numbers in the left column should stand out a bit more; while moving
>    through a file the numbers are sometimes hard to read.
> 2. *"Actualmente el número de la línea donde está el cursor está en otra columna tiene color naranja."* — the
>    number on the cursor's line sits in its own column and is orange today. Stated as the current situation, so
>    the baseline to preserve, not necessarily a complaint about the color itself.
> 3. *"Adicional en el buffer line también quiero que el buffer activo si nombre aparezca con un poco más de
>    tonalidad u otro color."* — additionally, the active buffer's name in the buffer row should appear with more
>    tone, or another color.
>
> The developer's one-line summary in the command singles out item 3. Both parts of the issue are specified here
> (see [Assumptions](#assumptions) → "Scope"); either one is independently shippable and independently valuable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The buffer I am editing is unmistakable (Priority: P1)

As a developer with a dozen files open, I want the tab of the buffer I am currently editing to be visibly stronger
than every other tab, so that I never have to read the names to work out which file I am in, and never edit the
wrong buffer by accident.

**Why this priority**: This is the half of the report the developer named first and the one with a direct cost
when it is missing — editing the wrong buffer. The buffer row is the developer's map of their own open work;
when the current position on that map is ambiguous, every glance costs a verification step.

**Independent Test**: Open eight or more buffers with visibly different names, move the cursor between them, and
confirm the active tab is identified without reading names. Delivers the full value of the report on its own; the
line-number work is a separate, separable improvement.

**Acceptance Scenarios**:

1. **Given** eight or more buffers open in a window, **When** the developer looks at the buffer row, **Then** the
   tab of the buffer being edited is the strongest-looking tab in the row, and they can say which one it is
   without reading the names.
2. **Given** the cursor is in a different buffer, **When** the developer moves to it, **Then** the emphasis moves
   with the buffer in the same visual update — no frame where two tabs look active, and no frame where none does.
3. **Given** a tab whose name is too long to show in full, **When** the tab is the active one, **Then** the visible
   part of its name carries the emphasis too.
4. **Given** a tab that has unsaved changes and/or reported problems, **When** that tab is active, **Then** its
   emphasis and its change/problem indicators are both still readable, and neither is recolored into the tab
   background.

---

### User Story 2 - I can read the numbers while I move (Priority: P1)

As a developer scrolling through a long file, I want the numbers in the left column — including the relative
ones — to be readable at a glance, so I can tell where I am and how far I have moved without stopping to focus
on the column.

**Why this priority**: This is the other half of the reported defect, and the reported symptom is exactly a
readability failure: *"a veces moverme y no logro ver bien los números."* Relative numbers are the element the
developer names, because they are the ones that fill the column and the ones that fade against the background.

**Independent Test**: Open a file of several hundred lines, scroll through it, and confirm every number in the
column is legible without effort, and that the cursor's own line is still identifiable among them. Delivers the
full value of this half of the report on its own.

**Acceptance Scenarios**:

1. **Given** a file open with relative numbering in effect, **When** the developer scrolls through it, **Then**
   every number in the left column is legible against the background without the developer adjusting anything.
2. **Given** the cursor sits on a line, **When** the developer looks at the number column, **Then** the number on
   the cursor's line is still the one that stands out among the column's numbers, in the same column position it
   occupies today.
3. **Given** the developer has moved down many lines, **When** they look at the column, **Then** the relative
   numbers read as one consistent group that is clearly present, not as near-invisible marks.
4. **Given** the developer switches between normal and insert mode, **When** the column is displayed in each,
   **Then** the numbers are equally legible, and the emphasis on the cursor's line does not disappear or change
   meaning.

---

### User Story 3 - The emphasis holds everywhere and never costs me readability (Priority: P2)

As a developer who splits windows, works in several tabs and runs tools that print output into the editor, I
want the new emphasis to hold in all of those places, and I want it not to have been achieved by making anything
else harder to read.

**Why this priority**: Emphasis that only works in the simplest layout will not survive real use, and emphasis
that was bought by dimming the surrounding interface is a net loss. This story is what makes the change safe to
adopt rather than merely noticeable.

**Independent Test**: Repeat the User Story 1 and User Story 2 checks across multiple windows, multiple tabs,
several editor modes, and a few files of different types — including tool-generated output — and confirm the
behavior is identical everywhere and that the previously readable elements are unchanged.

**Acceptance Scenarios**:

1. **Given** two or more windows open, **When** the developer changes which window has focus, **Then** the
   strongest emphasis follows the focused window's buffer, and a buffer that is selected in another window is
   still distinguishable from an ordinary inactive tab without being mistaken for the focused one.
2. **Given** the developer restarts the editor, **When** the first buffer row is drawn, **Then** the emphasis is
   already present — no setting to turn on and no manual step.
3. **Given** the developer changes the editor's color scheme at runtime, **When** it takes effect, **Then** the
   emphasis and the number-column behavior are still in place.
4. **Given** content with colored syntax, comments, warnings and tool output, **When** the emphasis is active,
   **Then** those elements look exactly as they did before this change.
5. **Given** a terminal that does not advertise full color support, **When** the editor starts, **Then** it starts
   normally and the emphasis degrades to whatever the terminal can show rather than producing an error or an
   unreadable result.

---

### User Story 4 - I can see where these colors come from and change them (Priority: P3)

As the person who maintains this configuration, I want the editor's module documentation to state what decides the
number column's and the buffer row's appearance, where to change it, and how to check the result, so that the
next adjustment is a one-line change instead of a search.

**Why this priority**: This repository is meant to outlive any single complaint. The constitution requires module
documentation to change in the same change that alters user-facing configuration, and this is exactly that kind
of change. Lowest priority because it delivers no visible improvement by itself.

**Independent Test**: Read the module documentation and make a color change using only what it says, then confirm
the documented validation commands report success.

**Acceptance Scenarios**:

1. **Given** a reader with the module documentation open, **When** they want a different tone for the active
   buffer name, **Then** the documentation names the place to change, the effect of changing it, and the command
   that verifies the result.
2. **Given** the developer has just applied the change, **When** they follow the documented validation commands,
   **Then** each command either passes or reports a problem they can act on.

---

### Edge Cases

- **Only one buffer is open.** The buffer row may not be drawn at all; there is nothing to emphasize and nothing
  may appear to be missing.
- **The active buffer has no name yet** (a new, unsaved file). Its tab still gets the emphasis, and its label is
  whatever the editor shows for an unnamed buffer.
- **Very long buffer names** are truncated in the row. The emphasis applies to what is visible, not to a portion
  that is not drawn.
- **A buffer that is active in two windows at once.** Both windows' tabs are selected; the focused window's is
  the strongest. This must not collapse into "two tabs look equally active with no way to tell which window".
- **The active tab also carries a modified marker, a problem indicator, or both.** Emphasis and marker must coexist
  and remain individually readable.
- **A window wider than the row, with more tabs than fit.** Truncated tabs and the overflow indicator keep their
  current appearance.
- **A colorscheme switch at runtime**, including switching away and back. Emphasis set up only at startup would be
  silently discarded; that case is covered explicitly (FR-021).
- **Folds, long wrapped lines, and the left column's own width.** The number column's width and alignment, and the
  position of the cursor-line number, are unchanged (FR-013).
- **Tool-generated output buffers** (query results and similar) are displayed like any other buffer. This change
  adds no per-buffer color exceptions, so an exception for generated output would be a deliberate decision, not an
  accident.
- **Terminals without full color support.** Colors fall back to what the terminal can display; nothing errors.
- **A terminal using a light background**, if the editor ever runs there. The appearance is derived from the
  active color scheme's own background rather than assuming a dark one.

## Requirements *(mandatory)*

### Functional Requirements

**The active buffer's tab (User Story 1)**

- **FR-001**: In the window that has focus, the tab of the buffer currently being edited MUST be visually
  distinguishable from every other tab in the row in **at least two independent visual ways** — for example text
  tone, background, or text weight — so that the active tab remains identifiable by someone who cannot distinguish
  the relevant colors.
- **FR-002**: The active tab's name MUST have the highest contrast against its own background of any name in the
  row; no inactive tab's name may reach or exceed it.
- **FR-003**: The emphasis MUST be carried by the tab's **name**, as reported, and MUST NOT depend solely on a
  background change that leaves the name itself the same tone as every other name.
- **FR-004**: Inactive tab names MUST remain legible: each MUST be distinguishable from the row background at or
  above the legibility threshold this specification sets, and this change MUST NOT push any of them below it.
- **FR-005**: Moving the cursor to another buffer MUST move the emphasis to that buffer's tab in the same visual
  update that changes the displayed content. There MUST NOT be an intermediate frame in which two tabs carry the
  full emphasis, nor one in which none does.
- **FR-006**: With two or more windows open, the full emphasis MUST belong to the focused window's buffer. A tab
  that is selected in a **non-focused** window MUST remain distinguishable from an ordinary inactive tab and MUST
  NOT look identical to the focused window's active tab.
- **FR-007**: The change MUST be limited to appearance. It MUST NOT alter which buffers appear in the row, their
  order, their names, their change markers, their problem indicators, the close icon, or the row's own
  show/hide behavior.
- **FR-008**: A tab's close icon and problem indicators MUST remain legible on the active tab; emphasis MUST NOT
  recolor them until they are indistinguishable from the tab background.

**The number column (User Story 2)**

- **FR-009**: Every number drawn in the left-hand number column MUST be legible against the editor background,
  including the relative numbers, without the developer adjusting anything.
- **FR-010**: The number column MUST present three distinguishable levels of emphasis, ordered from strongest to
  weakest: the number on the cursor's line, then the relative numbers, then the background. The relative numbers
  MUST be clearly present rather than near-invisible, and MUST remain weaker than the cursor's own line number so
  the cursor's position stays findable.
- **FR-011**: The numbers MUST satisfy the legibility thresholds this specification sets: the cursor's line number
  at or above the stricter threshold, every other number in the column at or above the looser one, measured
  against the editor background actually in use.
- **FR-012**: The numbers MUST remain legible in every editor mode in which the column is displayed — normal,
  insert, visual, and command-line mode — and the cursor's line number MUST NOT change meaning between modes.
- **FR-013**: This change MUST NOT alter the number column's width, its alignment, the position of the cursor-line
  number within it, or whether relative numbering is used at all. Those stay exactly as they are today.
- **FR-014**: The number-column appearance MUST apply uniformly across every buffer the developer edits. No buffer
  type may be silently excluded; any exclusion MUST be a stated decision.
- **FR-015**: The change MUST NOT alter the color scheme's other decisions — syntax highlighting, comments,
  pickers, indent guides, statusline sections, or anything else already customized.

**Durability (User Story 3)**

- **FR-016**: The new appearance MUST be in effect on the first buffer row and number column the editor draws
  after a normal start, with no setting to enable, no keymap to press, and no manual step.
- **FR-017**: The appearance MUST remain in effect after the developer changes the editor's color scheme at
  runtime, and after switching away and back. An appearance that survives only until the first colorscheme change
  does not satisfy this requirement.
- **FR-018**: The change MUST NOT add a plugin, an external tool, or any other dependency.
- **FR-019**: The change MUST be confined to the editor module. No other module of this repository — terminal
  emulator, terminal multiplexer, shell, keyboard, installer — may be altered by it, and applying it MUST NOT
  require any of them.
- **FR-020**: The change MUST be delivered through this repository's shared configuration and MUST NOT require the
  developer to edit any file outside the repository to get the result.
- **FR-021**: The appearance MUST be expressed in a way that survives a colorscheme reload, and the change MUST
  document the mechanism so a future maintainer can tell an intentional override from an accidental one.
- **FR-022**: Where the editor is started in a terminal that cannot show the full palette, the change MUST degrade
  to what that terminal supports and MUST NOT produce an error, a failed start, or an unreadable result.

**Documentation, validation and workflow (User Stories 3 and 4)**

- **FR-023**: The editor module's documentation MUST be updated in the same change, covering what decides the
  number column's and the buffer row's appearance, where to change it, the effect of changing it, the documented
  validation commands, and that rollback is an ordinary repository revert.
- **FR-024**: The change MUST contain no user-specific absolute paths and MUST behave the same on Apple Silicon
  and on Intel.
- **FR-025**: No credential, token, private key, personal identifier, or real local secret may appear anywhere in
  the change.
- **FR-026**: The change MUST pass the editor module's existing validation — formatting checks, a headless start,
  and every existing smoke test — with 0 failures.
- **FR-027**: New automated coverage MUST assert the properties this specification defines: that the active tab
  and the cursor's line number are each the strongest in their row or column, and that no inactive element falls
  below the legibility threshold. Coverage MUST fail if a later change removes the emphasis.
- **FR-028**: Implementation MUST be developed on a feature branch, committed with conventional commit messages,
  and submitted through a pull request. Before the pull request is created, the active specification MUST be
  checked against the change's scope, and the developer MUST be asked whether this specification should be closed
  as the completed solution for issue #95.
- **FR-029**: The generated task list MUST remain navigable: a visible legend of its markers, and a link from each
  user-story phase to the matching heading in this specification.

### Out of Scope

- **Changing the number column's layout or behavior.** Its width, the cursor-line number's separate column
  position, and the use of relative numbering are all preserved (FR-013). The report describes the cursor-line
  number's position and color as the current situation, not as a request to move it.
- **Changing the cursor-line number's color for its own sake.** It is orange today and stays legible; the report
  asks for the *other* numbers to catch up, not for this one to move.
- **A runtime toggle or keymap for the emphasis.** The appearance is the configuration's standing default, not a
  mode (FR-016).
- **Choosing a new color scheme, adding a second one, or changing the editor's overall palette.** The change is
  limited to the number column and the buffer row within the scheme already in use (FR-015).
- **Buffer-row features that were not requested**: grouping, sorting modes, per-directory tabs, pinning, tab
  numbering, and similar.
- **Any change to buffer visibility rules.** Which buffers have a tab is governed by
  `specs/011-query-buffer-tab-visibility/` and is unaffected — FR-007 only prevents this change from altering it.
- **Any other module of this repository** (FR-019).
- **Typography, spacing, or icon changes** in either the number column or the buffer row.

### Key Entities

- **Buffer tab**: one buffer's representation in the buffer row, carrying a name and a state (active, selected in
  another window, or inactive).
- **Tab emphasis**: the visual treatment that marks the active buffer's tab. This feature changes only this, never
  the set of tabs.
- **Number column**: the left-hand column of line numbers. Its three states — cursor-line number, relative number,
  and empty background — are the subject of User Story 2.
- **Legibility threshold**: the minimum contrast between a piece of text and its background that this
  specification considers readable. Applied to every number in the column and to every tab name in the row.
- **Appearance source**: the single documented place in the shared configuration that decides these colors, so the
  emphasis is a stated decision rather than an incidental one (FR-021, FR-023).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 20 trials with 8 or more buffers open, a developer identifies the active tab correctly on first
  glance in 20 of 20 trials, without reading the tab names.
- **SC-002**: The active tab's name measures a contrast ratio against its own background of at least 4.5:1, and at
  least 1.5× the contrast ratio of the least-contrasted inactive tab name in the same row, in 20 of 20 measured
  windows.
- **SC-003**: 0 inactive tab names measure a contrast ratio below 3:1 against the row background in any measured
  row, including rows containing unsaved-change markers and problem indicators.
- **SC-004**: 0 relative line numbers measure a contrast ratio below 3:1 against the editor background, measured
  across at least 3 files of different types and at least 20 scroll positions per file.
- **SC-005**: The cursor's line number measures a contrast ratio of at least 4.5:1 against the editor background,
  and remains identifiable among the column's other numbers in 20 of 20 trials.
- **SC-006**: In 20 cursor moves between buffers, 0 frames show two tabs carrying the full emphasis and 0 frames
  show none.
- **SC-007**: In 10 window-focus changes, the full emphasis follows the focused window's buffer in 10 of 10 cases,
  and in 10 of 10 a tab selected in a non-focused window remains distinguishable from an ordinary inactive tab.
- **SC-008**: 0 changes to the set of tabs, their order, their names, their change markers, or their problem
  indicators, verified by comparing the row before and after this change for the same session.
- **SC-009**: 0 changes to syntax highlighting, comments, pickers, indent guides, or statusline sections, verified
  by comparison against the appearance before this change.
- **SC-010**: The emphasis is present on the first buffer row drawn after a normal start in 10 of 10 restarts,
  with no manual step.
- **SC-011**: The emphasis remains present after a runtime color scheme change, and after switching away and back,
  in 10 of 10 trials.
- **SC-012**: The editor module's existing validation and smoke tests continue to pass, and the new coverage for
  the emphasis and the legibility thresholds passes, with 0 failures.
- **SC-013**: 0 discrepancies between the module documentation's claims about the number column and the buffer row
  and the observed behavior, found by reviewing each claim.
- **SC-014**: 0 new dependencies and 0 user-specific absolute paths introduced by the change.

## Assumptions

- **Scope: both halves of issue #95 are in scope** — the active buffer name's emphasis in the buffer row, and the
  legibility of the numbers in the left column. The developer's one-line summary named only the buffer row, but
  the issue's first paragraph asks for the numbers explicitly, so both are specified. Each is a separate user story
  and either can ship alone; dropping one is a decision to make at review, not an omission hidden here.
- **"More tone, or another color" means the active name should read stronger**, not that the inactive names should
  be dimmed to make room. Dimming the rest of the row is not an acceptable way to achieve the emphasis
  (FR-004 sets a floor the inactive names must stay above).
- **The orange cursor-line number is the baseline to keep.** The issue states it as the current situation, and it
  is the one number that already works; the complaint is that the other numbers do not match it.
- **The three-number-column states must stay in this order**: cursor line strongest, relative numbers next. The
  developer's reason for wanting the relative numbers to stand out is to judge distance while moving, which only
  works if the cursor's own line stays the strongest.
- **Emphasis must not rely on hue alone.** Where two visual channels are named in the report ("more tone, or
  another color"), either satisfies it, but a single hue-only difference is not enough on its own for a developer
  who cannot distinguish the relevant colors.
- **Appearance applies to every buffer, with no generated-output exception.** Excluding tool output would need a
  stated reason; nothing in the report asks for it.
- **Contrast thresholds are the shared yardstick for every legibility claim in this specification.** They are
  stated as measurable ratios in [Success Criteria](#success-criteria) rather than as subjective adjectives, so
  that "readable" has one meaning across both stories.
- **Rollback is an ordinary repository revert.** This change alters configuration values only — it creates,
  moves, overwrites or backs up no user file — so no restoration machinery is required beyond the repository
  history.
- **No dependency is needed.** The editor's own color configuration is sufficient to express both requirements
  (FR-018).
- **Existing correct behavior is preserved**: window navigation, close-icon behavior, buffer ordering, buffer
  visibility rules from `specs/011-query-buffer-tab-visibility/`, and the object-listing behavior from
  `specs/010-dbobjects-listing-integrity/` are unaffected and covered by their existing tests.

## Clarifications

### Defaults chosen during specification — 2026-10-01

No blocking question remained, because every open point had a default the repository itself or the issue already
established. The defaults are recorded here so they can be overridden at review rather than discovered later.

- **Q1 (scope — the buffer row only, as the summary said, or both halves of issue #95?)** — *Answer*: both. The
  issue's first paragraph asks for the numbers explicitly, and each half is independently valuable and
  independently shippable. **Rationale**: omitting the numbers would silently drop half of the linked issue.
  *Alternative rejected*: buffer row only, which would leave the reported number-readability complaint unaddressed.
- **Q2 (how to make the active name stronger — brighten the active name, or dim the others?)** — *Answer*:
  strengthen the active name; do not dim the inactive ones. **Rationale**: the developer asked for the active name
  to carry more tone; dimming everything else trades one readability problem for another. Recorded as FR-002 and
  FR-004. *Alternative rejected*: reducing the inactive names' contrast to make the active one look stronger by
  contrast.
- **Q3 (should the orange cursor-line number change too?)** — *Answer*: no, keep it as the strongest number in the
  column. **Rationale**: the issue states the orange number as the current situation, and it is the one number the
  developer can already read; the complaint is that the other numbers do not match it. Recorded as FR-010 and in
  [Out of Scope](#out-of-scope).
- **Q4 (should the change add a toggle so the emphasis can be turned off?)** — *Answer*: no. **Rationale**: no
  request asked for one, and a toggle for a standing appearance default is an extra surface nobody has asked for.
  Recorded as FR-016 and in [Out of Scope](#out-of-scope).