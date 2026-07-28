package tui

import (
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
