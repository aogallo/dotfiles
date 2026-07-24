# Quickstart: AWS YAML Editor Support

Use this guide to validate the implementation after `/speckit.tasks` and apply are complete.

## Prerequisites

- Run commands from the repository root.
- Use a feature branch before implementation commits.
- Keep downloaded language server bundles, parser binaries, caches, and macOS security exceptions outside git.
- Install or verify the baseline Neovim dependencies with the existing Neovim dependency workflow.

## 1. Validate Neovim still starts

Run:

```sh
nvim --headless -u nvim/init.lua '+quitall'
```

Expected outcome:

- Neovim exits successfully.
- No repeated startup error is produced by YAML parsing, generic YAML support, or AWS template support.

## 2. Validate dependency documentation

Run:

```sh
setup/validate-nvim-deps.sh
```

Expected outcome:

- Required baseline Neovim dependencies are reported clearly.
- AWS-specific tools are either detected or reported with install guidance.
- Missing optional AWS validation tools do not block unrelated Neovim startup.

## 3. Validate generic YAML remains generic

Open the three non-AWS fixtures:

```sh
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/non-aws-yaml/docker-compose.yml
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/non-aws-yaml/app-config.yaml
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/non-aws-yaml/notes.yaml
```

Expected outcome:

- Generic YAML syntax/schema behavior remains available.
- No CloudFormation or SAM diagnostics appear by default.
- Completion remains useful without AWS-specific noise.

## 4. Validate CloudFormation assistance

Open the representative CloudFormation template:

```sh
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/cloudformation-valid.yaml
```

Expected outcome:

- The buffer is classified as CloudFormation or follows the documented manual classification path.
- AWS-relevant completion appears for template sections, resource types, or resource properties.
- Diagnostics source makes it clear that AWS template analysis is active.

## 5. Validate intentional CloudFormation mistakes

Open the invalid CloudFormation fixture:

```sh
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/cloudformation-invalid.yaml
```

The fixture includes:

- One misspelled top-level template key.
- One invalid resource property.
- One missing reference or invalid resource relationship.

Expected outcome:

- The editor reports actionable diagnostics for supported mistakes, or the fallback lint command reports them clearly.
- The user can tell whether the diagnostic came from parser, generic YAML, AWS language assistance, or fallback linting.

Fallback command:

```sh
cfn-lint specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/cloudformation-invalid.yaml
```

## 6. Validate SAM behavior

Open a representative SAM template containing the SAM transform and at least one `AWS::Serverless::*` resource.

```sh
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/sam-template.yaml
```

Expected outcome:

- The buffer is classified as SAM or CloudFormation-with-SAM according to the documented support level.
- The documentation clearly states whether SAM completion and diagnostics are fully supported or partially supported.
- Fallback validation for SAM is documented and runnable when the optional tool is installed.

Fallback commands:

```sh
cfn-lint specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/sam-template.yaml
sam validate --lint --template-file specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/sam-template.yaml
```

## 7. Validate Serverless Framework behavior

Open a representative `serverless.yml`.

```sh
nvim specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/serverless.yml
```

Expected outcome:

- Generic YAML assistance remains available.
- CloudFormation-only diagnostics do not attach to the whole file by default.
- Documentation explains that Serverless Framework support is separate from CloudFormation/SAM support unless a future work unit adds dedicated handling.

## 8. Validate parser and language server troubleshooting

Review `nvim/README.md` troubleshooting guidance for these failure classes:

- macOS blocks the YAML parser binary from loading.
- The AWS template language assistance process exits or reports an internal error.
- Generic YAML assistance works but AWS-specific assistance is unavailable.
- AWS-specific assistance works but fallback lint tooling is missing.

Expected outcome:

- Each failure class has a clear diagnosis path.
- Recovery steps do not require committing local machine state.
- Non-AWS YAML editing remains usable while AWS assistance is degraded.

## 9. Review repository hygiene

Run:

```sh
git status --short
```

Expected outcome:

- Intended source and spec files are visible for review.
- No downloaded AWS language server bundle, generated parser binary, cache directory, private path, or macOS security exception state is tracked.

## Final Support Matrix

| Context | Support Level | Editor Behavior | Fallback |
|---------|---------------|-----------------|----------|
| CloudFormation | Supported | Generic YAML plus guarded `cfn_lsp` for classified templates. | `cfn-lint <template>` |
| SAM | Supported as CloudFormation/SAM extension | Classified when SAM transform or `AWS::Serverless::*` resources are present; editor assistance is CloudFormation-oriented. | `cfn-lint <template>` or `sam validate --lint --template-file <template>` |
| Serverless Framework | Generic YAML by default | `yamlls`/SchemaStore only; no CloudFormation-only diagnostics by default. | Add framework-specific validation in a future work unit if needed. |
| Generic YAML | Generic YAML only | `yamlls`/SchemaStore remains active; AWS LSP does not attach without template markers. | YAML syntax/schema validation. |

## Apply Results

- `nvim --headless -u nvim/init.lua '+quitall'` passed on 2026-07-22.
- `setup/validate-nvim-deps.sh` passed on 2026-07-24 with AWS optional tools available and `shfmt`/`shellcheck` still reported as non-blocking optional tools.
- `stylua --check nvim` passed on 2026-07-22.
- Fixture context smoke checks passed on 2026-07-22:
  - `cloudformation-valid.yaml` -> `cloudformation`
  - `cloudformation-invalid.yaml` -> `cloudformation`
  - `sam-template.yaml` -> `sam`
  - `serverless.yml` -> `generic-yaml`
  - all non-AWS YAML fixtures -> `generic-yaml`
- The local AWS CloudFormation language server bundle was repaired on 2026-07-24 by restoring the missing `darwin-arm64` `@tree-sitter-grammars/tree-sitter-yaml` prebuild from npm and removing quarantine from the trusted local bundle.
- `cfn-lint specs/archive/2026-07-24-001-aws-yaml-lsp/fixtures/cloudformation-invalid.yaml` reported the expected misspelled top-level key, missing reference, invalid S3 bucket property, and missing `GetAtt` target on 2026-07-24.
- Repository hygiene check (`git status --short`) showed intended source/spec changes plus pre-existing unrelated `.specify/feature.json` modification; no downloaded AWS language server bundle, generated parser binary, cache directory, private path, or macOS security exception state appeared as tracked changes.
