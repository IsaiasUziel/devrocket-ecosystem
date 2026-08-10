package devrocket_test

import (
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
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

func TestMuxAutostartWaitsForP10kCleanup(t *testing.T) {
	if _, err := exec.LookPath("script"); err != nil {
		t.Skip("script is required for pseudo-TTY verification")
	}
	repoRoot := repoRoot(t)
	home := t.TempDir()
	marker := filepath.Join(home, "mux")
	lifecycle := filepath.Join(home, "lifecycle")
	instantOutput := filepath.Join(home, "p10k-instant-output")
	gitstatusPID := filepath.Join(home, "gitstatus.pid")
	fakeMux := writeFakeMux(t, home)

	harness := muxSelectorSource(t, repoRoot) + `
_mux_selector_process_tree_has_command() { return 1 }
WM_CMD=` + shellQuote(fakeMux) + `
_mux_selector_register_autostart
exec {__p9k_fd_0}<&0 {__p9k_fd_1}>&1 {__p9k_fd_2}>&2
typeset -gx __p9k_fd_0 __p9k_fd_1 __p9k_fd_2
typeset -gx __p9k_instant_prompt_active=1
: > "$INSTANT_OUTPUT"
/bin/sleep 30 &
typeset -g gitstatus_pid=$!
print -r -- $gitstatus_pid > "$GITSTATUS_PID"
_fake_p10k_cleanup() {
  unset __p9k_instant_prompt_active
  exec 0<&$__p9k_fd_0 1>&$__p9k_fd_1 2>&$__p9k_fd_2 {__p9k_fd_0}>&- {__p9k_fd_1}>&- {__p9k_fd_2}>&-
  unset __p9k_fd_0 __p9k_fd_1 __p9k_fd_2
  rm -f "$INSTANT_OUTPUT"
  kill $gitstatus_pid
  wait $gitstatus_pid 2>/dev/null
}
precmd_functions=(_fake_p10k_cleanup $precmd_functions)
print -r -- zshrc-complete > "$LIFECYCLE"
for hook in $precmd_functions; do
  $hook
done
`
	runPTYHarness(t, home, harness, map[string]string{
		"GITSTATUS_PID":  gitstatusPID,
		"INSTANT_OUTPUT": instantOutput,
		"LIFECYCLE":      lifecycle,
		"MARKER":         marker,
	})

	assertFileContains(t, lifecycle, "zshrc-complete")
	assertFileContains(t, marker, "state=clean tty=tty,tty,tty")
	if _, err := os.Stat(instantOutput); !os.IsNotExist(err) {
		t.Fatalf("instant prompt output remains: %v", err)
	}
	pidData, err := os.ReadFile(gitstatusPID)
	if err != nil {
		t.Fatal(err)
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(pidData)))
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Kill(pid, 0); err != syscall.ESRCH {
		t.Fatalf("gitstatus harness process %d remains: %v", pid, err)
	}
}

func TestMuxAutostartRetriesBehindScheduledP10kCleanup(t *testing.T) {
	repoRoot := repoRoot(t)
	home := t.TempDir()
	marker := filepath.Join(home, "mux")
	fakeMux := writeFakeMux(t, home)
	zshrc := muxSelectorSource(t, repoRoot) + `
_mux_selector_process_tree_has_command() { return 1 }
WM_CMD=` + shellQuote(fakeMux) + `
exec {__p9k_fd_0}<&0 {__p9k_fd_1}>&1 {__p9k_fd_2}>&2
typeset -gx __p9k_fd_0 __p9k_fd_1 __p9k_fd_2
typeset -gx __p9k_instant_prompt_active=1
_fake_p10k_cleanup() {
  unset __p9k_instant_prompt_active
  exec 0<&$__p9k_fd_0 1>&$__p9k_fd_1 2>&$__p9k_fd_2 {__p9k_fd_0}>&- {__p9k_fd_1}>&- {__p9k_fd_2}>&-
  unset __p9k_fd_0 __p9k_fd_1 __p9k_fd_2
}
_fake_p10k_precmd_first() {
  zmodload zsh/sched
  sched +0 _fake_p10k_cleanup
  precmd_functions=(${precmd_functions:#_fake_p10k_precmd_first})
}
precmd_functions=(_fake_p10k_precmd_first $precmd_functions)
_mux_selector_register_autostart
PROMPT='fallback-prompt> '
`
	mustWriteFile(t, filepath.Join(home, ".zshrc"), zshrc)
	cmd := exec.Command("script", "-q", "/dev/null", "env", "ZDOTDIR="+home, "HOME="+home, "MARKER="+marker, "zsh", "-d")
	input, inputWriter := io.Pipe()
	cmd.Stdin = input
	go func() {
		time.Sleep(200 * time.Millisecond)
		_, _ = io.WriteString(inputWriter, "exit\n")
		_ = inputWriter.Close()
	}()
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("scheduled cleanup harness failed: %v\n%s", err, output)
	}
	_ = input.Close()
	assertFileContains(t, marker, "state=clean tty=tty,tty,tty")
}

