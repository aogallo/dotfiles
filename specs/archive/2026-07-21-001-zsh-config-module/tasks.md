# Tasks: Zsh Configuration Module

**Input**: `specs/001-zsh-config-module/plan.md`, `specs/001-zsh-config-module/spec.md`, optional design docs, and `.specify/memory/constitution.md`
**Tests**: Tests are optional; validation is required by the specification and constitution.
**Organization**: Tasks are grouped by user story in priority order and can be implemented independently after foundation.

## Phase 1: Setup

- [x] T001 Create `zsh/` module files at `zsh/.zshrc`, `zsh/.zshenv.example`, `zsh/local.example.zsh`, `zsh/dependencies.tsv`, and `zsh/README.md`
- [x] T002 Inspect current-machine zsh sources `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.zlogin`, `~/.zlogout`, `~/.p10k.zsh`, and sourced files, then record findings in `specs/001-zsh-config-module/zsh-source-inventory.md`
- [x] T003 Create validation script scaffold in `setup/validate-zsh-config.sh`

---

## Phase 2: Foundational

- [x] T004 Classify each reviewed current-machine source item as portable or excluded in `specs/001-zsh-config-module/zsh-source-inventory.md`
- [x] T005 Add guarded load-order sections for environment, plugins, tools, aliases, and local overrides in `zsh/.zshrc`
- [x] T006 [P] Define dependency manifest columns and baseline rows in `zsh/dependencies.tsv`
- [x] T007 [P] Add syntax, dependency, and repeated-source validation commands in `setup/validate-zsh-config.sh`

---

## Phase 3: User Story 1 - Capture Portable Zsh Configuration (Priority: P1) MVP

**Goal**: Portable shell behavior is represented in the repository while local-only/private values are excluded.
**Independent Test**: Review `specs/001-zsh-config-module/zsh-source-inventory.md` and `zsh/` to confirm every identified source is represented or excluded with no private values committed.

- [x] T008 [US1] Add guarded Oh My Zsh, plugin, and prompt initialization to `zsh/.zshrc`
- [x] T009 [US1] Add portable shell options, aliases, and functions to `zsh/.zshrc`
- [x] T010 [US1] Add guarded fzf, zoxide, atuin, carapace, tmux, fd, bat, nvm, and pnpm initialization to `zsh/.zshrc`
- [x] T011 [US1] Add placeholder-only environment examples to `zsh/.zshenv.example`
- [x] T012 [US1] Add private alias/export customization examples to `zsh/local.example.zsh`
- [x] T013 [US1] Validate secret and absolute-path exclusions across `zsh/` and `specs/001-zsh-config-module/zsh-source-inventory.md`

---

## Phase 4: User Story 2 - Understand and Customize Managed Zsh Behavior (Priority: P2)

**Goal**: A user can understand managed scope, dependencies, customization, validation, and recovery without reading implementation internals.
**Independent Test**: Read `zsh/README.md` and verify managed files, local-only paths, dependency expectations, validation steps, and customization guidance are clear in under 10 minutes.

- [x] T014 [US2] Document managed files and local-only boundaries in `zsh/README.md`
- [x] T015 [US2] Document required and optional dependencies from `zsh/dependencies.tsv` in `zsh/README.md`
- [x] T016 [US2] Document validation commands and expected outcomes in `zsh/README.md`
- [x] T017 [US2] Document personal customization workflow using `zsh/local.example.zsh` and `zsh/.zshenv.example` in `zsh/README.md`
- [x] T018 [US2] Validate documentation against `specs/001-zsh-config-module/quickstart.md`

---

## Phase 5: User Story 3 - Prepare Safe Future Installation (Priority: P3)

**Goal**: The module defines safe future linking expectations without delivering the installer in this feature.
**Independent Test**: Inspect `zsh/README.md` and `specs/001-zsh-config-module/contracts/zsh-module.md` to confirm conflict detection, backups, repeated runs, skipped dependencies, partial failures, and rollback are covered.

- [x] T019 [US3] Document future conflict detection and backup expectations in `zsh/README.md`
- [x] T020 [US3] Document rollback, removal, and interrupted-run recovery guidance in `zsh/README.md`
- [x] T021 [US3] Cross-check future linker expectations against `specs/001-zsh-config-module/contracts/zsh-module.md`
- [x] T022 [US3] Validate idempotency expectations for PATH and sourced files in `zsh/.zshrc`

---

## Final Phase: Polish & Cross-Cutting Concerns

- [x] T023 Run `zsh -n zsh/.zshrc` and record any fix in `zsh/.zshrc`
- [x] T024 Run `setup/validate-zsh-config.sh` and fix failures in `zsh/` or `setup/validate-zsh-config.sh`
- [x] T025 [P] Verify no secrets or private paths are staged in `zsh/`, `setup/`, and `specs/001-zsh-config-module/`
- [x] T026 [P] Verify issue #38 and active spec relationship are documented before PR creation in `specs/001-zsh-config-module/spec.md`

---

## Dependencies & Execution Order

- Phase 1 has no dependencies.
- Phase 2 depends on Phase 1 and blocks all user stories.
- US1, US2, and US3 depend on Phase 2; implement in priority order for the safest path.
- Final Phase depends on completed target stories.

## Parallel Opportunities

- T006 and T007 can run in parallel after T001-T003.
- US1 file-focused tasks T011 and T012 can run in parallel with T008-T010.
- US2 documentation tasks can run in parallel with US3 future-safety documentation after Phase 2 if `zsh/README.md` edit ownership is coordinated.
- T025 and T026 can run in parallel during Polish.

## Parallel Example: User Story 1

```bash
Task: "T011 [US1] Add placeholder-only environment examples to zsh/.zshenv.example"
Task: "T012 [US1] Add private alias/export customization examples to zsh/local.example.zsh"
Task: "T013 [US1] Validate secret and absolute-path exclusions across zsh/ and specs/001-zsh-config-module/zsh-source-inventory.md"
```

## Parallel Example: User Story 2

```bash
Task: "T015 [US2] Document required and optional dependencies from zsh/dependencies.tsv in zsh/README.md"
Task: "T016 [US2] Document validation commands and expected outcomes in zsh/README.md"
```

## Parallel Example: User Story 3

```bash
Task: "T021 [US3] Cross-check future linker expectations against specs/001-zsh-config-module/contracts/zsh-module.md"
Task: "T022 [US3] Validate idempotency expectations for PATH and sourced files in zsh/.zshrc"
```

## Implementation Strategy

### MVP Scope

Complete Phases 1-2 and US1, then run T023 and T025 to prove portable zsh behavior is captured without secrets or user-specific absolute paths.

### Incremental Delivery

1. Setup + Foundational: create the module skeleton, inventory, dependency manifest, and validation script.
2. US1: capture portable shell behavior safely as the MVP.
3. US2: add user-facing documentation for adoption and customization.
4. US3: document future safe linking, backup, idempotency, and rollback expectations.
5. Polish: run validation and PR/spec governance checks.

---

## Phase 6: Convergence

- [x] T027 Review and remove or justify unused helpers `zsh_path_append` and `zsh_eval_if_available` in `zsh/.zshrc` per Constitution XI / plan constraints (unrequested)
