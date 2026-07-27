package installer

import (
	"fmt"
	"os"
	"path/filepath"
)

// Plan describes the ordered installer work prepared before execution.
type Plan struct {
	Flow                 Flow
	ModulePlans          []ModulePlan
	Steps                []Action
	RequiresConfirmation bool
	ManualGuidance       []ManualNextStep
	CreatedFromInventory []string
	ConfigTargets        []ManagedConfigTarget
}

// PlanOptions configures state-sensitive planning without changing safe defaults.
type PlanOptions struct {
	Root          string
	Home          string
	ConfirmBackup bool
	ConfirmRemove bool
}

// ConfigTargetState describes the inspected ownership state of a config target.
type ConfigTargetState string

const (
	ConfigTargetMissing       ConfigTargetState = "missing"
	ConfigTargetManaged       ConfigTargetState = "repo_managed"
	ConfigTargetUnmanaged     ConfigTargetState = "unmanaged"
	ConfigTargetBrokenSymlink ConfigTargetState = "broken_symlink"
	ConfigTargetUnknown       ConfigTargetState = "unknown"
)

// ManagedConfigTarget records a local config path inspected by sync planning.
type ManagedConfigTarget struct {
	ModuleID    ModuleID
	TargetPath  string
	SourcePath  string
	State       ConfigTargetState
	SafeActions []StepKind
}

// ModulePlan groups planned actions for a module.
type ModulePlan struct {
	Module Module
	Steps  []Action
}

// PlanBuilder builds a plan while enforcing foundational safety invariants.
type PlanBuilder struct {
	plan Plan
}

// NewPlanBuilder creates a builder for a flow.
func NewPlanBuilder(flow Flow) *PlanBuilder {
	return &PlanBuilder{plan: Plan{Flow: flow}}
}

// AddInventorySource records a repository-relative source consulted for the plan.
func (b *PlanBuilder) AddInventorySource(path string) {
	b.plan.CreatedFromInventory = append(b.plan.CreatedFromInventory, path)
}

// AddConfigTarget records an inspected config target for sync reporting.
func (b *PlanBuilder) AddConfigTarget(target ManagedConfigTarget) {
	b.plan.ConfigTargets = append(b.plan.ConfigTargets, target)
}

// AddStep appends an action step after validating command and ordering rules.
func (b *PlanBuilder) AddStep(step Action) error {
	if err := step.Validate(); err != nil {
		return err
	}

	if IsMutatingStepKind(step.Kind) && !b.hasPriorPreview(step.ModuleID) {
		return fmt.Errorf("mutating action %q must be preceded by a dry-run/report step", step.ID)
	}

	b.plan.Steps = append(b.plan.Steps, step)
	if step.RequiresConfirmation() {
		b.plan.RequiresConfirmation = true
	}
	if step.Classification == ActionManualOnly {
		b.plan.ManualGuidance = append(b.plan.ManualGuidance, ManualNextStep{
			ModuleID: step.ModuleID,
			StepID:   step.ID,
			Message:  step.Description,
		})
	}

	return nil
}

// Build returns the completed plan with per-module step groups populated.
func (b *PlanBuilder) Build() Plan {
	plan := b.plan
	modulePlans := make([]ModulePlan, 0, len(plan.Steps))
	moduleIndex := map[ModuleID]int{}

	for _, step := range plan.Steps {
		idx, ok := moduleIndex[step.ModuleID]
		if !ok {
			module, _ := ModuleByID(step.ModuleID)
			modulePlans = append(modulePlans, ModulePlan{Module: module})
			idx = len(modulePlans) - 1
			moduleIndex[step.ModuleID] = idx
		}
		modulePlans[idx].Steps = append(modulePlans[idx].Steps, step)
	}

	plan.ModulePlans = modulePlans
	return plan
}

// BuildPlan builds an install/report plan for all requested modules.
func BuildPlan(flow Flow, moduleIDs []ModuleID, root string) (Plan, error) {
	return BuildPlanWithOptions(flow, moduleIDs, PlanOptions{Root: root})
}

// BuildPlanWithOptions builds a state-sensitive action plan for all requested modules.
func BuildPlanWithOptions(flow Flow, moduleIDs []ModuleID, options PlanOptions) (Plan, error) {
	root := options.Root
	inventory, err := InventoryModules(root)
	if err != nil {
		return Plan{}, err
	}
	if len(moduleIDs) == 0 {
		for _, item := range inventory.Modules {
			if supportsFlow(item.Module, flow) {
				moduleIDs = append(moduleIDs, item.Module.ID)
			}
		}
	}

	builder := NewPlanBuilder(flow)
	for _, id := range moduleIDs {
		item, ok := inventory.ByModule(id)
		if !ok {
			return Plan{}, fmt.Errorf("unknown module %q", id)
		}
		if !supportsFlow(item.Module, flow) {
			continue
		}
		for _, source := range item.Sources {
			builder.AddInventorySource(source)
		}
		if err := addModuleSteps(builder, item, flow, root, options); err != nil {
			return Plan{}, err
		}
	}
	return builder.Build(), nil
}

