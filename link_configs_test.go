package devrocket_test

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

type linkState struct {
	Version   int               `json:"version"`
	RepoRoot  string            `json:"repo_root"`
	LinkedAt  string            `json:"linked_at"`
	BackupDir string            `json:"backup_dir"`
	Targets   []linkStateTarget `json:"targets"`
}

type linkStateTarget struct {
	ID           string `json:"id"`
	Kind         string `json:"kind"`
	Source       string `json:"source"`
	Target       string `json:"target"`
	ExpectedLink string `json:"expected_link"`
	Backup       string `json:"backup"`
}

func TestLinkConfigsLinksAllSupportedTargetsAndWritesState(t *testing.T) {
	repoRoot := repoRoot(t)
	homeDir := t.TempDir()
	stateHome := filepath.Join(t.TempDir(), "state-home")

	mustMkdirAll(t, filepath.Join(homeDir, ".config", "ghostty"))
	mustMkdirAll(t, filepath.Join(homeDir, ".config", "nvim"))
	mustWriteFile(t, filepath.Join(homeDir, ".tmux.conf"), "set -g mouse off\n")
	mustWriteFile(t, filepath.Join(homeDir, ".config", "ghostty", "config"), "theme = old\n")
	mustWriteFile(t, filepath.Join(homeDir, ".config", "nvim", "init.lua"), "print('legacy')\n")

	result := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if result.err != nil {
		t.Fatalf("link-configs.sh failed: %v\nstdout:\n%s\nstderr:\n%s", result.err, result.stdout, result.stderr)
	}

	assertSymlink(t, filepath.Join(homeDir, ".config", "nvim"), filepath.Join(repoRoot, "configs", "nvim"))
	assertSymlink(t, filepath.Join(homeDir, ".tmux.conf"), filepath.Join(repoRoot, "configs", "tmux", "tmux.conf"))
	assertSymlink(t, filepath.Join(homeDir, ".config", "ghostty", "config"), filepath.Join(repoRoot, "configs", "ghostty", "config"))
	assertSymlink(t, filepath.Join(homeDir, ".config", "ghostty", "assets"), filepath.Join(repoRoot, "configs", "ghostty", "assets"))
	assertSymlink(t, filepath.Join(homeDir, ".config", "ghostty", "themes"), filepath.Join(repoRoot, "configs", "ghostty", "themes"))
	assertSymlink(t, filepath.Join(homeDir, ".config", "ghostty", "shaders"), filepath.Join(repoRoot, "configs", "ghostty", "shaders"))
	assertSymlink(t, filepath.Join(homeDir, ".zshrc"), filepath.Join(repoRoot, "configs", "zsh", "zshrc"))
	assertSymlink(t, filepath.Join(homeDir, ".p10k.zsh"), filepath.Join(repoRoot, "configs", "zsh", "p10k.zsh"))
	assertSymlink(t, filepath.Join(homeDir, ".local", "bin", "tmux-cheatsheet"), filepath.Join(repoRoot, "configs", "cheatsheet", "tmux-cheatsheet"))

	state := readState(t, stateHome)
	if state.Version != 1 {
		t.Fatalf("expected state version 1, got %d", state.Version)
	}
	if state.RepoRoot != repoRoot {
		t.Fatalf("expected repo root %q, got %q", repoRoot, state.RepoRoot)
	}
	if state.LinkedAt == "" {
		t.Fatal("expected linked_at to be populated")
	}
	if len(state.Targets) != 9 {
		t.Fatalf("expected 9 targets in state, got %d", len(state.Targets))
	}
	if _, err := os.Stat(filepath.Join(homeDir, ".devrocket-manifest.json")); !os.IsNotExist(err) {
		t.Fatalf("expected manifest to remain untouched, err=%v", err)
	}
	if _, err := os.Stat(filepath.Join(homeDir, ".devrocket-backup")); !os.IsNotExist(err) {
		t.Fatalf("expected installer backup dir to remain untouched, err=%v", err)
	}

	tmuxState := stateTargetByID(t, state, "tmux")
	if tmuxState.Backup == "" {
		t.Fatal("expected tmux target backup to be recorded")
	}
	assertFileContains(t, tmuxState.Backup, "set -g mouse off")
	nvimState := stateTargetByID(t, state, "nvim")
	if nvimState.Backup == "" {
		t.Fatal("expected nvim target backup to be recorded")
	}
	assertFileContains(t, filepath.Join(nvimState.Backup, "init.lua"), "legacy")
	ghosttyThemes := stateTargetByID(t, state, "ghostty-themes")
	if ghosttyThemes.Backup != "" {
		t.Fatalf("expected empty backup for missing themes target, got %q", ghosttyThemes.Backup)
	}
}

