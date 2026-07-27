package tui

import (
	"context"
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/aogallo/dotfiles/installer/internal/installer"
	"github.com/aogallo/dotfiles/installer/internal/runner"
)

// Update handles Bubble Tea messages for the installer model.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			m.screen = ScreenExit
			return m, tea.Quit
		case "q":
			if m.screen != ScreenMainMenu {
				m.screen = ScreenMainMenu
				m.selectedFlow = ""
				return m, nil
			}

			m.screen = ScreenExit
			return m, tea.Quit
		case "j", "down":
			if m.screen == ScreenMainMenu || m.screen == ScreenModuleList {
				m.moveCursor(1)
			}
		case "k", "up":
			if m.screen == ScreenMainMenu || m.screen == ScreenModuleList {
				m.moveCursor(-1)
			}
		case "enter":
			switch m.screen {
			case ScreenMainMenu:
				return m.selectMenuItem()
			case ScreenModuleList:
				return m.buildActionPlan(selectedModuleIDs(m)), nil
			case ScreenActionPlan:
				if m.plan.RequiresConfirmation {
					m.screen = ScreenConfirmation
				} else {
					m = m.finalizeReport()
				}
			case ScreenConfirmation:
				m = m.finalizeReport()
			case ScreenReport:
				m.screen = ScreenMainMenu
			}
		case "esc", "backspace":
			if m.screen != ScreenMainMenu {
				m.screen = ScreenMainMenu
				m.selectedFlow = ""
			}
		}
	}

	return m, nil
}

func (m *Model) moveCursor(delta int) {
	length := len(m.menuItems)
	if m.screen == ScreenModuleList {
		length = len(m.modules)
	}
	if length == 0 {
		return
	}

	m.cursor = (m.cursor + delta + length) % length
}

func (m Model) selectMenuItem() (tea.Model, tea.Cmd) {
	if len(m.menuItems) == 0 {
		return m, nil
	}

	selected := m.menuItems[m.cursor]
	m.selectedFlow = selected.Flow
	if selected.Flow == "quit" {
		m.screen = ScreenExit
		return m, tea.Quit
	}

	m.cursor = 0
	m.screen = ScreenModuleList
	return m, nil
}

func (m Model) buildActionPlan(moduleIDs []installer.ModuleID) Model {
	plan, err := installer.BuildPlanWithOptions(m.selectedFlow, moduleIDs, installer.PlanOptions{Root: repositoryRoot()})
	if err != nil {
		m.report = installer.NewReport(m.selectedFlow)
		m.report.Items = append(m.report.Items, installer.ReportItem{Status: installer.StatusFailed, Message: "Failed to build action plan", Details: err.Error()})
		m.report.Totals.Failed = 1
		m.report.ExitCode = installer.ExitFailure
		m.exitCode = installer.ExitFailure
		m.screen = ScreenReport
		return m
	}
	m.plan = plan
	m.screen = ScreenActionPlan
	return m
}

func (m Model) finalizeReport() Model {
	m.screen = ScreenRunning
	m.report = installer.BuildReport(m.plan, m.executePlan(context.Background()))
	m.screen = ScreenReport
	m.exitCode = m.report.ExitCode
	return m
}

func (m Model) executePlan(ctx context.Context) map[string]runner.Result {
	results := map[string]runner.Result{}
	repository, err := runner.NewRepositoryRoot(repositoryRoot())
	if err != nil {
		return executionFailureResults(m.plan, err)
	}

	for _, step := range m.plan.Steps {
		if !step.HasCommand() {
			continue
		}

		command, err := repository.Command(step.Command[0], step.Command[1:]...)
		if err != nil {
			results[step.ID] = runner.Result{Stderr: err.Error(), ExitCode: -1}
			continue
		}

		result, err := m.runner.Run(ctx, command)
		if err != nil && result.ExitCode == 0 {
			result.ExitCode = -1
			if result.Stderr == "" {
				result.Stderr = err.Error()
			}
		}
		results[step.ID] = result
	}

	return results
}

func executionFailureResults(plan installer.Plan, err error) map[string]runner.Result {
	results := map[string]runner.Result{}
	for _, step := range plan.Steps {
		if step.HasCommand() {
			results[step.ID] = runner.Result{Stderr: err.Error(), ExitCode: -1}
		}
	}
	return results
}

func repositoryRoot() string {
	wd, err := os.Getwd()
	if err != nil {
		return ".."
	}
	for dir := wd; ; dir = filepath.Dir(dir) {
		if _, err := os.Stat(filepath.Join(dir, "nvim", "dependencies.tsv")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return ".."
		}
	}
}

func selectedModuleIDs(m Model) []installer.ModuleID {
	if len(m.modules) == 0 || m.cursor == 0 {
		ids := make([]installer.ModuleID, 0, len(m.modules))
		for _, module := range m.modules {
			ids = append(ids, module.ID)
		}
		return ids
	}
	return []installer.ModuleID{m.modules[m.cursor].ID}
}
