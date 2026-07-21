# Archive Report: Obsidian Title-Based Filenames

**Archived**: 2026-07-21
**Source Feature**: `specs/002-obsidian-title-filenames`
**Archive Location**: `specs/archive/2026-07-21-002-obsidian-title-filenames`
**Pull Request**: https://github.com/aogallo/dotfiles/pull/32
**Issue**: https://github.com/aogallo/dotfiles/issues/31

## Completion Status

- Specification: Complete
- Plan: Complete
- Tasks: 20/20 complete
- Implementation: Complete
- Validation: Complete
- PR: Opened as #32 with maintainer-approved `size:exception`

## Validation Evidence

- `stylua --check nvim`: passed
- `nvim --headless -u nvim/init.lua '+quitall'`: passed
- `setup/validate-nvim-deps.sh`: required dependencies passed; optional `shfmt` and `shellcheck` remain missing
- Temp-vault smoke: `:Obsidian new AWS CodePipeline` created `aws-codepipeline.md`
- Temp-vault smoke: duplicate title created `aws-codepipeline-2.md`
- Headless keymap assertion confirmed `<leader>nn` with description `New note`

## Archived Artifacts

- `spec.md`
- `plan.md`
- `research.md`
- `data-model.md`
- `contracts/obsidian-note-creation.md`
- `quickstart.md`
- `tasks.md`
- `checklists/requirements.md`

## Notes

- The installed Obsidian.nvim version honors title-based filenames through top-level `note_id_func = require('obsidian.builtin').title_id`.
- The active feature pointer now references this archived directory so downstream review can trace the completed work.