func TestLinkConfigsIsIdempotentAndRepairsMissingManagedLink(t *testing.T) {
	repoRoot := repoRoot(t)
	homeDir := t.TempDir()
	stateHome := filepath.Join(t.TempDir(), "state-home")

	first := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if first.err != nil {
		t.Fatalf("initial link failed: %v\nstdout:\n%s\nstderr:\n%s", first.err, first.stdout, first.stderr)
	}
	stateBefore := readState(t, stateHome)

	second := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if second.err != nil {
		t.Fatalf("relink failed: %v\nstdout:\n%s\nstderr:\n%s", second.err, second.stdout, second.stderr)
	}
	stateAfter := readState(t, stateHome)
	if stateAfter.BackupDir != stateBefore.BackupDir {
		t.Fatalf("expected relink to preserve backup dir, got %q want %q", stateAfter.BackupDir, stateBefore.BackupDir)
	}

	missingTarget := filepath.Join(homeDir, ".config", "ghostty", "themes")
	if err := os.Remove(missingTarget); err != nil {
		t.Fatalf("remove managed target: %v", err)
	}

	repair := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if repair.err != nil {
		t.Fatalf("repair relink failed: %v\nstdout:\n%s\nstderr:\n%s", repair.err, repair.stdout, repair.stderr)
	}
	assertSymlink(t, missingTarget, filepath.Join(repoRoot, "configs", "ghostty", "themes"))
}

func TestLinkConfigsRefusesUnsupportedTargetsAndForeignSymlinks(t *testing.T) {
	repoRoot := repoRoot(t)
	homeDir := t.TempDir()
	stateHome := filepath.Join(t.TempDir(), "state-home")

	unsupported := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh", "atuin")
	if unsupported.err == nil {
		t.Fatal("expected unsupported target to fail")
	}
	if !strings.Contains(unsupported.stderr, "unsupported target") {
		t.Fatalf("expected unsupported target error, got stderr=%q", unsupported.stderr)
	}

	mustMkdirAll(t, filepath.Join(homeDir, ".config"))
	foreignTarget := filepath.Join(homeDir, ".tmux.conf")
	if err := os.Symlink(filepath.Join(homeDir, "elsewhere.conf"), foreignTarget); err != nil {
		t.Fatalf("create foreign symlink: %v", err)
	}

	foreign := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh", "tmux")
	if foreign.err == nil {
		t.Fatal("expected foreign symlink to fail")
	}
	if !strings.Contains(foreign.stderr, "foreign symlink") {
		t.Fatalf("expected foreign symlink error, got stderr=%q", foreign.stderr)
	}
	assertSymlink(t, foreignTarget, filepath.Join(homeDir, "elsewhere.conf"))
}

func TestUnlinkConfigsRestoresBackupsAndRemovesState(t *testing.T) {
	repoRoot := repoRoot(t)
	homeDir := t.TempDir()
	stateHome := filepath.Join(t.TempDir(), "state-home")

	mustWriteFile(t, filepath.Join(homeDir, ".tmux.conf"), "set -g status off\n")
	mustMkdirAll(t, filepath.Join(homeDir, ".config", "nvim"))
	mustWriteFile(t, filepath.Join(homeDir, ".config", "nvim", "init.lua"), "print('before')\n")

	link := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if link.err != nil {
		t.Fatalf("link failed: %v\nstdout:\n%s\nstderr:\n%s", link.err, link.stdout, link.stderr)
	}

	unlink := runScript(t, repoRoot, homeDir, stateHome, "unlink-configs.sh")
	if unlink.err != nil {
		t.Fatalf("unlink failed: %v\nstdout:\n%s\nstderr:\n%s", unlink.err, unlink.stdout, unlink.stderr)
	}

	assertFileContains(t, filepath.Join(homeDir, ".tmux.conf"), "set -g status off")
	assertFileContains(t, filepath.Join(homeDir, ".config", "nvim", "init.lua"), "before")
	statePath := filepath.Join(stateHome, "devrocket-ecosystem", "link-configs.json")
	if _, err := os.Stat(statePath); !os.IsNotExist(err) {
		t.Fatalf("expected state file removal, err=%v", err)
	}
}

