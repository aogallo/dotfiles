# Contract: TUI State and Rendering

## Purpose

Defines what the installer UI must expose to users on every screen.

## Screens

| Screen | Required Content | Required Actions |
|--------|------------------|------------------|
| Main menu | Product title, safe/preview state, install/sync/upgrade/quit choices | Move selection, select, quit |
| Module list | Selected flow, modules, automation explanation in user language | Move selection, select all/current, back |
| Action plan | Planned files/tools, preview/mutating/manual grouping, backup summary | Continue, back/cancel |
| Confirmation | Plain-language change summary, backup behavior, skipped/manual items | Confirm, cancel |
| Running | Current step, overall count, progress/waiting indicator, recent result | Cancel where safe |
| Report | Totals, backups, manual actions, failures, recovery guidance | Return, quit |

## Status Semantics

Every status MUST include a text label. Color and emoji MAY supplement the label.

| Canonical Status | User Label | Severity |
|------------------|------------|----------|
| safe preview | Preview only | info |
| pending change | Will change | warning |
| active work | Working | info |
| success | Complete | success |
| skipped | Skipped | neutral |
| manual | Manual action | warning |
| failed | Failed | error |
| backed up | Backed up | success |
| cancelled | Cancelled | warning |

## Layout Requirements

- The UI MUST render header, content, progress/status, and footer regions when terminal size allows.
- At 80x24, critical labels, current action, and footer shortcuts MUST remain visible.
- If full-screen or color support is unavailable, output MUST remain readable as plain text.
