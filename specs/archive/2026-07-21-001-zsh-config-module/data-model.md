# Data Model: Zsh Configuration Module

## Zsh Configuration Module

**Fields**: module path, managed files, documentation, dependency manifest, validation commands, future installer expectations.

**Relationships**: Contains portable shell items, dependency declarations, local override guidance, and recovery guidance.

**Validation rules**: Must live under `zsh/`; must not require unrelated modules; must document validation and rollback.

## Local Zsh Configuration Source

**Fields**: source path, category, reviewed status, portable items, excluded local-only items, notes.

**Relationships**: Produces portable shell items or local-only shell items.

**Validation rules**: Every reviewed current-machine source is represented as included or excluded.

## Portable Shell Item

**Fields**: item type, purpose, required dependencies, startup order, guard condition, destination file.

**Relationships**: May depend on dependency declarations and local override values.

**Validation rules**: Must avoid user-specific absolute paths; must degrade safely when optional dependencies are absent.

## Local-Only Shell Item

**Fields**: item type, reason excluded, safe customization path, example placeholder if useful.

**Relationships**: Documents values that must stay outside repository-managed config.

**Validation rules**: Must not include real secrets, credentials, private endpoints, or owner-specific absolute paths in committed files.

## Dependency Declaration

**Fields**: name, executable or file, required flag, source, install hint, used by.

**Relationships**: Referenced by portable shell items and validation checks.

**Validation rules**: Required dependencies fail validation when missing; optional dependencies are reported without failing baseline validation.

## Recovery Guidance

**Fields**: conflict behavior, backup location expectation, restore steps, remove steps, interrupted-run guidance.

**Relationships**: Supports the future installer/linker contract.

**Validation rules**: Must cover existing config conflicts, repeated runs, skipped optional dependencies, partial failures, and rollback.

## State Transitions

```text
Unreviewed local item -> Portable shared item -> Validated managed item
Unreviewed local item -> Local-only item -> Documented exclusion
Future link target -> Conflict detected -> Backed up or refused -> Linked -> Removed or restored
```
