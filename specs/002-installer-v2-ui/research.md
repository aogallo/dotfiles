# Research: Installer V2 UI and Install Flow

## Decision: Keep the existing Go/Bubble Tea installer

**Rationale**: The repo already has an isolated Go 1.22 module with Bubble Tea, tests, a shell-free runner boundary, and installer/domain packages. Reusing it minimizes risk and preserves release assets.

**Alternatives considered**: New GUI app, shell-only installer, rewrite around another TUI framework. Rejected because they increase distribution and safety complexity.

## Decision: Use Bubble Tea alternate screen for full-screen mode

**Rationale**: Bubble Tea supports `tea.WithAltScreen()` for full-window terminal apps and exits the alternate screen automatically. This matches the desired full-screen experience without inventing terminal control logic.

**Alternatives considered**: Plain scrolling output or manual ANSI screen control. Rejected because plain output does not meet the UX goal and manual control is fragile.

## Decision: Drive layout from terminal size messages

**Rationale**: Bubble Tea sends `WindowSizeMsg` on start and resize. Storing width/height in the model lets the view render header, content, progress, and footer for 80x24 and larger terminals.

**Alternatives considered**: Fixed-width rendering only. Rejected because it cannot satisfy full-screen and small-terminal criteria.

## Decision: Execute install steps asynchronously through Bubble Tea messages

**Rationale**: Current execution is synchronous, so `ScreenRunning` does not meaningfully render before the final report. Each command-backed step should run as a `tea.Cmd` and return a completion message, allowing the UI to show active progress between steps.

**Alternatives considered**: Keep synchronous execution and print logs afterward; run all commands concurrently. Rejected because users need live progress and installer steps must preserve order.

## Decision: Preserve ordered, shell-free command execution

**Rationale**: Existing `runner.Command` avoids shell interpolation and `PlanBuilder` enforces preview-before-mutation. V2 should add progress around this boundary, not weaken it.

**Alternatives considered**: Stream arbitrary shell commands or combine steps into one shell script. Rejected for security and testability.

## Decision: Use text labels and colors as primary status indicators; emojis are supplemental

**Rationale**: User wants Bubble Tea-style visual richness and emojis are allowed, but terminal emoji rendering varies. Every status must remain understandable without emoji rendering.

**Alternatives considered**: No emojis; emoji-only statuses. Rejected because no emojis is less expressive than requested and emoji-only breaks accessibility/fallback.

## Decision: Keep setup scripts as behavior source of truth

**Rationale**: Current installer plans approved invocations of existing setup scripts. V2 should improve planning, confirmation, progress, and reporting without duplicating script internals in Go.

**Alternatives considered**: Port setup scripts into Go. Rejected as too broad for UI/UX V2 and risky for existing module behavior.

## Decision: Document direct binary execution and bootstrap execution separately

**Rationale**: The v1.0.0 release asset can be executed from a terminal, but non-terminal launch paths can appear to do nothing. Release-facing docs and fallback output must tell users exactly how to run the artifact.

**Alternatives considered**: Assume users always launch from terminal; ship only bootstrap script. Rejected because the reported issue is direct binary confusion.
