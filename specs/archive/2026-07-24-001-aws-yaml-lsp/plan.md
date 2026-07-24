# Implementation Plan: AWS YAML Editor Support

**Branch**: `main` (planning only; implementation must move to a feature branch before code changes) | **Date**: 2026-07-22 | **Spec**: `specs/001-aws-yaml-lsp/spec.md`

**Input**: Feature specification from `specs/001-aws-yaml-lsp/spec.md`

**Note**: `.specify/scripts/bash/setup-plan.sh` is not present in this checkout, so this plan was generated in filesystem mode from `.specify/feature.json`.

## Summary

Add reliable AWS infrastructure template assistance to the shared Neovim configuration without treating every YAML file as CloudFormation. The implementation will use the existing generic YAML stack for normal YAML/schema behavior, add narrowly-scoped CloudFormation language assistance for CloudFormation and SAM template contexts, document Serverless Framework support as separate from CloudFormation/SAM, add fallback validation through AWS template linting, and document troubleshooting for macOS parser quarantine and language-server startup failures.

## Technical Context

**Language/Version**: Neovim 0.12 Lua configuration, YAML/JSON AWS infrastructure templates, shell validation scripts where needed.

**Primary Dependencies**: Existing Neovim LSP bootstrap, `yaml-language-server`, SchemaStore.nvim, nvim-treesitter YAML parser, AWS CloudFormation language server installed locally, Node.js for the AWS language server, optional `cfn-lint`, optional AWS SAM CLI for SAM validation.

**Storage**: Repository files under `nvim/`, especially `nvim/lsp/`, `nvim/plugin/`, `nvim/dependencies.tsv`, and `nvim/README.md`; local-only AWS language server download under the user's data directory; generated parser caches and downloaded binaries remain outside shared repository state.

**Testing**: Headless Neovim startup, LSP configuration smoke checks, YAML parser health checks, representative CloudFormation/SAM/non-AWS YAML file checks, dependency manifest validation, documentation review, and optional external validation with CloudFormation/SAM linting tools when installed.

**Target Platform**: macOS development machines using this dotfiles repository; Apple Silicon is the current baseline, with Intel macOS behavior documented when relevant.

**Project Type**: Dotfiles repository with modular Neovim configuration.

**Performance Goals**: Opening representative AWS and non-AWS YAML files should attach the intended assistance within 10 seconds and should not produce repeated startup errors.

**Constraints**: Do not commit downloaded AWS language server bundles, generated parser binaries, caches, quarantine/security state, secrets, private paths, or machine-specific absolute paths. Do not enable CloudFormation diagnostics on unrelated YAML files by default. Keep missing optional AWS validation tools non-blocking for baseline Neovim startup.

**Scale/Scope**: One Neovim AWS/YAML support work unit covering classification, LSP scoping, fallback validation guidance, dependency documentation, troubleshooting, and representative validation fixtures or instructions.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Pre-design: PASS. The feature is scoped to shared Neovim configuration, keeps machine-local downloads outside the repository, preserves generic YAML behavior, requires validation, and does not overwrite local files. Implementation must not be committed on `main`; planning artifacts may exist on `main` but implementation commits must move to a feature branch.

Post-design: PASS. The research and design artifacts define layered AWS YAML support, local dependency boundaries, validation contracts, fallback linting, troubleshooting, and no repository ownership of downloaded binaries or macOS security exceptions. No constitutional exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/001-aws-yaml-lsp/
├── plan.md                         # This file
├── research.md                     # Phase 0 output
├── data-model.md                   # Phase 1 output
├── quickstart.md                   # Phase 1 output
├── contracts/
│   └── aws-yaml-editor-support.md  # User-facing support contract
└── tasks.md                        # Phase 2 output, not created by plan
```

### Source Code (repository root)

```text
nvim/
├── README.md
├── dependencies.tsv
├── lsp/
│   ├── yamlls.lua
│   └── cfn_lsp.lua
├── plugin/
│   ├── schemastore.lua
│   └── treesitter.lua
└── lua/
    └── lsp.lua

setup/
└── validate-nvim-deps.sh
```

**Structure Decision**: Keep CloudFormation-specific configuration in `nvim/lsp/cfn_lsp.lua`, preserve generic YAML behavior in `nvim/lsp/yamlls.lua`, update dependency and README documentation in the existing Neovim module, and use existing setup validation patterns rather than introducing a new top-level AWS module.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
