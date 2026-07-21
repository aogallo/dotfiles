# Research: Markdown Notes Formatting

## Decision: Treat Obsidian-style notes folders as Markdown content, not project roots

**Rationale**: Obsidian works with local Markdown files inside a vault and keeps application settings vault-local. A notes folder should not need package manifests or formatter dependencies just to edit and save notes from Neovim.

**Alternatives considered**: Require every notes vault to include `package.json` and Prettier config; rejected because it turns personal notes into a software project and creates avoidable maintenance. Disable Markdown formatting globally; rejected because project documentation still benefits from formatting.

## Decision: Use Conform's dynamic formatter selection for Markdown

**Rationale**: Conform supports `formatters_by_ft` as a function and exposes formatter availability checks. This lets Markdown choose Prettier when the configured project signal exists and choose a safe fallback for notes-only folders.

**Alternatives considered**: Hard-code notes paths; rejected by portability. Keep static `markdown = { 'prettier' }`; rejected because notes-only folders produce disruptive no-formatter behavior. Add a new formatter plugin; rejected because Conform already supports the needed behavior.

## Decision: Keep Prettier behind project/config detection

**Rationale**: The current config already sets `prettier = { require_cwd = true }`, indicating Prettier should not run without a project root. Planning should make that intent explicit for Markdown and prevent no-formatter notifications in notes contexts.

**Alternatives considered**: Run global Prettier everywhere; rejected because it can impose project-style formatting on personal notes. Remove Prettier from Markdown entirely; rejected because configured documentation projects should keep project formatting.

## Decision: Use trim fallback for notes-only Markdown

**Rationale**: Conform's built-in trim formatters are already configured as generic fallbacks. For notes-only Markdown, trimming trailing whitespace/newlines is safe, requires no external project tooling, and avoids save-time errors.

**Alternatives considered**: Skip formatting entirely; acceptable but less consistent. Use `dprint`; rejected as a default fallback because the repo treats it as optional and notes-only folders still may not have project config.

## Decision: Document a lightweight notes-folder recommendation

**Rationale**: The user asked whether the notes folder should contain configuration. The recommended default should be Markdown files plus optional Obsidian vault settings. Formatter config is optional and only needed when the user wants project-style formatting in that vault.

**Alternatives considered**: Document a mandatory `.prettierrc`; rejected because the desired baseline is frictionless note-taking.