func TestUnlinkConfigsRefusesTamperedTargetsAndRepoMismatch(t *testing.T) {
	repoRoot := repoRoot(t)
	homeDir := t.TempDir()
	stateHome := filepath.Join(t.TempDir(), "state-home")

	link := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if link.err != nil {
		t.Fatalf("link failed: %v\nstdout:\n%s\nstderr:\n%s", link.err, link.stdout, link.stderr)
	}

	tamperedTarget := filepath.Join(homeDir, ".tmux.conf")
	if err := os.Remove(tamperedTarget); err != nil {
		t.Fatalf("remove managed symlink: %v", err)
	}
	mustWriteFile(t, tamperedTarget, "manual drift\n")

	tampered := runScript(t, repoRoot, homeDir, stateHome, "unlink-configs.sh", "tmux")
	if tampered.err == nil {
		t.Fatal("expected tampered target refusal")
	}
	if !strings.Contains(tampered.stderr, "unexpected target state") {
		t.Fatalf("expected tampered target error, got stderr=%q", tampered.stderr)
	}
	assertFileContains(t, tamperedTarget, "manual drift")

	statePath := filepath.Join(stateHome, "devrocket-ecosystem", "link-configs.json")
	data, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatalf("read state: %v", err)
	}
	rewritten := strings.Replace(string(data), repoRoot, filepath.Join(homeDir, "other-repo"), 1)
	if err := os.WriteFile(statePath, []byte(rewritten), 0644); err != nil {
		t.Fatalf("rewrite state: %v", err)
	}

	mismatch := runScript(t, repoRoot, homeDir, stateHome, "link-configs.sh")
	if mismatch.err == nil {
		t.Fatal("expected repo mismatch refusal")
	}
	if !strings.Contains(mismatch.stderr, "repo root mismatch") {
		t.Fatalf("expected repo mismatch error, got stderr=%q", mismatch.stderr)
	}
}

func TestReadmeDocumentsDeveloperLinkModeWorkflow(t *testing.T) {
	data, err := os.ReadFile(filepath.Join(repoRoot(t), "README.md"))
	if err != nil {
		t.Fatalf("read README: %v", err)
	}
	content := string(data)

	for _, expected := range []string{
		"## 🔗 Developer Link Mode",
		"scripts/link-configs.sh",
		"scripts/unlink-configs.sh",
		"~/.local/state/devrocket-ecosystem/link-configs.json",
		"ghostty-config",
		"ghostty-assets",
		"ghostty-themes",
		"ghostty-shaders",
		"zshrc",
		"p10k",
		"cheatsheet",
		"The Go installer and dr-sys copy/install flow are unchanged",
		"This workflow never manages `~/.zshrc.local`",
	} {
		if !strings.Contains(content, expected) {
			t.Fatalf("expected README to contain %q", expected)
		}
	}
}

type scriptResult struct {
	stdout string
	stderr string
	err    error
}

func runScript(t *testing.T, repoRoot, homeDir, stateHome, script string, args ...string) scriptResult {
	t.Helper()
	cmdArgs := append([]string{filepath.Join(repoRoot, "scripts", script)}, args...)
	cmd := exec.Command("sh", cmdArgs...)
	cmd.Env = append(os.Environ(),
		"HOME="+homeDir,
		"XDG_STATE_HOME="+stateHome,
		"DEVROCKET_LINK_BIN_DIR="+filepath.Join(homeDir, ".local", "bin"),
	)
	cmd.Dir = repoRoot
	out, err := cmd.Output()
	result := scriptResult{stdout: string(out), err: err}
	if err == nil {
		return result
	}
	exitErr, ok := err.(*exec.ExitError)
	if !ok {
		return result
	}
	result.stderr = string(exitErr.Stderr)
	return result
}

func repoRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	return wd
}

func readState(t *testing.T, stateHome string) linkState {
	t.Helper()
	statePath := filepath.Join(stateHome, "devrocket-ecosystem", "link-configs.json")
	data, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatalf("read state: %v", err)
	}
	var state linkState
	if err := json.Unmarshal(data, &state); err != nil {
		t.Fatalf("unmarshal state: %v\n%s", err, string(data))
	}
	return state
}

func stateTargetByID(t *testing.T, state linkState, id string) linkStateTarget {
	t.Helper()
	for _, target := range state.Targets {
		if target.ID == id {
			return target
		}
	}
	t.Fatalf("target %q not found in state", id)
	return linkStateTarget{}
}

func assertSymlink(t *testing.T, path, expected string) {
	t.Helper()
	actual, err := os.Readlink(path)
	if err != nil {
		t.Fatalf("readlink %s: %v", path, err)
	}
	if actual != expected {
		t.Fatalf("expected symlink %s -> %s, got %s", path, expected, actual)
	}
}

func assertFileContains(t *testing.T, path, want string) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read file %s: %v", path, err)
	}
	if !strings.Contains(string(data), want) {
		t.Fatalf("expected %s to contain %q, got %q", path, want, string(data))
	}
}

func mustMkdirAll(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(path, 0755); err != nil {
		t.Fatalf("mkdir %s: %v", path, err)
	}
}

func mustWriteFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("mkdir parent for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("write file %s: %v", path, err)
	}
}
