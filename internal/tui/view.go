package tui

import (
	"fmt"
	"strings"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/installer"
)

const banner = `
 ____             ____            _        _   
|  _ \  _____   _|  _ \ ___   ___| | _____| |_ 
| | | |/ _ \ \ / / |_) / _ \ / __| |/ / _ \ __|
| |_| |  __/\ V /|  _ < (_) | (__|   <  __/ |_ 
|____/ \___| \_/ |_| \_\___/ \___|_|\_\___|\__|
`

// View implements tea.Model.
func (m Model) View() string {
	switch m.screen {
	case ScreenWelcome:
		return m.viewWelcome()
	case ScreenSelector:
		return m.viewSelector()
	case ScreenPreflight:
		return m.viewPreflight()
	case ScreenInstalling:
		return m.viewInstalling()
	case ScreenUninstalling:
		return m.viewUninstalling()
	case ScreenResult:
		return m.viewResult()
	default:
		return "Unknown screen\n"
	}
}

func (m Model) viewWelcome() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render(banner))
	b.WriteString("\n")
	b.WriteString(accentStyle.Render("  E C O S Y S T E M"))
	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render(fmt.Sprintf("  v%s", m.version)))
	b.WriteString("\n\n")
	b.WriteString("  An opinionated, batteries-included terminal dev environment.\n")
	b.WriteString(dimStyle.Render("  Ghostty + Tmux + Neovim/LazyVim + Zsh\n"))
	b.WriteString("\n\n")

	options := []string{"Install", "Uninstall", "Quit"}
	for i, opt := range options {
		if i == m.welcomeCursor {
			b.WriteString("  " + buttonActiveStyle.Render(fmt.Sprintf(" ▸ %s ", opt)) + "  ")
		} else {
			b.WriteString("  " + buttonInactiveStyle.Render(fmt.Sprintf("   %s ", opt)) + "  ")
		}
	}

	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("  ← → / h l to navigate • Enter to select • q to quit"))
	b.WriteString("\n")

	return b.String()
}

func (m Model) viewSelector() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("  Select Components to Install"))
	b.WriteString("\n\n")

	for i, item := range m.components {
		cursor := "  "
		if i == m.selectorIdx {
			cursor = accentStyle.Render("▸ ")
		}

		checkbox := checkboxOffStyle.Render("[ ]")
		if item.Selected {
			checkbox = checkboxOnStyle.Render("[✓]")
		}

		name := item.Component.Name
		if i == m.selectorIdx {
			name = selectedStyle.Render(name)
		}

		desc := dimStyle.Render(item.Component.Description)
		b.WriteString(fmt.Sprintf("  %s %s %s  %s\n", cursor, checkbox, name, desc))
	}

	b.WriteString("\n")

	// Backup toggle
	backupCursor := "  "
	if m.selectorIdx == len(m.components) {
		backupCursor = accentStyle.Render("▸ ")
	}
	backupCheck := checkboxOffStyle.Render("[ ]")
	if m.backupEnabled {
		backupCheck = checkboxOnStyle.Render("[✓]")
	}
	backupLabel := "Backup existing configs first"
	if m.selectorIdx == len(m.components) {
		backupLabel = selectedStyle.Render(backupLabel)
	}
	b.WriteString(fmt.Sprintf("  %s %s %s\n", backupCursor, backupCheck, backupLabel))

	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("  ↑↓ / j k navigate • Space toggle • a all • n none • Enter proceed • Esc back"))
	b.WriteString("\n")

	return b.String()
}

func (m Model) viewPreflight() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("  Pre-flight Checks"))
	b.WriteString("\n\n")

	// System info
	b.WriteString(fmt.Sprintf("  System: %s\n", accentStyle.Render(installer.FormatOS(m.systemInfo))))
	b.WriteString(fmt.Sprintf("  Homebrew: %s\n", accentStyle.Render(m.systemInfo.BrewPrefix)))

	if m.gentlemanDots {
		b.WriteString(fmt.Sprintf("  Gentleman.Dots: %s\n", successStyle.Render("✓ detected")))
	} else {
		b.WriteString(fmt.Sprintf("  Gentleman.Dots: %s\n", warnStyle.Render("⚠ not found (recommended)")))
	}

	b.WriteString("\n")
	b.WriteString("  Component Status:\n\n")

	for _, item := range m.components {
		if !item.Selected {
			continue
		}

		var statusIcon string
		var detail string
		if item.Status.Installed {
			statusIcon = successStyle.Render("  ✓")
			detail = dimStyle.Render(" ready")
		} else {
			statusIcon = warnStyle.Render("  ⚠")
			detail = warnStyle.Render(" not found — will skip")
		}

		b.WriteString(fmt.Sprintf("  %s %s%s\n", statusIcon, item.Component.Name, detail))
	}

	if m.backupEnabled {
		b.WriteString(fmt.Sprintf("\n  Backup: %s\n", successStyle.Render("✓ enabled")))
	}

	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("  Enter to proceed • Esc to go back"))
	b.WriteString("\n")

	return b.String()
}

