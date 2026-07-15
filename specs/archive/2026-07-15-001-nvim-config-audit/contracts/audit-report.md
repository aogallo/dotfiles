# Contract: Neovim Audit Report

The implementation must produce a review artifact that follows this structure. The exact
filename may be chosen during task generation, but it must live under the feature directory
or another documented review location.

## Required Sections

### Summary

- Target Neovim version.
- Documentation sources used.
- Overall readiness status: `ready`, `ready-with-warnings`, or `not-ready`.
- Count of findings by severity.

### Configuration Coverage

Table columns:
- Area
- Paths Reviewed
- Status
- Evidence Source
- Notes

### Findings

Table columns:
- ID
- Severity
- Classification
- Location
- Observation
- Impact
- Recommendation
- Validation

### Dependency Inventory

Table columns:
- Dependency
- Executable
- Used By
- Source
- Required
- Install Hint
- Validation Command

### Installer Readiness

Checklist covering:
- Portability
- Idempotency
- Non-destructive behavior
- Dependency declaration
- Secret/local override separation
- Validation commands
- Rollback/recovery requirements

### Open Questions

Only include questions that remain after code and documentation review. Each question must
state why it blocks or changes a recommendation.

## Acceptance Rules

- Every `nvim/` Lua file must be represented in Configuration Coverage.
- Every LSP config under `nvim/lsp/` must contribute at least one dependency row.
- Any `critical` or `high` finding must have a validation command or explicit manual
  verification step.
- Any machine-specific path or work-specific setting must appear in Findings or be
  justified as intentionally portable.
