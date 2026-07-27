package tui

import (
	"strings"
	"testing"
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
