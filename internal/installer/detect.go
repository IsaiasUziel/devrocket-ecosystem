package installer

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
)

// SystemInfo holds detected system information.
type SystemInfo struct {
	OS         string
	Arch       string
	BrewPrefix string
}

// DetectSystem returns OS and architecture information for the current machine.
func DetectSystem() SystemInfo {
	return SystemInfo{
		OS:         runtime.GOOS,
		Arch:       runtime.GOARCH,
		BrewPrefix: config.BrewPrefix(),
	}
}

// ToolStatus represents whether a component's required tool is present.
type ToolStatus struct {
	Name      string
	Installed bool
	Version   string
}

// CheckTool checks if the tool required by the given component is available.
// It tries the command from PATH first, then falls back to a macOS .app bundle.
// Components with no external dependency (e.g. Cheatsheet) are always marked installed.
func CheckTool(comp config.Component) ToolStatus {
	status := ToolStatus{Name: comp.Name}

	// Check command in PATH.
	if comp.DetectCmd != "" {
		if path, err := exec.LookPath(comp.DetectCmd); err == nil {
			status.Installed = true
			// Best-effort version string (truncated to 50 chars).
			if out, err := exec.Command(path, "--version").Output(); err == nil {
				v := string(out)
				if len(v) > 50 {
					v = v[:50]
				}
				status.Version = v
			}
			return status
		}
	}

	// Check macOS .app bundle.
	if comp.DetectApp != "" {
		if _, err := os.Stat(comp.DetectApp); err == nil {
			status.Installed = true
			status.Version = "app bundle"
			return status
		}
	}

	// Components with no external dependency are always available.
	if comp.DetectCmd == "" && comp.DetectApp == "" {
		status.Installed = true
		status.Version = "no dependency"
	}

	return status
}

// CheckGentlemanDots reports whether the gentleman-dots binary is on PATH.
func CheckGentlemanDots() bool {
	_, err := exec.LookPath("gentleman-dots")
	return err == nil
}

// FormatOS returns a human-readable OS / architecture string.
func FormatOS(info SystemInfo) string {
	osName := "Unknown"
	switch info.OS {
	case "darwin":
		osName = "macOS"
	case "linux":
		osName = "Linux"
	}
	arch := info.Arch
	switch arch {
	case "arm64":
		arch = "Apple Silicon"
	case "amd64":
		arch = "Intel x86_64"
	}
	return fmt.Sprintf("%s (%s)", osName, arch)
}
