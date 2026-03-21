package main

import (
	"fmt"
	"os"

	devrocket "github.com/IsaiasUziel/devrocket-ecosystem"
	"github.com/IsaiasUziel/devrocket-ecosystem/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
)

var version = "dev"

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "--version", "-v":
			fmt.Printf("devrocket-ecosystem %s\n", version)
			os.Exit(0)
		case "--help", "-h":
			printHelp()
			os.Exit(0)
		}
	}

	// Set the embedded filesystem for the TUI installer before launching.
	tui.EmbedFS = devrocket.Configs

	p := tea.NewProgram(tui.NewModel(version), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func printHelp() {
	fmt.Println(`DevRocket Ecosystem — Terminal Development Environment

Usage:
  devrocket-ecosystem            Launch interactive TUI installer
  devrocket-ecosystem --version  Show version
  devrocket-ecosystem --help     Show this help

For more info: https://github.com/IsaiasUziel/devrocket-ecosystem`)
}
