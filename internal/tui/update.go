package tui

import (
	"fmt"
	"io/fs"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/installer"
	tea "github.com/charmbracelet/bubbletea"
)

// Messages for async operations.
type installDoneMsg struct {
	result installer.InstallResult
}

// installSkipMsg fires synchronously when the current step is not selected.
// It carries the skipped result so updateInstalling can append it and advance.
type installSkipMsg struct {
	result installer.InstallResult
}

type installAllDoneMsg struct{}

type uninstallDoneMsg struct {
	result *installer.UninstallResult
	err    error
}

// EmbedFS is set from main.go (Phase 4) with the embedded config filesystem.
// It is declared here so update.go can reference it for async install commands.
var EmbedFS fs.FS

// Update implements tea.Model.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case tea.KeyMsg:
		// Global quit shortcut — works on every screen.
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
	}

	switch m.screen {
	case ScreenWelcome:
		return m.updateWelcome(msg)
	case ScreenSelector:
		return m.updateSelector(msg)
	case ScreenPreflight:
		return m.updatePreflight(msg)
	case ScreenInstalling:
		return m.updateInstalling(msg)
	case ScreenUninstalling:
		return m.updateUninstalling(msg)
	case ScreenResult:
		return m.updateResult(msg)
	}

	return m, nil
}

func (m Model) updateWelcome(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "left", "h":
			if m.welcomeCursor > 0 {
				m.welcomeCursor--
			}
		case "right", "l":
			if m.welcomeCursor < 2 {
				m.welcomeCursor++
			}
		case "enter":
			switch m.welcomeCursor {
			case 0: // Install
				m.action = ActionInstall
				m.screen = ScreenSelector
			case 1: // Uninstall
				m.action = ActionUninstall
				if !installer.ManifestExists() {
					m.resultError = fmt.Errorf("no installation manifest found — nothing to uninstall")
					m.screen = ScreenResult
				} else {
					m.screen = ScreenUninstalling
					return m, m.doUninstall()
				}
			case 2: // Quit
				return m, tea.Quit
			}
		case "q":
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m Model) updateSelector(msg tea.Msg) (tea.Model, tea.Cmd) {
	maxIdx := len(m.components)
	if m.hasZshLocal && m.zshSelected() {
		maxIdx = len(m.components) + 1
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.selectorIdx > 0 {
				m.selectorIdx--
			}
		case "down", "j":
			if m.selectorIdx < maxIdx {
				m.selectorIdx++
			}
		case " ":
			if m.selectorIdx < len(m.components) {
				m.components[m.selectorIdx].Selected = !m.components[m.selectorIdx].Selected
			} else if m.selectorIdx == len(m.components) {
				m.backupEnabled = !m.backupEnabled
			} else if m.hasZshLocal && m.zshSelected() && m.selectorIdx == len(m.components)+1 {
				m.replaceZshLocal = !m.replaceZshLocal
			}
		case "a":
			for i := range m.components {
				m.components[i].Selected = true
			}
		case "n":
			for i := range m.components {
				m.components[i].Selected = false
			}
		case "enter":
			// Run pre-flight checks before showing the preflight screen.
			m.systemInfo = installer.DetectSystem()
			m.gentlemanDots = installer.CheckGentlemanDots()
			for i := range m.components {
				m.components[i].Status = installer.CheckTool(m.components[i].Component)
			}
			m.screen = ScreenPreflight
		case "esc", "q":
			m.screen = ScreenWelcome
		}
	}
	if m.selectorIdx > maxIdx {
		m.selectorIdx = maxIdx
	}
	return m, nil
}

func (m Model) updatePreflight(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			// Start installation.
			m.screen = ScreenInstalling
			m.currentStep = 0
			m.results = nil
			return m, m.doInstallNext()
		case "esc":
			m.screen = ScreenSelector
		}
	}
	return m, nil
}

func (m Model) updateInstalling(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case installSkipMsg:
		// Skipped step: record result, advance, check next.
		m.results = append(m.results, msg.result)
		m.currentStep++
		return m, m.doInstallNext()

	case installDoneMsg:
		m.results = append(m.results, msg.result)
		m.currentStep++
		return m, m.doInstallNext()

	case installAllDoneMsg:
		// Write manifest.
		manifest := installer.BuildManifest(m.version, m.results, m.backupEnabled)
		_ = installer.WriteManifest(manifest)

		// Create .zshrc.local if needed.
		if EmbedFS != nil && m.zshSelected() {
			if note, err := installer.CreateZshrcLocal(EmbedFS, m.replaceZshLocal, m.backupEnabled); err == nil && note != "" {
				for i := range m.results {
					if m.results[i].Component == "Zsh" {
						m.results[i].Notes = append(m.results[i].Notes, note)
						break
					}
				}
			}
		}

		m.screen = ScreenResult
	}
	return m, nil
}

func (m Model) updateUninstalling(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case uninstallDoneMsg:
		m.uninstallResult = msg.result
		m.resultError = msg.err
		m.screen = ScreenResult
	}
	return m, nil
}

func (m Model) updateResult(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "enter":
			return m, tea.Quit
		}
	}
	return m, nil
}

// doInstallNext returns a tea.Cmd for the current step.
//
// Value-semantics note: this method runs on a copy of Model (value receiver).
// It must NOT mutate m.currentStep or m.results — those mutations belong in
// updateInstalling, which holds the real model. Instead:
//   - If the current step should be skipped, return an installSkipMsg so that
//     updateInstalling appends the result and advances the cursor.
//   - If the current step is ready, fire the async goroutine and return installDoneMsg.
//   - If all steps are exhausted, return installAllDoneMsg.
func (m Model) doInstallNext() tea.Cmd {
	if m.currentStep >= len(m.components) {
		return func() tea.Msg { return installAllDoneMsg{} }
	}

	comp := m.components[m.currentStep]

	// Not selected by the user — skip via message so updateInstalling can
	// properly mutate the real model's results and currentStep.
	if !comp.Selected {
		return func() tea.Msg {
			return installSkipMsg{
				result: installer.InstallResult{
					Component: comp.Component.Name,
					Skipped:   true,
				},
			}
		}
	}

	return func() tea.Msg {
		if EmbedFS == nil {
			return installDoneMsg{
				result: installer.InstallResult{
					Component: comp.Component.Name,
					Error:     fmt.Errorf("embedded filesystem not available"),
				},
			}
		}

		// Skip if the required tool is not installed (Cheatsheet has no dep
		// and is always marked installed by CheckTool, so this only affects
		// components with DetectCmd set and no tool found).
		if !comp.Status.Installed && comp.Component.DetectCmd != "" {
			return installDoneMsg{
				result: installer.InstallResult{
					Component: comp.Component.Name,
					Skipped:   true,
				},
			}
		}

		result := installer.InstallComponent(comp.Component, EmbedFS, m.backupEnabled)
		return installDoneMsg{result: result}
	}
}

// doUninstall returns a tea.Cmd that performs the uninstall operation.
func (m Model) doUninstall() tea.Cmd {
	return func() tea.Msg {
		result, err := installer.Uninstall()
		return uninstallDoneMsg{result: result, err: err}
	}
}
