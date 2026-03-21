package tui

import "github.com/charmbracelet/lipgloss"

// Kanagawa Dragon color palette
var (
	colorBg     = lipgloss.Color("#1f1f28")
	colorFg     = lipgloss.Color("#dcd7ba")
	colorSubtle = lipgloss.Color("#54546d")
	colorAccent = lipgloss.Color("#7e9cd8")
	colorGreen  = lipgloss.Color("#98bb6c")
	colorYellow = lipgloss.Color("#e6c384")
	colorRed    = lipgloss.Color("#ff5d62")
	colorCyan   = lipgloss.Color("#7fb4ca")
	_           = lipgloss.Color("#ffa066") // colorOrange — reserved for future use
)

var (
	titleStyle = lipgloss.NewStyle().
			Foreground(colorYellow).
			Bold(true)

	subtitleStyle = lipgloss.NewStyle().
			Foreground(colorSubtle).
			Italic(true)

	accentStyle = lipgloss.NewStyle().
			Foreground(colorAccent)

	successStyle = lipgloss.NewStyle().
			Foreground(colorGreen)

	warnStyle = lipgloss.NewStyle().
			Foreground(colorYellow)

	errorStyle = lipgloss.NewStyle().
			Foreground(colorRed)

	dimStyle = lipgloss.NewStyle().
			Foreground(colorSubtle)

	selectedStyle = lipgloss.NewStyle().
			Foreground(colorCyan).
			Bold(true)

	checkboxOnStyle = lipgloss.NewStyle().
			Foreground(colorGreen)

	checkboxOffStyle = lipgloss.NewStyle().
				Foreground(colorSubtle)

	buttonActiveStyle = lipgloss.NewStyle().
				Foreground(colorBg).
				Background(colorAccent).
				Bold(true).
				Padding(0, 3)

	buttonInactiveStyle = lipgloss.NewStyle().
				Foreground(colorSubtle).
				Background(lipgloss.Color("#2a2a37")).
				Padding(0, 3)

	borderStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(colorSubtle).
			Padding(1, 2)

	statusCheckStyle = successStyle.Copy()
	statusWarnStyle  = warnStyle.Copy()
)

// Ensure unused styles don't trigger compiler errors — they are part of the
// exported visual vocabulary and will be used in later phases.
var (
	_ = colorFg
	_ = subtitleStyle
	_ = borderStyle
	_ = statusCheckStyle
	_ = statusWarnStyle
)
