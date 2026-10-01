# Specification Quality Checklist: Query Buffer Always Shows Its Tab

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-30
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

### Iteration 1 — 2026-09-30 (all items pass)

No spec revision was required. Validation notes, for the reviewer:

1. **Root-cause block kept implementation-free.** The reported defect is a buffer-registration
   problem, so the summary above the user scenarios names the *effect* ("a buffer that is in front
   of the user but has no tab", "the buffer row filters it out") rather than the mechanism. A
   search of the spec for plugin names, option names, buffer flags, file paths under `nvim/`, or
   language-level constructs returns 0 hits, so the spec does not pre-commit the plan to a fix.
2. **"Route-independent" requirement replaces the unmappable key.** The report cites `<leader>j`,
   which is not mapped anywhere in this repository (the buffer picker is under `<leader>b`). Rather
   than guess, FR-002 requires the outcome for *every* reopen route, which is both testable and
   durable. Recorded in Assumptions so a reviewer can override it if a specific mapping was meant.
3. **Regression guard made explicit.** The obvious over-correction is to make generated query
   output visible too. User Story 4 and FR-018 exist to keep that from happening, and SC-008
   measures it.
4. **Close semantics frozen rather than changed.** Force-close currently discards unsaved content.
   FR-017 and the Out of Scope list record that this feature MUST NOT alter that destructive
   behavior, so the fix cannot smuggle in a semantic change to a delete operation.
5. **Success criteria are counts, not adjectives.** Each of SC-001 to SC-013 is expressed as a
   number of occurrences (0 discrepancies, 20 cycles, 100% of routes), verifiable without knowing
   how the fix is implemented.
6. **Known documentation defect captured.** The module `README.md` claims the buffer row
   auto-hides with a single buffer, which the current configuration does not do. FR-024 and
   SC-013 require the correction in the same change, since it is in the area this issue is about.

### Open items for planning (not blocking)

- `research.md` is referenced by the spec's root-cause block and is produced by `/speckit.plan`.
  The block is written so the spec stands on its own if planning is deferred.
- Manual verification with the developer should confirm which key actually opens the buffer
  picker on their machine, so the quickstart reproduces the report exactly. The automated
  coverage does not depend on the answer.

### Post-approval note — 2026-09-30

- **Amendment A-001 applied.** The Phase 0 investigation found that FR-013 (content must survive a
  close/reopen cycle) and FR-017 (force-close must discard unsaved content) were mutually
  unsatisfiable, because `:bdelete` unloads the buffer. The developer approved the rewording; FR-017,
  US3-4, SC-006 and the "Out of Scope" entry now state the amended contract and are marked as such,
  and a dated entry in `spec.md` §Clarifications records the decision and its rationale.
- The contradiction was **not** caught by this checklist's items as originally written: both
  clauses are individually unambiguous and testable. For future specs, a requirements pair that
  describes the *same* behavior from two angles deserves an explicit cross-check during planning.
  Recorded here so the next reviewer knows it was considered and resolved, not overlooked.