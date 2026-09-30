# Specification Quality Checklist: Trusted `:DBObjects` Listing

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-25
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

### Iteration 1 — 2026-09-25

**Failing item**: "No [NEEDS CLARIFICATION] markers remain".

**Issues found and fixed in this iteration**:

1. *Implementation leakage in the root-cause summary* — the first draft named catalog tables
   (`syscomments`), client binaries (`isql`, `sqsh`) and the Lua/VimScript modules
   (`db_context.lua`, `sybase.vim`). Replaced with capability language ("the server's object
   catalogue", "the command-line client", "the object reader"). Concrete names belong in
   [plan.md](../plan.md) and [contracts/](../contracts/), not in the specification.
2. *Untestable FR-016* — "failure messages MUST be helpful" was replaced with "MUST name the
   database or object it concerns and MUST list the plausible causes", which a reviewer can check
   by reading the message.
3. *Unmeasurable SC-002/SC-004* — "listings stay fast" and "errors surface quickly" were replaced
   with a 2× wall-clock bound (SC-011) and a 5-second, exactly-one-message assertion (SC-004).
4. *Missing scope boundary* — nothing stated that cross-database name search stays closed. An
   explicit **Out of Scope** section was added, cross-referencing the archived spec that closed it.
5. *Unbounded entity* — "Object row" said nothing about an unmapped kind. The server-reported-kind
   fallback was added to the entity and to FR-011.

**Open item put to the user**: one marker, Q1 (object-kind coverage), in FR-009 and User Story 2
scenario 4. It was a genuine fork with no defensible default — enumerate everything (only option
that fully satisfies "no discrepancy vs. the reference path", but unusable volume and real load) vs.
a curated subset (usable, but keeps a silent hole) vs. grouped-and-filterable (satisfies both, new
interaction). It was escalated rather than guessed.

### Iteration 2 — 2026-09-25 (after the developer answered Q1)

**Q1 answer**: keep the listing to the kinds the developer works with — procedures, views,
functions, triggers (tables retained) — do not enumerate the system catalogue, and avoid degrading
the database. Instead of accepting a silent hole, add a **direct-open entry** so any object is
reachable by name from the confirmed database.

**All items now pass.** Changes made in this iteration:

1. **FR-009/FR-010 rewritten** — the covered kinds are now stated positively (tables, views,
   procedures, functions, triggers) and the system catalogue is now an explicit prohibition
   (FR-010) with a rationale, instead of an open-ended enumeration.
2. **User Story 2 rescoped** — the headline changed from "every object the server can describe" to
   "every object the developer works with", and its independent test now compares against the five
   covered kinds and checks that uncovered kinds are reachable rather than silently absent.
3. **User Story 3 added (new capability)** — direct open by name, with six acceptance scenarios
   including the two guards that keep it honest: it is not offered without a confirmed database
   (FR-017), and it issues no request until the developer confirms a name (FR-018).
4. **The 60 % solution was rejected in favour of this one.** Option C (curated list + report the
   exclusions) was not taken, because the object the developer actually wants would still be
   missing. Reachability was chosen over admission, which is strictly better at equal cost.
5. **Numbering repaired** — inserting a new requirement block produced a duplicate `FR-014`.
   All requirements were renumbered sequentially (`FR-001`–`FR-044`) and the two in-prose
   cross-references (`FR-033` → `FR-015`, `FR-017` → `FR-025`) were corrected. Verified: no
   duplicates, no gaps, no dangling references.
6. **Server load made testable** — the developer's performance condition was promoted from a
   qualitative wish to a requirement set (FR-041–FR-044) and a budget assertion (SC-010: at most
   3 requests per invocation, identical for 50 and 50,000 objects). An assumption now states that
   any design issuing one request per database or per object is out.
7. **Out of Scope grew three entries** — the system-catalogue sweep, the direct-open entry becoming
   a cross-database side door (FR-021), and grouping/sorting/multi-column filtering.
8. **One assumption flagged as the most likely to be wrong** — "execute the function with the
   params you provide" is read as running the *object-help command* with the tool's existing
   options, not executing the object itself. Recorded in Assumptions to be confirmed at plan time
   rather than silently carried into implementation.
9. **User stories renumbered** — the new story was inserted as US3 and the two later stories
   shifted to US4/US5, so priorities still read in document order (P1, P1, P2, P2, P3).

**Remaining risk for the planning phase**: SC-003, FR-009 and the direct-open entry assume the
developer can reach *any* object by name from the confirmed database. If the server refuses to
read the source of a specific uncovered kind, FR-019's single actionable notice is the designed
outcome rather than a defect — this must not be mistaken during verification for a regression.

### Session 2026-09-25 — assumption closed before implementation

The specification's one flagged assumption — whether "execute the function with the params you
provide" meant running the object-help command or executing the object — was **confirmed by the
developer as "reuse the one that already exists"**, i.e. read the source through the existing
`g:db_sybase_source_mode` path. Recorded in [spec.md](../spec.md) Assumptions,
[research.md](../research.md) R-0006, and the gate lifted on T050 in [tasks.md](../tasks.md).

Consequence: no requirement changed, no task was renumbered, and no new SQL, source mode or
dependency is introduced. The direct-open entry stays a thin exposure of an existing capability,
which is also what keeps it inside the FR-036 request budget.

**All checks pass. The specification is approved for implementation.**
