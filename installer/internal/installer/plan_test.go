package installer

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestInventoryModulesReadsManifestsAndDocs(t *testing.T) {
	t.Parallel()

	inventory, err := InventoryModules("../../..")
	if err != nil {
		t.Fatalf("InventoryModules() error = %v", err)
	}

	tests := []struct {
		module      ModuleID
		wantSource  string
		wantDoc     string
		wantDepsMin int
	}{
		{ModuleNeovim, "setup/bootstrap-nvim-deps.sh", "nvim/README.md", 20},
		{ModuleZsh, "setup/validate-zsh-config.sh", "zsh/README.md", 10},
		{ModuleGhostty, "setup/link-ghostty-config.sh", "ghostty/README.md", 3},
		{ModuleTmux, "Tmux/README.md", "Tmux/README.md", 0},
		{ModuleKeyboard, "keyboard/iris_rev__5.json", "keyboard/README.md", 0},
		{ModuleMacOS, "setup/macos.sh", "setup/macos.sh", 0},
	}

	for _, tt := range tests {
		t.Run(string(tt.module), func(t *testing.T) {
			item, ok := inventory.ByModule(tt.module)
			if !ok {
				t.Fatalf("inventory missing module %q", tt.module)
			}
			if !contains(item.Sources, tt.wantSource) {
				t.Fatalf("Sources = %v, want %q", item.Sources, tt.wantSource)
			}
			if !contains(item.Docs, tt.wantDoc) {
				t.Fatalf("Docs = %v, want %q", item.Docs, tt.wantDoc)
			}
			if len(item.Dependencies) < tt.wantDepsMin {
				t.Fatalf("Dependencies = %d, want at least %d", len(item.Dependencies), tt.wantDepsMin)
			}
		})
	}
}

func TestBuildInstallPlanSeparatesAutomaticConfirmedReportAndManual(t *testing.T) {
	t.Parallel()

	plan, err := BuildPlan(FlowInstall, []ModuleID{ModuleNeovim, ModuleZsh, ModuleGhostty, ModuleTmux, ModuleKeyboard, ModuleMacOS}, "../../..")
	if err != nil {
		t.Fatalf("BuildPlan() error = %v", err)
	}

	if !plan.RequiresConfirmation {
		t.Fatal("plan should require confirmation for install/link apply steps")
	}
	for _, want := range []string{"nvim/dependencies.tsv", "zsh/dependencies.tsv", "ghostty/dependencies.tsv", "setup/macos.sh"} {
		if !contains(plan.CreatedFromInventory, want) {
			t.Fatalf("CreatedFromInventory = %v, want %q", plan.CreatedFromInventory, want)
		}
	}

	assertStepOrder(t, plan, "nvim-link-dry-run", "nvim-link-backup-apply")
	assertStepOrder(t, plan, "ghostty-link-dry-run", "ghostty-link-backup-apply")
	assertPlanLacksStep(t, plan, "nvim-link-apply")
	assertPlanLacksStep(t, plan, "ghostty-link-apply")
	assertStep(t, plan, "zsh-validate", ActionAutomatic, StepValidate)
	assertStep(t, plan, "tmux-manual-guidance", ActionManualOnly, StepManualGuidance)
	assertStep(t, plan, "keyboard-manual-guidance", ActionManualOnly, StepManualGuidance)
	assertStep(t, plan, "macos-manual-guidance", ActionManualOnly, StepManualGuidance)
}

func TestInstallPlanUsesAutomaticBackupStepsForConfigLinks(t *testing.T) {
	t.Parallel()

	plan, err := BuildPlan(FlowInstall, []ModuleID{ModuleNeovim, ModuleGhostty}, "../../..")
	if err != nil {
		t.Fatalf("BuildPlan() error = %v", err)
	}

	for _, id := range []string{"nvim-link-backup-apply", "ghostty-link-backup-apply"} {
		step := findStep(t, plan, id)
		if step.Kind != StepBackup {
			t.Fatalf("step %q kind = %q, want backup", id, step.Kind)
		}
		if !contains(step.Command, "--backup") {
			t.Fatalf("step %q command = %v, want --backup", id, step.Command)
		}
	}
}

