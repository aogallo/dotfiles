package tui

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/aogallo/dotfiles/installer/internal/installer"
	"github.com/aogallo/dotfiles/installer/internal/runner"
)

// Update handles Bubble Tea messages for the installer model.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case StartupError:
		m.screen = ScreenStartupError
		m.startupError = msg
		m.exitCode = installer.ExitFailure
		return m, tea.Quit
	case runner.StepStarted:
		m.screen = ScreenRunning
		m.progress.ActiveStepID = msg.StepID
		m.progress.ActiveModuleID = installer.ModuleID(msg.ModuleID)
		m.progress.ActiveDescription = msg.Description
		m.progress.CurrentStepIndex = msg.Index
		m.progress.TotalSteps = msg.Total
		return m, m.executeActiveStep(msg.StepID)
	case runner.StepCompleted:
		if m.results == nil {
			m.results = map[string]runner.Result{}
		}
		m.results[msg.StepID] = msg.Result
		m.progress.CompletedSteps++
		m.progress.RecentResults = appendRecentResult(m.progress.RecentResults, progressResultFromStep(m.plan, msg.StepID, installer.StatusUnchanged, msg.Result.Stdout))
		m.progress.IncompleteStepIDs = remainingStepIDs(m.plan, m.progress.CompletedSteps)
		m.progress.ActiveStepID = ""
		m.progress.ActiveDescription = ""
		return m.advanceOrFinalize(), m.nextStepCmd()
	case runner.StepFailed:
		if m.results == nil {
			m.results = map[string]runner.Result{}
		}
		m.results[msg.StepID] = msg.Result
		m.progress.CompletedSteps++
		details := strings.TrimSpace(msg.Result.Stderr)
		if details == "" && msg.Err != nil {
			details = msg.Err.Error()
		}
		m.progress.RecentResults = appendRecentResult(m.progress.RecentResults, progressResultFromStep(m.plan, msg.StepID, installer.StatusFailed, details))
		m.progress.IncompleteStepIDs = remainingStepIDs(m.plan, m.progress.CompletedSteps)
		m.progress.ActiveStepID = ""
		m.progress.ActiveDescription = ""
		return m.advanceOrFinalize(), m.nextStepCmd()
	case runner.StepSkipped:
		m.progress.CompletedSteps++
		status := installer.StatusSkipped
		if msg.Status != "" {
			status = installer.ActionStatus(msg.Status)
		}
		m.progress.RecentResults = appendRecentResult(m.progress.RecentResults, progressResultFromStep(m.plan, msg.StepID, status, msg.Reason))
		m.progress.IncompleteStepIDs = remainingStepIDs(m.plan, m.progress.CompletedSteps)
		m.progress.ActiveStepID = ""
		m.progress.ActiveDescription = ""
		return m.advanceOrFinalize(), m.nextStepCmd()
	case runner.InstallCancelled:
		m.progress.Cancelled = true
		m.progress.CompletedSteps = msg.CompletedCount
		m.progress.IncompleteStepIDs = remainingStepIDs(m.plan, msg.CompletedCount)
		m.report = installer.BuildReport(m.plan, m.results)
		m.exitCode = installer.ExitFailure
		m.screen = ScreenReport
		return m, nil
	case tea.WindowSizeMsg:
		m.terminal.Width = msg.Width
		m.terminal.Height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			m.screen = ScreenExit
			return m, tea.Quit
		case "q":
			if m.screen != ScreenMainMenu {
				if m.screen == ScreenConfirmation {
					m.progress.Cancelled = true
					m.progress.IncompleteStepIDs = m.plan.PlannedStepIDs()
				}
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
					return m.startRunning()
				}
			case ScreenConfirmation:
				return m.startRunning()
			case ScreenReport:
				m.screen = ScreenMainMenu
			}
		case "esc", "backspace":
			if m.screen != ScreenMainMenu {
				if m.screen == ScreenConfirmation {
					m.progress.Cancelled = true
					m.progress.IncompleteStepIDs = m.plan.PlannedStepIDs()
				}
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
	m.progress = ProgressSession{TotalSteps: len(plan.Steps), IncompleteStepIDs: plan.PlannedStepIDs()}
	m.results = map[string]runner.Result{}
	m.screen = ScreenActionPlan
	return m
}

func (m Model) finalizeReport() Model {
	m.screen = ScreenRunning
	m.progress.TotalSteps = len(m.plan.Steps)
	m.progress.IncompleteStepIDs = m.plan.PlannedStepIDs()
	m.report = installer.BuildReport(m.plan, m.executePlan(context.Background()))
	m.screen = ScreenReport
	m.exitCode = m.report.ExitCode
	m.progress.IncompleteStepIDs = incompleteStepIDs(m.plan, m.report)
	return m
}

