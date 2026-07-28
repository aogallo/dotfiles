package tui

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/aogallo/dotfiles/installer/internal/installer"
	"github.com/aogallo/dotfiles/installer/internal/runner"
)

func TestUpdateKeyBehavior(t *testing.T) {
	tests := []struct {
		name             string
		arrange          func(Model) Model
		key              tea.KeyMsg
		wantCursor       int
		wantScreen       Screen
		wantSelectedFlow installer.Flow
		wantQuitCmd      bool
	}{
		{
			name:       "j moves focus down",
			key:        runeKey('j'),
			wantCursor: 1,
			wantScreen: ScreenMainMenu,
		},
		{
			name:       "k moves focus up with wraparound",
			key:        runeKey('k'),
			wantCursor: 3,
			wantScreen: ScreenMainMenu,
		},
		{
			name: "enter selects focused non-quit action without quitting",
			arrange: func(model Model) Model {
				model.cursor = 1
				return model
			},
			key:              key(tea.KeyEnter),
			wantCursor:       0,
			wantScreen:       ScreenModuleList,
			wantSelectedFlow: installer.FlowSync,
		},
		{
			name: "enter on quit exits",
			arrange: func(model Model) Model {
				model.cursor = 3
				return model
			},
			key:              key(tea.KeyEnter),
			wantCursor:       3,
			wantScreen:       ScreenExit,
			wantSelectedFlow: installer.FlowQuit,
			wantQuitCmd:      true,
		},
		{
			name:        "q exits from main menu",
			key:         runeKey('q'),
			wantScreen:  ScreenExit,
			wantQuitCmd: true,
		},
		{
			name: "q backs out from safe sub-screen",
			arrange: func(model Model) Model {
				model.screen = ScreenModuleList
				model.selectedFlow = installer.FlowInstall
				return model
			},
			key:        runeKey('q'),
			wantScreen: ScreenMainMenu,
		},
		{
			name:        "ctrl+c exits immediately",
			key:         key(tea.KeyCtrlC),
			wantScreen:  ScreenExit,
			wantQuitCmd: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			model := NewModel()
			if tt.arrange != nil {
				model = tt.arrange(model)
			}

			updatedModel, cmd := model.Update(tt.key)
			got, ok := updatedModel.(Model)
			if !ok {
				t.Fatalf("updated model type = %T, want tui.Model", updatedModel)
			}

			if got.Cursor() != tt.wantCursor {
				t.Fatalf("cursor = %d, want %d", got.Cursor(), tt.wantCursor)
			}
			if got.Screen() != tt.wantScreen {
				t.Fatalf("screen = %q, want %q", got.Screen(), tt.wantScreen)
			}
			if got.SelectedFlow() != tt.wantSelectedFlow {
				t.Fatalf("selected flow = %q, want %q", got.SelectedFlow(), tt.wantSelectedFlow)
			}
			if (cmd != nil) != tt.wantQuitCmd {
				t.Fatalf("quit command presence = %v, want %v", cmd != nil, tt.wantQuitCmd)
			}
		})
	}
}

func TestInstallFlowTransitionsThroughPlanConfirmationAndReport(t *testing.T) {
	fake := &runner.FakeRunner{}
	model := NewModel()
	model.runner = fake

	updatedModel, _ := model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	if model.Screen() != ScreenModuleList {
		t.Fatalf("screen = %q, want module list", model.Screen())
	}

	updatedModel, _ = model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	if model.Screen() != ScreenActionPlan {
		t.Fatalf("screen = %q, want action plan", model.Screen())
	}
	if len(model.Plan().Steps) == 0 {
		t.Fatal("plan should include module actions")
	}

	updatedModel, _ = model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	if model.Screen() != ScreenConfirmation {
		t.Fatalf("screen = %q, want confirmation", model.Screen())
	}

	updatedModel, cmd := model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	if model.Screen() != ScreenRunning {
		t.Fatalf("screen = %q, want running before report", model.Screen())
	}
	if cmd == nil {
		t.Fatal("confirmation should schedule the first progress command")
	}
	model = drainCommands(t, model, cmd)
	if model.Screen() != ScreenReport {
		t.Fatalf("screen = %q, want report after draining commands", model.Screen())
	}
	if len(model.Report().Items) == 0 {
		t.Fatal("report should include executed, skipped, or manual items")
	}
	if len(fake.Calls) == 0 {
		t.Fatal("installer should execute command-backed plan steps before reporting")
	}
}

