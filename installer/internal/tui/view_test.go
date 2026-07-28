package tui

import (
	"os"
	"strings"
	"testing"

	"github.com/aogallo/dotfiles/installer/internal/installer"
)

func TestViewShowsRequiredMenuLabelsAndSafeStatus(t *testing.T) {
	view := NewModel().View()

	for _, label := range []string{"start installation", "sync configs", "Upgrade tools", "quit"} {
		if !strings.Contains(view, label) {
			t.Fatalf("view missing menu label %q:\n%s", label, view)
		}
	}

	for _, copy := range []string{"Safe mode", "dry-run preview only", "No setup scripts run until you select and confirm an action"} {
		if !strings.Contains(view, copy) {
			t.Fatalf("view missing safe status copy %q:\n%s", copy, view)
		}
	}

	if !strings.Contains(view, "> start installation") {
		t.Fatalf("view should style the selected item with a marker:\n%s", view)
	}
}

func TestConfirmationViewExplainsChangesBackupsSkippedAndManualActions(t *testing.T) {
	model := NewModel()
	model.screen = ScreenConfirmation
	model.plan = installer.Plan{
		Flow: installer.FlowInstall,
		Steps: []installer.Action{
			{ID: "nvim-link-dry-run", ModuleID: installer.ModuleNeovim, Kind: installer.StepDryRun, Classification: installer.ActionDryRunReportOnly, Description: "Preview repository-managed config linking without changing files."},
			{ID: "nvim-link-backup-apply", ModuleID: installer.ModuleNeovim, Kind: installer.StepBackup, Classification: installer.ActionConfirmationRequired, Description: "Back up any existing local config automatically before linking after you confirm installation."},
			{ID: "nvim-bootstrap-install", ModuleID: installer.ModuleNeovim, Kind: installer.StepInstall, Classification: installer.ActionConfirmationRequired, Description: "Install supported missing Neovim dependencies after confirmation."},
			{ID: "tmux-manual-guidance", ModuleID: installer.ModuleTmux, Kind: installer.StepManualGuidance, Classification: installer.ActionManualOnly, Description: "Install TPM plugins manually."},
		},
	}

	view := model.View()
	for _, want := range []string{
		"Review this before anything changes",
		"What will change:",
		"Install supported missing Neovim dependencies",
		"Automatic backups:",
		"moved to ~/.dotfiles_backup",
		"Skipped or preview-only items:",
		"Preview repository-managed config linking",
		"Manual actions:",
		"Install TPM plugins manually",
		"q to cancel without changing files",
	} {
		if !strings.Contains(view, want) {
			t.Fatalf("confirmation view missing %q:\n%s", want, view)
		}
	}

	for _, internal := range []string{"confirmation_required", "manual_only", "dry_run_report_only"} {
		if strings.Contains(view, internal) {
			t.Fatalf("confirmation view exposes internal label %q:\n%s", internal, view)
		}
	}
}

func TestActionPlanViewUsesPlainLanguageForTargetState(t *testing.T) {
	model := NewModel()
	model.screen = ScreenActionPlan
	model.plan = installer.Plan{ConfigTargets: []installer.ManagedConfigTarget{{
		ModuleID:   installer.ModuleNeovim,
		TargetPath: "~/.config/nvim",
		SourcePath: "repo/nvim",
		BackupPath: "~/.dotfiles_backup/nvim-20260727-120000-1",
		State:      installer.ConfigTargetUnmanaged,
	}}}

	view := model.View()
	for _, want := range []string{"Existing local file; backup needed", "backup planned:"} {
		if !strings.Contains(view, want) {
			t.Fatalf("action plan view missing %q:\n%s", want, view)
		}
	}
}

func TestModuleListDoesNotExposeInternalAutomationLabels(t *testing.T) {
	model := NewModel()
	model.screen = ScreenModuleList
	model.selectedFlow = installer.FlowInstall

	view := model.View()
	for _, want := range []string{"Needs your confirmation", "Preview/report only", "Manual action"} {
		if !strings.Contains(view, want) {
			t.Fatalf("module list missing user-facing label %q:\n%s", want, view)
		}
	}
	for _, internal := range []string{"confirmation_required", "report_only", "manual_only"} {
		if strings.Contains(view, internal) {
			t.Fatalf("module list exposes internal label %q:\n%s", internal, view)
		}
	}
}