func TestNextAvailableBackupPathDoesNotOverwriteExistingBackups(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	candidate := filepath.Join(dir, "nvim-20260727-120000")
	mustWriteFile(t, candidate, "first backup")
	mustWriteFile(t, candidate+"-1", "second backup")

	got := nextAvailableBackupPath(candidate, pathExists)
	want := candidate + "-2"
	if got != want {
		t.Fatalf("nextAvailableBackupPath() = %q, want %q", got, want)
	}
}

func TestPlannedBackupPathUsesEstablishedBackupDirectories(t *testing.T) {
	t.Parallel()

	home := t.TempDir()
	at := time.Date(2026, 7, 27, 12, 0, 0, 0, time.UTC)

	tests := []struct {
		name     string
		moduleID ModuleID
		want     string
	}{
		{name: "neovim", moduleID: ModuleNeovim, want: filepath.Join(home, ".dotfiles_backup", "nvim-20260727-120000")},
		{name: "ghostty", moduleID: ModuleGhostty, want: filepath.Join(home, ".dotfiles_backup", "ghostty", "config.ghostty-20260727-120000")},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := plannedBackupPath(tt.moduleID, home, at, func(string) bool { return false })
			if got != tt.want {
				t.Fatalf("plannedBackupPath() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestBuildPerModulePlanLimitsModules(t *testing.T) {
	t.Parallel()

	plan, err := BuildPlan(FlowInstall, []ModuleID{ModuleGhostty}, "../../..")
	if err != nil {
		t.Fatalf("BuildPlan() error = %v", err)
	}

	for _, step := range plan.Steps {
		if step.ModuleID != ModuleGhostty {
			t.Fatalf("step %q module = %q, want ghostty only", step.ID, step.ModuleID)
		}
	}
}

func TestBuildSyncPlanConfigTargetStates(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name      string
		arrange   func(t *testing.T, root, home string)
		options   PlanOptions
		wantState ConfigTargetState
		wantIDs   []string
		denyIDs   []string
	}{
		{
			name:      "missing target plans confirmed link only",
			wantState: ConfigTargetMissing,
			wantIDs:   []string{"nvim-link-dry-run", "nvim-link-apply"},
			denyIDs:   []string{"nvim-link-backup-apply", "nvim-link-remove"},
		},
		{
			name: "managed target reports managed and remove only when confirmed",
			arrange: func(t *testing.T, root, home string) {
				t.Helper()
				mustSymlink(t, filepath.Join(root, "nvim"), filepath.Join(home, ".config", "nvim"))
			},
			options:   PlanOptions{ConfirmRemove: true},
			wantState: ConfigTargetManaged,
			wantIDs:   []string{"nvim-link-dry-run", "nvim-link-remove"},
			denyIDs:   []string{"nvim-link-apply", "nvim-link-backup-apply"},
		},
		{
			name: "unmanaged target refuses overwrite until backup is confirmed",
			arrange: func(t *testing.T, root, home string) {
				t.Helper()
				mustWriteFile(t, filepath.Join(home, ".config", "nvim"), "local config")
			},
			wantState: ConfigTargetUnmanaged,
			wantIDs:   []string{"nvim-link-dry-run", "nvim-backup-required"},
			denyIDs:   []string{"nvim-link-apply", "nvim-link-backup-apply"},
		},
		{
			name: "unmanaged target permits backup only after explicit confirmation",
			arrange: func(t *testing.T, root, home string) {
				t.Helper()
				mustWriteFile(t, filepath.Join(home, ".config", "nvim"), "local config")
			},
			options:   PlanOptions{ConfirmBackup: true},
			wantState: ConfigTargetUnmanaged,
			wantIDs:   []string{"nvim-link-dry-run", "nvim-link-backup-apply"},
			denyIDs:   []string{"nvim-link-apply"},
		},
		{
			name: "broken symlink requires recovery guidance before backup confirmation",
			arrange: func(t *testing.T, root, home string) {
				t.Helper()
				mustSymlink(t, filepath.Join(home, "missing-source"), filepath.Join(home, ".config", "nvim"))
			},
			wantState: ConfigTargetBrokenSymlink,
			wantIDs:   []string{"nvim-link-dry-run", "nvim-backup-required"},
			denyIDs:   []string{"nvim-link-apply", "nvim-link-backup-apply"},
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			root, home := syncSandbox(t)
			if tt.arrange != nil {
				tt.arrange(t, root, home)
			}
			tt.options.Root = root
			tt.options.Home = home

			plan, err := BuildPlanWithOptions(FlowSync, []ModuleID{ModuleNeovim}, tt.options)
			if err != nil {
				t.Fatalf("BuildPlanWithOptions() error = %v", err)
			}

			if len(plan.ConfigTargets) != 1 || plan.ConfigTargets[0].State != tt.wantState {
				t.Fatalf("ConfigTargets = %#v, want state %q", plan.ConfigTargets, tt.wantState)
			}
			for _, id := range tt.wantIDs {
				assertPlanHasStep(t, plan, id)
			}
			for _, id := range tt.denyIDs {
				assertPlanLacksStep(t, plan, id)
			}
		})
	}
}

func TestBuildSyncPlanIncludesSkippedFailedBackedUpAndRemovedOutcomes(t *testing.T) {
	t.Parallel()

	root, home := syncSandbox(t)
	mustSymlink(t, filepath.Join(root, "ghostty", "config.ghostty"), filepath.Join(home, "Library", "Application Support", "com.mitchellh.ghostty", "config.ghostty"))

	plan, err := BuildPlanWithOptions(FlowSync, []ModuleID{ModuleGhostty}, PlanOptions{Root: root, Home: home, ConfirmRemove: true})
	if err != nil {
		t.Fatalf("BuildPlanWithOptions() error = %v", err)
	}

	assertStepStatuses(t, plan, "ghostty-link-dry-run", StatusManaged, StatusSkipped, StatusFailed)
	assertStepStatuses(t, plan, "ghostty-link-remove", StatusRemoved, StatusSkipped, StatusFailed)

	mustRemove(t, filepath.Join(home, "Library", "Application Support", "com.mitchellh.ghostty", "config.ghostty"))
	mustWriteFile(t, filepath.Join(home, "Library", "Application Support", "com.mitchellh.ghostty", "config.ghostty"), "local config")
	plan, err = BuildPlanWithOptions(FlowSync, []ModuleID{ModuleGhostty}, PlanOptions{Root: root, Home: home, ConfirmBackup: true})
	if err != nil {
		t.Fatalf("BuildPlanWithOptions() backup error = %v", err)
	}
	assertStepStatuses(t, plan, "ghostty-link-backup-apply", StatusBackedUp, StatusChanged, StatusFailed)
}

func TestBuildSyncPlanRepeatedRunsConvergeWithoutBackupLoops(t *testing.T) {
	t.Parallel()

	root, home := syncSandbox(t)
	target := filepath.Join(home, ".config", "nvim")
	mustWriteFile(t, target, "local config")

	first, err := BuildPlanWithOptions(FlowSync, []ModuleID{ModuleNeovim}, PlanOptions{Root: root, Home: home, ConfirmBackup: true})
	if err != nil {
		t.Fatalf("first BuildPlanWithOptions() error = %v", err)
	}
	assertPlanHasStep(t, first, "nvim-link-backup-apply")

	mustRemove(t, target)
	mustSymlink(t, filepath.Join(root, "nvim"), target)
	second, err := BuildPlanWithOptions(FlowSync, []ModuleID{ModuleNeovim}, PlanOptions{Root: root, Home: home, ConfirmBackup: true})
	if err != nil {
		t.Fatalf("second BuildPlanWithOptions() error = %v", err)
	}

	if len(second.ConfigTargets) != 1 || second.ConfigTargets[0].State != ConfigTargetManaged {
		t.Fatalf("second ConfigTargets = %#v, want managed", second.ConfigTargets)
	}
	assertPlanHasStep(t, second, "nvim-link-dry-run")
	assertPlanLacksStep(t, second, "nvim-link-apply")
	assertPlanLacksStep(t, second, "nvim-link-backup-apply")
}

func assertStep(t *testing.T, plan Plan, id string, classification ActionClassification, kind StepKind) {
	t.Helper()
	for _, step := range plan.Steps {
		if step.ID == id {
			if step.Classification != classification || step.Kind != kind {
				t.Fatalf("step %q = (%q,%q), want (%q,%q)", id, step.Classification, step.Kind, classification, kind)
			}
			return
		}
	}
	t.Fatalf("missing step %q", id)
}

func findStep(t *testing.T, plan Plan, id string) Action {
	t.Helper()
	for _, step := range plan.Steps {
		if step.ID == id {
			return step
		}
	}
	t.Fatalf("missing step %q in %#v", id, plan.Steps)
	return Action{}
}

func assertPlanHasStep(t *testing.T, plan Plan, id string) {
	t.Helper()
	for _, step := range plan.Steps {
		if step.ID == id {
			return
		}
	}
	t.Fatalf("missing step %q in %#v", id, plan.Steps)
}

func assertPlanLacksStep(t *testing.T, plan Plan, id string) {
	t.Helper()
	for _, step := range plan.Steps {
		if step.ID == id {
			t.Fatalf("unexpected step %q in %#v", id, plan.Steps)
		}
	}
}

func assertStepStatuses(t *testing.T, plan Plan, id string, statuses ...ActionStatus) {
	t.Helper()
	for _, step := range plan.Steps {
		if step.ID == id {
			for _, status := range statuses {
				if !containsStatus(step.ExpectedStatuses, status) {
					t.Fatalf("step %q statuses = %v, want %q", id, step.ExpectedStatuses, status)
				}
			}
			return
		}
	}
	t.Fatalf("missing step %q", id)
}

func assertStepOrder(t *testing.T, plan Plan, before, after string) {
	t.Helper()
	beforeIdx, afterIdx := -1, -1
	for i, step := range plan.Steps {
		if step.ID == before {
			beforeIdx = i
		}
		if step.ID == after {
			afterIdx = i
		}
	}
	if beforeIdx == -1 || afterIdx == -1 || beforeIdx >= afterIdx {
		t.Fatalf("want %q before %q in %#v", before, after, plan.Steps)
	}
}

func syncSandbox(t *testing.T) (string, string) {
	t.Helper()
	root := t.TempDir()
	home := t.TempDir()
	mustMkdir(t, filepath.Join(root, "nvim"))
	mustMkdir(t, filepath.Join(root, "ghostty"))
	mustWriteFile(t, filepath.Join(root, "ghostty", "config.ghostty"), "font-size = 14")
	for _, path := range []string{"nvim/dependencies.tsv", "zsh/dependencies.tsv", "ghostty/dependencies.tsv"} {
		mustWriteFile(t, filepath.Join(root, path), "tool\texe\tyes\thomebrew\tbrew install tool\ttest\n")
	}
	return root, home
}

func mustMkdir(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatalf("MkdirAll(%s) error = %v", path, err)
	}
}

func mustWriteFile(t *testing.T, path, content string) {
	t.Helper()
	mustMkdir(t, filepath.Dir(path))
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("WriteFile(%s) error = %v", path, err)
	}
}

func mustSymlink(t *testing.T, oldname, newname string) {
	t.Helper()
	mustMkdir(t, filepath.Dir(newname))
	if err := os.Symlink(oldname, newname); err != nil {
		t.Fatalf("Symlink(%s, %s) error = %v", oldname, newname, err)
	}
}

func mustRemove(t *testing.T, path string) {
	t.Helper()
	if err := os.Remove(path); err != nil {
		t.Fatalf("Remove(%s) error = %v", path, err)
	}
}

func containsStatus(items []ActionStatus, want ActionStatus) bool {
	for _, item := range items {
		if item == want {
			return true
		}
	}
	return false
}
