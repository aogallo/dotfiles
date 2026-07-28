package tui

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/aogallo/dotfiles/installer/internal/installer"
)

const (
	ansiReset  = "\x1b[0m"
	ansiDim    = "\x1b[2m"
	ansiBold   = "\x1b[1m"
	ansiCyan   = "\x1b[36m"
	ansiGreen  = "\x1b[32m"
	ansiYellow = "\x1b[33m"
	ansiRed    = "\x1b[31m"
	ansiBlue   = "\x1b[34m"
	ansiGray   = "\x1b[90m"
)

const (
	minWidth = 40
)

type viewRegions struct {
	header  string
	content string
	status  string
	footer  string
}

type statusCue struct {
	Label string
	Icon  string
	Color string
}

// View renders the installer TUI.
func (m Model) View() string {
	regions := m.regions()
	return renderLayout(regions, m.terminal)
}

func (m Model) regions() viewRegions {
	var b strings.Builder

	header := styled("dotfiles installer", ansiBold+ansiCyan) + "\n" + styled("Safe mode: dry-run preview only. No setup scripts run until you select and confirm an action.", ansiDim)
	footer := footerForScreen(m.screen)
	status := statusForModel(m)

	switch m.screen {
	case ScreenStartupError:
		b.WriteString("The installer could not start interactively.\n")
		if m.startupError.Reason != "" {
			b.WriteString(fmt.Sprintf("Reason: %s\n", m.startupError.Reason))
		}
		if m.startupError.Details != "" {
			b.WriteString(fmt.Sprintf("Details: %s\n", m.startupError.Details))
		}
		if m.startupError.Command != "" {
			b.WriteString("Run it from a terminal with:\n")
			b.WriteString(fmt.Sprintf("  %s\n", m.startupError.Command))
		}
		b.WriteString("If macOS blocks the file, remove quarantine only for a trusted release asset or use the bootstrap --prefer-binary path documented in installer/README.md.\n")
	case ScreenFlowInfo, ScreenModuleList:
		b.WriteString(fmt.Sprintf("%s: module list\n", m.selectedFlow))
		for i, module := range m.modules {
			marker := " "
			if i == m.cursor {
				marker = ">"
			}
			b.WriteString(fmt.Sprintf("%s %s — %s\n", marker, module.Name, automationLevelLabel(module.AutomationLevel)))
		}
		b.WriteString("\nEnter selects all when Neovim is focused; move to a module for per-module planning. Press q to go back.\n")
	case ScreenActionPlan:
		b.WriteString("action plan\n")
		for _, target := range m.plan.ConfigTargets {
			b.WriteString(fmt.Sprintf("- target [%s] %s -> %s\n", configTargetStateLabel(target.State), target.TargetPath, target.SourcePath))
			if target.BackupPath != "" {
				b.WriteString(fmt.Sprintf("  backup planned: %s\n", target.BackupPath))
			}
		}
		for _, step := range m.plan.Steps {
			b.WriteString(fmt.Sprintf("- [%s] %s: %s\n", step.Classification.ClassificationLabel(), step.ModuleID, step.Description))
		}
		if m.plan.RequiresConfirmation {
			b.WriteString("\nConfirmation is required before mutating steps. Press enter to review confirmation.\n")
		} else {
			b.WriteString("\nNo mutating steps are available without additional explicit confirmation. Press enter to show the safe report.\n")
		}
		b.WriteString("Press q to go back.\n")
	case ScreenConfirmation:
		b.WriteString("confirmation\n")
		b.WriteString("Review this before anything changes. Press enter only if you want the installer to continue.\n\n")
		renderConfirmationSummary(&b, m.plan)
		b.WriteString("\nPress enter to confirm and run the approved actions, or q to cancel without changing files.\n")
	case ScreenRunning:
		b.WriteString("running approved actions...\n")
		completed := m.progress.CompletedSteps
		total := m.progress.TotalSteps
		if total == 0 {
			total = len(m.plan.Steps)
		}
		b.WriteString(fmt.Sprintf("Overall progress: %d of %d steps complete\n", completed, total))
		if m.progress.ActiveStepID != "" {
			b.WriteString(fmt.Sprintf("Current step: %d of %d — %s\n", m.progress.CurrentStepIndex, total, m.progress.ActiveDescription))
			b.WriteString(fmt.Sprintf("Status: Working (%s)\n", m.progress.ActiveStepID))
		} else if completed < total {
			b.WriteString("Status: Preparing the next step.\n")
		} else {
			b.WriteString("Status: Finalizing report.\n")
		}
		if len(m.progress.RecentResults) > 0 {
			b.WriteString("Recent results:\n")
			for _, result := range m.progress.RecentResults {
				b.WriteString(fmt.Sprintf("- [%s] %s", statusCell(result.Status), result.Message))
				if result.Details != "" {
					b.WriteString(fmt.Sprintf(" — %s", result.Details))
				}
				b.WriteString("\n")
			}
		}
		if len(m.progress.IncompleteStepIDs) > 0 {
			b.WriteString(fmt.Sprintf("Remaining steps: %d\n", len(m.progress.IncompleteStepIDs)))
		}
		b.WriteString("If a step fails, the final report will show the reason and recovery guidance.\n")
	case ScreenReport:
		b.WriteString("final report\n")
		b.WriteString(fmt.Sprintf("changed=%d unchanged=%d skipped=%d failed=%d not_completed=%d backups=%d manual=%d\n", m.report.Totals.Changed, m.report.Totals.Unchanged, m.report.Totals.Skipped, m.report.Totals.Failed, m.report.Totals.Cancelled, m.report.Totals.Backup, m.report.Totals.Manual))
		for _, item := range m.report.Items {
			b.WriteString(fmt.Sprintf("- [%s] %s", statusCell(item.Status), item.Message))
			if item.Details != "" {
				b.WriteString(fmt.Sprintf(" — %s", item.Details))
			}
			b.WriteString("\n")
		}
		for _, backup := range m.report.Backups {
			b.WriteString(fmt.Sprintf("backup: %s\n", backup.BackupPath))
			if backup.RestoreGuidance != "" {
				b.WriteString(fmt.Sprintf("restore: %s\n", backup.RestoreGuidance))
			}
		}
		for _, next := range m.report.ManualNextSteps {
			b.WriteString(fmt.Sprintf("manual: %s\n", next.Message))
		}
		b.WriteString("Press enter to return to the main menu, or q to go back.\n")
	default:
		for i, item := range m.menuItems {
			marker := " "
			if i == m.cursor {
				marker = ">"
			}
			b.WriteString(fmt.Sprintf("%s %s\n", marker, item.Label))
		}
	}

	return viewRegions{header: header, content: b.String(), status: status, footer: footer}
}

