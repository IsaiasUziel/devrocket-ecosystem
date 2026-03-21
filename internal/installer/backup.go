package installer

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
)

// CreateBackup copies an existing file or directory into a timestamped
// subdirectory under ~/.devrocket-backup/. Returns the backup path on success
// or an empty string when there is nothing to back up (target does not exist).
// Symlinks are skipped intentionally — only real files are backed up.
func CreateBackup(target string) (string, error) {
	info, err := os.Lstat(target)
	if err != nil {
		return "", nil // nothing to back up
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return "", nil // don't back up symlinks
	}

	timestamp := time.Now().Format("2006-01-02_150405")
	backupBase := filepath.Join(config.BackupDir(), timestamp)
	if err := os.MkdirAll(backupBase, 0755); err != nil {
		return "", fmt.Errorf("failed to create backup dir: %w", err)
	}

	backupPath := filepath.Join(backupBase, filepath.Base(target))

	if info.IsDir() {
		if err := copyDir(target, backupPath); err != nil {
			return "", fmt.Errorf("failed to backup directory %s: %w", target, err)
		}
	} else {
		if err := copyFile(target, backupPath); err != nil {
			return "", fmt.Errorf("failed to backup file %s: %w", target, err)
		}
	}

	return backupPath, nil
}

// copyFile copies a single file from src to dst, preserving permissions.
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return err
	}

	info, err := os.Stat(src)
	if err != nil {
		return err
	}
	return os.Chmod(dst, info.Mode())
}

// copyDir recursively copies a directory tree from src to dst.
func copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		relPath, _ := filepath.Rel(src, path)
		targetPath := filepath.Join(dst, relPath)

		if info.IsDir() {
			return os.MkdirAll(targetPath, info.Mode())
		}

		return copyFile(path, targetPath)
	})
}
