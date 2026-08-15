# Tasks: Windows Tooling Audit Document

**Input**: Design documents from `specs/001-windows-tooling-audit/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/windows-tooling-audit.md](./contracts/windows-tooling-audit.md), [quickstart.md](./quickstart.md)

**Tests**: No automated test suite is requested. This documentation-only feature uses review and validation tasks from [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing. Each user-story phase links to its matching heading in [spec.md](./spec.md).

## Format: `[ID] [P?] [Story] Description`

- **T###**: Stable task ID used for tracking implementation.
- **[P]**: Parallelizable task that can run independently because it touches different files or has no dependency on incomplete work.
- **[US#]**: User story marker. The phase's `Story Link` points to the matching `spec.md` heading.
- Include exact file paths in task descriptions.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare the documentation target and source inventory without installing or running setup automation.

- [X] T001 Create `docs/windows-tooling-audit.md` with the required section headings from `specs/001-windows-tooling-audit/contracts/windows-tooling-audit.md`
- [X] T002 Add the compatibility status legend to `docs/windows-tooling-audit.md` based on `specs/001-windows-tooling-audit/data-model.md`
- [X] T003 [P] Build the repository evidence inventory for root docs and generated outputs in `docs/windows-tooling-audit.md` from `README.md`, `.github/workflows/`, and `dist/`
- [X] T004 [P] Build the repository evidence inventory for tool modules in `docs/windows-tooling-audit.md` from `nvim/`, `Tmux/`, `ghostty/`, `zsh/`, `keyboard/`, `installer/`, and `setup/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the audit matrix and trusted reference baseline that every user story needs.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T005 Create the summary table skeleton in `docs/windows-tooling-audit.md` with rows for `README.md`, `nvim/`, `Tmux/`, `ghostty/`, `zsh/`, `keyboard/`, `installer/`, `setup/`, `.github/workflows/`, and `dist/`
- [X] T006 Add repository-specific caveat notes to `docs/windows-tooling-audit.md` for Homebrew-only guidance, macOS application paths, `pbcopy`, Xcode Command Line Tools, darwin-only release assets, local override files, and generated state
- [X] T007 [P] Collect official or maintainer links for editor, terminal, shell, multiplexer, keyboard, package-manager, Go, and GitHub Actions tooling in `docs/windows-tooling-audit.md`
- [X] T008 [P] Record out-of-scope rules for generated artifacts, local state, private overrides, and non-tool files in `docs/windows-tooling-audit.md`

**Checkpoint**: Foundation ready. The final document has its structure, source inventory, summary rows, reference baseline, and non-destructive boundaries.

---

## Phase 3: User Story 1 - Understand Windows Compatibility (Priority: P1) MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---understand-windows-compatibility-priority-p1)

**Goal**: The user can see which repository tools and modules are compatible, partially compatible, not compatible, unknown, or out of scope for Windows.

**Independent Test**: Review `docs/windows-tooling-audit.md` and confirm every relevant repository area has a Windows compatibility status, rationale, and recommended usage path.

### Implementation for User Story 1

- [X] T009 [US1] Classify `nvim/` and related Neovim dependencies in `docs/windows-tooling-audit.md` using evidence from `nvim/README.md`, `nvim/dependencies.tsv`, and `setup/validate-nvim-deps.sh`
- [X] T010 [US1] Classify `Tmux/` in `docs/windows-tooling-audit.md` using evidence from `Tmux/README.md` and `Tmux/tmux.conf`
- [X] T011 [US1] Classify `ghostty/` in `docs/windows-tooling-audit.md` using evidence from `ghostty/README.md`, `ghostty/config.ghostty`, and `ghostty/dependencies.tsv`
- [X] T012 [US1] Classify `zsh/` in `docs/windows-tooling-audit.md` using evidence from `zsh/README.md`, `zsh/.zshrc`, and `zsh/dependencies.tsv`
- [X] T013 [US1] Classify `keyboard/` in `docs/windows-tooling-audit.md` using evidence from `keyboard/README.md` and `keyboard/iris_rev__5.json`
- [X] T014 [US1] Classify `installer/` and `setup/` in `docs/windows-tooling-audit.md` using evidence from `installer/README.md`, `setup/bootstrap-dotfiles-installer.sh`, and `setup/macos.sh`
- [X] T015 [US1] Classify root documentation, `.github/workflows/`, and `dist/` in `docs/windows-tooling-audit.md` as audited or out of scope based on `README.md`, `.github/workflows/release-installer.yml`, and `dist/`
- [X] T016 [US1] Update the summary table in `docs/windows-tooling-audit.md` so every audited row has status, repository location, recommended path, and reference entry
- [X] T017 [US1] Validate coverage in `docs/windows-tooling-audit.md` against Scenario 1 in `specs/001-windows-tooling-audit/quickstart.md`

