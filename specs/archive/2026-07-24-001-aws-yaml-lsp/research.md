# Research: AWS YAML Editor Support

## Decision: Use layered YAML support instead of one AWS server for every YAML file

**Rationale**: The repository already has `yamlls` configured with SchemaStore for generic YAML and JSON-schema-based assistance. The user's main risk is false CloudFormation/SAM diagnostics in unrelated YAML files. A layered approach keeps generic YAML support active for all YAML files while AWS-specific assistance attaches only after template classification.

**Alternatives considered**: Attach the CloudFormation language server to all `yaml` and `json` buffers. Rejected because Docker, notes, application configuration, and Serverless Framework files can be valid YAML without being CloudFormation templates.

## Decision: Treat CloudFormation as the first-class supported AWS template target

**Rationale**: The user's immediate file is a CloudFormation template, and AWS's CloudFormation tooling validates templates against CloudFormation resource provider schemas and additional rules. CloudFormation is the most direct fit for completion and key/property diagnostics.

**Alternatives considered**: Start with a broad generic AWS YAML abstraction. Rejected because there is no single YAML structure shared by CloudFormation, SAM, Serverless Framework, Docker, and generic YAML.

## Decision: Support SAM through the CloudFormation/SAM relationship, with validation explicitly verified

**Rationale**: AWS SAM templates are an extension of CloudFormation templates and transform into CloudFormation. AWS documentation recommends CloudFormation Linter validation for SAM, and SAM CLI exposes `sam validate --lint`, which applies cfn-lint rules to SAM templates. Planning should include SAM as supported or partially supported only after implementation proves editor behavior for `Transform: AWS::Serverless-2016-10-31`.

**Alternatives considered**: Assume SAM has identical editor behavior to plain CloudFormation. Rejected because SAM adds shorthand syntax and `AWS::Serverless::*` resources that must be validated separately.

## Decision: Do not claim full Serverless Framework support through CloudFormation tooling

**Rationale**: Serverless Framework configuration is YAML, but it is not the same document shape as a CloudFormation or SAM template. Some sections may eventually synthesize CloudFormation, but CloudFormation language assistance should not be presented as authoritative for `serverless.yml` as a whole.

**Alternatives considered**: Attach CloudFormation assistance to Serverless Framework files. Rejected because it would likely produce misleading diagnostics and completions for valid Serverless Framework sections.

## Decision: Use cfn-lint as the fallback validation authority for CloudFormation/SAM

**Rationale**: cfn-lint validates CloudFormation YAML/JSON templates against CloudFormation resource schemas and performs additional checks. It supports SAM by transforming SAM templates before linting, and SAM CLI can run cfn-lint via `sam validate --lint`. This gives a documented fallback when editor diagnostics are incomplete or the language server fails.

**Alternatives considered**: Rely only on editor LSP diagnostics. Rejected because LSP failures and partial validation are part of the reported problem, and command-line linting provides a clearer recovery path.

## Decision: Keep AWS language server downloads local and document them as external dependencies

**Rationale**: The user's current AWS CloudFormation language server is manually downloaded under a user data directory. That binary bundle is machine-specific, can be blocked by macOS policy, and should not be committed. The shared repository should reference the expected local executable path or documented installation procedure, while validation reports whether it is available.

**Alternatives considered**: Commit the downloaded language server bundle into dotfiles. Rejected because it would add generated/vendor binary state and platform-specific artifacts to shared config.

## Decision: Handle the macOS YAML parser warning as a Treesitter/parser troubleshooting path

**Rationale**: The reported message names `@tree-sitter-grammars+tree-sitter-yaml.node`, which points to the YAML Treesitter parser binary rather than CloudFormation itself. The plan must separate parser load failures from AWS language server internal errors so the user fixes the right layer.

**Alternatives considered**: Treat the warning as a CloudFormation LSP failure. Rejected because the blocked component name is a parser binary; confusing these layers would send troubleshooting in the wrong direction.

## Decision: Make file classification visible to the user

**Rationale**: The user specifically wants to know whether a suggestion belongs to CloudFormation, SAM, or Serverless. The implementation should provide either filetype/status visibility, documentation, or diagnostics source naming that makes the active template context clear.

**Alternatives considered**: Rely on implicit LSP attachment with no user-visible context. Rejected because the user asked for confidence about which AWS format each suggestion applies to.
