package installer

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ModuleID is the stable identifier for a repository module.
type ModuleID string

const (
	ModuleNeovim   ModuleID = "nvim"
	ModuleZsh      ModuleID = "zsh"
	ModuleGhostty  ModuleID = "ghostty"
	ModuleTmux     ModuleID = "tmux"
	ModuleKeyboard ModuleID = "keyboard"
	ModuleMacOS    ModuleID = "macos"
)

// AutomationLevel describes the safest automation level available for a module.
type AutomationLevel string

const (
	AutomationAutomatic            AutomationLevel = "automatic"
	AutomationConfirmationRequired AutomationLevel = "confirmation_required"
	AutomationReportOnly           AutomationLevel = "report_only"
	AutomationManualOnly           AutomationLevel = "manual_only"
)

// Module describes a repository area managed or reported by the installer.
type Module struct {
	ID                 ModuleID
	Name               string
	SourcePaths        []string
	DependencyManifest string
	Validator          []string
	Linker             []string
	AutomationLevel    AutomationLevel
	SupportedFlows     []Flow
}

// Dependency describes one manifest dependency row.
type Dependency struct {
	Name        string
	Executable  string
	Required    bool
	Source      string
	InstallHint string
	UsedBy      string
}

// Category returns a report-oriented dependency category.
func (d Dependency) Category() ActionStatus {
	source := strings.ToLower(d.Source)
	switch {
	case strings.Contains(source, "mason"):
		return StatusManual
	case strings.Contains(d.Name, "AWS") || strings.Contains(source, "external"):
		return StatusOptional
	case d.Required:
		return StatusMissing
	default:
		return StatusOptional
	}
}

// ModuleInventory records source files, docs, and manifest dependencies discovered for a module.
type ModuleInventory struct {
	Module       Module
	Sources      []string
	Docs         []string
	Dependencies []Dependency
}

// Inventory is the full module inventory in display order.
type Inventory struct {
	Modules []ModuleInventory
}

// ByModule returns inventory for a module id.
func (i Inventory) ByModule(id ModuleID) (ModuleInventory, bool) {
	for _, module := range i.Modules {
		if module.Module.ID == id {
			return module, true
		}
	}
	return ModuleInventory{}, false
}

// InventoryModules inventories setup scripts, dependency manifests, and module docs from the repository.
func InventoryModules(root string) (Inventory, error) {
	if root == "" {
		root = "."
	}
	var inventory Inventory
	for _, module := range Modules() {
		item := ModuleInventory{Module: module, Sources: append([]string(nil), module.SourcePaths...)}
		for _, source := range module.SourcePaths {
			if strings.HasSuffix(source, "README.md") || source == "setup/macos.sh" {
				item.Docs = append(item.Docs, source)
			}
		}
		if module.DependencyManifest != "" {
			deps, err := readDependencyManifest(filepath.Join(root, module.DependencyManifest))
			if err != nil {
				return Inventory{}, err
			}
			item.Dependencies = deps
		}
		inventory.Modules = append(inventory.Modules, item)
	}
	return inventory, nil
}

func readDependencyManifest(path string) ([]Dependency, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("read dependency manifest %s: %w", path, err)
	}
	defer file.Close()

	var deps []Dependency
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		delim := "|"
		if strings.Contains(line, "\t") {
			delim = "\t"
		}
		parts := strings.Split(line, delim)
		if len(parts) < 6 {
			return nil, fmt.Errorf("invalid dependency row in %s: %q", path, line)
		}
		deps = append(deps, Dependency{
			Name:        strings.TrimSpace(parts[0]),
			Executable:  strings.TrimSpace(parts[1]),
			Required:    strings.EqualFold(strings.TrimSpace(parts[2]), "yes"),
			Source:      strings.TrimSpace(parts[3]),
			InstallHint: strings.TrimSpace(parts[4]),
			UsedBy:      strings.TrimSpace(parts[5]),
		})
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scan dependency manifest %s: %w", path, err)
	}
	return deps, nil
}

// Modules returns the initial module catalog in display order.
func Modules() []Module {
	return []Module{
		{
			ID:                 ModuleNeovim,
			Name:               "Neovim",
			SourcePaths:        []string{"nvim/", "nvim/dependencies.tsv", "nvim/README.md", "setup/validate-nvim-deps.sh", "setup/bootstrap-nvim-deps.sh", "setup/link-nvim-config.sh"},
			DependencyManifest: "nvim/dependencies.tsv",
			Validator:          []string{"setup/validate-nvim-deps.sh"},
			Linker:             []string{"setup/link-nvim-config.sh"},
			AutomationLevel:    AutomationConfirmationRequired,
			SupportedFlows:     []Flow{FlowInstall, FlowSync, FlowUpgrade},
		},
		{
			ID:                 ModuleZsh,
			Name:               "zsh",
			SourcePaths:        []string{"zsh/", "zsh/dependencies.tsv", "zsh/README.md", "setup/validate-zsh-config.sh"},
			DependencyManifest: "zsh/dependencies.tsv",
			Validator:          []string{"setup/validate-zsh-config.sh"},
			AutomationLevel:    AutomationReportOnly,
			SupportedFlows:     []Flow{FlowInstall, FlowUpgrade},
		},
		{
			ID:                 ModuleGhostty,
			Name:               "Ghostty",
			SourcePaths:        []string{"ghostty/", "ghostty/dependencies.tsv", "ghostty/README.md", "setup/validate-ghostty-config.sh", "setup/link-ghostty-config.sh"},
			DependencyManifest: "ghostty/dependencies.tsv",
			Validator:          []string{"setup/validate-ghostty-config.sh"},
			Linker:             []string{"setup/link-ghostty-config.sh"},
			AutomationLevel:    AutomationConfirmationRequired,
			SupportedFlows:     []Flow{FlowInstall, FlowSync, FlowUpgrade},
		},
		{
			ID:              ModuleTmux,
			Name:            "tmux",
			SourcePaths:     []string{"Tmux/", "Tmux/README.md"},
			AutomationLevel: AutomationManualOnly,
			SupportedFlows:  []Flow{FlowInstall, FlowSync, FlowUpgrade},
		},
		{
			ID:              ModuleKeyboard,
			Name:            "keyboard",
			SourcePaths:     []string{"keyboard/", "keyboard/README.md", "keyboard/iris_rev__5.json"},
			AutomationLevel: AutomationManualOnly,
			SupportedFlows:  []Flow{FlowInstall, FlowSync},
		},
		{
			ID:              ModuleMacOS,
			Name:            "macOS setup",
			SourcePaths:     []string{"setup/macos.sh"},
			AutomationLevel: AutomationManualOnly,
			SupportedFlows:  []Flow{FlowInstall, FlowUpgrade},
		},
	}
}

// ModuleByID returns a module from the initial catalog.
func ModuleByID(id ModuleID) (Module, bool) {
	for _, module := range Modules() {
		if module.ID == id {
			return module, true
		}
	}

	return Module{}, false
}
