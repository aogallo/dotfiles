package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/aogallo/dotfiles/installer/internal/tui"
)

func main() {
	os.Exit(run())
}

func run() int {
	program := tea.NewProgram(tui.NewModel())
	finalModel, err := program.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "dotfiles-installer failed: %v\n", err)
		return 1
	}

	model, ok := finalModel.(tui.Model)
	if !ok {
		return 1
	}

	return model.ExitCode()
}
