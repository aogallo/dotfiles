# Research: Configuration README Documentation

## Decision: Add a dedicated Tmux README next to `tmux.conf`

**Rationale**: `Tmux/` currently contains only `tmux.conf`, so users must inspect config comments or root README snippets to understand purpose, activation, TPM setup, reload behavior, and key workflows. A local README reduces recall and keeps maintenance near the config.

**Alternatives considered**: Expand the root README; rejected because it would keep tool-specific details far from the file they explain and increase duplication. Add comments only to `tmux.conf`; rejected because activation and validation guidance does not belong entirely inside config syntax.

## Decision: Preserve and refine `nvim/README.md`

**Rationale**: `nvim/README.md` already documents quick validation, dependencies, linking, notifications, local overrides, and Obsidian behavior. The implementation should keep this structure and only adjust wording where it fails to emphasize shared configuration.

**Alternatives considered**: Rewrite the Neovim README from scratch; rejected because the existing doc already follows a useful quick-path structure. Move details to root README; rejected because directory-local docs are easier to maintain.

## Decision: Keep root README high-level unless contradiction removal is required

**Rationale**: The root README currently contains older setup snippets for Tmux and Neovim. The feature goal is focused per-directory documentation, so root changes should be limited to preventing contradictory guidance and pointing users toward directory READMEs when necessary.

**Alternatives considered**: Fully modernize the root README in this feature; rejected because that expands scope beyond Tmux/Neovim directory documentation.

## Decision: Use cognitive-load-first documentation structure

**Rationale**: Readers should see the answer first: what this directory contains, how to activate it, how to validate it, and how to roll back. Details such as plugin behavior and key workflows should come after the quick path.

**Alternatives considered**: Long narrative documentation; rejected because setup docs are used during action and review, not casual reading.

## Decision: Document safe activation rather than automate new behavior

**Rationale**: The spec is documentation-only. Existing setup scripts already cover Neovim linking and dependency validation; Tmux activation can be documented without adding scripts in this change.

**Alternatives considered**: Add a tmux installer/linker script; rejected because it is an implementation feature outside this documentation scope.
