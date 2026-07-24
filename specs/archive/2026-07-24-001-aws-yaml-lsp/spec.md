# Feature Specification: AWS YAML Editor Support

**Feature Branch**: Not created by hook
**Created**: 2026-07-22
**Status**: Draft
**Input**: User description: "Estoy haciendo muchos proyectos, probando, leyendo y poniendo en practica muchos servicios de aws. Por lo que estaba creando un archivo de cloudformation... Quiero poder tener un autocompleatdo, sugerencia, errores, linter etc, para arhcivos de aws... me gustaria que las sugerencias pueda ver yo que ohhh esta suggestion es para arhcivos cloudformation or serverless o sam. Si la manera que yo lo ando haciendo ahorita especifco para un arhivo de lcoudformation y hay otra forma facil y general proponela"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Author AWS Infrastructure Templates With Editor Assistance (Priority: P1)

As the dotfiles owner, I want Neovim to provide useful completion, validation, and diagnostics while I edit AWS infrastructure templates so misspelled keys, invalid resource shapes, and common template mistakes are caught before I run deployment commands.

**Why this priority**: The immediate problem is writing CloudFormation-style YAML safely. Without reliable editor feedback, the user loses confidence and must discover basic mistakes later through slower AWS tooling.

**Independent Test**: Open a representative AWS infrastructure template and confirm the editor provides context-aware suggestions, highlights invalid or misspelled template keys, and reports actionable diagnostics without crashing.

**Acceptance Scenarios**:

1. **Given** a user opens a CloudFormation template, **When** they edit resource declarations and template sections, **Then** the editor offers AWS-relevant completions and reports invalid or misspelled keys.
2. **Given** a template contains a resource property that does not belong to that resource, **When** the file is analyzed, **Then** the editor surfaces a clear diagnostic near the problem.
3. **Given** the editor cannot fully validate a template, **When** the user reviews the file, **Then** they still receive a clear message explaining what validation is unavailable and what fallback check to run.

---

### User Story 2 - Distinguish YAML Contexts Without Polluting Every YAML File (Priority: P1)

As a developer who edits many YAML formats, I want AWS-specific assistance to activate only for AWS infrastructure files so Docker, generic YAML, notes, and unrelated configuration do not receive misleading CloudFormation or SAM suggestions.

**Why this priority**: YAML is shared by many tools. Treating every YAML file as CloudFormation would create noisy suggestions and false diagnostics, which is worse than having no assistance.

**Independent Test**: Open AWS infrastructure templates and non-AWS YAML files, then confirm AWS-specific diagnostics appear only when the file is identified as an AWS template.

**Acceptance Scenarios**:

1. **Given** a YAML file is clearly a CloudFormation or SAM template, **When** it is opened, **Then** AWS-specific assistance activates automatically or through a documented file classification path.
2. **Given** a YAML file is Docker, generic application configuration, notes, or another non-AWS format, **When** it is opened, **Then** AWS-specific completions and diagnostics do not appear by default.
3. **Given** a YAML file could reasonably belong to more than one AWS-related format, **When** suggestions or diagnostics appear, **Then** the user can identify which template context they apply to.

---

### User Story 3 - Recover From Local Tooling and macOS Security Failures (Priority: P2)

As the dotfiles owner, I want editor setup guidance to diagnose local parser, language server, and macOS security failures so startup errors do not block AWS template editing.

**Why this priority**: The reported blocker includes a macOS malware verification prompt for a YAML parser and an internal language server error. The feature is not useful unless failures are understandable and recoverable.

**Independent Test**: Trigger or simulate a missing, blocked, or failing editor dependency and verify the documentation tells the user how to identify the failing component, restore editor startup, and re-run validation.

**Acceptance Scenarios**:

1. **Given** macOS blocks a local editor dependency from loading, **When** Neovim starts, **Then** the user can identify the blocked component and follow documented recovery steps.
2. **Given** the AWS template assistance process exits or reports an internal error, **When** the user checks diagnostics, **Then** they can distinguish editor parser failure from AWS template analysis failure.
3. **Given** recovery steps are followed, **When** the user reopens an AWS template, **Then** the editor starts without repeated startup errors and reports the current assistance state.

---

### User Story 4 - Compare Specific and General AWS YAML Support Paths (Priority: P3)

As the dotfiles owner, I want the final configuration decision to document whether a CloudFormation-specific setup or a broader AWS YAML workflow is the better fit so future maintenance is intentional instead of accidental.

**Why this priority**: The user explicitly asked whether the current CloudFormation-specific direction is too narrow and wants an easier general approach if one exists.

**Independent Test**: Review the resulting documentation or planning notes and confirm they explain the chosen scope, when each AWS template type is supported, and which formats are intentionally excluded or deferred.

**Acceptance Scenarios**:

1. **Given** the user writes CloudFormation templates, **When** they review the setup, **Then** they know whether CloudFormation is supported directly and how to name or classify those files.
2. **Given** the user writes SAM or Serverless Framework files, **When** they review the setup, **Then** they know whether assistance is supported, partially supported, or intentionally deferred.
3. **Given** a future maintainer changes AWS YAML support, **When** they read the documentation, **Then** they can see why the current scope was chosen and what tradeoffs were accepted.

### Edge Cases