**Checkpoint**: User Story 1 is complete when the audit answers what works on Windows, what does not, what is partial, and what is out of scope.

---

## Phase 4: User Story 2 - Compare Adoption Tradeoffs (Priority: P2)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---compare-adoption-tradeoffs-priority-p2)

**Goal**: The user can compare the practical benefits and drawbacks of using each compatible or partially compatible tool on Windows.

**Independent Test**: Select any compatible or partially compatible item in `docs/windows-tooling-audit.md` and confirm it includes Windows-specific advantages, disadvantages, and caveats.

### Implementation for User Story 2

- [X] T018 [US2] Add Windows-specific advantages and disadvantages for Neovim-related items in `docs/windows-tooling-audit.md`
- [X] T019 [US2] Add Windows-specific advantages and disadvantages for terminal and multiplexer items in `docs/windows-tooling-audit.md`
- [X] T020 [US2] Add Windows-specific advantages and disadvantages for shell and CLI dependency items in `docs/windows-tooling-audit.md`
- [X] T021 [US2] Add Windows-specific advantages and disadvantages for keyboard, installer, setup, and workflow items in `docs/windows-tooling-audit.md`
- [X] T022 [US2] Distinguish native Windows, WSL, Git Bash, MSYS2, manual-only, and unsupported usage paths in every relevant detail section of `docs/windows-tooling-audit.md`
- [X] T023 [US2] Validate tradeoff completeness in `docs/windows-tooling-audit.md` against Scenario 2 and Scenario 4 in `specs/001-windows-tooling-audit/quickstart.md`

**Checkpoint**: User Story 2 is complete when compatible and partially compatible items include useful adoption tradeoffs, not just status labels.

---

## Phase 5: User Story 3 - Follow Safe Installation Guidance (Priority: P3)

