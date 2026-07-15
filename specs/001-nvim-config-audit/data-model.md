# Data Model: Neovim Config Audit

## ConfigurationArea

Represents one audited subsystem or file group.

Fields:
- `id`: Stable slug, such as `lsp-core`, `treesitter`, `mason`, or `formatting`.
- `paths`: Repository-relative paths included in the area.
- `owner`: Logical responsibility, such as core Neovim, plugin manager, LSP, formatting,
  completion, Markdown, Git integration, or installer readiness.
- `status`: One of `not-reviewed`, `correct`, `has-findings`, `blocked`, or `not-applicable`.
- `documentation_sources`: Primary docs used to validate the area.

Validation rules:
- Every discovered area must have at least one path.
- Every completed area must have a non-empty status and evidence source.

## Finding

Represents one audit result.

Fields:
- `id`: Stable identifier, such as `F001`.
- `severity`: `critical`, `high`, `medium`, `low`, or `info`.
- `classification`: `correct`, `improvement`, `risk`, `deprecated`, `incompatible`,
  `missing-dependency`, `portability`, `security`, or `installer-readiness`.
- `path`: Repository-relative file path.
- `lines`: Optional line or range when available.
- `observed`: What the configuration currently does.
- `evidence`: Documentation or code evidence used.
- `impact`: Why the finding matters.
- `recommendation`: Concrete next action.
- `validation`: How to prove the recommendation works.

Validation rules:
- Must-fix findings must include `impact`, `recommendation`, and `validation`.
- Version-sensitive findings must cite a documentation source or state uncertainty.

## Dependency

Represents one external tool, language server, parser, formatter, linter, or CLI used by
the Neovim configuration.

Fields:
- `name`: Human-readable dependency name.
- `executable`: Command expected in PATH when relevant.
- `used_by`: Configuration areas or paths that reference it.
- `source`: `mason`, `external`, `plugin-managed`, `homebrew`, `language-toolchain`,
  `optional`, or `unresolved`.
- `install_hint`: Portable install recommendation or documented manual source.
- `validation_command`: Command or Neovim health check that verifies availability.
- `required`: Boolean indicating whether missing dependency blocks baseline operation.

Validation rules:
- Every executable referenced by `cmd = { ... }` in `nvim/lsp/*.lua` must appear in the
  dependency inventory.
- Dependencies installed outside Mason must include an external validation command.

## InstallationStrategy

Represents how the future dotfiles installer should handle one module or dependency class.

Fields:
- `module`: Tool module, such as `nvim`.
- `operation`: `install`, `update`, `validate`, `remove`, or `rollback`.
- `managed_paths`: Paths the repository would manage.
- `conflict_policy`: How existing user files are detected and handled.
- `backup_policy`: How replacements are backed up and restored.
- `idempotency_check`: How repeated runs avoid duplicate side effects.
- `summary_output`: What the installer reports to the user.

Validation rules:
- Any strategy that replaces a file or link must define conflict and backup policy.
- Any strategy that installs dependencies must define prerequisite validation.

## LocalOverride

Represents private, machine-specific, or work-specific config that must not live in shared
portable configuration.

Fields:
- `purpose`: Why the override exists.
- `example_path`: Template or ignored local path if proposed.
- `sensitive`: Whether it may contain private data.
- `loading_rule`: How shared config discovers or loads it safely.
- `fallback_behavior`: What happens when it is absent.

Validation rules:
- Local overrides must be optional by default.
- Local overrides must not contain real credentials, private keys, or committed secrets.