func (m Model) viewInstalling() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("  Installing..."))
	b.WriteString("\n\n")

	resultIdx := 0
	for i, item := range m.components {
		if !item.Selected {
			continue
		}

		if i < m.currentStep {
			// Completed — find this component's result
			var result *installer.InstallResult
			for j := range m.results {
				if m.results[j].Component == item.Component.Name {
					result = &m.results[j]
					break
				}
			}
			_ = resultIdx

			if result != nil && result.Success {
				b.WriteString(fmt.Sprintf("  %s %s\n", successStyle.Render("✓"), item.Component.Name))
			} else if result != nil && result.Skipped {
				b.WriteString(fmt.Sprintf("  %s %s %s\n", warnStyle.Render("⚠"), item.Component.Name, dimStyle.Render("skipped")))
			} else if result != nil && result.Error != nil {
				b.WriteString(fmt.Sprintf("  %s %s %s\n", errorStyle.Render("✗"), item.Component.Name, errorStyle.Render(result.Error.Error())))
			} else {
				b.WriteString(fmt.Sprintf("  %s %s\n", successStyle.Render("✓"), item.Component.Name))
			}
		} else if i == m.currentStep {
			// In progress
			b.WriteString(fmt.Sprintf("  %s %s...\n", accentStyle.Render("◌"), item.Component.Name))
		} else {
			// Pending
			b.WriteString(fmt.Sprintf("  %s %s\n", dimStyle.Render("○"), dimStyle.Render(item.Component.Name)))
		}
	}

	if m.progressMsg != "" {
		b.WriteString(fmt.Sprintf("\n  %s\n", dimStyle.Render(m.progressMsg)))
	}

	return b.String()
}

func (m Model) viewUninstalling() string {
	var b strings.Builder
	b.WriteString(titleStyle.Render("  Uninstalling..."))
	b.WriteString("\n\n")
	b.WriteString(fmt.Sprintf("  %s Removing installed files...\n", accentStyle.Render("◌")))
	return b.String()
}

func (m Model) viewResult() string {
	var b strings.Builder

	if m.action == ActionInstall {
		b.WriteString(successStyle.Render("\n  🚀 DevRocket Ecosystem installed!\n"))
		b.WriteString("\n")

		succeeded := 0
		skipped := 0
		failed := 0
		for _, r := range m.results {
			if r.Success {
				succeeded++
			} else if r.Skipped {
				skipped++
			} else {
				failed++
			}
		}

		b.WriteString(fmt.Sprintf("  %s %d components installed\n", successStyle.Render("✓"), succeeded))
		if skipped > 0 {
			b.WriteString(fmt.Sprintf("  %s %d components skipped\n", warnStyle.Render("⚠"), skipped))
		}
		if failed > 0 {
			b.WriteString(fmt.Sprintf("  %s %d components failed\n", errorStyle.Render("✗"), failed))
		}

		b.WriteString("\n")
		b.WriteString(titleStyle.Render("  Next Steps:"))
		b.WriteString("\n\n")
		b.WriteString(fmt.Sprintf("  1. %s to apply terminal config\n", accentStyle.Render("Restart Ghostty")))
		b.WriteString(fmt.Sprintf("  2. If you installed from outside tmux, run %s\n", accentStyle.Render("tmux source ~/.tmux.conf")))
		b.WriteString(fmt.Sprintf("  3. Press %s inside tmux for TPM plugins\n", accentStyle.Render("C-a + I")))
		b.WriteString(fmt.Sprintf("  4. Open %s and wait for LazyVim sync\n", accentStyle.Render("nvim")))
		b.WriteString(fmt.Sprintf("  5. Edit %s for private aliases\n", accentStyle.Render("~/.zshrc.local")))
		b.WriteString(fmt.Sprintf("  6. Press %s for cheatsheet popup\n", accentStyle.Render("Alt+c")))

		for _, r := range m.results {
			if len(r.Notes) == 0 {
				continue
			}
			b.WriteString("\n")
			b.WriteString(titleStyle.Render(fmt.Sprintf("  %s Notes:", r.Component)))
			b.WriteString("\n")
			for _, note := range r.Notes {
				style := dimStyle
				if strings.Contains(note, "reloaded automatically") {
					style = successStyle
				} else if strings.Contains(note, "not reloaded automatically") {
					style = warnStyle
				}
				b.WriteString(fmt.Sprintf("  • %s\n", style.Render(note)))
			}
		}
	} else if m.action == ActionUninstall {
		if m.resultError != nil {
			b.WriteString(errorStyle.Render(fmt.Sprintf("\n  ✗ Uninstall failed: %v\n", m.resultError)))
		} else if m.uninstallResult != nil {
			b.WriteString(successStyle.Render("\n  ✓ DevRocket Ecosystem uninstalled!\n"))
			b.WriteString("\n")
			b.WriteString(fmt.Sprintf("  Files removed: %d\n", m.uninstallResult.FilesRemoved))
			if m.uninstallResult.FilesRestored > 0 {
				b.WriteString(fmt.Sprintf("  Configs restored from backup: %d\n", m.uninstallResult.FilesRestored))
			}
			b.WriteString(fmt.Sprintf("\n  %s\n", warnStyle.Render("~/.zshrc.local was preserved (your private data is safe)")))
		}
	}

	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render("  Press q or Esc to exit"))
	b.WriteString("\n")

	return b.String()
}
