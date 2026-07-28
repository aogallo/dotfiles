package runner

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestStepProgressMessagesCarryRequiredFields(t *testing.T) {
	t.Parallel()

	startedAt := time.Date(2026, 7, 27, 12, 0, 0, 0, time.UTC)
	completedAt := startedAt.Add(time.Second)
	started := StepStarted{StepID: "nvim-bootstrap-install", ModuleID: "nvim", Index: 2, Total: 4, Description: "Install tools", StartedAt: startedAt}
	completed := StepCompleted{StepID: started.StepID, Status: "changed", Result: Result{Stdout: "ok", ExitCode: 0}, CompletedAt: completedAt}
	failed := StepFailed{StepID: "ghostty-link", Err: errors.New("boom"), Result: Result{Stderr: "boom", ExitCode: 7}, CompletedAt: completedAt}
	skipped := StepSkipped{StepID: "tmux-manual-guidance", Reason: "manual action remains", Status: "manual"}
	cancelled := InstallCancelled{CompletedCount: 1, RemainingCount: 3}

	if started.StepID == "" || started.ModuleID == "" || started.Index != 2 || started.Total != 4 || started.Description == "" || started.StartedAt.IsZero() {
		t.Fatalf("started message missing required fields: %#v", started)
	}
	if completed.StepID != started.StepID || completed.Result.Stdout != "ok" || completed.CompletedAt.IsZero() {
		t.Fatalf("completed message missing result fields: %#v", completed)
	}
	if failed.StepID == "" || failed.Err == nil || failed.Result.ExitCode != 7 || failed.CompletedAt.IsZero() {
		t.Fatalf("failed message missing failure fields: %#v", failed)
	}
	if skipped.StepID == "" || skipped.Reason == "" || skipped.Status != "manual" {
		t.Fatalf("skipped message missing accounting fields: %#v", skipped)
	}
	if cancelled.CompletedCount != 1 || cancelled.RemainingCount != 3 {
		t.Fatalf("cancelled message = %#v, want completed/remaining counts", cancelled)
	}
}

func TestFakeRunnerRecordsCallsAndReturnsQueuedResults(t *testing.T) {
	t.Parallel()

	wantErr := errors.New("boom")
	fake := &FakeRunner{
		Results: []Result{{Stdout: "ok", ExitCode: 0}},
		Errors:  []error{wantErr},
	}

	result, err := fake.Run(context.Background(), Command{Name: "setup/validate-nvim-deps.sh", Args: []string{"--dry-run"}})
	if !errors.Is(err, wantErr) {
		t.Fatalf("Run() error = %v, want %v", err, wantErr)
	}
	if result.Stdout != "ok" {
		t.Fatalf("Run() Stdout = %q, want ok", result.Stdout)
	}
	if len(fake.Calls) != 1 {
		t.Fatalf("Calls length = %d, want 1", len(fake.Calls))
	}
	if fake.Calls[0].Args[0] != "--dry-run" {
		t.Fatalf("recorded Args = %v, want --dry-run", fake.Calls[0].Args)
	}
}

func TestRepositoryRootCommandUsesPathSafeArgv(t *testing.T) {
	t.Parallel()

	rootPath := t.TempDir()
	root, err := NewRepositoryRoot(rootPath)
	if err != nil {
		t.Fatalf("NewRepositoryRoot() error = %v", err)
	}

	cmd, err := root.Command("setup/link-nvim-config.sh", "--apply", "--backup")
	if err != nil {
		t.Fatalf("Command() error = %v", err)
	}

	wantName := filepath.Join(rootPath, "setup/link-nvim-config.sh")
	if cmd.Name != wantName {
		t.Fatalf("Command().Name = %q, want %q", cmd.Name, wantName)
	}
	if cmd.Dir != rootPath {
		t.Fatalf("Command().Dir = %q, want %q", cmd.Dir, rootPath)
	}
	if len(cmd.Args) != 2 || cmd.Args[0] != "--apply" || cmd.Args[1] != "--backup" {
		t.Fatalf("Command().Args = %v, want [--apply --backup]", cmd.Args)
	}
}

func TestRepositoryRootRejectsUnsafeExecutablePaths(t *testing.T) {
	t.Parallel()

	root, err := NewRepositoryRoot(t.TempDir())
	if err != nil {
		t.Fatalf("NewRepositoryRoot() error = %v", err)
	}

	tests := []string{
		"",
		"../setup/macos.sh",
		"/bin/sh",
	}

	for _, relativeExecutable := range tests {
		relativeExecutable := relativeExecutable
		t.Run(relativeExecutable, func(t *testing.T) {
			t.Parallel()

			if _, err := root.Command(relativeExecutable); err == nil {
				t.Fatal("Command() error = nil, want unsafe path rejection")
			}
		})
	}
}

func TestExecRunnerCapturesStreamsAndPropagatesFailure(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	script := filepath.Join(dir, "script.sh")
	if err := os.WriteFile(script, []byte("#!/usr/bin/env bash\nprintf 'out:%s\\n' \"$1\"\nprintf 'err:%s\\n' \"$2\" >&2\nexit 7\n"), 0o755); err != nil {
		t.Fatalf("write script: %v", err)
	}

	var stdout, stderr strings.Builder
	result, err := ExecRunner{Stdout: &stdout, Stderr: &stderr}.Run(context.Background(), Command{
		Name: script,
		Args: []string{"a;rm -rf /", "b && bad"},
		Dir:  dir,
	})
	if err == nil {
		t.Fatal("Run() error = nil, want failure propagation")
	}
	if result.ExitCode != 7 {
		t.Fatalf("ExitCode = %d, want 7", result.ExitCode)
	}
	if !strings.Contains(result.Stdout, "out:a;rm -rf /") || !strings.Contains(stdout.String(), result.Stdout) {
		t.Fatalf("stdout capture/stream mismatch: result=%q stream=%q", result.Stdout, stdout.String())
	}
	if !strings.Contains(result.Stderr, "err:b && bad") || !strings.Contains(stderr.String(), result.Stderr) {
		t.Fatalf("stderr capture/stream mismatch: result=%q stream=%q", result.Stderr, stderr.String())
	}
}