func TestRunningScreenShowsActiveStepBeforeCommandCompletes(t *testing.T) {
	fake := &runner.FakeRunner{Results: []runner.Result{{Stdout: "ok validation", ExitCode: 0}}}
	model := NewModel()
	model.runner = fake
	model.selectedFlow = installer.FlowInstall
	model.plan = installer.Plan{
		Flow: installer.FlowInstall,
		Steps: []installer.Action{{
			ID:             "nvim-validate",
			ModuleID:       installer.ModuleNeovim,
			Kind:           installer.StepValidate,
			Classification: installer.ActionAutomatic,
			Command:        []string{"setup/validate-nvim-deps.sh"},
			Description:    "Validate Neovim dependencies.",
		}},
	}

	updatedModel, cmd := model.startRunning()
	model = updatedModel.(Model)
	if model.Screen() != ScreenRunning || cmd == nil {
		t.Fatalf("startRunning screen/cmd = %q/%v, want running with command", model.Screen(), cmd != nil)
	}

	msg := cmd()
	started, ok := msg.(runner.StepStarted)
	if !ok {
		t.Fatalf("first message = %T, want runner.StepStarted", msg)
	}
	updatedModel, cmd = model.Update(started)
	model = updatedModel.(Model)
	if model.Screen() != ScreenRunning {
		t.Fatalf("screen = %q, want running while command is active", model.Screen())
	}
	if model.progress.ActiveStepID != "nvim-validate" || model.progress.CurrentStepIndex != 1 || model.progress.TotalSteps != 1 {
		t.Fatalf("progress = %#v, want active first step", model.progress)
	}
	if !strings.Contains(model.View(), "Current step: 1 of 1") || !strings.Contains(model.View(), "Status: Working") {
		t.Fatalf("running view missing active progress:\n%s", model.View())
	}
	if len(fake.Calls) != 0 {
		t.Fatal("runner should not execute until the StepStarted update returns its command")
	}

	model = drainCommands(t, model, cmd)
	if model.Screen() != ScreenReport || len(fake.Calls) != 1 {
		t.Fatalf("screen/calls = %q/%d, want final report and one runner call", model.Screen(), len(fake.Calls))
	}
}

func TestRunningProgressRecordsFailureAndContinuesToNextStep(t *testing.T) {
	fake := &runner.FakeRunner{Results: []runner.Result{{Stderr: "boom", ExitCode: 7}, {Stdout: "ok", ExitCode: 0}}}
	model := NewModel()
	model.runner = fake
	model.selectedFlow = installer.FlowInstall
	model.plan = installer.Plan{
		Flow: installer.FlowInstall,
		Steps: []installer.Action{
			{ID: "first", ModuleID: installer.ModuleNeovim, Kind: installer.StepValidate, Classification: installer.ActionAutomatic, Command: []string{"setup/validate-nvim-deps.sh"}, Description: "First step."},
			{ID: "second", ModuleID: installer.ModuleGhostty, Kind: installer.StepValidate, Classification: installer.ActionAutomatic, Command: []string{"setup/validate-ghostty-config.sh"}, Description: "Second step."},
		},
	}

	updatedModel, cmd := model.startRunning()
	model = drainCommands(t, updatedModel.(Model), cmd)

	if model.Screen() != ScreenReport {
		t.Fatalf("screen = %q, want report", model.Screen())
	}
	if len(fake.Calls) != 2 {
		t.Fatalf("runner calls = %d, want both steps executed sequentially", len(fake.Calls))
	}
	if model.Report().Totals.Failed != 1 || model.ExitCode() != int(installer.ExitFailure) {
		t.Fatalf("report totals/exit = %#v/%d, want one failure", model.Report().Totals, model.ExitCode())
	}
	if len(model.progress.RecentResults) < 2 || model.progress.RecentResults[0].Status != installer.StatusFailed {
		t.Fatalf("recent results = %#v, want failed result preserved", model.progress.RecentResults)
	}
}

