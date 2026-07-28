package tui

import (
	"fmt"
	"strings"

	"github.com/aogallo/dotfiles/installer/internal/installer"
)

// View renders the installer TUI.
func (m Model) View() string {
	var b strings.Builder

	b.WriteString("dotfiles installer\n")
	b.WriteString("Safe mode: dry-run preview only. No setup scripts run until you select and confirm an action.\n\n")

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
	case ScreenReport:
		b.WriteString("final report\n")
		b.WriteString(fmt.Sprintf("changed=%d unchanged=%d skipped=%d failed=%d not_completed=%d backups=%d manual=%d\n", m.report.Totals.Changed, m.report.Totals.Unchanged, m.report.Totals.Skipped, m.report.Totals.Failed, m.report.Totals.Cancelled, m.report.Totals.Backup, m.report.Totals.Manual))
		for _, item := range m.report.Items {
			b.WriteString(fmt.Sprintf("- [%s] %s", statusLabel(item.Status), item.Message))
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
		b.WriteString("\nUse j/k to move, enter to select, q to quit.\n")
	}

	return b.String()
}

func statusLabel(status installer.ActionStatus) string {
	return status.StatusLabel()
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
	b.WriteString(title + ":\n")
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
