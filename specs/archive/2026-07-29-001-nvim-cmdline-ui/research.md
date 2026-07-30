# Research: Neovim Command-Line UI

## Decision: Use Noice as the primary command-line and message UI provider, pending user approval

**Rationale**: Noice directly targets the requested surface area: command-line replacement, command popupmenu, message routing, notification routing, and LSP progress. Its documented `cmdline_popup` and `popupmenu` views allow explicit width, position, border, and highlight configuration, which directly addresses the disliked narrow options list. It also handles `:messages`, errors, warnings, and LSP progress in one routing model.

**Alternatives considered**:

- **Dressing**: Rejected. The repository is archived as of 2025-02-12 and its own README recommends Snacks for `vim.ui.*`. It targets `vim.ui.input` and `vim.ui.select`, not real command-line mode or message routing.
- **Snacks only**: Rejected for command-line replacement. Snacks is already installed and useful for `input`, `notifier`, picker/history, explorer, and lazygit. It does not replace Neovim command-line mode. Using Snacks only would not satisfy the floating command-line and full-width command options requirements.
- **Fidget only**: Rejected for command-line replacement. Fidget is strong for LSP progress and notifications but does not replace the command line or command popupmenu.
- **Custom command-line UI**: Rejected initially. A custom implementation would be high-maintenance and risk incomplete command-line semantics, history, search, cancellation, and completion behavior.
- **Noice plus Fidget**: Deferred. This could create overlapping LSP progress and notification surfaces. Consider only if Noice command-line behavior is approved but Noice LSP progress fails the expected unobtrusive progress style.

## Decision: Keep Snacks installed, but avoid overlapping notification ownership

**Rationale**: Snacks already provides active value in this repo: `input`, `notifier`, explorer, lazygit, picker support, and notification history integration. Removing it just because Noice is added would be too broad. However, the implementation must avoid two active notification backends fighting over `vim.notify` or showing duplicate messages.

**Alternatives considered**:

- **Disable all Snacks modules**: Rejected because unrelated useful modules would be removed.
- **Disable only Snacks notifier immediately**: Deferred until implementation testing. If Noice notification view depends on another backend or duplicates Snacks output, disable Snacks notifier or route Noice notifications away from it deliberately.
- **Keep current custom wrapper unchanged**: Risky. The wrapper captures history and normalizes icons/titles, but it also wraps `vim.notify`. Implementation must verify it does not conflict with Noice's notify route.

## Decision: Configure the command popupmenu width explicitly

**Rationale**: The user specifically rejected the UI where options render in a narrow list under a wider command input. Noice supports separate `cmdline_popup` and `popupmenu` views with explicit width and position. The plan should make command input and popupmenu share the same intended width and alignment.

**Alternatives considered**:

- **Use Noice defaults**: Rejected because defaults may reproduce a detached/narrow popupmenu layout.
- **Use completion engine command-line completion**: Deferred. `blink.cmp` currently disables `cmdline`; Noice's popupmenu should own regular command-line completions first to minimize insert-mode completion risk.
- **Build a custom popupmenu**: Rejected initially as unnecessary unless Noice cannot meet the width/alignment contract.

## Decision: Treat Fidget as an LSP-progress reference, not the default implementation

**Rationale**: Fidget's README describes exactly the kind of unobtrusive floating LSP progress the user likes: a corner-managed UI for `$/progress`, configurable notification backend, history, and clearing behavior. Current Fidget releases require Neovim 0.11.3 for full functionality, and adding it alongside Noice could duplicate LSP progress. It is valuable as a visual and behavioral benchmark, but Noice should first be evaluated because it already includes LSP progress routing.

**Alternatives considered**:

- **Install Fidget immediately**: Rejected for initial plan because it increases dependency overlap.
- **Use Fidget for all notifications**: Rejected because Snacks notifier is already active and Noice can route notifications/messages.
- **Use Noice LSP progress first**: Recommended. If it fails the expected behavior, the follow-up choice is either tune Noice progress view or add Fidget and disable Noice LSP progress.

## Decision: Preserve statusline mode as the command-mode indicator

**Rationale**: The current custom statusline already renders `COMMAND` mode. The feature goal is to remove duplicated bottom command-line information, not replace the statusline.

**Alternatives considered**:

- **Show command mode only in command popup**: Rejected because the user explicitly likes the statusline mode indicator.
- **Remove statusline command mode**: Rejected as opposite of the requested behavior.

## Approval Gate Before Implementation

Recommended implementation direction for user approval:

1. Add Noice for cmdline popup, command popupmenu, messages, and initial LSP progress.
2. Add/tune Noice views so `cmdline_popup` and `popupmenu` share the same width and visual anchor.
3. Keep Snacks for current non-conflicting modules and history fallback.
4. During implementation testing, either integrate current notification wrapper with Noice or disable the conflicting provider so only one backend owns visible notifications.
5. Do not add Fidget unless Noice LSP progress is visually or behaviorally insufficient after testing.

Implementation must stop for user approval before code changes if this recommendation has not been explicitly accepted.