func addModuleSteps(builder *PlanBuilder, item ModuleInventory, flow Flow, root string, options PlanOptions) error {
	module := item.Module
	switch module.ID {
	case ModuleNeovim:
		if flow == FlowSync {
			return addSyncLinkSteps(builder, module.ID, "nvim", "setup/link-nvim-config.sh", root, options)
		}
		if flow == FlowUpgrade {
			return addNeovimUpgradeSteps(builder, module.ID)
		}
		if err := builder.AddStep(Action{ID: "nvim-validate", ModuleID: module.ID, Kind: StepValidate, Classification: ActionAutomatic, Command: mustApprovedCommand("setup/validate-nvim-deps.sh"), Description: "Validate Neovim dependencies and report required, optional, Mason-backed, and AWS tooling.", ExpectedStatuses: []ActionStatus{StatusUnchanged, StatusMissing, StatusOptional, StatusFailed}}); err != nil {
			return err
		}
		if err := builder.AddStep(Action{ID: "nvim-bootstrap-dry-run", ModuleID: module.ID, Kind: StepDryRun, Classification: ActionDryRunReportOnly, Command: mustApprovedCommand("setup/bootstrap-nvim-deps.sh", "--dry-run"), Description: "Preview supported Neovim dependency installation without changing the machine.", ExpectedStatuses: []ActionStatus{StatusSkipped, StatusManual, StatusOptional}}); err != nil {
			return err
		}
		if flow == FlowInstall {
			if err := builder.AddStep(Action{ID: "nvim-bootstrap-install", ModuleID: module.ID, Kind: StepInstall, Classification: ActionConfirmationRequired, Command: mustApprovedCommand("setup/bootstrap-nvim-deps.sh", "--install"), Description: "Install supported missing required Neovim dependencies after confirmation.", ExpectedStatuses: []ActionStatus{StatusChanged, StatusSkipped, StatusManual, StatusFailed}}); err != nil {
				return err
			}
		}
		return addLinkSteps(builder, module.ID, "nvim", "setup/link-nvim-config.sh", flow)
	case ModuleZsh:
		if flow == FlowSync {
			return addManualStep(builder, module.ID, "zsh-sync-manual-guidance", "Review zsh files manually; no repository-owned zsh linker exists yet, so sync is report-only.")
		}
		return builder.AddStep(Action{ID: "zsh-validate", ModuleID: module.ID, Kind: StepValidate, Classification: ActionAutomatic, Command: mustApprovedCommand("setup/validate-zsh-config.sh"), Description: "Validate zsh config and report optional shell integrations; no zsh linker exists yet.", ExpectedStatuses: []ActionStatus{StatusUnchanged, StatusOptional, StatusFailed}})
	case ModuleGhostty:
		if flow == FlowSync {
			return addSyncLinkSteps(builder, module.ID, "ghostty", "setup/link-ghostty-config.sh", root, options)
		}
		if flow == FlowUpgrade {
			return addGhosttyUpgradeSteps(builder, module.ID)
		}
		if err := builder.AddStep(Action{ID: "ghostty-validate", ModuleID: module.ID, Kind: StepValidate, Classification: ActionAutomatic, Command: mustApprovedCommand("setup/validate-ghostty-config.sh"), Description: "Validate Ghostty files and dependency readiness.", ExpectedStatuses: []ActionStatus{StatusUnchanged, StatusMissing, StatusOptional, StatusFailed}}); err != nil {
			return err
		}
		return addLinkSteps(builder, module.ID, "ghostty", "setup/link-ghostty-config.sh", flow)
	case ModuleTmux:
		return addManualStep(builder, module.ID, "tmux-manual-guidance", "Install tmux/TPM manually, link or copy Tmux/tmux.conf only after reviewing any existing ~/.tmux.conf, then press TPM prefix + I inside tmux.")
	case ModuleKeyboard:
		return addManualStep(builder, module.ID, "keyboard-manual-guidance", "Import keyboard/iris_rev__5.json manually through VIA; the installer must not automate hardware layout changes.")
	case ModuleMacOS:
		return addManualStep(builder, module.ID, "macos-manual-guidance", "Review setup/macos.sh as historical setup guidance only; macOS security approvals, GitHub SSH/account setup, and global shell edits remain manual.")
	default:
		return fmt.Errorf("unsupported module %q", module.ID)
	}
}