func TestPreConfirmCancelDoesNotExecutePlan(t *testing.T) {
	fake := &runner.FakeRunner{}
	model := NewModel()
	model.runner = fake

	updatedModel, _ := model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	updatedModel, _ = model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	updatedModel, _ = model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	if model.Screen() != ScreenConfirmation {
		t.Fatalf("screen = %q, want confirmation", model.Screen())
	}

	updatedModel, cmd := model.Update(runeKey('q'))
	model = updatedModel.(Model)

	if model.Screen() != ScreenMainMenu {
		t.Fatalf("screen = %q, want main menu after cancellation", model.Screen())
	}
	if len(fake.Calls) != 0 {
		t.Fatalf("runner calls = %d, want none before confirmation", len(fake.Calls))
	}
	if cmd != nil {
		t.Fatal("pre-confirm cancellation should not quit or run commands")
	}
	if !model.progress.Cancelled || len(model.progress.IncompleteStepIDs) == 0 {
		t.Fatalf("progress cancellation = %#v, want planned steps marked incomplete", model.progress)
	}
}

func TestHelpOpensFromCurrentScreenAndReturns(t *testing.T) {
	model := NewModel()
	model.screen = ScreenActionPlan

	updatedModel, cmd := model.Update(keyString("?"))
	model = updatedModel.(Model)
	if cmd != nil {
		t.Fatal("help should not schedule a command")
	}
	if model.Screen() != ScreenHelp {
		t.Fatalf("screen = %q, want help", model.Screen())
	}

	updatedModel, _ = model.Update(key(tea.KeyEsc))
	model = updatedModel.(Model)
	if model.Screen() != ScreenActionPlan {
		t.Fatalf("screen = %q, want action plan", model.Screen())
	}
}

func TestSyncAndUpgradeFlowsUseConfirmationGatesAndReports(t *testing.T) {
	tests := []struct {
		name       string
		cursor     int
		wantFlow   installer.Flow
		wantStepID string
	}{
		{name: "sync configs", cursor: 1, wantFlow: installer.FlowSync, wantStepID: "nvim-link-dry-run"},
		{name: "Upgrade tools", cursor: 2, wantFlow: installer.FlowUpgrade, wantStepID: "nvim-upgrade-preview"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fake := &runner.FakeRunner{}
			model := NewModel()
			model.runner = fake
			model.cursor = tt.cursor

			updatedModel, _ := model.Update(key(tea.KeyEnter))
			model = updatedModel.(Model)
			if model.SelectedFlow() != tt.wantFlow || model.Screen() != ScreenModuleList {
				t.Fatalf("selected flow/screen = %q/%q, want %q/%q", model.SelectedFlow(), model.Screen(), tt.wantFlow, ScreenModuleList)
			}

			updatedModel, _ = model.Update(key(tea.KeyEnter))
			model = updatedModel.(Model)
			if model.Screen() != ScreenActionPlan {
				t.Fatalf("screen = %q, want action plan", model.Screen())
			}
			if !planHasStep(model.Plan(), tt.wantStepID) {
				t.Fatalf("plan missing %q in %#v", tt.wantStepID, model.Plan().Steps)
			}

			requiresConfirmation := model.Plan().RequiresConfirmation
			updatedModel, cmd := model.Update(key(tea.KeyEnter))
			model = updatedModel.(Model)
			if requiresConfirmation {
				if model.Screen() != ScreenConfirmation {
					t.Fatalf("screen = %q, want confirmation", model.Screen())
				}
				updatedModel, cmd := model.Update(key(tea.KeyEnter))
				model = updatedModel.(Model)
				model = drainCommands(t, model, cmd)
			} else {
				model = drainCommands(t, model, cmd)
			}
			if model.Screen() != ScreenReport {
				t.Fatalf("screen = %q, want report", model.Screen())
			}
			if model.Report().Flow != tt.wantFlow {
				t.Fatalf("report flow = %q, want %q", model.Report().Flow, tt.wantFlow)
			}
			if len(fake.Calls) == 0 {
				t.Fatal("flow should execute command-backed plan steps before reporting")
			}
		})
	}
}

