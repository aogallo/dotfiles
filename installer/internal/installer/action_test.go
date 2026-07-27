package installer

import (
	"reflect"
	"testing"
)

func TestActionClassificationSafety(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		action  Action
		wantErr bool
	}{
		{
			name: "manual-only action rejects command",
			action: Action{
				ID:             "keyboard-via-import",
				ModuleID:       ModuleKeyboard,
				Kind:           StepManualGuidance,
				Classification: ActionManualOnly,
				Command:        []string{"setup/macos.sh"},
			},
			wantErr: true,
		},
		{
			name: "manual-only guidance without command is valid",
			action: Action{
				ID:             "keyboard-via-import",
				ModuleID:       ModuleKeyboard,
				Kind:           StepManualGuidance,
				Classification: ActionManualOnly,
			},
		},
		{
			name: "mutating step requires confirmation",
			action: Action{
				ID:             "nvim-link-apply",
				ModuleID:       ModuleNeovim,
				Kind:           StepLink,
				Classification: ActionAutomatic,
				Command:        []string{"setup/link-nvim-config.sh", "--apply"},
			},
			wantErr: true,
		},
		{
			name: "confirmed mutating step is valid",
			action: Action{
				ID:             "nvim-link-apply",
				ModuleID:       ModuleNeovim,
				Kind:           StepLink,
				Classification: ActionConfirmationRequired,
				Command:        []string{"setup/link-nvim-config.sh", "--apply"},
			},
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			err := tt.action.Validate()
			if (err != nil) != tt.wantErr {
				t.Fatalf("Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestPlanBuilderRequiresPreviewBeforeMutation(t *testing.T) {
	t.Parallel()

	builder := NewPlanBuilder(FlowInstall)
	err := builder.AddStep(Action{
		ID:             "nvim-link-apply",
		ModuleID:       ModuleNeovim,
		Kind:           StepLink,
		Classification: ActionConfirmationRequired,
		Command:        []string{"setup/link-nvim-config.sh", "--apply"},
	})
	if err == nil {
		t.Fatal("AddStep() error = nil, want dry-run/report ordering error")
	}
}

func TestPlanBuilderAcceptsPreviewBeforeMutation(t *testing.T) {
	t.Parallel()

	builder := NewPlanBuilder(FlowInstall)
	if err := builder.AddStep(Action{
		ID:             "nvim-link-dry-run",
		ModuleID:       ModuleNeovim,
		Kind:           StepDryRun,
		Classification: ActionDryRunReportOnly,
		Command:        []string{"setup/link-nvim-config.sh", "--dry-run"},
	}); err != nil {
		t.Fatalf("AddStep(dry-run) error = %v", err)
	}

	if err := builder.AddStep(Action{
		ID:             "nvim-link-apply",
		ModuleID:       ModuleNeovim,
		Kind:           StepLink,
		Classification: ActionConfirmationRequired,
		Command:        []string{"setup/link-nvim-config.sh", "--apply"},
	}); err != nil {
		t.Fatalf("AddStep(apply) error = %v", err)
	}

	plan := builder.Build()
	if !plan.RequiresConfirmation {
		t.Fatal("Build().RequiresConfirmation = false, want true")
	}
}

func TestApprovedScriptArgvGeneration(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		argv []string
	}{
		{"nvim validator", []string{"setup/validate-nvim-deps.sh"}},
		{"nvim bootstrap dry-run", []string{"setup/bootstrap-nvim-deps.sh", "--dry-run"}},
		{"nvim bootstrap install", []string{"setup/bootstrap-nvim-deps.sh", "--install"}},
		{"nvim link dry-run", []string{"setup/link-nvim-config.sh", "--dry-run"}},
		{"nvim link apply", []string{"setup/link-nvim-config.sh", "--apply"}},
		{"nvim link apply backup", []string{"setup/link-nvim-config.sh", "--apply", "--backup"}},
		{"nvim link remove", []string{"setup/link-nvim-config.sh", "--apply", "--remove"}},
		{"zsh validator", []string{"setup/validate-zsh-config.sh"}},
		{"ghostty validator", []string{"setup/validate-ghostty-config.sh"}},
		{"ghostty link dry-run", []string{"setup/link-ghostty-config.sh", "--dry-run"}},
		{"ghostty link apply", []string{"setup/link-ghostty-config.sh", "--apply"}},
		{"ghostty link apply backup", []string{"setup/link-ghostty-config.sh", "--apply", "--backup"}},
		{"ghostty link remove", []string{"setup/link-ghostty-config.sh", "--remove"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, err := NewApprovedCommand(tt.argv[0], tt.argv[1:]...)
			if err != nil {
				t.Fatalf("NewApprovedCommand() error = %v", err)
			}
			if !reflect.DeepEqual(got, tt.argv) {
				t.Fatalf("NewApprovedCommand() = %#v, want %#v", got, tt.argv)
			}
		})
	}
}

func TestApprovedScriptArgvRejectsMacOSScript(t *testing.T) {
	t.Parallel()

	if _, err := NewApprovedCommand("setup/macos.sh"); err == nil {
		t.Fatal("NewApprovedCommand(setup/macos.sh) error = nil, want rejection")
	}
}
