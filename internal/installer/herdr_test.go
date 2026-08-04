package installer

import (
	"io/fs"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/IsaiasUziel/devrocket-ecosystem/internal/config"
)

func TestHerdrInstallAndUninstallRestoresConfigWithoutTouchingRuntime(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	herdrDir := filepath.Join(home, ".config", "herdr")
	configPath := filepath.Join(herdrDir, "config.toml")
	runtimePath := filepath.Join(herdrDir, "session.db")
	mustWrite(t, configPath, "old = true\n")
	mustWrite(t, runtimePath, "runtime\n")

	comp := herdrComponent(t)
	embedFS := fstest.MapFS{"configs/herdr/config.toml": &fstest.MapFile{Data: []byte("onboarding = false\n")}}
	result := InstallComponent(comp, embedFS, true)
	if !result.Success || result.Error != nil {
		t.Fatalf("install failed: %+v", result)
	}
	backupPath := result.Backups[configPath]
	if backupPath == "" {
		t.Fatal("expected exact destination-to-backup mapping")
	}
	assertContent(t, backupPath, "old = true\n")
	assertContent(t, runtimePath, "runtime\n")

	manifest := BuildManifest("test", []InstallResult{result}, true)
	if manifest.Backups[configPath] != backupPath {
		t.Fatalf("manifest backup = %q, want %q", manifest.Backups[configPath], backupPath)
	}
	if err := WriteManifest(manifest); err != nil {
		t.Fatal(err)
	}
	uninstalled, err := Uninstall()
	if err != nil {
		t.Fatal(err)
	}
	if uninstalled.FilesRestored != 1 {
		t.Fatalf("restored = %d, want 1", uninstalled.FilesRestored)
	}
	assertContent(t, configPath, "old = true\n")
	assertContent(t, runtimePath, "runtime\n")
}

func TestUninstallRestoresLegacyBackupDirManifest(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	tmuxPath := filepath.Join(home, ".tmux.conf")
	backupDir := filepath.Join(home, ".devrocket-backup", "legacy")
	mustWrite(t, tmuxPath, "installed\n")
	mustWrite(t, filepath.Join(backupDir, "tmux.conf"), "legacy\n")
	if err := WriteManifest(Manifest{Files: []string{tmuxPath}, BackupDir: backupDir}); err != nil {
		t.Fatal(err)
	}
	if _, err := Uninstall(); err != nil {
		t.Fatal(err)
	}
	assertContent(t, tmuxPath, "legacy\n")
}

func TestFailedInstallPersistsBackupForUninstall(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	configPath := filepath.Join(home, ".config", "herdr", "config.toml")
	mustWrite(t, configPath, "original\n")

	result := InstallComponent(herdrComponent(t), fstest.MapFS{}, true)
	if result.Success || result.Error == nil {
		t.Fatalf("expected extract failure, got %+v", result)
	}
	manifest := BuildManifest("test", []InstallResult{result}, true)
	if manifest.Backups[configPath] == "" {
		t.Fatal("expected failed install backup in manifest")
	}
	if len(manifest.Files) != 1 || manifest.Files[0] != configPath {
		t.Fatalf("failed install files = %v, want [%s]", manifest.Files, configPath)
	}
	if err := WriteManifest(manifest); err != nil {
		t.Fatal(err)
	}
	if _, err := Uninstall(); err != nil {
		t.Fatal(err)
	}
	assertContent(t, configPath, "original\n")
}

func TestManifestRecordsMultiTargetPartialInstall(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	firstDest := filepath.Join(home, ".config", "partial", "first")
	secondDest := filepath.Join(home, ".config", "partial", "second")
	mustWrite(t, firstDest, "old first\n")
	mustWrite(t, secondDest, "old second\n")
	comp := config.Component{
		Name:     "Partial",
		EmbedDir: "configs/partial",
		Targets: []config.Target{
			{Source: "first", Dest: firstDest},
			{Source: "second", Dest: secondDest},
		},
	}
	embedFS := fstest.MapFS{"configs/partial/first": &fstest.MapFile{Data: []byte("new first\n")}}

	result := InstallComponent(comp, embedFS, true)
	if result.Success || result.Error == nil {
		t.Fatalf("expected second target failure, got %+v", result)
	}
	manifest := BuildManifest("test", []InstallResult{result}, true)
	if len(manifest.Files) != 2 || manifest.Files[0] != firstDest || manifest.Files[1] != secondDest {
		t.Fatalf("partial files = %v, want attempted targets", manifest.Files)
	}
	if len(manifest.Backups) != 2 {
		t.Fatalf("partial backups = %v, want both targets", manifest.Backups)
	}
}

func herdrComponent(t *testing.T) config.Component {
	t.Helper()
	for _, comp := range config.AllComponents() {
		if comp.Name == "Herdr" {
			if comp.DetectCmd != "herdr" || len(comp.Targets) != 1 || comp.Targets[0].IsDir {
				t.Fatalf("invalid Herdr component: %+v", comp)
			}
			return comp
		}
	}
	t.Fatal("Herdr component not registered")
	return config.Component{}
}

func mustWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), fs.FileMode(0644)); err != nil {
		t.Fatal(err)
	}
}

func assertContent(t *testing.T, path, want string) {
	t.Helper()
	got, err := os.ReadFile(path)
	if err != nil || string(got) != want {
		t.Fatalf("%s = %q, %v; want %q", path, got, err, want)
	}
}
