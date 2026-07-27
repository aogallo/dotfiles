package installer

import (
	"fmt"
	"strings"
)

// ActionClassification describes how safely an action may be handled.
type ActionClassification string

const (
	ActionAutomatic            ActionClassification = "automatic"
	ActionConfirmationRequired ActionClassification = "confirmation_required"
	ActionDryRunReportOnly     ActionClassification = "dry_run_report_only"
	ActionManualOnly           ActionClassification = "manual_only"
)

// StepKind describes the kind of work represented by an action step.
type StepKind string

const (
	StepValidate       StepKind = "validate"
	StepDryRun         StepKind = "dry_run"
	StepReport         StepKind = "report"
	StepInstall        StepKind = "install"
	StepLink           StepKind = "link"
	StepBackup         StepKind = "backup"
	StepRemove         StepKind = "remove"
	StepUpgrade        StepKind = "upgrade"
	StepSync           StepKind = "sync"
	StepManualGuidance StepKind = "manual_guidance"
)

// Flow describes a top-level installer flow.
type Flow string

const (
	FlowInstall Flow = "install"
	FlowSync    Flow = "sync"
	FlowUpgrade Flow = "upgrade"
	FlowQuit    Flow = "quit"
)

// ActionStatus describes a normalized status an action may produce.
type ActionStatus string

const (
	StatusChanged   ActionStatus = "changed"
	StatusUnchanged ActionStatus = "unchanged"
	StatusSkipped   ActionStatus = "skipped"
	StatusFailed    ActionStatus = "failed"
	StatusOptional  ActionStatus = "optional"
	StatusManual    ActionStatus = "manual"
	StatusManaged   ActionStatus = "managed"
	StatusUnmanaged ActionStatus = "unmanaged"
	StatusMissing   ActionStatus = "missing"
	StatusBackedUp  ActionStatus = "backed_up"
	StatusRemoved   ActionStatus = "removed"
)

// Action describes a unit of installer work.
type Action struct {
	ID               string
	ModuleID         ModuleID
	Kind             StepKind
	Classification   ActionClassification
	Command          []string
	Description      string
	ExpectedStatuses []ActionStatus
}

// RequiresConfirmation reports whether the action needs an explicit user confirmation.
func (a Action) RequiresConfirmation() bool {
	return IsMutatingStepKind(a.Kind) || a.Classification == ActionConfirmationRequired
}

// HasCommand reports whether the action has an executable argv boundary.
func (a Action) HasCommand() bool {
	return len(a.Command) > 0
}

// Validate enforces foundational safety rules for action metadata.
func (a Action) Validate() error {
	if a.Classification == ActionManualOnly && a.HasCommand() {
		return fmt.Errorf("manual-only action %q must not have an executable command", a.ID)
	}

	if IsMutatingStepKind(a.Kind) && a.Classification != ActionConfirmationRequired {
		return fmt.Errorf("mutating action %q must require confirmation", a.ID)
	}

	return nil
}

// IsMutatingStepKind reports whether a step kind may change local machine state.
func IsMutatingStepKind(kind StepKind) bool {
	switch kind {
	case StepInstall, StepLink, StepBackup, StepRemove, StepUpgrade, StepSync:
		return true
	default:
		return false
	}
}

// IsPreviewStepKind reports whether a step can satisfy the preview-before-mutation gate.
func IsPreviewStepKind(kind StepKind) bool {
	switch kind {
	case StepValidate, StepDryRun, StepReport, StepManualGuidance:
		return true
	default:
		return false
	}
}

// NewApprovedCommand returns a repository-relative argv only for documented setup-script invocations.
func NewApprovedCommand(script string, args ...string) ([]string, error) {
	argv := append([]string{script}, args...)
	key := strings.Join(argv, "\x00")
	if _, ok := approvedCommands()[key]; !ok {
		return nil, fmt.Errorf("command is not approved for installer execution: %v", argv)
	}
	return argv, nil
}

func mustApprovedCommand(script string, args ...string) []string {
	argv, err := NewApprovedCommand(script, args...)
	if err != nil {
		panic(err)
	}
	return argv
}

func approvedCommands() map[string]struct{} {
	commands := [][]string{
		{"setup/validate-nvim-deps.sh"},
		{"setup/bootstrap-nvim-deps.sh", "--dry-run"},
		{"setup/bootstrap-nvim-deps.sh", "--install"},
		{"setup/link-nvim-config.sh", "--dry-run"},
		{"setup/link-nvim-config.sh", "--apply"},
		{"setup/link-nvim-config.sh", "--apply", "--backup"},
		{"setup/link-nvim-config.sh", "--apply", "--remove"},
		{"setup/validate-zsh-config.sh"},
		{"setup/validate-ghostty-config.sh"},
		{"setup/link-ghostty-config.sh", "--dry-run"},
		{"setup/link-ghostty-config.sh", "--apply"},
		{"setup/link-ghostty-config.sh", "--apply", "--backup"},
		{"setup/link-ghostty-config.sh", "--remove"},
	}

	approved := make(map[string]struct{}, len(commands))
	for _, command := range commands {
		approved[strings.Join(command, "\x00")] = struct{}{}
	}
	return approved
}