func statusCell(status installer.ActionStatus) string {
	cue := statusCueFor(status)
	label := cue.Label
	if cue.Icon != "" {
		label = cue.Icon + " " + label
	}
	return styled(label, cue.Color)
}

func statusCueFor(status installer.ActionStatus) statusCue {
	switch status {
	case installer.StatusChanged, installer.StatusRemoved:
		return statusCue{Label: status.StatusLabel(), Icon: "◆", Color: ansiYellow}
	case installer.StatusUnchanged, installer.StatusManaged, installer.StatusBackedUp:
		return statusCue{Label: status.StatusLabel(), Icon: "✓", Color: ansiGreen}
	case installer.StatusFailed, installer.StatusMissing, installer.StatusUnmanaged:
		return statusCue{Label: status.StatusLabel(), Icon: "!", Color: ansiRed}
	case installer.StatusCancelled, installer.StatusManual:
		return statusCue{Label: status.StatusLabel(), Icon: "!", Color: ansiYellow}
	case installer.StatusSkipped, installer.StatusOptional:
		return statusCue{Label: status.StatusLabel(), Icon: "•", Color: ansiGray}
	default:
		return statusCue{Label: status.StatusLabel(), Icon: "?", Color: ansiBlue}
	}
}

func renderConfirmationSummary(b *strings.Builder, plan installer.Plan) {
	writeStepSection(b, "What will change", plan.Steps, func(step installer.Action) bool {
		return step.RequiresConfirmation() && step.Kind != installer.StepBackup
	}, "No non-backup changes are planned.")

	writeStepSection(b, "Automatic backups", plan.Steps, func(step installer.Action) bool {
		return step.Kind == installer.StepBackup
	}, "No existing local config files need automatic backup.")
	b.WriteString("Existing files replaced by backup-capable steps are moved to ~/.dotfiles_backup before linking. Backup paths are kept distinct so an earlier backup is not overwritten.\n")

	writeStepSection(b, "Skipped or preview-only items", plan.Steps, func(step installer.Action) bool {
		return step.Classification == installer.ActionDryRunReportOnly
	}, "No preview-only items are planned.")

	writeStepSection(b, "Manual actions", plan.Steps, func(step installer.Action) bool {
		return step.Classification == installer.ActionManualOnly
	}, "No manual actions are currently planned.")
}