func TestMuxAutostartIsOneShotAcrossRepeatedPrompts(t *testing.T) {
	repoRoot := repoRoot(t)
	home := t.TempDir()
	marker := filepath.Join(home, "mux")
	hooks := filepath.Join(home, "hooks")
	fakeMux := writeFakeMux(t, home)
	harness := muxSelectorSource(t, repoRoot) + `
WM_CMD=` + shellQuote(fakeMux) + `
TMUX=guarded
_mux_selector_register_autostart
_mux_autostart_precmd
unset TMUX
_mux_autostart_precmd
_mux_autostart_zle_line_init
add-zsh-hook -L > "$HOOKS"
add-zle-hook-widget -L >> "$HOOKS"
:
`
	runPTYHarness(t, home, harness, map[string]string{"HOOKS": hooks, "MARKER": marker})
	if _, err := os.Stat(marker); !os.IsNotExist(err) {
		t.Fatalf("mux executed after one-shot guard: %v", err)
	}
	data, err := os.ReadFile(hooks)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "_mux_autostart_") {
		t.Fatalf("autostart hooks remain registered:\n%s", data)
	}
}

func TestMissingMuxCommandLeavesUsablePromptAndRemovesHooks(t *testing.T) {
	repoRoot := repoRoot(t)
	home := t.TempDir()
	marker := filepath.Join(home, "prompt")
	harness := muxSelectorSource(t, repoRoot) + `
WM_CMD=` + shellQuote(filepath.Join(home, "missing-mux")) + `
_mux_selector_register_autostart
_mux_autostart_precmd
print -r -- prompt-usable > "$MARKER"
(( _mux_autostart_pending == 0 ))
[[ " ${precmd_functions[*]} " != *" _mux_autostart_precmd "* ]]
`
	runPTYHarness(t, home, harness, map[string]string{"MARKER": marker})
	assertFileContains(t, marker, "prompt-usable")
}

