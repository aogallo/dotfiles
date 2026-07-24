# Contract: AWS YAML Editor Support

This contract defines the expected user-visible behavior for AWS YAML editing in the shared Neovim configuration.

## Supported Contexts

| File Context | Expected Assistance | Must Not Do |
|--------------|---------------------|-------------|
| CloudFormation template | AWS-aware completion, template diagnostics, top-level key validation where supported, resource/property diagnostics where supported, fallback lint guidance. | Must not require unrelated YAML files to use CloudFormation rules. |
| SAM template | CloudFormation-related assistance plus documented SAM support level and fallback SAM lint validation. | Must not claim full SAM support unless representative SAM validation passes. |
| Serverless Framework file | Generic YAML support and documented AWS-specific limitations. | Must not attach CloudFormation-only diagnostics to the whole file by default. |
| Generic YAML file | Generic YAML syntax/schema support only. | Must not show CloudFormation/SAM-specific completion or diagnostics by default. |
| Ambiguous YAML file | Generic YAML support and documented manual classification path. | Must not silently assume CloudFormation when markers are absent. |

## Diagnostics Contract

- Diagnostics must make their source understandable enough for the user to distinguish parser errors, generic YAML schema errors, AWS template analysis errors, and fallback linter errors.
- A misspelled CloudFormation top-level key in a supported template must produce an actionable diagnostic when the selected tooling can detect it.
- An invalid CloudFormation resource property in a supported template must produce an actionable diagnostic when the selected tooling can detect it.
- Non-AWS YAML files must remain free from AWS-specific diagnostics by default.

## Completion Contract

- CloudFormation template buffers should expose AWS-relevant completion for template sections, resource types, and resource properties when supported by the active tooling.
- SAM template buffers should expose either verified SAM-aware completion or clear documentation that completion is CloudFormation-oriented with SAM validation handled by fallback checks.
- Completion menus or surrounding documentation must let the user understand which file context is active.

## Failure Contract

- If the YAML parser is blocked or missing, the user must be able to identify it as parser failure rather than AWS language server failure.
- If the AWS language server fails, the editor must remain usable for generic YAML editing and documentation must identify the fallback lint path.
- If optional CloudFormation/SAM lint tools are missing, baseline Neovim startup must still succeed and the dependency documentation must explain how to install or skip them.
- Local macOS security prompts, downloaded language server bundles, and generated parser binaries must not be represented as repository-managed state.

## Validation Contract

The implementation is acceptable only when these representative checks pass:

1. A CloudFormation template opens without startup errors and receives AWS-relevant assistance.
2. A CloudFormation template with at least three intentional mistakes reports actionable diagnostics or has a documented fallback lint result.
3. A SAM template with a SAM transform is classified and its support level is documented.
4. A Serverless Framework file does not receive CloudFormation-only diagnostics by default.
5. At least three non-AWS YAML files open without AWS-specific diagnostic noise.
6. The macOS parser warning class and AWS language server internal error class have documented recovery paths.