func TestViewRendersViewportShellAtTerminalSize(t *testing.T) {
	model := NewModel()
	model.terminal = TerminalSession{Interactive: true, Width: 80, Height: 24}

	view := model.View()
	lines := strings.Split(strings.TrimRight(view, "\n"), "\n")
	if len(lines) != 24 {
		t.Fatalf("line count = %d, want 24:\n%s", len(lines), view)
	}
	for i, line := range lines {
		if visibleLen(line) != 80 {
			t.Fatalf("line %d visible width = %d, want 80: %q", i+1, visibleLen(line), line)
		}
	}
	for _, want := range []string{"dotfiles installer", "Preview only", "j/k move", "enter select"} {
		if !strings.Contains(view, want) {
			t.Fatalf("viewport shell missing %q:\n%s", want, view)
		}
	}
}

func TestRunningViewKeepsCriticalStatusAtNarrowSize(t *testing.T) {
	model := NewModel()
	model.screen = ScreenRunning
	model.terminal = TerminalSession{Interactive: true, Width: 44, Height: 12, Compact: true}
	model.plan = installer.Plan{Steps: []installer.Action{{ID: "nvim-validate", ModuleID: installer.ModuleNeovim, Description: "Validate Neovim dependencies with a deliberately long description that must truncate."}}}
	model.progress = ProgressSession{CurrentStepIndex: 1, TotalSteps: 1, ActiveStepID: "nvim-validate", ActiveDescription: "Validate Neovim dependencies with a deliberately long description that must truncate."}

	view := model.View()
	for _, want := range []string{"Current step", "Status: Working", "Compact layout", "ctrl+c quit"} {
		if !strings.Contains(view, want) {
			t.Fatalf("narrow running view missing %q:\n%s", want, view)
		}
	}
	for i, line := range strings.Split(strings.TrimRight(view, "\n"), "\n") {
		if visibleLen(line) != 44 {
			t.Fatalf("line %d visible width = %d, want 44: %q", i+1, visibleLen(line), line)
		}
	}
}

func TestStatusCueIncludesTextLabelIconAndColor(t *testing.T) {
	tests := []struct {
		status installer.ActionStatus
		label  string
		icon   string
		color  string
	}{
		{status: installer.StatusBackedUp, label: "Backed up", icon: "✓", color: ansiGreen},
		{status: installer.StatusManual, label: "Manual action needed", icon: "!", color: ansiYellow},
		{status: installer.StatusFailed, label: "Failed", icon: "!", color: ansiRed},
		{status: installer.StatusSkipped, label: "Skipped", icon: "•", color: ansiGray},
	}

	for _, tt := range tests {
		t.Run(string(tt.status), func(t *testing.T) {
			cue := statusCueFor(tt.status)
			if cue.Label != tt.label || cue.Icon != tt.icon || cue.Color != tt.color {
				t.Fatalf("cue = %#v, want label=%q icon=%q color=%q", cue, tt.label, tt.icon, tt.color)
			}
			cell := statusCell(tt.status)
			if !strings.Contains(cell, tt.label) || !strings.Contains(cell, tt.icon) || !strings.Contains(cell, tt.color) {
				t.Fatalf("status cell should preserve text, icon, and color: %q", cell)
			}
		})
	}
}

func TestTerminalPreviewArtifact(t *testing.T) {
	if os.Getenv("TUI_PREVIEW") != "1" {
		t.Skip("set TUI_PREVIEW=1 to print the stable terminal preview artifact")
	}

	t.Log("\n" + stripANSI(fullScreenPreview()))
}

func fullScreenPreview() string {
	model := NewModel()
	model.terminal = TerminalSession{Interactive: true, Width: 80, Height: 24}
	return model.View()
}

func stripANSI(value string) string {
	replacer := strings.NewReplacer(
		ansiReset, "",
		ansiDim, "",
		ansiBold, "",
		ansiCyan, "",
		ansiGreen, "",
		ansiYellow, "",
		ansiRed, "",
		ansiBlue, "",
		ansiGray, "",
	)
	return replacer.Replace(value)
}
