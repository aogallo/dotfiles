package tui

import (
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

	updatedModel, _ = model.Update(key(tea.KeyEnter))
	model = updatedModel.(Model)
	if model.Screen() != ScreenReport {
		t.Fatalf("screen = %q, want report", model.Screen())
	}
	if len(model.Report().Items) == 0 {
		t.Fatal("report should include executed, skipped, or manual items")
	}
	if len(fake.Calls) == 0 {
		t.Fatal("installer should execute command-backed plan steps before reporting")
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
			updatedModel, _ = model.Update(key(tea.KeyEnter))
			model = updatedModel.(Model)
			if requiresConfirmation {
				if model.Screen() != ScreenConfirmation {
					t.Fatalf("screen = %q, want confirmation", model.Screen())
				}
				updatedModel, _ = model.Update(key(tea.KeyEnter))
				model = updatedModel.(Model)
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