func TestP10kChildShellReachesPromptWithSharedCache(t *testing.T) {
	if _, err := exec.LookPath("script"); err != nil {
		t.Skip("script is required for pseudo-TTY verification")
	}
	repoRoot := repoRoot(t)
	home := t.TempDir()
	cache := filepath.Join(home, "cache")
	marker := filepath.Join(home, "child-ready")
	instantOutput := filepath.Join(cache, "p10k-instant-output")
	gitstatusPIDs := filepath.Join(home, "gitstatus.pids")
	zshrc := muxSelectorSource(t, repoRoot) + `
WM_CMD=tmux
TMUX=inside-herdr
exec {__p9k_fd_0}<&0 {__p9k_fd_1}>&1 {__p9k_fd_2}>&2
typeset -g __p9k_instant_prompt_active=1
: > "$INSTANT_OUTPUT"
/bin/sleep 30 &
typeset -g gitstatus_pid=$!
print -r -- $gitstatus_pid >> "$GITSTATUS_PIDS"
_fake_p10k_cleanup() {
  unset __p9k_instant_prompt_active
  exec 0<&$__p9k_fd_0 1>&$__p9k_fd_1 2>&$__p9k_fd_2 {__p9k_fd_0}>&- {__p9k_fd_1}>&- {__p9k_fd_2}>&-
  unset __p9k_fd_0 __p9k_fd_1 __p9k_fd_2
  rm -f "$INSTANT_OUTPUT"
  kill $gitstatus_pid
  wait $gitstatus_pid 2>/dev/null
}
precmd_functions=(_fake_p10k_cleanup $precmd_functions)
_mux_selector_register_autostart
PROMPT='child-prompt> '
`
	mustWriteFile(t, filepath.Join(home, ".zshrc"), zshrc)

	for range 2 {
		cmd := exec.Command("script", "-q", "/dev/null", "env", "ZDOTDIR="+home, "HOME="+home, "XDG_CACHE_HOME="+cache, "CHILD_MARKER="+marker, "INSTANT_OUTPUT="+instantOutput, "GITSTATUS_PIDS="+gitstatusPIDs, "zsh", "-d")
		input, inputWriter := io.Pipe()
		cmd.Stdin = input
		go func() {
			time.Sleep(100 * time.Millisecond)
			_, _ = io.WriteString(inputWriter, "print -r -- child-ready >> \"$CHILD_MARKER\"\nexit\n")
			_ = inputWriter.Close()
		}()
		output, err := cmd.CombinedOutput()
		_ = input.Close()
		if err != nil {
			t.Fatalf("child shell failed: %v\n%s", err, output)
		}
		text := string(output)
		if !strings.Contains(text, "child-prompt>") {
			t.Fatalf("child prompt not reached:\n%s", text)
		}
		if strings.Contains(text, "configuration wizard") || strings.Contains(text, "gitstatus failed") || strings.Contains(text, "not sourced") {
			t.Fatalf("child shell emitted a P10k warning:\n%s", text)
		}
	}

	data, err := os.ReadFile(marker)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(data), "child-ready") != 2 {
		t.Fatalf("child shells did not both accept input: %q", data)
	}
	if _, err := os.Stat(instantOutput); !os.IsNotExist(err) {
		t.Fatalf("instant prompt output remains after child shell: %v", err)
	}
	pidData, err := os.ReadFile(gitstatusPIDs)
	if err != nil {
		t.Fatal(err)
	}
	for _, value := range strings.Fields(string(pidData)) {
		pid, err := strconv.Atoi(value)
		if err != nil {
			t.Fatal(err)
		}
		if err := syscall.Kill(pid, 0); err != syscall.ESRCH {
			t.Fatalf("child gitstatus harness process %d remains: %v", pid, err)
		}
	}
}

func TestNonP10kShellAutostartsWithStaleHerdrEnvironment(t *testing.T) {
	repoRoot := repoRoot(t)
	home := t.TempDir()
	marker := filepath.Join(home, "mux")
	fakeMux := writeFakeMux(t, home)
	harness := muxSelectorSource(t, repoRoot) + `
_mux_selector_process_tree_has_command() { return 1 }
WM_CMD=` + shellQuote(fakeMux) + `
HERDR_ENV=stale
_mux_selector_register_autostart
_mux_autostart_precmd
`
	runPTYHarness(t, home, harness, map[string]string{"MARKER": marker})
	assertFileContains(t, marker, "state=clean tty=tty,tty,tty")
}

func writeFakeMux(t *testing.T, home string) string {
	t.Helper()
	fakeMux := filepath.Join(home, "fake-herdr")
	mustWriteFile(t, fakeMux, `#!/bin/sh
state=clean
[ "${__p9k_instant_prompt_active+set}" = set ] && state=dirty
[ "${__p9k_fd_0+set}" = set ] && state=dirty
[ "${__p9k_fd_1+set}" = set ] && state=dirty
[ "${__p9k_fd_2+set}" = set ] && state=dirty
fd0=notty; fd1=notty; fd2=notty
[ -t 0 ] && fd0=tty
[ -t 1 ] && fd1=tty
[ -t 2 ] && fd2=tty
printf 'state=%s tty=%s,%s,%s\n' "$state" "$fd0" "$fd1" "$fd2" >> "$MARKER"
`)
	if err := os.Chmod(fakeMux, 0755); err != nil {
		t.Fatal(err)
	}
	return fakeMux
}

func runPTYHarness(t *testing.T, home, body string, env map[string]string) {
	t.Helper()
	if _, err := exec.LookPath("script"); err != nil {
		t.Skip("script is required for pseudo-TTY verification")
	}
	harness := filepath.Join(home, "harness.zsh")
	mustWriteFile(t, harness, body)
	cmd := exec.Command("script", "-q", "/dev/null", "zsh", "-fic", "source "+shellQuote(harness))
	cmd.Env = append(os.Environ(), "HOME="+home, "XDG_CONFIG_HOME="+filepath.Join(home, ".config"))
	for key, value := range env {
		cmd.Env = append(cmd.Env, key+"="+value)
	}
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("PTY harness failed: %v\n%s", err, output)
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
