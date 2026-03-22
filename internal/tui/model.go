// Package tui provides the Bubbletea TUI model for the devrocket installer.
package tui

import (
	"os"
	"path/filepath"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
	"github.com/IsaiasUziel/devrocket-ecosystem/internal/installer"
	tea "github.com/charmbracelet/bubbletea"
)

// Screen represents the current TUI screen.
type Screen int

const (
	ScreenWelcome Screen = iota
	ScreenSelector
	ScreenPreflight
	ScreenInstalling
	ScreenUninstalling
	ScreenResult
)

// Action represents what the user chose to do.
type Action int

const (
	ActionNone Action = iota
	ActionInstall
	ActionUninstall
)

// ComponentItem represents a selectable component in the UI.
type ComponentItem struct {
	Component config.Component
	Selected  bool
	Status    installer.ToolStatus
}

// Model is the main Bubbletea model.
type Model struct {
	screen  Screen
	action  Action
	version string
	width   int
	height  int

	// Welcome screen
	welcomeCursor int // 0=Install, 1=Uninstall, 2=Quit

	// Selector screen
	components      []ComponentItem
	selectorIdx     int
	backupEnabled   bool
	hasZshLocal     bool
	replaceZshLocal bool

	// Preflight
	systemInfo    installer.SystemInfo
	gentlemanDots bool

	// Progress
	currentStep int
	totalSteps  int
	progressMsg string
	installing  bool

	// Results
	results         []installer.InstallResult
	uninstallResult *installer.UninstallResult
	resultError     error
}

// NewModel creates a new TUI model.
func NewModel(version string) Model {
	components := config.AllComponents()
	items := make([]ComponentItem, len(components))
	for i, c := range components {
		items[i] = ComponentItem{
			Component: c,
			Selected:  true,
		}
	}

	zshLocalPath := filepath.Join(config.HomeDir(), ".zshrc.local")
	_, err := os.Stat(zshLocalPath)
	hasZshLocal := err == nil

	return Model{
		screen:        ScreenWelcome,
		version:       version,
		components:    items,
		backupEnabled: true,
		hasZshLocal:   hasZshLocal,
	}
}

// Init implements tea.Model.
func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) zshSelected() bool {
	for _, item := range m.components {
		if item.Component.Name == "Zsh" {
			return item.Selected
		}
	}
	return false
}
