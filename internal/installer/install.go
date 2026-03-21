package installer

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
)

// InstallResult holds the outcome of installing a single component.
type InstallResult struct {
	Component string
	Success   bool
	Error     error
	Files     []string
	Skipped   bool
	Notes     []string
}

// InstallComponent extracts embedded files for a component into their target locations.
// When backup is true, existing targets are backed up before being overwritten.
// The embed.FS is wired in Phase 4 — callers pass an fs.FS so this stays testable.
func InstallComponent(comp config.Component, embedFS fs.FS, backup bool) InstallResult {
	result := InstallResult{Component: comp.Name}

	for _, target := range comp.Targets {
		srcPath := filepath.Join(comp.EmbedDir, target.Source)

		if backup {
			if _, err := CreateBackup(target.Dest); err != nil {
				result.Error = fmt.Errorf("backup failed for %s: %w", target.Dest, err)
				return result
			}
		}

		// Remove existing target before writing new one.
		os.RemoveAll(target.Dest)

		if target.IsDir {
			files, err := extractDir(embedFS, srcPath, target.Dest)
			if err != nil {
				result.Error = fmt.Errorf("failed to extract %s: %w", srcPath, err)
				return result
			}
			result.Files = append(result.Files, files...)
		} else {
			if err := extractFile(embedFS, srcPath, target.Dest); err != nil {
				result.Error = fmt.Errorf("failed to extract %s: %w", srcPath, err)
				return result
			}
			result.Files = append(result.Files, target.Dest)
		}
	}

	if comp.Name == "Tmux" {
		if err := reloadTmuxConfig(filepath.Join(config.HomeDir(), ".tmux.conf")); err != nil {
			result.Notes = append(result.Notes, fmt.Sprintf("tmux config installed but not reloaded automatically: %v", err))
		} else {
			result.Notes = append(result.Notes, "tmux config reloaded automatically")
		}
	}

	result.Success = true
	return result
}

// CreateZshrcLocal creates ~/.zshrc.local from the bundled template only when
// the file does not already exist, preserving any customisations the user has.
func CreateZshrcLocal(embedFS fs.FS) error {
	localPath := filepath.Join(config.HomeDir(), ".zshrc.local")
	if _, err := os.Stat(localPath); err == nil {
		return nil // already exists — preserve it
	}
	return extractFile(embedFS, "configs/zsh/zshrc.local.example", localPath)
}

// BuildManifest constructs a manifest from a completed set of install results.
func BuildManifest(version string, results []InstallResult, backupEnabled bool) Manifest {
	m := Manifest{
		Version:   version,
		Timestamp: time.Now(),
	}

	if backupEnabled {
		timestamp := time.Now().Format("2006-01-02_150405")
		m.BackupDir = filepath.Join(config.BackupDir(), timestamp)
	}

	for _, r := range results {
		if r.Success {
			m.Components = append(m.Components, r.Component)
			m.Files = append(m.Files, r.Files...)
		}
	}

	return m
}

// extractFile reads a single file from the embedded FS and writes it to dst.
// Shell scripts and the tmux-cheatsheet helper are made executable (0755).
func extractFile(fsys fs.FS, src, dst string) error {
	data, err := fs.ReadFile(fsys, src)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}

	perm := os.FileMode(0644)
	if strings.HasSuffix(src, ".sh") || strings.HasPrefix(filepath.Base(src), "tmux-cheatsheet") {
		perm = 0755
	}

	return os.WriteFile(dst, data, perm)
}

// extractDir walks the embedded FS subtree at srcDir and copies every file
// into dstDir, preserving the relative directory structure.
func extractDir(fsys fs.FS, srcDir, dstDir string) ([]string, error) {
	var files []string

	err := fs.WalkDir(fsys, srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		relPath, _ := filepath.Rel(srcDir, path)
		targetPath := filepath.Join(dstDir, relPath)

		if d.IsDir() {
			return os.MkdirAll(targetPath, 0755)
		}

		if err := extractFile(fsys, path, targetPath); err != nil {
			return err
		}
		files = append(files, targetPath)
		return nil
	})

	return files, err
}

func reloadTmuxConfig(configPath string) error {
	if os.Getenv("TMUX") == "" {
		return fmt.Errorf("not running inside tmux; run 'tmux source-file ~/.tmux.conf'")
	}

	cmd := exec.Command("tmux", "source-file", configPath)
	if out, err := cmd.CombinedOutput(); err != nil {
		msg := strings.TrimSpace(string(out))
		if msg == "" {
			return err
		}
		return fmt.Errorf("%s", msg)
	}

	return nil
}
