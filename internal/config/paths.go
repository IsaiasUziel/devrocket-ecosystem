package config

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// HomeDir returns the user's home directory.
func HomeDir() string {
	home, _ := os.UserHomeDir()
	return home
}

// ConfigDir returns ~/.config.
func ConfigDir() string {
	return filepath.Join(HomeDir(), ".config")
}

// BrewPrefix detects the Homebrew prefix for the current system.
// Order of detection: `brew --prefix`, known macOS paths, Linux ~/.linuxbrew.
func BrewPrefix() string {
	if out, err := exec.Command("brew", "--prefix").Output(); err == nil {
		return strings.TrimSpace(string(out))
	}
	if runtime.GOOS == "darwin" {
		if _, err := os.Stat("/opt/homebrew"); err == nil {
			return "/opt/homebrew"
		}
		return "/usr/local"
	}
	home := HomeDir()
	if _, err := os.Stat(filepath.Join(home, ".linuxbrew")); err == nil {
		return filepath.Join(home, ".linuxbrew")
	}
	return "/usr/local"
}

// BackupDir returns the base backup directory path (~/.devrocket-backup).
func BackupDir() string {
	return filepath.Join(HomeDir(), ".devrocket-backup")
}

// ManifestPath returns the installation manifest file path.
func ManifestPath() string {
	return filepath.Join(HomeDir(), ".devrocket-manifest.json")
}
