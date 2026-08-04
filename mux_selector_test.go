package devrocket_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestMuxSelectorStateWriteIsAtomicAndDoesNotFollowSymlink(t *testing.T) {
	repoRoot := repoRoot(t)
	home := t.TempDir()
	configHome := filepath.Join(home, ".config")
	statePath := filepath.Join(configHome, "devrocket", "mux")
	victim := filepath.Join(home, "victim")
	mustWriteFile(t, victim, "unchanged\n")
	mustMkdirAll(t, filepath.Dir(statePath))
	if err := os.Symlink(victim, statePath); err != nil {
		t.Fatal(err)
	}

	script := muxSelectorSource(t, repoRoot) + "\n_mux_selector_write herdr\n"
	cmd := exec.Command("zsh", "-fc", script)
	cmd.Env = append(os.Environ(), "HOME="+home, "XDG_CONFIG_HOME="+configHome)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("selector write failed: %v\n%s", err, output)
	}
	assertFileContains(t, victim, "unchanged")
	if info, err := os.Lstat(statePath); err != nil || info.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("expected state symlink replacement, info=%v err=%v", info, err)
	}
	assertFileContains(t, statePath, "herdr")
	matches, err := filepath.Glob(filepath.Join(filepath.Dir(statePath), ".mux.*"))
	if err != nil || len(matches) != 0 {
		t.Fatalf("temporary files left behind: %v, err=%v", matches, err)
	}

	if err := os.Remove(statePath); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(statePath, 0000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(statePath, 0700) })
	failure := exec.Command("zsh", "-fc", script)
	failure.Env = cmd.Env
	if err := failure.Run(); err == nil {
		t.Fatal("expected atomic rename failure")
	}
	matches, err = filepath.Glob(filepath.Join(filepath.Dir(statePath), ".mux.*"))
	if err != nil || len(matches) != 0 {
		t.Fatalf("temporary files left after failure: %v, err=%v", matches, err)
	}
}

func TestMuxAutostartRestoresSavedTTYDescriptors(t *testing.T) {
	if _, err := exec.LookPath("script"); err != nil {
		t.Skip("script is required for pseudo-TTY verification")
	}
	repoRoot := repoRoot(t)
	home := t.TempDir()
	marker := filepath.Join(home, "fds")
	fakeMux := filepath.Join(home, "fake-herdr")
	mustWriteFile(t, fakeMux, "#!/bin/sh\nfd0=notty; fd1=notty; fd2=notty\n[ -t 0 ] && fd0=tty\n[ -t 1 ] && fd1=tty\n[ -t 2 ] && fd2=tty\nprintf '%s %s %s' \"$fd0\" \"$fd1\" \"$fd2\" > \"$MARKER\"\n")
	if err := os.Chmod(fakeMux, 0755); err != nil {
		t.Fatal(err)
	}

	zshScript := filepath.Join(home, "harness.zsh")
	scriptBody := muxSelectorSource(t, repoRoot) + "\nWM_CMD=" + shellQuote(fakeMux) + "\nexec {saved_in}<&0 {saved_out}>&1 {saved_err}>&2\n__p9k_fd_0=$saved_in __p9k_fd_1=$saved_out __p9k_fd_2=$saved_err\nstart_if_needed </dev/null >" + shellQuote(filepath.Join(home, "stdout")) + " 2>" + shellQuote(filepath.Join(home, "stderr")) + "\n"
	mustWriteFile(t, zshScript, scriptBody)
	cmd := exec.Command("script", "-q", "/dev/null", "zsh", "-fic", "source "+shellQuote(zshScript))
	cmd.Env = append(os.Environ(), "HOME="+home, "XDG_CONFIG_HOME="+filepath.Join(home, ".config"), "MARKER="+marker)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("PTY harness failed: %v\n%s", err, output)
	}
	data, err := os.ReadFile(marker)
	if err != nil || string(data) != "tty tty tty" {
		t.Fatalf("mux descriptors = %q, err=%v", data, err)
	}

	if err := os.Remove(marker); err != nil {
		t.Fatal(err)
	}
	fallbackBody := muxSelectorSource(t, repoRoot) + "\nWM_CMD=" + shellQuote(fakeMux) + "\nstart_if_needed\n"
	mustWriteFile(t, zshScript, fallbackBody)
	fallback := exec.Command("script", "-q", "/dev/null", "zsh", "-fic", "source "+shellQuote(zshScript))
	fallback.Env = cmd.Env
	if output, err := fallback.CombinedOutput(); err != nil {
		t.Fatalf("fallback PTY harness failed: %v\n%s", err, output)
	}
	data, err = os.ReadFile(marker)
	if err != nil || string(data) != "tty tty tty" {
		t.Fatalf("fallback mux descriptors = %q, err=%v", data, err)
	}
}

func muxSelectorSource(t *testing.T, repoRoot string) string {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(repoRoot, "configs", "zsh", "zshrc"))
	if err != nil {
		t.Fatal(err)
	}
	content := string(data)
	start := strings.Index(content, "MUX_SELECTOR_STATE_FILE=")
	end := strings.Index(content, "\n_mux_selector_sync_runtime\n")
	if start < 0 || end < start {
		t.Fatal("mux selector block not found")
	}
	return content[start:end]
}

func shellQuote(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}
