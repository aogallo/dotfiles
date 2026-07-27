package tui

import (
	"reflect"
	"testing"

	"github.com/aogallo/dotfiles/installer/internal/installer"
)

func TestNewModelInitialMenuAndDryRun(t *testing.T) {
	model := NewModel()

	gotLabels := labels(model.MenuItems())
	wantLabels := []string{"start installation", "sync configs", "Upgrade tools", "quit"}
	if !reflect.DeepEqual(gotLabels, wantLabels) {
		t.Fatalf("menu labels = %#v, want %#v", gotLabels, wantLabels)
	}

	gotFlows := flows(model.MenuItems())
	wantFlows := []installer.Flow{installer.FlowInstall, installer.FlowSync, installer.FlowUpgrade, installer.FlowQuit}
	if !reflect.DeepEqual(gotFlows, wantFlows) {
		t.Fatalf("menu flows = %#v, want %#v", gotFlows, wantFlows)
	}

	if !model.DryRun() {
		t.Fatal("new model should default to dry-run mode")
	}
	if model.Cursor() != 0 {
		t.Fatalf("cursor = %d, want 0", model.Cursor())
	}
	if model.Screen() != ScreenMainMenu {
		t.Fatalf("screen = %q, want %q", model.Screen(), ScreenMainMenu)
	}
	if model.ExitCode() != int(installer.ExitSuccess) {
		t.Fatalf("exit code = %d, want %d", model.ExitCode(), installer.ExitSuccess)
	}
}

func labels(items []MenuItem) []string {
	labels := make([]string, 0, len(items))
	for _, item := range items {
		labels = append(labels, item.Label)
	}
	return labels
}

func flows(items []MenuItem) []installer.Flow {
	flows := make([]installer.Flow, 0, len(items))
	for _, item := range items {
		flows = append(flows, item.Flow)
	}
	return flows
}
