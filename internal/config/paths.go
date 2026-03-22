package config

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

var darwinBrewPrefixes = []string{
	"/opt/homebrew",
	"/usr/local",
}

// HomeDir returns the user's home directory.
func HomeDir() string {
	home, _ := os.UserHomeDir()
	return home
}

// ConfigDir returns ~/.config.
func ConfigDir() string {
	return filepath.Join(HomeDir(), ".config")
}

func existingDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func detectBrewPrefix() string {
	if out, err := exec.Command("brew", "--prefix").Output(); err == nil {
		prefix := strings.TrimSpace(string(out))
		if prefix != "" && existingDir(prefix) {
			return prefix
		}
	}

	home := HomeDir()
	candidates := []string{}
	if runtime.GOOS == "darwin" {
		candidates = append(candidates, darwinBrewPrefixes...)
	}
	candidates = append(candidates,
		filepath.Join(home, ".linuxbrew"),
		"/home/linuxbrew/.linuxbrew",
	)

	for _, prefix := range candidates {
		if existingDir(prefix) && existingDir(filepath.Join(prefix, "bin")) {
			return prefix
		}
	}

	return ""
}

// BrewPrefix detects the preferred install prefix for the current system.
// Order of detection: `brew --prefix`, known Homebrew/Linuxbrew paths, Linux ~/.local fallback.
func BrewPrefix() string {
	if prefix := detectBrewPrefix(); prefix != "" {
		return prefix
	}

	if runtime.GOOS == "linux" {
		return filepath.Join(HomeDir(), ".local")
	}

	return filepath.Join("/usr/local")
}

// BinDir returns the preferred user-facing bin directory for installed helpers.
func BinDir() string {
	if prefix := detectBrewPrefix(); prefix != "" {
		binDir := filepath.Join(prefix, "bin")
		if existingDir(binDir) {
			return binDir
		}
	}

	if runtime.GOOS == "linux" {
		return filepath.Join(HomeDir(), ".local", "bin")
	}

	return filepath.Join("/usr/local", "bin")
}

// BackupDir returns the base backup directory path (~/.devrocket-backup).
func BackupDir() string {
	return filepath.Join(HomeDir(), ".devrocket-backup")
}

// ManifestPath returns the installation manifest file path.
func ManifestPath() string {
	return filepath.Join(HomeDir(), ".devrocket-manifest.json")
}