**Story Link**: [US3 in spec.md](./spec.md#user-story-3---follow-safe-installation-guidance-priority-p3)

**Goal**: The user can later install compatible tools manually from trustworthy sources without this feature installing anything.

**Independent Test**: Confirm every compatible or partially compatible tool in `docs/windows-tooling-audit.md` has official or reputable links and clearly optional Windows installation guidance.

### Implementation for User Story 3

- [X] T024 [US3] Add official or reputable installation links for native Windows-compatible tools in `docs/windows-tooling-audit.md`
- [X] T025 [US3] Add WSL, Git Bash, MSYS2, or manual workflow guidance for partially compatible tools in `docs/windows-tooling-audit.md`
- [X] T026 [US3] Add package-manager alternatives such as winget, Scoop, Chocolatey, or WSL package managers only where they are appropriate future/manual options in `docs/windows-tooling-audit.md`
- [X] T027 [US3] Review every installation command or instruction in `docs/windows-tooling-audit.md` to ensure it is framed as optional future/manual guidance and not as executed work
- [X] T028 [US3] Validate installation guidance and non-destructive wording in `docs/windows-tooling-audit.md` against Scenario 3 in `specs/001-windows-tooling-audit/quickstart.md`

**Checkpoint**: User Story 3 is complete when installation guidance is useful, linked, and safely non-executed.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final review, readability, contract compliance, and governance checks.

- [X] T029 [P] Check `docs/windows-tooling-audit.md` against `specs/001-windows-tooling-audit/contracts/windows-tooling-audit.md` for required structure, coverage, and acceptance checks
- [X] T030 [P] Check `docs/windows-tooling-audit.md` against `specs/001-windows-tooling-audit/data-model.md` for required fields on audited tools, installation references, and portability concerns
- [X] T031 Run the fast-lookup validation from Scenario 5 in `specs/001-windows-tooling-audit/quickstart.md` against `docs/windows-tooling-audit.md`
- [X] T032 Review `docs/windows-tooling-audit.md` for Spanish readability, scan-friendly headings, and summary-first structure
- [X] T033 Verify `docs/windows-tooling-audit.md` contains no secrets, private paths, generated local state, or claims that tools were installed during this feature
- [X] T034 Verify active spec relationship and PR closure question obligations are ready for future PR preparation in `specs/001-windows-tooling-audit/tasks.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion; blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational completion; delivers the MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational completion and benefits from US1 classifications, but remains independently reviewable by checking tradeoff sections.
- **User Story 3 (Phase 5)**: Depends on Foundational completion and benefits from US1 classifications, but remains independently reviewable by checking link and install-guidance sections.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2; no dependency on other user stories.
- **User Story 2 (P2)**: Can start after Phase 2; best completed after US1 so tradeoffs attach to settled classifications.
- **User Story 3 (P3)**: Can start after Phase 2; best completed after US1 so installation guidance attaches to settled classifications.

### Within Each User Story

- Repository evidence should be read before writing a classification or caveat.
- Summary rows should be updated after detail sections are drafted.
- Quickstart validation should run after the story's document sections are complete.

### Parallel Opportunities

- T003 and T004 can run in parallel because they inspect different repository areas.
- T007 and T008 can run in parallel because one collects links and the other defines exclusions.
- T009 through T015 can be divided by module if multiple contributors edit coordinated sections of `docs/windows-tooling-audit.md`; avoid simultaneous writes to the same section.
- T018 through T021 can be split by tool family once the US1 classifications exist.
- T024 through T026 can be split by installation path once the US1 classifications exist.
- T029 and T030 can run in parallel because they validate against different design artifacts.

---

## Parallel Example: User Story 1

```text
Task: "T009 [US1] Classify nvim/ and related Neovim dependencies in docs/windows-tooling-audit.md"
Task: "T010 [US1] Classify Tmux/ in docs/windows-tooling-audit.md"
Task: "T011 [US1] Classify ghostty/ in docs/windows-tooling-audit.md"
Task: "T012 [US1] Classify zsh/ in docs/windows-tooling-audit.md"
```

## Parallel Example: User Story 2

```text
Task: "T018 [US2] Add Windows-specific advantages and disadvantages for Neovim-related items in docs/windows-tooling-audit.md"
Task: "T019 [US2] Add Windows-specific advantages and disadvantages for terminal and multiplexer items in docs/windows-tooling-audit.md"
Task: "T020 [US2] Add Windows-specific advantages and disadvantages for shell and CLI dependency items in docs/windows-tooling-audit.md"
```

## Parallel Example: User Story 3

```text
Task: "T024 [US3] Add official or reputable installation links for native Windows-compatible tools in docs/windows-tooling-audit.md"
Task: "T025 [US3] Add WSL, Git Bash, MSYS2, or manual workflow guidance for partially compatible tools in docs/windows-tooling-audit.md"
Task: "T026 [US3] Add package-manager alternatives such as winget, Scoop, Chocolatey, or WSL package managers in docs/windows-tooling-audit.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational audit matrix and references.
3. Complete Phase 3: User Story 1 compatibility classifications.
4. Stop and validate Scenario 1 in [quickstart.md](./quickstart.md).
5. Review the summary table to confirm the user can answer what works on Windows.

### Incremental Delivery

1. Deliver US1 for compatibility status and recommended paths.
2. Add US2 for practical pros/cons and caveats.
3. Add US3 for safe manual installation guidance and links.
4. Run Phase 6 contract, data-model, readability, and safety validation.

### Single-Agent Strategy

1. Work module-by-module to avoid contradictory edits in `docs/windows-tooling-audit.md`.
2. Keep the summary table synchronized after each module detail section.
3. Do not run installation, bootstrap, setup, or package-manager commands; use repository files and trusted documentation links as evidence.

## Notes

- This feature intentionally creates documentation only.
- Do not add Windows automation, installer code, scripts, symlinks, package installs, or setup command execution.
- If implementation discovers stale existing module README content, document it as an audit caveat unless the user explicitly expands scope to edit module behavior/docs.
- Before creating a PR, verify whether this active spec is related to the PR and ask whether the completed spec should be closed.
