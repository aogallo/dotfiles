# Data Model: AWS YAML Editor Support

## AWS Infrastructure Template

**Description**: A file intended to define AWS resources or deployment configuration.

| Field | Description | Validation |
|-------|-------------|------------|
| `path` | Repository or local file path opened by the editor. | Must not require private absolute paths in shared config. |
| `syntax` | YAML or JSON. | Must remain parseable by the base editor parser before AWS analysis is trusted. |
| `template_context` | Classification such as CloudFormation, SAM, Serverless Framework, generic YAML, or unknown. | Must be determined before AWS-specific diagnostics are treated as authoritative. |
| `markers` | Filename, top-level keys, transform declarations, or schema hints used for classification. | Must be documented and testable with representative files. |

**Relationships**: Owns one `Template Context`; receives one or more `Editor Assistance State` records.

## Template Context

**Description**: The classification that decides which suggestions, diagnostics, and validation paths apply.

| Field | Description | Validation |
|-------|-------------|------------|
| `name` | CloudFormation, SAM, Serverless Framework, generic YAML, or unknown. | Must be visible through documentation or editor status/troubleshooting. |
| `activation_rule` | The observable rule that selects the context. | Must avoid activating CloudFormation on unrelated YAML by default. |
| `supported_level` | Supported, partially supported, deferred, or generic-only. | Must be documented for CloudFormation, SAM, and Serverless Framework. |
| `fallback_validation` | Command or documented check when editor assistance is insufficient. | Must exist for CloudFormation and SAM contexts. |

**Initial Context Matrix**:

| Context | Support Level | Classification Basis | Fallback Validation |
|---------|---------------|----------------------|---------------------|
| CloudFormation | Supported | Template markers or explicit file classification. | CloudFormation linting. |
| SAM | Supported or partially supported after validation | CloudFormation-like template plus SAM transform/resource markers. | CloudFormation linting or SAM lint validation. |
| Serverless Framework | Deferred for AWS-specific LSP; generic YAML support remains | Serverless Framework filename/shape. | Serverless Framework-specific checks if added later. |
| Generic YAML | Supported by generic YAML tooling only | No AWS template markers. | Generic YAML syntax/schema checks. |
| Unknown YAML | Generic-only until classified | Ambiguous or missing markers. | Manual classification or documented fallback. |

## CloudFormation Template

**Description**: An AWS template using CloudFormation sections, resources, properties, and intrinsic functions.

| Field | Description | Validation |
|-------|-------------|------------|
| `top_level_sections` | Sections such as resources, parameters, outputs, mappings, conditions, and metadata. | Misspelled or unsupported sections must be reported when tooling detects them. |
| `resources` | Declared AWS resources. | Resource type and property diagnostics must be checked with intentional invalid examples. |
| `intrinsic_functions` | AWS template functions and shorthand syntax. | Must not be broken by generic YAML parsing assumptions. |

## SAM Template

**Description**: A CloudFormation-extension template for serverless applications.

| Field | Description | Validation |
|-------|-------------|------------|
| `transform` | SAM transform marker. | Must identify SAM context when present. |
| `serverless_resources` | `AWS::Serverless::*` resources. | Must be validated or documented as partial support. |
| `cloudformation_compatibility` | Relationship to underlying CloudFormation validation. | Must document any difference between editor diagnostics and command-line linting. |

## Serverless Framework File

**Description**: A YAML service configuration that may deploy to AWS but is not itself a CloudFormation/SAM template.

| Field | Description | Validation |
|-------|-------------|------------|
| `service_config` | Framework-specific service, provider, functions, plugins, and custom sections. | Must not receive CloudFormation-only diagnostics by default. |
| `aws_overlap` | Sections that may indirectly create AWS resources. | Must be documented as not equivalent to CloudFormation template structure. |

## Editor Assistance State

**Description**: The visible behavior for completion, diagnostics, validation, and failure status in the current buffer.

| Field | Description | Validation |
|-------|-------------|------------|
| `base_yaml_active` | Generic YAML parser/schema assistance state. | Must remain available for normal YAML files when dependencies are installed. |
| `aws_assistance_active` | Whether AWS-specific assistance is active. | Must be false for non-AWS YAML by default. |
| `diagnostic_sources` | Source names shown for parser, generic YAML, CloudFormation, SAM, or fallback lint diagnostics. | Must allow the user to distinguish the origin of errors. |
| `startup_status` | Attached, missing dependency, parser blocked, LSP failed, or degraded. | Must be documented for troubleshooting. |

## Local Tooling Failure

**Description**: A local failure mode that affects editor behavior but should not corrupt shared config.

| Field | Description | Validation |
|-------|-------------|------------|
| `component` | Parser, generic YAML server, AWS language server, linter, SAM tool, or completion UI. | Troubleshooting must identify the component separately. |
| `symptom` | User-visible warning, diagnostic, startup error, or missing completion. | Must include the reported macOS parser warning and internal LSP error class. |
| `recovery_path` | Documented recovery or fallback validation step. | Must not require committing local machine state. |
| `repository_impact` | Whether shared files need a change. | Local-only security exceptions and downloaded binaries must remain untracked. |
