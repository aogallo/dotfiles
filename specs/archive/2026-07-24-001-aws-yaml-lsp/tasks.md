# Tasks: AWS YAML Editor Support

## Phase 1: Setup

- [x] T001 Inspect existing CloudFormation LSP attachment rules in nvim/lsp/cfn_lsp.lua
- [x] T002 Inspect generic YAML SchemaStore behavior to preserve in nvim/lsp/yamlls.lua
- [x] T003 Inspect YAML parser install/update commands and macOS parser failure surface in nvim/plugin/treesitter.lua
- [x] T004 Inspect dependency manifest and validator conventions in nvim/dependencies.tsv and setup/validate-nvim-deps.sh

## Phase 2: Foundational

- [x] T005 Create representative CloudFormation fixture with valid resources in specs/001-aws-yaml-lsp/fixtures/cloudformation-valid.yaml
- [x] T006 [P] Create CloudFormation fixture with misspelled top-level key, invalid property, and broken reference in specs/001-aws-yaml-lsp/fixtures/cloudformation-invalid.yaml
- [x] T007 [P] Create representative SAM fixture with Transform and AWS::Serverless resource in specs/001-aws-yaml-lsp/fixtures/sam-template.yaml
- [x] T008 [P] Create representative Serverless Framework fixture in specs/001-aws-yaml-lsp/fixtures/serverless.yml
- [x] T009 [P] Create representative non-AWS YAML fixtures in specs/001-aws-yaml-lsp/fixtures/non-aws-yaml/
- [x] T010 Define explicit CloudFormation/SAM classification markers and manual classification path in nvim/README.md

## Phase 3: User Story 1 - Author AWS Infrastructure Templates With Editor Assistance (Priority: P1)

**Goal**: Provide AWS-aware completion, validation, diagnostics, and fallback validation for CloudFormation-style templates.

**Independent Test**: Open a representative CloudFormation template and confirm AWS-relevant suggestions and actionable diagnostics appear without startup crashes.

- [x] T011 [US1] Narrow cfn_lsp command setup to a guarded local executable path with clear missing-server behavior in nvim/lsp/cfn_lsp.lua
- [x] T012 [US1] Configure cfn_lsp capabilities and settings for CloudFormation diagnostics/completion without overriding generic YAML behavior in nvim/lsp/cfn_lsp.lua
- [x] T013 [US1] Add documented cfn-lint fallback commands for CloudFormation templates in nvim/README.md
- [x] T014 [P] [US1] Add optional CloudFormation language server and cfn-lint entries to nvim/dependencies.tsv
- [x] T015 [US1] Update dependency validator messaging so optional AWS tools are reported as non-blocking in setup/validate-nvim-deps.sh
- [x] T016 [US1] Smoke-validate CloudFormation fixture startup and diagnostic source visibility using specs/001-aws-yaml-lsp/fixtures/cloudformation-valid.yaml
- [x] T017 [US1] Smoke-validate intentional CloudFormation mistakes with editor diagnostics or cfn-lint fallback using specs/001-aws-yaml-lsp/fixtures/cloudformation-invalid.yaml

## Phase 4: User Story 2 - Distinguish YAML Contexts Without Polluting Every YAML File (Priority: P1)

**Goal**: Activate AWS-specific assistance only for classified CloudFormation/SAM contexts while keeping yamlls/SchemaStore for generic YAML.

**Independent Test**: Open AWS and non-AWS YAML files and confirm CloudFormation/SAM diagnostics attach only to classified templates.

- [x] T018 [US2] Remove broad yaml/json filetype attachment from CloudFormation LSP setup in nvim/lsp/cfn_lsp.lua
- [x] T019 [US2] Add classification-based activation for CloudFormation and SAM templates in nvim/lsp/cfn_lsp.lua
- [x] T020 [US2] Preserve generic yamlls SchemaStore coverage for all YAML files in nvim/lsp/yamlls.lua
- [x] T021 [P] [US2] Document that Serverless Framework remains generic YAML by default in nvim/README.md
- [x] T022 [US2] Smoke-validate non-AWS fixtures open without CloudFormation diagnostics using specs/001-aws-yaml-lsp/fixtures/non-aws-yaml/
- [x] T023 [US2] Smoke-validate serverless.yml keeps generic YAML support without CloudFormation-only diagnostics using specs/001-aws-yaml-lsp/fixtures/serverless.yml

