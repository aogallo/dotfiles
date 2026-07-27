package installer

import (
	"strings"
	"testing"

	"github.com/aogallo/dotfiles/installer/internal/runner"
)

func TestBuildReportNormalizesStatusesBackupsLogsAndExitCode(t *testing.T) {
	t.Parallel()

	plan, err := BuildPlan(FlowInstall, []ModuleID{ModuleNeovim, ModuleZsh, ModuleGhostty, ModuleTmux, ModuleKeyboard, ModuleMacOS}, "../../..")
	if err != nil {
		t.Fatalf("BuildPlan() error = %v", err)
	}

	results := map[string]runner.Result{
		"nvim-validate":          {Stdout: "missing  TypeScript native preview (tsgo) [required]\noptional AWS SAM CLI (sam) [missing, non-blocking]\n", ExitCode: 1},
		"nvim-bootstrap-dry-run": {Stdout: "manual   JSON language server: install via Mason\nmanual   AWS CloudFormation language server: Download bundle\n", ExitCode: 0},
		"ghostty-link-dry-run":   {Stdout: "State: unmanaged\nskip     backup required before apply\n", ExitCode: 0},
		"ghostty-link-apply":     {Stdout: "backup   /tmp/config.ghostty-1\nSummary: 1 changed, 0 skipped, 0 failed\n", ExitCode: 0},
	}

	report := BuildReport(plan, results)

	if report.Totals.Failed == 0 || report.ExitCode != ExitFailure {
		t.Fatalf("failed total=%d exit=%d, want failure exit", report.Totals.Failed, report.ExitCode)
	}
	for _, status := range []ActionStatus{StatusMissing, StatusOptional, StatusManual, StatusUnmanaged, StatusBackedUp} {
		if !reportHasStatus(report, status) {
			t.Fatalf("report missing status %q in %#v", status, report.Items)
		}
	}
	if len(report.Backups) != 1 || report.Backups[0].BackupPath != "/tmp/config.ghostty-1" {
		t.Fatalf("Backups = %#v, want parsed backup path", report.Backups)
	}
	if len(report.ManualNextSteps) == 0 {
		t.Fatal("ManualNextSteps should include manual-only and report-only guidance")
	}
	if !strings.Contains(report.RawLogs["nvim-validate"].Stdout, "tsgo") {
		t.Fatalf("raw logs did not preserve command stdout: %#v", report.RawLogs)
	}
}

func TestBuildUpgradeReportNormalizesToolCategories(t *testing.T) {
	t.Parallel()

	plan := Plan{
		Flow: FlowUpgrade,
		Steps: []Action{
			{ID: "nvim-upgrade-supported", ModuleID: ModuleNeovim, Kind: StepUpgrade, Classification: ActionConfirmationRequired, Description: "Upgrade supported Neovim dependencies."},
			{ID: "nvim-upgrade-preview", ModuleID: ModuleNeovim, Kind: StepDryRun, Classification: ActionDryRunReportOnly, Description: "Preview Neovim upgrades."},
			{ID: "tmux-manual-guidance", ModuleID: ModuleTmux, Kind: StepManualGuidance, Classification: ActionManualOnly, Description: "Install TPM plugins manually."},
		},
	}
	results := map[string]runner.Result{
		"nvim-upgrade-supported": {
			Stdout: strings.Join([]string{
				"run      brew upgrade ripgrep",
				"skip     fd already current",
				"optional shfmt [missing, non-blocking]",
				"manual   Mason manages lua-language-server",
				"external AWS SAM CLI requires manual bundle repair",
			}, "\n"),
			Stderr:   "failed   shellcheck upgrade failed",
			ExitCode: 1,
		},
	}

	report := BuildReport(plan, results)

	for _, status := range []ActionStatus{StatusChanged, StatusSkipped, StatusFailed, StatusOptional, StatusManual} {
		if !reportHasStatus(report, status) {
			t.Fatalf("upgrade report missing status %q in %#v", status, report.Items)
		}
	}
	if !reportHasDetails(report, StatusManual, "Mason") {
		t.Fatalf("upgrade report should keep Mason-backed manual detail: %#v", report.Items)
	}
	if !reportHasDetails(report, StatusOptional, "AWS") || !reportHasDetails(report, StatusOptional, "external") {
		t.Fatalf("upgrade report should mark AWS/external entries optional: %#v", report.Items)
	}
	if report.ExitCode != ExitFailure {
		t.Fatalf("ExitCode = %d, want failure", report.ExitCode)
	}
}

func reportHasStatus(report Report, status ActionStatus) bool {
	for _, item := range report.Items {
		if item.Status == status {
			return true
		}
	}
	return false
}

func reportHasDetails(report Report, status ActionStatus, detail string) bool {
	for _, item := range report.Items {
		if item.Status == status && strings.Contains(item.Details, detail) {
			return true
		}
	}
	return false
}
