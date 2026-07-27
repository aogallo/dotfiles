package installer

import "testing"

func TestModuleMetadata(t *testing.T) {
	t.Parallel()

	tests := []struct {
		id           ModuleID
		wantName     string
		wantLevel    AutomationLevel
		wantManifest string
		wantSource   string
	}{
		{ModuleNeovim, "Neovim", AutomationConfirmationRequired, "nvim/dependencies.tsv", "setup/link-nvim-config.sh"},
		{ModuleZsh, "zsh", AutomationReportOnly, "zsh/dependencies.tsv", "setup/validate-zsh-config.sh"},
		{ModuleGhostty, "Ghostty", AutomationConfirmationRequired, "ghostty/dependencies.tsv", "setup/link-ghostty-config.sh"},
		{ModuleTmux, "tmux", AutomationManualOnly, "", "Tmux/README.md"},
		{ModuleKeyboard, "keyboard", AutomationManualOnly, "", "keyboard/iris_rev__5.json"},
		{ModuleMacOS, "macOS setup", AutomationManualOnly, "", "setup/macos.sh"},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(string(tt.id), func(t *testing.T) {
			t.Parallel()

			module, ok := ModuleByID(tt.id)
			if !ok {
				t.Fatalf("ModuleByID(%q) ok = false, want true", tt.id)
			}
			if module.Name != tt.wantName {
				t.Fatalf("Name = %q, want %q", module.Name, tt.wantName)
			}
			if module.AutomationLevel != tt.wantLevel {
				t.Fatalf("AutomationLevel = %q, want %q", module.AutomationLevel, tt.wantLevel)
			}
			if module.DependencyManifest != tt.wantManifest {
				t.Fatalf("DependencyManifest = %q, want %q", module.DependencyManifest, tt.wantManifest)
			}
			if !contains(module.SourcePaths, tt.wantSource) {
				t.Fatalf("SourcePaths = %v, want to contain %q", module.SourcePaths, tt.wantSource)
			}
		})
	}
}

func TestMacOSModuleDoesNotExposeExecutableCommand(t *testing.T) {
	t.Parallel()

	module, ok := ModuleByID(ModuleMacOS)
	if !ok {
		t.Fatal("ModuleByID(ModuleMacOS) ok = false, want true")
	}
	if len(module.Validator) != 0 || len(module.Linker) != 0 {
		t.Fatalf("macOS module Validator=%v Linker=%v, want no executable boundary", module.Validator, module.Linker)
	}
}

func contains(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}
