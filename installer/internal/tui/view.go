package tui

import (
	"fmt"
	"strings"
)

// View renders the installer TUI.
func (m Model) View() string {
	var b strings.Builder

	b.WriteString("dotfiles installer\n")
	b.WriteString("Safe mode: dry-run preview only. No setup scripts run until you select and confirm an action.\n\n")

	switch m.screen {
	case ScreenFlowInfo, ScreenModuleList:
		b.WriteString(fmt.Sprintf("%s: module list\n", m.selectedFlow))
		for i, module := range m.modules {
			marker := " "
			if i == m.cursor {
				marker = ">"
			}
			b.WriteString(fmt.Sprintf("%s %s — %s\n", marker, module.Name, module.AutomationLevel))
		}
		b.WriteString("\nEnter selects all when Neovim is focused; move to a module for per-module planning. Press q to go back.\n")
	case ScreenActionPlan:
		b.WriteString("action plan\n")
		for _, target := range m.plan.ConfigTargets {
			b.WriteString(fmt.Sprintf("- target [%s] %s -> %s\n", target.State, target.TargetPath, target.SourcePath))
		}
		for _, step := range m.plan.Steps {
			b.WriteString(fmt.Sprintf("- [%s] %s: %s\n", step.Classification, step.ModuleID, step.Description))
		}
		if m.plan.RequiresConfirmation {
			b.WriteString("\nConfirmation is required before mutating steps. Press enter to review confirmation.\n")
		} else {
			b.WriteString("\nNo mutating steps are available without additional explicit confirmation. Press enter to show the safe report.\n")
		}
		b.WriteString("Press q to go back.\n")
	case ScreenConfirmation:
		b.WriteString("confirmation\n")
		b.WriteString("Dry-run/report steps are safe. Mutating install, link, backup, remove, sync, and upgrade steps require explicit confirmation.\n")
		b.WriteString("Press enter to continue to the report, or q to cancel.\n")
	case ScreenRunning:
		b.WriteString("running approved actions...\n")
	case ScreenReport:
		b.WriteString("final report\n")
		b.WriteString(fmt.Sprintf("changed=%d unchanged=%d skipped=%d failed=%d backups=%d manual=%d\n", m.report.Totals.Changed, m.report.Totals.Unchanged, m.report.Totals.Skipped, m.report.Totals.Failed, m.report.Totals.Backup, m.report.Totals.Manual))
		for _, item := range m.report.Items {
			b.WriteString(fmt.Sprintf("- [%s] %s", item.Status, item.Message))
			if item.Details != "" {
				b.WriteString(fmt.Sprintf(" — %s", item.Details))
			}
			b.WriteString("\n")
		}
		for _, backup := range m.report.Backups {
			b.WriteString(fmt.Sprintf("backup: %s\n", backup.BackupPath))
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
		b.WriteString("\nUse j/k to move, enter to select, q to quit.\n")
	}

	return b.String()
}