func writeStepSection(b *strings.Builder, title string, steps []installer.Action, include func(installer.Action) bool, empty string) {
	b.WriteString(styled(title+":", ansiBold) + "\n")
	wrote := false
	for _, step := range steps {
		if !include(step) {
			continue
		}
		wrote = true
		b.WriteString(fmt.Sprintf("- %s: %s\n", step.ModuleID, step.Description))
	}
	if !wrote {
		b.WriteString("- " + empty + "\n")
	}
	b.WriteString("\n")
}

func renderLayout(regions viewRegions, terminal TerminalSession) string {
	if terminal.Width <= 0 || terminal.Height <= 0 {
		return renderPlainLayout(regions)
	}

	width := terminal.Width
	if width < minWidth {
		width = minWidth
	}
	height := terminal.Height
	if height < 8 {
		height = 8
	}

	innerWidth := width - 4
	contentHeight := height - 8
	if contentHeight < 1 {
		contentHeight = 1
	}

	var b strings.Builder
	b.WriteString("┌" + strings.Repeat("─", width-2) + "┐\n")
	writeBoxLines(&b, splitAndFit(regions.header, innerWidth, 2), innerWidth)
	b.WriteString("├" + strings.Repeat("─", width-2) + "┤\n")
	writeBoxLines(&b, fitLines(splitLines(regions.content), innerWidth, contentHeight), innerWidth)
	b.WriteString("├" + strings.Repeat("─", width-2) + "┤\n")
	writeBoxLines(&b, splitAndFit(regions.status, innerWidth, 1), innerWidth)
	writeBoxLines(&b, splitAndFit(regions.footer, innerWidth, 1), innerWidth)
	b.WriteString("└" + strings.Repeat("─", width-2) + "┘\n")
	return b.String()
}

func renderPlainLayout(regions viewRegions) string {
	var b strings.Builder
	b.WriteString(regions.header)
	b.WriteString("\n\n")
	b.WriteString(regions.content)
	b.WriteString("\n")
	b.WriteString(regions.status)
	b.WriteString("\n")
	b.WriteString(regions.footer)
	b.WriteString("\n")
	return b.String()
}

func splitAndFit(value string, width, maxLines int) []string {
	return fitLines(splitLines(value), width, maxLines)
}

func splitLines(value string) []string {
	value = strings.TrimRight(value, "\n")
	if value == "" {
		return []string{""}
	}
	return strings.Split(value, "\n")
}

func fitLines(lines []string, width, maxLines int) []string {
	if maxLines < 1 {
		maxLines = 1
	}
	fitted := make([]string, 0, maxLines)
	for _, line := range lines {
		if len(fitted) >= maxLines {
			break
		}
		fitted = append(fitted, truncateVisible(line, width))
	}
	for len(fitted) < maxLines {
		fitted = append(fitted, "")
	}
	return fitted
}

