package tui

import (
	"slices"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/aogallo/dotfiles/installer/internal/installer"
	"github.com/aogallo/dotfiles/installer/internal/runner"
)

// Screen identifies the active installer view.
type Screen string

const (
	ScreenMainMenu     Screen = "main_menu"
	ScreenFlowInfo     Screen = "flow_info"
	ScreenModuleList   Screen = "module_list"
	ScreenActionPlan   Screen = "action_plan"
	ScreenConfirmation Screen = "confirmation"
	ScreenRunning      Screen = "running"
	ScreenReport       Screen = "report"
	ScreenExit         Screen = "exit"
)

// MenuItem is a top-level action shown in the main menu.
type MenuItem struct {
	Label string
	Flow  installer.Flow
}

// Model is the root Bubble Tea model for the installer TUI.
type Model struct {
	screen       Screen
	menuItems    []MenuItem
	cursor       int
	dryRun       bool
	selectedFlow installer.Flow
	modules      []installer.Module
	plan         installer.Plan
	report       installer.Report
	exitCode     installer.ExitCode
	runner       runner.Runner
}

// NewModel creates the initial installer TUI model.
func NewModel() Model {
	return Model{
		screen: ScreenMainMenu,
		menuItems: []MenuItem{
			{Label: "start installation", Flow: installer.FlowInstall},
			{Label: "sync configs", Flow: installer.FlowSync},
			{Label: "Upgrade tools", Flow: installer.FlowUpgrade},
			{Label: "quit", Flow: installer.FlowQuit},
		},
		dryRun:   true,
		modules:  installer.Modules(),
		report:   installer.NewReport(installer.FlowInstall),
		exitCode: installer.ExitSuccess,
		runner:   runner.ExecRunner{},
	}
}

// Init performs startup work for the TUI.
func (m Model) Init() tea.Cmd {
	return nil
}

// MenuItems returns a copy of the top-level menu items.
func (m Model) MenuItems() []MenuItem {
	return slices.Clone(m.menuItems)
}

// Cursor returns the selected main-menu index.
func (m Model) Cursor() int {
	return m.cursor
}

// DryRun reports whether the session starts in safe preview mode.
func (m Model) DryRun() bool {
	return m.dryRun
}

// Screen returns the active installer view.
func (m Model) Screen() Screen {
	return m.screen
}

// SelectedFlow returns the currently selected top-level flow.
func (m Model) SelectedFlow() installer.Flow {
	return m.selectedFlow
}

// ExitCode returns the process exit code represented by the model.
func (m Model) ExitCode() int {
	return int(m.exitCode)
}

// Modules returns a copy of the installer module list.
func (m Model) Modules() []installer.Module {
	return slices.Clone(m.modules)
}

// Plan returns the current action plan.
func (m Model) Plan() installer.Plan {
	return m.plan
}

// Report returns the current installation report.
func (m Model) Report() installer.Report {
	return m.report
}
