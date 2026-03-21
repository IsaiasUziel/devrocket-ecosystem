package installer

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
)

// UninstallResult holds the outcome of an uninstall operation.
type UninstallResult struct {
	FilesRemoved  int
	FilesRestored int
	Errors        []string
}

// Uninstall removes all files tracked in the installation manifest.
// When a backup directory is recorded in the manifest, backed-up files are
// restored. ~/.zshrc.local is NEVER removed — it contains user customisations.
func Uninstall() (*UninstallResult, error) {
	manifest, err := ReadManifest()
	if err != nil {
		return nil, fmt.Errorf("no installation manifest found — nothing to uninstall")
	}

	result := &UninstallResult{}

	// Remove installed files in reverse order.
	for i := len(manifest.Files) - 1; i >= 0; i-- {
		file := manifest.Files[i]
		if err := os.Remove(file); err != nil && !os.IsNotExist(err) {
			result.Errors = append(result.Errors, fmt.Sprintf("failed to remove %s: %v", file, err))
		} else {
			result.FilesRemoved++
		}
	}

	// Remove known config directories if they are now empty.
	cleanupDirs := []string{
		filepath.Join(config.ConfigDir(), "ghostty", "shaders"),
		filepath.Join(config.ConfigDir(), "ghostty", "themes"),
		filepath.Join(config.ConfigDir(), "ghostty"),
		filepath.Join(config.ConfigDir(), "nvim"),
	}
	for _, dir := range cleanupDirs {
		entries, err := os.ReadDir(dir)
		if err == nil && len(entries) == 0 {
			os.Remove(dir)
		}
	}

	// Restore from backup when one was recorded.
	if manifest.BackupDir != "" {
		if _, err := os.Stat(manifest.BackupDir); err == nil {
			restored, errs := restoreBackup(manifest.BackupDir)
			result.FilesRestored = restored
			result.Errors = append(result.Errors, errs...)
		}
	}

	// Remove the manifest itself.
	RemoveManifest()

	return result, nil
}

// restoreBackup copies files from backupDir back to their original locations.
// The mapping is derived from known installer-managed file names.
func restoreBackup(backupDir string) (int, []string) {
	restored := 0
	var errors []string

	restoreMap := map[string]string{
		"config":    filepath.Join(config.ConfigDir(), "ghostty", "config"),
		"themes":    filepath.Join(config.ConfigDir(), "ghostty", "themes"),
		"shaders":   filepath.Join(config.ConfigDir(), "ghostty", "shaders"),
		"tmux.conf": filepath.Join(config.HomeDir(), ".tmux.conf"),
		"nvim":      filepath.Join(config.ConfigDir(), "nvim"),
		"zshrc":     filepath.Join(config.HomeDir(), ".zshrc"),
		"p10k.zsh":  filepath.Join(config.HomeDir(), ".p10k.zsh"),
	}

	entries, err := os.ReadDir(backupDir)
	if err != nil {
		return 0, []string{fmt.Sprintf("failed to read backup dir: %v", err)}
	}

	for _, entry := range entries {
		dest, ok := restoreMap[entry.Name()]
		if !ok {
			continue
		}

		src := filepath.Join(backupDir, entry.Name())
		if entry.IsDir() {
			if err := copyDir(src, dest); err != nil {
				errors = append(errors, fmt.Sprintf("failed to restore %s: %v", entry.Name(), err))
			} else {
				restored++
			}
		} else {
			if err := copyFile(src, dest); err != nil {
				errors = append(errors, fmt.Sprintf("failed to restore %s: %v", entry.Name(), err))
			} else {
				restored++
			}
		}
	}

	return restored, errors
}