func (m Model) startRunning() (tea.Model, tea.Cmd) {
	m.screen = ScreenRunning
	m.progress = ProgressSession{TotalSteps: len(m.plan.Steps), IncompleteStepIDs: m.plan.PlannedStepIDs()}
	m.report = installer.NewReport(m.selectedFlow)
	m.results = map[string]runner.Result{}
	if len(m.plan.Steps) == 0 {
		m = m.advanceOrFinalize()
		return m, nil
	}
	return m, m.nextStepCmd()
}

func (m Model) nextStepCmd() tea.Cmd {
	if m.progress.CompletedSteps >= len(m.plan.Steps) {
		return nil
	}
	step := m.plan.Steps[m.progress.CompletedSteps]
	index := m.progress.CompletedSteps + 1
	return func() tea.Msg {
		if !step.HasCommand() {
			status := string(installer.StatusSkipped)
			reason := "No command was needed for this planned step."
			if step.Classification == installer.ActionManualOnly {
				status = string(installer.StatusManual)
				reason = "Manual action remains for this step."
			}
			return runner.StepSkipped{StepID: step.ID, Reason: reason, Status: status}
		}
		return runner.StepStarted{StepID: step.ID, ModuleID: string(step.ModuleID), Index: index, Total: len(m.plan.Steps), Description: step.Description, StartedAt: time.Now()}
	}
}

func (m Model) executeActiveStep(stepID string) tea.Cmd {
	step, ok := findStep(m.plan, stepID)
	if !ok {
		return func() tea.Msg {
			return runner.StepFailed{StepID: stepID, Err: errors.New("planned step not found"), Result: runner.Result{ExitCode: -1, Stderr: "planned step not found"}, CompletedAt: time.Now()}
		}
	}
	return func() tea.Msg {
		repository, err := runner.NewRepositoryRoot(repositoryRoot())
		if err != nil {
			return runner.StepFailed{StepID: step.ID, Err: err, Result: runner.Result{Stderr: err.Error(), ExitCode: -1}, CompletedAt: time.Now()}
		}
		command, err := repository.Command(step.Command[0], step.Command[1:]...)
		if err != nil {
			return runner.StepFailed{StepID: step.ID, Err: err, Result: runner.Result{Stderr: err.Error(), ExitCode: -1}, CompletedAt: time.Now()}
		}
		result, err := m.runner.Run(context.Background(), command)
		if err != nil && result.ExitCode == 0 {
			result.ExitCode = -1
			if result.Stderr == "" {
				result.Stderr = err.Error()
			}
		}
		if err != nil || result.ExitCode != 0 {
			return runner.StepFailed{StepID: step.ID, Err: err, Result: result, CompletedAt: time.Now()}
		}
		return runner.StepCompleted{StepID: step.ID, Status: string(installer.StatusUnchanged), Result: result, CompletedAt: time.Now()}
	}
}

func (m Model) advanceOrFinalize() Model {
	if m.progress.CompletedSteps < len(m.plan.Steps) {
		return m
	}
	m.report = installer.BuildReport(m.plan, m.results)
	m.screen = ScreenReport
	m.exitCode = m.report.ExitCode
	m.progress.ActiveStepID = ""
	m.progress.ActiveDescription = ""
	m.progress.IncompleteStepIDs = incompleteStepIDs(m.plan, m.report)
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

func incompleteStepIDs(plan installer.Plan, report installer.Report) []string {
	incomplete := map[string]struct{}{}
	for _, item := range report.Items {
		if item.Status == installer.StatusCancelled || item.Status == installer.StatusFailed || item.Status == installer.StatusMissing || item.Status == installer.StatusUnmanaged {
			incomplete[item.StepID] = struct{}{}
		}
	}
	ids := make([]string, 0, len(incomplete))
	for _, step := range plan.Steps {
		if _, ok := incomplete[step.ID]; ok {
			ids = append(ids, step.ID)
		}
	}
	return ids
}

func remainingStepIDs(plan installer.Plan, completed int) []string {
	if completed >= len(plan.Steps) {
		return nil
	}
	ids := make([]string, 0, len(plan.Steps)-completed)
	for _, step := range plan.Steps[completed:] {
		ids = append(ids, step.ID)
	}
	return ids
}

func findStep(plan installer.Plan, stepID string) (installer.Action, bool) {
	for _, step := range plan.Steps {
		if step.ID == stepID {
			return step, true
		}
	}
	return installer.Action{}, false
}

func progressResultFromStep(plan installer.Plan, stepID string, status installer.ActionStatus, details string) ProgressResult {
	step, ok := findStep(plan, stepID)
	message := stepID
	if ok {
		message = step.Description
	}
	return ProgressResult{StepID: stepID, Status: status, Message: message, Details: strings.TrimSpace(details)}
}

func appendRecentResult(results []ProgressResult, result ProgressResult) []ProgressResult {
	results = append(results, result)
	if len(results) > 5 {
		return results[len(results)-5:]
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