- A YAML file has no obvious filename or top-level markers that identify its template type.
- A file contains valid YAML syntax but invalid AWS template structure.
- A template uses AWS-specific intrinsic functions or shorthand syntax that generic YAML tooling may not understand.
- A file mixes AWS template content with framework-specific sections.
- A parser or analysis dependency is installed but blocked by local operating system security policy.
- The language assistance process starts successfully but returns an internal error after opening a file.
- A dependency update changes validation behavior or breaks previously working completion.
- Non-AWS YAML files must remain usable even if AWS template assistance is broken.
- Local downloads, generated binaries, caches, or machine-specific paths must not become shared repository state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The feature MUST define a reliable way to identify AWS infrastructure template files separately from generic YAML and JSON files.
- **FR-002**: The feature MUST provide AWS-relevant completion, validation, and diagnostics for CloudFormation templates.
- **FR-003**: The feature MUST document whether SAM templates are supported, partially supported, or deferred, including the user-visible behavior for each state.
- **FR-004**: The feature MUST document whether Serverless Framework files are supported, partially supported, or deferred, including the user-visible behavior for each state.
- **FR-005**: The feature MUST prevent AWS-specific suggestions and diagnostics from activating by default in unrelated YAML files.
- **FR-006**: The feature MUST make it clear to the user which template context a suggestion or diagnostic belongs to when multiple AWS-related contexts are possible.
- **FR-007**: The feature MUST surface misspelled or invalid top-level template keys in supported AWS template files.
- **FR-008**: The feature MUST surface invalid or unsupported resource properties in supported AWS template files when the selected validation source can identify them.
- **FR-009**: The feature MUST provide a documented fallback validation path for cases where editor assistance cannot fully validate a template.
- **FR-010**: The feature MUST include troubleshooting guidance for local parser failures, language assistance failures, and operating system security prompts.
- **FR-011**: The feature MUST distinguish syntax parsing failures from AWS template analysis failures in user-facing diagnostics or documentation.
- **FR-012**: The feature MUST preserve normal editing behavior for non-AWS YAML formats when AWS template support is unavailable, disabled, or failing.
- **FR-013**: The feature MUST keep downloaded tools, generated files, caches, and machine-specific paths out of shared repository state unless they are explicitly documented as local setup steps.
- **FR-014**: The feature MUST include validation steps that prove the editor can open representative AWS and non-AWS YAML files without startup errors.
- **FR-015**: The feature MUST document the chosen support strategy and tradeoffs between CloudFormation-specific assistance and broader AWS YAML assistance.

### Key Entities

- **AWS Infrastructure Template**: A file intended to define AWS resources or deployment configuration, including CloudFormation, SAM, and possibly Serverless Framework formats.
- **Template Context**: The classification used to decide which suggestions, diagnostics, and validation rules apply to an open file.
- **CloudFormation Template**: An AWS infrastructure template using CloudFormation structure, sections, resource types, properties, and intrinsic functions.
- **SAM Template**: An AWS infrastructure template that extends CloudFormation concepts with serverless application resources and conventions.
- **Serverless Framework File**: A YAML configuration file for serverless service deployment that may overlap with AWS resource configuration but is not identical to CloudFormation.
- **Editor Assistance State**: The visible status of completion, diagnostics, validation, and failure conditions for the current file.
- **Local Tooling Failure**: A parser, language assistance, dependency, or operating system security issue that affects editor behavior on the user's machine.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can open a representative CloudFormation template and receive AWS-relevant completions and diagnostics within 10 seconds of editor startup.
- **SC-002**: At least 3 intentional template mistakes, including a misspelled top-level key and an invalid resource property, are reported as actionable diagnostics in a supported CloudFormation template.
- **SC-003**: Opening at least 3 non-AWS YAML files produces no AWS-specific diagnostics or completion noise by default.
- **SC-004**: A user can determine whether CloudFormation, SAM, and Serverless Framework files are supported, partially supported, or deferred in under 3 minutes from the documentation.
- **SC-005**: A user can identify and begin recovery from a local parser, language assistance, or operating system security failure in under 5 minutes using the troubleshooting guidance.
- **SC-006**: Editor startup succeeds for representative AWS and non-AWS YAML files without repeated internal errors after documented setup and recovery steps are applied.
- **SC-007**: Shared repository files contain no downloaded binaries, generated caches, private machine paths, or local-only security exception state.
- **SC-008**: The chosen AWS YAML support strategy is documented with its tradeoffs so a future maintainer can decide whether to extend, replace, or narrow it without reverse-engineering the setup.

## Assumptions

- The primary editor is Neovim managed through this dotfiles repository.
- The first supported AWS target is CloudFormation because the user's immediate file is a CloudFormation template.
- SAM support is desirable because it is closely related to CloudFormation, but final support level should be verified during planning.
- Serverless Framework support is desirable but may require separate classification or validation because its YAML structure differs from CloudFormation and SAM.
- Generic YAML, Docker files, notes, and unrelated configuration should not receive AWS-specific analysis by default.
- Local installation of editor dependencies may remain a user-machine concern as long as setup, validation, and recovery are documented clearly.
- The reported macOS warning about a YAML parser and the reported internal editor error are treated as troubleshooting scope for this feature.
