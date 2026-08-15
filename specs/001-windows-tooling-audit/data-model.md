# Data Model: Windows Tooling Audit Document

## Audited Tool

Represents a tool, configuration module, setup concern, or repository area evaluated for Windows usage.

| Field | Description | Validation |
|-------|-------------|------------|
| `name` | Published tool name or clear repository module name. | Required; preserve official capitalization where known. |
| `repository_location` | Path or paths used as evidence. | Required; use repository-relative paths. |
| `category` | Tool family such as editor, terminal, shell, multiplexer, keyboard, installer, package/dependency, setup script, generated artifact, or workflow. | Required. |
| `windows_status` | Compatibility classification. | Must be `Compatible`, `Partially compatible`, `Not compatible`, or `Unknown`. |
| `recommended_usage_path` | Practical Windows path such as native Windows, WSL, Git Bash/MSYS2, manual-only, or out of scope. | Required for every audited item. |
| `rationale` | Plain-language reason for the status. | Required; must include repository-specific evidence or a trusted reference. |
| `official_links` | Official or reputable references. | Required when available; otherwise document why not found. |
| `installation_guidance` | How the user could install or activate the tool later. | Required for compatible and partially compatible items; must not say it was installed. |
| `advantages` | Windows-specific benefits of adopting the tool. | At least one for compatible and partially compatible items. |
| `disadvantages` | Windows-specific drawbacks or risks. | At least one for compatible and partially compatible items. |
| `repo_caveats` | macOS assumptions, paths, shell differences, generated state, local-only settings, or manual-only boundaries found in the repository. | Required when evidence exists. |
| `audit_notes` | Short reviewer notes, exclusions, or confidence comments. | Optional. |

## Compatibility Status

| Status | Meaning | Allowed Follow-Up |
|--------|---------|-------------------|
| `Compatible` | Usable on Windows with a supported native Windows installation path and no major repository-specific blocker. | Document install choices and any config adaptation. |
| `Partially compatible` | Usable only with caveats, a subsystem, manual adaptation, or reduced functionality. | Explain the exact boundary and recommended path. |
| `Not compatible` | Not practical or not supported on Windows for this repository context. | Explain why and identify alternatives only when directly useful. |
| `Unknown` | Insufficient trustworthy evidence found during the audit. | Include what evidence is missing and avoid guessing. |

## Installation Reference

Represents a trusted source or manual path the user can follow later.

| Field | Description | Validation |
|-------|-------------|------------|
| `tool_name` | Tool the reference belongs to. | Required. |
| `reference_type` | Official docs, release page, package manager docs, project repository, or reputable fallback. | Required. |
| `url` | Link to the source. | Required unless no suitable link exists. |
| `windows_method` | Manual download, winget, Scoop, Chocolatey, WSL package manager, Git clone, app installer, or manual import. | Required for compatible and partially compatible tools. |
| `trust_note` | Why the source is suitable. | Required for non-official references. |

## Portability Concern

Represents a repository-specific issue that affects Windows usage.

| Field | Description | Validation |
|-------|-------------|------------|
| `source_path` | Repository file or module where the concern appears. | Required. |
| `concern_type` | Path, shell, package manager, terminal capability, clipboard, font, keyboard hardware, release target, security/local state, or generated artifact. | Required. |
| `description` | What may not translate directly to Windows. | Required. |
| `impact` | How it affects Windows usage. | Required. |
| `recommended_handling` | Native adaptation, WSL path, manual step, future spec, or mark unsupported. | Required. |

## Relationships

- One `Audited Tool` can have many `Installation Reference` entries.
- One `Audited Tool` can have many `Portability Concern` entries.
- One `Portability Concern` can apply to multiple tools when the same repository assumption affects multiple modules.

## State Transitions

```text
Discovered -> Audited -> Classified -> Documented -> Verified
```

- `Discovered`: Tool or module appears in repository evidence.
- `Audited`: Relevant files and trusted references were reviewed.
- `Classified`: Windows status and usage path were assigned.
- `Documented`: The final audit includes summary and detail entries.
- `Verified`: The quickstart checks confirm coverage, links, and non-destructive scope.
