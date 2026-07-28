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
│ > start installation                                                         │
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
│ j/k move • enter select • q quit • ctrl+c quit                               │
└──────────────────────────────────────────────────────────────────────────────┘
```
