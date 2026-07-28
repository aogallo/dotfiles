package installer

import (
	"strings"
	"time"

	"github.com/aogallo/dotfiles/installer/internal/runner"
)

// ExitCode describes process exit status for installer outcomes.
type ExitCode int

const (
	ExitSuccess ExitCode = 0
	ExitFailure ExitCode = 1
)

// Report describes the outcome of an installer run.
type Report struct {
	Flow            Flow
	Items           []ReportItem
	Totals          ReportTotals
	Backups         []BackupRecord
	ManualNextSteps []ManualNextStep
	RawLogs         map[string]RawLog
	ExitCode        ExitCode
}

// ReportItem is one normalized result line in the final report.
type ReportItem struct {
	ModuleID ModuleID
	StepID   string
	Status   ActionStatus
	Message  string
	Details  string
}

// ReportTotals groups status counts for quick rendering.
type ReportTotals struct {
	Changed   int
	Unchanged int
	Skipped   int
	Failed    int
	Cancelled int
	Backup    int
	Manual    int
}

// BackupRecord describes a recoverable user-owned config backup.
type BackupRecord struct {
	ModuleID        ModuleID
	SourceTarget    string
	BackupPath      string
	CreatedByStepID string
	CreatedAt       time.Time
	RestoreGuidance string
}

// ManualNextStep describes guidance that remains outside installer automation.
type ManualNextStep struct {
	ModuleID ModuleID
	StepID   string
	Message  string
	Details  string
}

// RawLog preserves command output for troubleshooting.
type RawLog struct {
	Stdout string
	Stderr string
}

// NewReport creates a report with initialized collections.
func NewReport(flow Flow) Report {
	return Report{Flow: flow, RawLogs: map[string]RawLog{}, ExitCode: ExitSuccess}
}

// BuildReport normalizes planned steps and command output into a final report.
func BuildReport(plan Plan, results map[string]runner.Result) Report {
	report := NewReport(plan.Flow)
	for _, step := range plan.Steps {
		result, hasResult := results[step.ID]
		if hasResult {
			report.RawLogs[step.ID] = RawLog{Stdout: result.Stdout, Stderr: result.Stderr}
		}

		if step.Classification == ActionManualOnly {
			report.addItem(ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusManual, Message: step.Description, Details: "Manual-only; no command was executed."})
			report.ManualNextSteps = append(report.ManualNextSteps, ManualNextStep{ModuleID: step.ModuleID, StepID: step.ID, Message: step.Description})
			continue
		}

		if !hasResult {
			if step.Classification == ActionDryRunReportOnly {
				report.addItem(ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusSkipped, Message: step.Description, Details: "Preview/report step was not executed in this report."})
				continue
			}
			if step.HasCommand() || step.RequiresConfirmation() {
				report.addItem(ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusCancelled, Message: step.Description, Details: "Planned step did not complete. Rerun the installer from a terminal to continue."})
			}
			continue
		}

		for _, item := range normalizeResult(step, result) {
			report.addItem(item)
			if item.Status == StatusBackedUp {
				sourceTarget := backupSourceTarget(step.ModuleID)
				report.Backups = append(report.Backups, BackupRecord{ModuleID: step.ModuleID, SourceTarget: sourceTarget, BackupPath: item.Details, CreatedByStepID: step.ID, RestoreGuidance: restoreGuidance(item.Details, sourceTarget)})
			}
			if item.Status == StatusManual {
				report.ManualNextSteps = append(report.ManualNextSteps, ManualNextStep{ModuleID: step.ModuleID, StepID: step.ID, Message: item.Message, Details: item.Details})
			}
		}
	}
	if report.Totals.Failed > 0 || report.Totals.Cancelled > 0 {
		report.ExitCode = ExitFailure
	}
	return report
}

func backupSourceTarget(moduleID ModuleID) string {
	switch moduleID {
	case ModuleNeovim:
		return "~/.config/nvim"
	case ModuleGhostty:
		return "~/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
	default:
		return "the original local config path"
	}
}

func restoreGuidance(backupPath, sourceTarget string) string {
	if strings.TrimSpace(backupPath) == "" {
		return "Restore manually by moving the backup back to the original target after reviewing the current file."
	}
	return "To restore, review the current file, then move " + backupPath + " back to " + sourceTarget + "."
}

func normalizeResult(step Action, result runner.Result) []ReportItem {
	var items []ReportItem
	output := strings.TrimSpace(result.Stdout + "\n" + result.Stderr)
	if result.ExitCode != 0 {
		if output == "" {
			output = "Command failed without output. Review the failed step and rerun the installer from a terminal after resolving the issue."
		}
		items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusFailed, Message: step.Description, Details: output})
	}
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "backup"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusBackedUp, Message: "Backup created", Details: strings.TrimSpace(strings.TrimPrefix(line, "backup"))})
		case strings.HasPrefix(line, "failed"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusFailed, Message: "Failed", Details: line})
		case strings.Contains(line, "[required]") || strings.Contains(line, "required missing"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusMissing, Message: "Required item missing", Details: line})
		case strings.Contains(line, "optional") || strings.Contains(line, "AWS") || strings.Contains(line, "external"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusOptional, Message: "Optional item", Details: line})
		case strings.Contains(line, "Mason") || strings.HasPrefix(line, "manual"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusManual, Message: "Manual next step", Details: line})
		case strings.Contains(line, "unmanaged") || strings.Contains(line, "conflict"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusUnmanaged, Message: "Unmanaged target detected", Details: line})
		case strings.Contains(line, "repo-managed") || strings.Contains(line, "already links"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusManaged, Message: "Managed target", Details: line})
		case strings.HasPrefix(line, "ok"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusUnchanged, Message: "Validation passed", Details: line})
		case strings.HasPrefix(line, "skip"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusSkipped, Message: "Skipped", Details: line})
		case strings.Contains(line, "removed"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusRemoved, Message: "Removed", Details: line})
		case strings.HasPrefix(line, "run") || strings.Contains(line, "created"):
			items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusChanged, Message: "Changed", Details: line})
		}
	}
	if len(items) == 0 {
		items = append(items, ReportItem{ModuleID: step.ModuleID, StepID: step.ID, Status: StatusUnchanged, Message: step.Description, Details: output})
	}
	return items
}

func (r *Report) addItem(item ReportItem) {
	r.Items = append(r.Items, item)
	switch item.Status {
	case StatusChanged, StatusRemoved:
		r.Totals.Changed++
	case StatusUnchanged, StatusManaged:
		r.Totals.Unchanged++
	case StatusSkipped:
		r.Totals.Skipped++
	case StatusFailed, StatusMissing, StatusUnmanaged:
		r.Totals.Failed++
	case StatusCancelled:
		r.Totals.Cancelled++
	case StatusBackedUp:
		r.Totals.Backup++
	case StatusManual:
		r.Totals.Manual++
	}
}
