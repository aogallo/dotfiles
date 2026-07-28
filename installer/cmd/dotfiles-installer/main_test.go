package main

import (
	"os"
	"strings"
	"testing"
)

func TestRunWithOptionsRejectsNonInteractiveLaunch(t *testing.T) {
	stdin := tempFile(t, "stdin")
	stdout := tempFile(t, "stdout")
	stderr := tempFile(t, "stderr")

	exitCode := runWithOptions(stdin, stdout, stderr, []string{"/tmp/dotfiles-installer-darwin-arm64"})

	if exitCode != 1 {
		t.Fatalf("exit code = %d, want 1", exitCode)
	}
	if _, err := stderr.Seek(0, 0); err != nil {
		t.Fatalf("Seek(stderr) error = %v", err)
	}
	content, err := os.ReadFile(stderr.Name())
	if err != nil {
		t.Fatalf("ReadFile(stderr) error = %v", err)
	}
	for _, want := range []string{
		"must be run from a terminal",
		"/tmp/dotfiles-installer-darwin-arm64",
		"bootstrap --prefer-binary",
	} {
		if !strings.Contains(string(content), want) {
			t.Fatalf("stderr missing %q:\n%s", want, content)
		}
	}
}

func tempFile(t *testing.T, name string) *os.File {
	t.Helper()
	file, err := os.CreateTemp(t.TempDir(), name)
	if err != nil {
		t.Fatalf("CreateTemp(%s) error = %v", name, err)
	}
	t.Cleanup(func() { file.Close() })
	return file
}