func addNeovimUpgradeSteps(builder *PlanBuilder, moduleID ModuleID) error {
	if err := builder.AddStep(Action{ID: "nvim-upgrade-preview", ModuleID: moduleID, Kind: StepDryRun, Classification: ActionDryRunReportOnly, Command: mustApprovedCommand("setup/bootstrap-nvim-deps.sh", "--dry-run"), Description: "Preview supported Neovim tool upgrades and report optional, Mason-backed, AWS/external, and manual items.", ExpectedStatuses: []ActionStatus{StatusChanged, StatusSkipped, StatusOptional, StatusManual, StatusFailed}}); err != nil {
		return err
	}
	return builder.AddStep(Action{ID: "nvim-upgrade-supported", ModuleID: moduleID, Kind: StepUpgrade, Classification: ActionConfirmationRequired, Command: mustApprovedCommand("setup/bootstrap-nvim-deps.sh", "--install"), Description: "Upgrade/install supported Neovim tools after confirmation; manual-only tooling remains guidance.", ExpectedStatuses: []ActionStatus{StatusChanged, StatusSkipped, StatusOptional, StatusManual, StatusFailed}})
}

func addGhosttyUpgradeSteps(builder *PlanBuilder, moduleID ModuleID) error {
	return builder.AddStep(Action{ID: "ghostty-upgrade-report", ModuleID: moduleID, Kind: StepValidate, Classification: ActionAutomatic, Command: mustApprovedCommand("setup/validate-ghostty-config.sh"), Description: "Report Ghostty readiness; app upgrades remain external to the installer.", ExpectedStatuses: []ActionStatus{StatusUnchanged, StatusOptional, StatusManual, StatusFailed}})
}

