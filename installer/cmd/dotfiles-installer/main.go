package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/aogallo/dotfiles/installer/internal/tui"
)

func main() {
	os.Exit(run())
}

func run() int {
	return runWithOptions(os.Stdin, os.Stdout, os.Stderr, os.Args)
}

func runWithOptions(stdin, stdout, stderr *os.File, args []string) int {
	if err := validatePlatform(); err != nil {
		printStartupGuidance(stderr, args, "This release artifact cannot run on the current platform.", err.Error())
		return 1
	}

	if !isTerminal(stdin) || !isTerminal(stdout) {
		printStartupGuidance(stderr, args, "The installer must be run from a terminal so it can show prompts and keyboard guidance.", "Open Terminal, cd to the download location, then run the command below.")
		return 1
	}

	program := tea.NewProgram(tui.NewModel(), tea.WithInput(stdin), tea.WithOutput(stdout))
	finalModel, err := program.Run()
	if err != nil {
		printStartupGuidance(stderr, args, "The interactive terminal UI failed to start.", err.Error())
		return 1
	}

	model, ok := finalModel.(tui.Model)
	if !ok {
		return 1
	}

	return model.ExitCode()
}

func validatePlatform() error {
	if runtime.GOOS != "darwin" {
		return fmt.Errorf("unsupported operating system %q; download a macOS release asset or run the repository bootstrap on macOS", runtime.GOOS)
	}
	if runtime.GOARCH != "arm64" && runtime.GOARCH != "amd64" {
		return fmt.Errorf("unsupported architecture %q; use dotfiles-installer-darwin-arm64 for Apple Silicon or dotfiles-installer-darwin-amd64 for Intel Macs", runtime.GOARCH)
	}
	return nil
}

func isTerminal(file *os.File) bool {
	if file == nil {
		return false
	}
	info, err := file.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}

func printStartupGuidance(stderr *os.File, args []string, reason, details string) {
	if stderr == nil {
		stderr = os.Stderr
	}
	guidance := tui.NewStartupErrorModel(tui.StartupError{Reason: reason, Details: details, Command: launchCommand(args)}).View()
	fmt.Fprint(stderr, guidance)
}

func launchCommand(args []string) string {
	name := "./dotfiles-installer-darwin-arm64"
	if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
		name = args[0]
	}
	if filepath.IsAbs(name) {
		return shellQuote(name)
	}
	if strings.ContainsRune(name, filepath.Separator) {
		return shellQuote(name)
	}
	return "./" + shellQuote(name)
}

func shellQuote(value string) string {
	if value == "" {
		return "''"
	}
	if strings.ContainsAny(value, " \t\n'\"\\$`!") {
		return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
	}
	return value
}
