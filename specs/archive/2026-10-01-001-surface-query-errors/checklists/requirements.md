# Specification Quality Checklist: Query Errors Are Always Surfaced

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-01
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

### Validation — 2026-10-01 (all items pass, iteration 1)

No spec revision was required. The validation was run against the checklist above; validation
notes for the reviewer:

1. **Root-cause block is implementation-free.** The reported defect and the failures found while
   tracing it are stated as *effects* — "nothing in the query path classifies what the server
   said", "one self-check crashes on ordinary SQL, and the crash blocks execution" — not as
   mechanisms. A search of the spec for module names, file paths under `nvim/`, function names,
   line numbers, client names, or flag names returns 0 hits. Both root causes were measured and
   reproduced during investigation; the spec records *that* they are real and *what* the user
   experiences, and leaves *where* they live to planning, so the plan is not pre-committed to
   the fix it should choose.
2. **The crash is stated as a user-visible guarantee, not a code fix.** FR-008 through FR-011
   require that the editor's checks complete and that a valid query runs, in terms of "the
   status line renders", "a query the server accepts is executed", "no internal error". A
   reviewer can verify each of these without knowing which routine is at fault.
3. **The silent variant is captured alongside the crash.** Root cause 5 is the same defect
   miscounting where it does not crash, and it makes the cross-database warning stop firing.
   It is given its own user story (US4) because its user-visible outcome is different — no
   message at all rather than a wrong one — and because it is the more dangerous of the two: a
   crash is noticed on the first run, a warning that silently stops working is not noticed until
   the query has already run against the wrong data. The existing smoke suite does not catch it,
   since every test line it uses happens to have no trailing comment or literal.
4. **No invented diagnoses is separated from the reported defect.** US3 is P2 rather than P1
   because it was not reported and is reached through database selection rather than query
   execution. It is in scope because the fix for "report the failure" would otherwise install a
   message that lies. FR-015 and FR-017 draw the line precisely: "could not determine" is a
   distinct outcome from "determined false", and FR-018 keeps the genuine finding working so the
   requirement cannot be satisfied by suppressing all database messages.
5. **Preservation of the server's full response is explicit.** The tempting implementation of
   "show me the error" is to filter the response down to the complaint. FR-005, FR-014, FR-025
   and FR-026 forbid that, and SC-008 measures it byte-for-byte. Q2 in Clarifications records
   the decision and the rejected alternative.
6. **Success criteria are counts, not adjectives.** Every one of SC-001 to SC-015 is a number
   (0 occurrences, 100% of routes, 20 lines per shape, 200-line corpus, 10 consecutive runs),
   verifiable without knowing how the fix is implemented. SC-005 and SC-007 in particular are
   written as shape-set sizes because the defect is positional — it depends on where the
   comment or literal sits on the line, not only on whether one is present.
7. **The false-positive direction is protected.** FR-007 and SC-004 exist so that "report every
   complaint" cannot be satisfied by treating an empty result set as a complaint. This is the
   most likely over-correction and it is measured.
8. **Three defaults recorded, no blockers.** Q1 (fold the false diagnosis into scope), Q2 (do
   not trim the server's response), Q3 (do not gate execution on an uninterpretable buffer)
   each had a repository-established default, so no clarification was asked. Q3 is the one worth
   a reviewer's attention: blocking execution when the editor cannot parse a buffer would turn a
   cosmetic defect into a hard block and reproduce the reported symptom in a new form.

### Cross-check performed (per the lesson recorded in spec 011's checklist)

Requirement pairs describing the same behavior from two angles were checked for mutual
satisfiability:

- FR-010 (a query the server accepts is executed) vs FR-008/FR-009 (checks complete for any
  text) vs FR-003 (successful runs keep today's presentation) — consistent. Satisfying the
  "report failures" requirement cannot make a successful run report a failure, because FR-003
  and FR-007 are separately stated and measured by SC-003 and SC-004.
- FR-019/FR-020 (the cross-database warning still fires) vs FR-023 (no warning when the switch
  names the connection's own database) — consistent; the forms in FR-020 vary only unrelated
  text on the line, not the declared database.
- FR-015/FR-017 (no invented diagnoses) vs FR-018 (genuine findings preserved) — consistent and
  jointly satisfiable only if "could not determine" is a distinct outcome, which FR-017 states
  and Q1's rationale explains.

No unsatisfiable pair was found. Contrast with spec 011's FR-013/FR-017 contradiction, which
this checklist's original items did not catch; the cross-check above is the mitigation.

### Open items for planning (not blocking)

- The measured reproduction of the crash and the discarded-diagnostic paths belong in
  `research.md`, produced by `/speckit.plan`. The spec's root-cause block stands on its own, so
  the spec does not depend on planning having happened.
- The exact notice mechanism is a planning decision; the spec requires only that the complaint
  reaches the developer through the editor's existing notification path (recorded in
  Assumptions), so the plan may choose the presentation without reopening scope.
- Manual verification with the developer should confirm the reproduction on Windows, where the
  report was filed. The automated coverage is platform-agnostic and does not depend on the
  answer.