## Phase 5: User Story 3 - Recover From Local Tooling and macOS Security Failures (Priority: P2)

**Goal**: Make parser, language server, lint, and macOS security failures diagnosable and recoverable without committing local machine state.

**Independent Test**: Simulate missing or blocked dependencies and verify the docs identify the failing layer and recovery path.

- [x] T024 [US3] Document macOS @tree-sitter-grammars+tree-sitter-yaml.node warning as YAML parser troubleshooting in nvim/README.md
- [x] T025 [US3] Document AWS CloudFormation language server internal errors separately from parser failures in nvim/README.md
- [x] T026 [US3] Add YAML parser health validation commands and recovery commands for TSInstallConfigured/TSUpdateConfigured in nvim/README.md
- [x] T027 [P] [US3] Ensure YAML parser dependency remains explicit in nvim/plugin/treesitter.lua
- [x] T028 [US3] Smoke-validate missing optional AWS tools do not fail baseline dependency validation in setup/validate-nvim-deps.sh
- [x] T029 [US3] Smoke-validate headless Neovim startup after recovery guidance using nvim/init.lua

## Phase 6: User Story 4 - Compare Specific and General AWS YAML Support Paths (Priority: P3)

**Goal**: Document why CloudFormation-specific support is chosen, how SAM is handled, and why Serverless Framework is not treated as CloudFormation by default.

**Independent Test**: Read the docs and confirm CloudFormation, SAM, Serverless Framework, generic YAML, and fallback validation tradeoffs are clear.

- [x] T030 [US4] Add CloudFormation-first support strategy and tradeoffs to nvim/README.md
- [x] T031 [US4] Document verified SAM support level and sam validate --lint fallback in nvim/README.md
- [x] T032 [P] [US4] Update validation guide with final support matrix and fixture commands in specs/001-aws-yaml-lsp/quickstart.md
- [x] T033 [US4] Smoke-validate SAM classification and fallback guidance using specs/001-aws-yaml-lsp/fixtures/sam-template.yaml

## Final Phase: Polish & Cross-Cutting Concerns

- [x] T034 Run Lua formatting check for changed Neovim Lua files with nvim/stylua.toml
- [x] T035 Run dependency manifest validation after AWS dependency entries with setup/validate-nvim-deps.sh
- [x] T036 Run repository hygiene check to ensure no downloaded binaries, caches, private paths, or macOS security state are tracked in /Users/allan/dotfiles
- [x] T037 Update quickstart results and any discovered caveats in specs/001-aws-yaml-lsp/quickstart.md

## Dependencies

- T001-T004 before implementation tasks that modify their referenced files.
- T005-T010 before story smoke validation tasks.
- US1 and US2 are both P1; implement T011-T023 before US3/US4 polish.
- T018 depends on T011-T012 so the CloudFormation server still has a guarded setup before activation is narrowed.
- T024-T029 depend on the final parser/LSP/dependency behavior from US1 and US2.
- T030-T033 depend on verified behavior from US1, US2, and US3.
- T034-T037 run after all implementation and documentation tasks.

## Parallel Execution Examples

- After T005, run T006, T007, T008, and T009 in parallel because they create separate fixture paths.
- T014 can run in parallel with T013 because nvim/dependencies.tsv and nvim/README.md are separate files.
- T021 can run in parallel after T018-T020 if no other README edit is active.
- T027 can run in parallel with T024-T026 because nvim/plugin/treesitter.lua and nvim/README.md are separate files.
- T032 can run in parallel with T030-T031 because specs/001-aws-yaml-lsp/quickstart.md and nvim/README.md are separate files.

## Implementation Strategy

1. Establish fixtures and classification rules first so every later change can be smoke-validated against representative AWS and non-AWS YAML files.
2. Make CloudFormation assistance useful, then immediately narrow activation so generic YAML remains clean.
3. Add recovery documentation and dependency validation after the final attachment behavior is known.
4. Finish by documenting support tradeoffs and running smoke checks from specs/001-aws-yaml-lsp/quickstart.md.