func TestFinalizeReportRecordsRunnerFailure(t *testing.T) {
	fake := &runner.FakeRunner{
		Results: []runner.Result{{Stderr: "boom", ExitCode: 7}},
	}
	model := NewModel()
	model.runner = fake
	model.plan = installer.Plan{
		Flow: installer.FlowSync,
		Steps: []installer.Action{{
			ID:             "nvim-link-dry-run",
			ModuleID:       installer.ModuleNeovim,
			Kind:           installer.StepDryRun,
			Classification: installer.ActionAutomatic,
			Command:        []string{"setup/link-nvim-config.sh", "--dry-run"},
			Description:    "Preview Neovim config sync",
		}},
	}

	model = model.finalizeReport()

	if len(fake.Calls) != 1 {
		t.Fatalf("runner calls = %d, want 1", len(fake.Calls))
	}
	if model.ExitCode() != int(installer.ExitFailure) {
		t.Fatalf("exit code = %d, want failure", model.ExitCode())
	}
	if len(model.Report().Items) != 1 || model.Report().Items[0].Status != installer.StatusFailed {
		t.Fatalf("report items = %#v, want one failed item", model.Report().Items)
	}
}

func TestStartupErrorMessageShowsGuidanceAndFailureExit(t *testing.T) {
	model := NewModel()

	updatedModel, cmd := model.Update(StartupError{
		Reason:  "The installer must be run from a terminal.",
		Details: "Open Terminal and rerun the downloaded binary.",
		Command: "./dotfiles-installer-darwin-arm64",
	})
	got := updatedModel.(Model)

	if got.Screen() != ScreenStartupError {
		t.Fatalf("screen = %q, want startup error", got.Screen())
	}
	if got.ExitCode() != int(installer.ExitFailure) {
		t.Fatalf("exit code = %d, want failure", got.ExitCode())
	}
	if got.StartupError().Command != "./dotfiles-installer-darwin-arm64" {
		t.Fatalf("startup command = %q", got.StartupError().Command)
	}
	if cmd == nil {
		t.Fatal("startup error should quit instead of entering the interactive flow")
	}
}

func TestStartupErrorViewIncludesActionableLaunchGuidance(t *testing.T) {
	model := NewStartupErrorModel(StartupError{
		Reason:  "The installer must be run from a terminal.",
		Details: "Open Terminal and rerun it from Downloads.",
		Command: "./dotfiles-installer-darwin-arm64",
	})

	view := model.View()
	for _, want := range []string{
		"could not start interactively",
		"The installer must be run from a terminal.",
		"./dotfiles-installer-darwin-arm64",
		"bootstrap --prefer-binary",
	} {
		if !strings.Contains(view, want) {
			t.Fatalf("view missing %q:\n%s", want, view)
		}
	}
}

func planHasStep(plan installer.Plan, id string) bool {
	for _, step := range plan.Steps {
		if step.ID == id {
			return true
		}
	}
	return false
}

func runeKey(r rune) tea.KeyMsg {
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}}
}

func key(keyType tea.KeyType) tea.KeyMsg {
	return tea.KeyMsg{Type: keyType}
}

func keyString(value string) tea.KeyMsg {
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(value)}
}

func drainCommands(t *testing.T, model Model, cmd tea.Cmd) Model {
	t.Helper()
	for i := 0; cmd != nil && i < 50; i++ {
		msg := cmd()
		updatedModel, next := model.Update(msg)
		var ok bool
		model, ok = updatedModel.(Model)
		if !ok {
			t.Fatalf("updated model type = %T, want tui.Model", updatedModel)
		}
		cmd = next
	}
	if cmd != nil {
		t.Fatal("command drain exceeded safety limit")
	}
	return model
}
