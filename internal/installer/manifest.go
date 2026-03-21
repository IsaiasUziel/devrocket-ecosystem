package installer

import (
	"encoding/json"
	"os"
	"time"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
)

// Manifest tracks the installation state for clean uninstall.
type Manifest struct {
	Version    string    `json:"version"`
	Timestamp  time.Time `json:"timestamp"`
	Components []string  `json:"components"`
	Files      []string  `json:"files"`
	BackupDir  string    `json:"backup_dir,omitempty"`
}

// WriteManifest serialises and saves the installation manifest.
func WriteManifest(m Manifest) error {
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(config.ManifestPath(), data, 0644)
}

// ReadManifest loads and parses the installation manifest.
func ReadManifest() (*Manifest, error) {
	data, err := os.ReadFile(config.ManifestPath())
	if err != nil {
		return nil, err
	}
	var m Manifest
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	return &m, nil
}

// ManifestExists reports whether a manifest file is present.
func ManifestExists() bool {
	_, err := os.Stat(config.ManifestPath())
	return err == nil
}

// RemoveManifest deletes the manifest file.
func RemoveManifest() error {
	return os.Remove(config.ManifestPath())
}