func addSyncLinkSteps(builder *PlanBuilder, moduleID ModuleID, prefix, script, root string, options PlanOptions) error {
	target, err := inspectManagedConfigTarget(moduleID, root, options.Home)
	if err != nil {
		return err
	}
	builder.AddConfigTarget(target)

	if err := builder.AddStep(Action{ID: prefix + "-link-dry-run", ModuleID: moduleID, Kind: StepDryRun, Classification: ActionDryRunReportOnly, Command: mustApprovedCommand(script, "--dry-run"), Description: "Inspect repository-managed config target and report managed, unmanaged, missing, broken, skipped, or failed state.", ExpectedStatuses: []ActionStatus{StatusManaged, StatusUnmanaged, StatusMissing, StatusSkipped, StatusFailed}}); err != nil {
		return err
	}

	switch target.State {
	case ConfigTargetMissing:
		return builder.AddStep(Action{ID: prefix + "-link-apply", ModuleID: moduleID, Kind: StepSync, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--apply"), Description: "Create repository-managed config link after confirmation.", ExpectedStatuses: []ActionStatus{StatusChanged, StatusManaged, StatusSkipped, StatusFailed}})
	case ConfigTargetManaged:
		if options.ConfirmRemove {
			return addRemoveStep(builder, moduleID, prefix, script)
		}
		return nil
	case ConfigTargetUnmanaged, ConfigTargetBrokenSymlink:
		if options.ConfirmBackup {
			return builder.AddStep(Action{ID: prefix + "-link-backup-apply", ModuleID: moduleID, Kind: StepBackup, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--apply", "--backup"), Description: "Back up unmanaged or broken config target before linking; this requires explicit backup confirmation.", ExpectedStatuses: []ActionStatus{StatusBackedUp, StatusChanged, StatusFailed}})
		}
		return addManualStep(builder, moduleID, prefix+"-backup-required", "Unmanaged or broken config target detected; sync refuses overwrite until backup is explicitly confirmed.")
	default:
		return addManualStep(builder, moduleID, prefix+"-sync-review-required", "Config target state is unknown; inspect it manually before running sync.")
	}
}

func addRemoveStep(builder *PlanBuilder, moduleID ModuleID, prefix, script string) error {
	if script == "setup/link-ghostty-config.sh" {
		return builder.AddStep(Action{ID: prefix + "-link-remove", ModuleID: moduleID, Kind: StepRemove, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--remove"), Description: "Remove only repository-managed Ghostty config link after confirmation.", ExpectedStatuses: []ActionStatus{StatusRemoved, StatusSkipped, StatusFailed}})
	}
	return builder.AddStep(Action{ID: prefix + "-link-remove", ModuleID: moduleID, Kind: StepRemove, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--apply", "--remove"), Description: "Remove only repository-managed Neovim config link after confirmation.", ExpectedStatuses: []ActionStatus{StatusRemoved, StatusSkipped, StatusFailed}})
}

func addLinkSteps(builder *PlanBuilder, moduleID ModuleID, prefix, script string, flow Flow) error {
	if err := builder.AddStep(Action{ID: prefix + "-link-dry-run", ModuleID: moduleID, Kind: StepDryRun, Classification: ActionDryRunReportOnly, Command: mustApprovedCommand(script, "--dry-run"), Description: "Preview repository-managed config linking and unmanaged target conflicts.", ExpectedStatuses: []ActionStatus{StatusChanged, StatusSkipped, StatusManaged, StatusUnmanaged, StatusFailed}}); err != nil {
		return err
	}
	if flow != FlowInstall && flow != FlowSync {
		return nil
	}
	if err := builder.AddStep(Action{ID: prefix + "-link-apply", ModuleID: moduleID, Kind: StepLink, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--apply"), Description: "Apply repository-managed config link; existing scripts refuse unmanaged overwrite without backup.", ExpectedStatuses: []ActionStatus{StatusChanged, StatusSkipped, StatusManaged, StatusUnmanaged, StatusFailed}}); err != nil {
		return err
	}
	if err := builder.AddStep(Action{ID: prefix + "-link-backup-apply", ModuleID: moduleID, Kind: StepBackup, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--apply", "--backup"), Description: "Back up unmanaged target before linking when explicitly selected.", ExpectedStatuses: []ActionStatus{StatusBackedUp, StatusChanged, StatusFailed}}); err != nil {
		return err
	}
	if script == "setup/link-ghostty-config.sh" {
		return builder.AddStep(Action{ID: prefix + "-link-remove", ModuleID: moduleID, Kind: StepRemove, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--remove"), Description: "Remove only repository-managed Ghostty config link.", ExpectedStatuses: []ActionStatus{StatusRemoved, StatusSkipped, StatusFailed}})
	}
	return builder.AddStep(Action{ID: prefix + "-link-remove", ModuleID: moduleID, Kind: StepRemove, Classification: ActionConfirmationRequired, Command: mustApprovedCommand(script, "--apply", "--remove"), Description: "Remove only repository-managed Neovim config link.", ExpectedStatuses: []ActionStatus{StatusRemoved, StatusSkipped, StatusFailed}})
}

func inspectManagedConfigTarget(moduleID ModuleID, root, home string) (ManagedConfigTarget, error) {
	if root == "" {
		root = "."
	}
	if home == "" {
		var err error
		home, err = os.UserHomeDir()
		if err != nil {
			return ManagedConfigTarget{}, err
		}
	}

	var target ManagedConfigTarget
	target.ModuleID = moduleID
	switch moduleID {
	case ModuleNeovim:
		target.SourcePath = filepath.Join(root, "nvim")
		target.TargetPath = filepath.Join(home, ".config", "nvim")
	case ModuleGhostty:
		target.SourcePath = filepath.Join(root, "ghostty", "config.ghostty")
		target.TargetPath = filepath.Join(home, "Library", "Application Support", "com.mitchellh.ghostty", "config.ghostty")
	default:
		return ManagedConfigTarget{}, fmt.Errorf("module %q has no managed sync target", moduleID)
	}

	info, err := os.Lstat(target.TargetPath)
	if err != nil {
		if os.IsNotExist(err) {
			target.State = ConfigTargetMissing
			target.SafeActions = []StepKind{StepSync}
			return target, nil
		}
		target.State = ConfigTargetUnknown
		return target, nil
	}
	if info.Mode()&os.ModeSymlink != 0 {
		linkTarget, err := os.Readlink(target.TargetPath)
		if err != nil {
			target.State = ConfigTargetUnknown
			return target, nil
		}
		if filepath.Clean(linkTarget) == filepath.Clean(target.SourcePath) {
			target.State = ConfigTargetManaged
			target.SafeActions = []StepKind{StepRemove}
			return target, nil
		}
		if _, err := os.Stat(target.TargetPath); os.IsNotExist(err) {
			target.State = ConfigTargetBrokenSymlink
			target.SafeActions = []StepKind{StepBackup}
			return target, nil
		}
	}

	target.State = ConfigTargetUnmanaged
	target.SafeActions = []StepKind{StepBackup}
	return target, nil
}

func addManualStep(builder *PlanBuilder, moduleID ModuleID, id, message string) error {
	return builder.AddStep(Action{ID: id, ModuleID: moduleID, Kind: StepManualGuidance, Classification: ActionManualOnly, Description: message, ExpectedStatuses: []ActionStatus{StatusManual}})
}

func supportsFlow(module Module, flow Flow) bool {
	for _, supported := range module.SupportedFlows {
		if supported == flow {
			return true
		}
	}
	return false
}

func (b *PlanBuilder) hasPriorPreview(moduleID ModuleID) bool {
	for _, step := range b.plan.Steps {
		if step.ModuleID == moduleID && IsPreviewStepKind(step.Kind) {
			return true
		}
	}

	return false
}
