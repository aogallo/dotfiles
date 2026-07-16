---
description: Verify implementation against the active Spec Kit spec, plan, tasks, and quickstart
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before verification)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_verify` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable.
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Verification Steps.
    ```
    After emitting the block above you MUST actually invoke the hook and wait for it to finish before continuing.
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently.

## Goal

Verify that the implementation satisfies the active Spec Kit feature artifacts before commit or PR.

This command is **verification-only**: do not implement missing work. If gaps are found, report them and recommend returning to `/speckit.implement`.

## Verification Steps

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root.
   - Parse `FEATURE_DIR` and `AVAILABLE_DOCS`.
   - Derive absolute paths:
     - `SPEC = FEATURE_DIR/spec.md`
     - `PLAN = FEATURE_DIR/plan.md`
     - `TASKS = FEATURE_DIR/tasks.md`
     - `QUICKSTART = FEATURE_DIR/quickstart.md`
     - `VERIFY_REPORT = FEATURE_DIR/verify-report.md`
   - Abort if `spec.md`, `plan.md`, or `tasks.md` is missing.

2. Load verification context:
   - Required: `spec.md`, `plan.md`, `tasks.md`
   - If present: `quickstart.md`, `research.md`, `data-model.md`, `contracts/`
   - If present: `.specify/memory/constitution.md`

3. Check checklist readiness:
   - If `FEATURE_DIR/checklists/` exists, scan every checklist file.
   - Count total, completed, and incomplete checkbox items.
   - Verification fails if any checklist has incomplete items.

4. Check task readiness:
   - Parse every `- [ ] T###` and `- [x] T###` item in `tasks.md`.
   - Verification fails if implementation or validation tasks are incomplete.
   - PR-only tasks may remain incomplete when no PR is being created yet. Treat tasks whose description explicitly says `Before PR creation`, `PR creation`, or `ask whether that spec should be closed` as deferrable.
   - Report deferrable PR-only tasks separately.

5. Run validation commands:
   - Prefer commands listed in `quickstart.md`.
   - For this dotfiles/Neovim workflow, run at minimum:
     ```bash
     stylua --check nvim/lua/statusline.lua --config-path nvim/stylua.toml
     ```
   - If safe, run an isolated headless Neovim smoke check for the changed module.
   - Do not require full interactive UI validation unless it is still marked incomplete in `tasks.md`; if the user already marked it complete, record that as manual evidence.

6. Validate against spec and constitution:
   - Map completed work to functional requirements and success criteria.
   - Confirm no constitution MUST-level rule is violated.
   - Confirm branch/PR governance is either complete or explicitly deferred to PR creation.

7. Write `verify-report.md` in the active feature directory with this structure:

   ```markdown
   # Verify Report: [FEATURE]

   ## Status
   Passed | Failed

   ## Summary
   [Concise result]

   ## Artifact Checks
   - Spec: passed/failed
   - Plan: passed/failed
   - Tasks: passed/failed
   - Checklists: passed/failed

   ## Task Status
   - Completed: N
   - Incomplete blocking: N
   - Deferred PR-only: N

   ## Validation Results
   - [command] — passed/failed

   ## Requirement Coverage
   - FR-001 — passed/failed/evidence
   - SC-001 — passed/failed/evidence

   ## Constitution Gate
   [Pass/fail with notes]

   ## Risks / Follow-ups
   - [Remaining issue or `None`]
   ```

8. Report completion to the user:
   - `VERIFY_REPORT` path
   - Passed/failed status
   - Blocking issues, if any
   - Deferred PR-only tasks, if any
   - Recommended next command/action

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

Check if `.specify/extensions.yml` exists in the project root.
- If it does not exist, or no hooks are registered under `hooks.after_verify`, skip to the Completion Report.
- If it exists, read it and look for entries under the `hooks.after_verify` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue to the Completion Report.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable.
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation.
- For each executable hook, output the following based on its `optional` flag:
  - **Mandatory hook** (`optional: false`) — **You MUST emit `EXECUTE_COMMAND:` for each mandatory hook**:
    ```
    ## Extension Hooks

    **Automatic Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    ```
    After emitting the block above you MUST actually invoke the hook and wait for it to finish before continuing.
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```

## Completion Report

Report:
- `VERIFY_REPORT` path
- Verification status
- Validation commands run
- Remaining blocking tasks, if any
- Deferred PR-only tasks, if any
- Recommended next action
