package runner

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Command describes an external process boundary without shell interpolation.
type Command struct {
	Name string
	Args []string
	Dir  string
}

// Result captures an external command result.
type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

// StepStarted records that an installer step became active in the UI.
type StepStarted struct {
	StepID      string
	ModuleID    string
	Index       int
	Total       int
	Description string
	StartedAt   time.Time
}

// StepCompleted records a successful command-backed installer step result.
type StepCompleted struct {
	StepID      string
	Status      string
	Result      Result
	CompletedAt time.Time
}

// StepFailed records a failed command-backed installer step result.
type StepFailed struct {
	StepID      string
	Err         error
	Result      Result
	CompletedAt time.Time
}

// StepSkipped records a non-command installer step that was accounted for without execution.
type StepSkipped struct {
	StepID string
	Reason string
	Status string
}

// InstallCancelled records cancellation progress for the installer session.
type InstallCancelled struct {
	CompletedCount int
	RemainingCount int
}

// Runner defines the boundary for invoking external commands.
type Runner interface {
	Run(context.Context, Command) (Result, error)
}

// RepositoryRoot resolves repository-relative executable paths safely.
type RepositoryRoot struct {
	path string
}

// NewRepositoryRoot validates and stores an absolute repository root path.
func NewRepositoryRoot(path string) (RepositoryRoot, error) {
	if path == "" {
		return RepositoryRoot{}, errors.New("repository root is required")
	}
	if !filepath.IsAbs(path) {
		return RepositoryRoot{}, fmt.Errorf("repository root must be absolute: %s", path)
	}

	return RepositoryRoot{path: filepath.Clean(path)}, nil
}

// Path returns the cleaned absolute repository root.
func (r RepositoryRoot) Path() string {
	return r.path
}

// Command builds a shell-free argv command for a repository-relative executable.
func (r RepositoryRoot) Command(relativeExecutable string, args ...string) (Command, error) {
	name, err := r.Resolve(relativeExecutable)
	if err != nil {
		return Command{}, err
	}

	return Command{Name: name, Args: append([]string(nil), args...), Dir: r.path}, nil
}

// Resolve converts a repository-relative path to an absolute path under the root.
func (r RepositoryRoot) Resolve(relativePath string) (string, error) {
	if r.path == "" {
		return "", errors.New("repository root is not initialized")
	}
	if relativePath == "" {
		return "", errors.New("relative path is required")
	}
	if filepath.IsAbs(relativePath) {
		return "", fmt.Errorf("path must be repository-relative: %s", relativePath)
	}
	if strings.ContainsRune(relativePath, '\x00') {
		return "", errors.New("path contains NUL byte")
	}

	clean := filepath.Clean(relativePath)
	if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return "", fmt.Errorf("path escapes repository root: %s", relativePath)
	}

	resolved := filepath.Join(r.path, clean)
	rel, err := filepath.Rel(r.path, resolved)
	if err != nil || rel == ".." || strings.HasPrefix(rel, "../") {
		return "", fmt.Errorf("path escapes repository root: %s", relativePath)
	}

	return resolved, nil
}

// FakeRunner is a test double for command execution boundaries.
type FakeRunner struct {
	Results []Result
	Errors  []error
	Calls   []Command
}

// Run records the command and returns queued fake results.
func (r *FakeRunner) Run(_ context.Context, cmd Command) (Result, error) {
	r.Calls = append(r.Calls, cmd)

	var result Result
	if len(r.Results) > 0 {
		result = r.Results[0]
		r.Results = r.Results[1:]
	}

	var err error
	if len(r.Errors) > 0 {
		err = r.Errors[0]
		r.Errors = r.Errors[1:]
	}

	return result, err
}

// ExecRunner executes commands without shell interpolation.
type ExecRunner struct {
	Stdout io.Writer
	Stderr io.Writer
}

// Run executes cmd.Name with cmd.Args directly through os/exec.
func (r ExecRunner) Run(ctx context.Context, command Command) (Result, error) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	if command.Name == "" {
		return Result{ExitCode: -1}, errors.New("command name is required")
	}
	return r.run(ctx, command, &stdout, &stderr)
}

func (r ExecRunner) run(ctx context.Context, command Command, stdout, stderr *bytes.Buffer) (Result, error) {
	cmd := exec.CommandContext(ctx, command.Name, command.Args...)
	cmd.Dir = command.Dir
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	if r.Stdout != nil {
		cmd.Stdout = io.MultiWriter(stdout, r.Stdout)
	}
	if r.Stderr != nil {
		cmd.Stderr = io.MultiWriter(stderr, r.Stderr)
	}

	err := cmd.Run()
	result := Result{Stdout: stdout.String(), Stderr: stderr.String()}
	if err == nil {
		return result, nil
	}
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		result.ExitCode = -1
		return result, err
	}

	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		result.ExitCode = exitErr.ExitCode()
	}

	return result, err
}
