# Contract: Runner Progress Messages

## Purpose

Defines the message flow between the TUI and command runner so long-running installs show visible progress.

## Message Types

| Message | Required Fields | Meaning |
|---------|-----------------|---------|
| step_started | step ID, module ID, index, total, description, started time | A command-backed step became active |
| step_completed | step ID, result status, stdout summary, stderr summary, exit code, completed time | A step finished and can be normalized into the report |
| step_failed | step ID, error, stderr summary, exit code, completed time | A step failed before or during execution |
| step_skipped | step ID, reason | A non-command or inapplicable step was accounted for |
| install_cancelled | completed count, remaining count | User cancelled or context ended before all work completed |

## Execution Rules

- Steps execute sequentially in plan order.
- Command execution remains shell-free through `runner.Command`.
- The UI updates after each message and before the next command starts.
- Failures are recorded in the final report even if later safe steps continue.
- Cancellation before confirmation executes no mutating steps.