func writeBoxLines(b *strings.Builder, lines []string, width int) {
	for _, line := range lines {
		b.WriteString("│ ")
		b.WriteString(line)
		padding := width - visibleLen(line)
		if padding > 0 {
			b.WriteString(strings.Repeat(" ", padding))
		}
		b.WriteString(" │\n")
	}
}

func truncateVisible(value string, width int) string {
	if visibleLen(value) <= width {
		return value
	}
	if width <= 1 {
		return "…"
	}
	plainBudget := width - 1
	var out strings.Builder
	visible := 0
	for len(value) > 0 && visible < plainBudget {
		if strings.HasPrefix(value, "\x1b[") {
			end := strings.IndexByte(value, 'm')
			if end >= 0 {
				out.WriteString(value[:end+1])
				value = value[end+1:]
				continue
			}
		}
		r, size := utf8.DecodeRuneInString(value)
		if r == utf8.RuneError && size == 0 {
			break
		}
		out.WriteRune(r)
		visible++
		value = value[size:]
	}
	out.WriteString("…")
	if strings.Contains(out.String(), "\x1b[") {
		out.WriteString(ansiReset)
	}
	return out.String()
}

func visibleLen(value string) int {
	visible := 0
	for len(value) > 0 {
		if strings.HasPrefix(value, "\x1b[") {
			end := strings.IndexByte(value, 'm')
			if end >= 0 {
				value = value[end+1:]
				continue
			}
		}
		_, size := utf8.DecodeRuneInString(value)
		if size == 0 {
			break
		}
		visible++
		value = value[size:]
	}
	return visible
}

func styled(value, style string) string {
	if style == "" || value == "" {
		return value
	}
	return style + value + ansiReset
}

func footerForScreen(screen Screen) string {
	switch screen {
	case ScreenConfirmation:
		return "enter confirm/run • q cancel without changing files • ctrl+c quit"
	case ScreenRunning:
		return "working sequentially • ctrl+c quit • final report shows recovery guidance"
	case ScreenReport:
		return "enter main menu • q back/quit • ctrl+c quit"
	case ScreenModuleList, ScreenFlowInfo:
		return "j/k move • enter select • q back • ctrl+c quit"
	case ScreenStartupError:
		return "open Terminal and rerun the command shown above"
	default:
		return "j/k move • enter select • q quit • ctrl+c quit"
	}
}

func statusForModel(m Model) string {
	if m.terminal.Compact {
		return styled("Compact layout", ansiYellow) + " · critical actions and labels remain visible"
	}
	switch m.screen {
	case ScreenRunning:
		completed := m.progress.CompletedSteps
		total := m.progress.TotalSteps
		if total == 0 {
			total = len(m.plan.Steps)
		}
		return fmt.Sprintf("%s · Overall progress: %d/%d", styled("Working", ansiBlue), completed, total)
	case ScreenReport:
		if m.report.Totals.Failed > 0 || m.report.Totals.Cancelled > 0 {
			return statusCell(installer.StatusFailed) + " · Review recovery guidance"
		}
		return statusCell(installer.StatusUnchanged) + " · Final report ready"
	case ScreenStartupError:
		return statusCell(installer.StatusFailed) + " · Interactive startup blocked"
	default:
		return styled("Preview only", ansiBlue) + " · No files change before confirmation"
	}
}

func configTargetStateLabel(state installer.ConfigTargetState) string {
	switch state {
	case installer.ConfigTargetMissing:
		return "Missing; the installer can create it"
	case installer.ConfigTargetManaged:
		return "Already managed by this repo"
	case installer.ConfigTargetUnmanaged:
		return "Existing local file; backup needed"
	case installer.ConfigTargetBrokenSymlink:
		return "Broken link; backup needed"
	default:
		return "Needs manual review"
	}
}

func automationLevelLabel(level installer.AutomationLevel) string {
	switch level {
	case installer.AutomationAutomatic:
		return "Automatic when safe"
	case installer.AutomationConfirmationRequired:
		return "Needs your confirmation"
	case installer.AutomationReportOnly:
		return "Preview/report only"
	case installer.AutomationManualOnly:
		return "Manual action"
	default:
		return "Needs review"
	}
}
