# Installer V2 UI Terminal Preview

Generated for PR4 / US4 visual review.

Command used:

```sh
cd /Users/allan/dotfiles/installer && TUI_PREVIEW=1 go test ./internal/tui -run TestTerminalPreviewArtifact -v
```

Preview (ANSI color removed for stable Markdown rendering):

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ dotfiles installer                                                           │
│ Safe mode: dry-run preview only. No setup scripts run until you select and … │
├──────────────────────────────────────────────────────────────────────────────┤
│ › start installation                                                         │
│   sync configs                                                               │
│   Upgrade tools                                                              │
│   quit                                                                       │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ Preview only · No files change before confirmation                           │
│ j/k move • enter select • ? help • q quit • ctrl+c quit                      │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ dotfiles installer                                                                           │
│ Safe mode: dry-run preview only. No setup scripts run until you select and confirm an actio… │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ help                                                                                         │
│ Every status keeps a text label. Color and icons are secondary cues.                         │
│                                                                                              │
│ - Preview: Safe review; no files change before confirmation.                                 │
│ - Automatic: The installer can run this when it is safe.                                     │
│ - Confirmation: A mutating action waits for explicit approval.                               │
│ - Manual action: Automation is unsafe or unreliable; you must do the step.                   │
│ - Skipped: The step was intentionally not executed.                                          │
│ - Failed: The step did not complete and needs recovery.                                      │
│ - Backed up: An existing local file was protected before changes.                            │
│ - Completed: The step finished or was already up to date.                                    │
│                                                                                              │
│ Press q or esc to return.                                                                    │
│                                                                                              │
│                                                                                              │
│                                                                                              │
│                                                                                              │
│                                                                                              │
│                                                                                              │
│                                                                                              │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Preview only · No files change before confirmation                                           │
│ q return • esc return • ctrl+c quit                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```
