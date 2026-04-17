package config

import "path/filepath"

// Component represents an installable config component.
type Component struct {
	Name        string
	Description string
	EmbedDir    string   // directory inside configs/
	Targets     []Target // where files go on disk
	DetectCmd   string   // command to verify tool exists (e.g. "nvim")
	DetectApp   string   // macOS .app bundle path (e.g. for Ghostty)
}

// Target maps a source path inside the embed tree to a destination on disk.
type Target struct {
	Source string // relative path inside EmbedDir
	Dest   string // absolute destination path
	IsDir  bool   // when true, the entire directory subtree is copied
}

// AllComponents returns the supported installable components.
// Destination paths are resolved at call time using the current user environment.
func AllComponents() []Component {
	home := HomeDir()
	configDir := ConfigDir()
	binDir := BinDir()

	return []Component{
		{
			Name:        "Ghostty",
			Description: "Terminal config + themes + 51 shaders",
			EmbedDir:    "configs/ghostty",
			DetectCmd:   "ghostty",
			DetectApp:   "/Applications/Ghostty.app",
			Targets: []Target{
				{Source: "config", Dest: filepath.Join(configDir, "ghostty", "config")},
				{Source: "themes", Dest: filepath.Join(configDir, "ghostty", "themes"), IsDir: true},
				{Source: "shaders", Dest: filepath.Join(configDir, "ghostty", "shaders"), IsDir: true},
			},
		},
		{
			Name:        "Tmux",
			Description: "Multiplexer config with C-a prefix + pane/navigation workflow",
			EmbedDir:    "configs/tmux",
			DetectCmd:   "tmux",
			Targets: []Target{
				{Source: "tmux.conf", Dest: filepath.Join(home, ".tmux.conf")},
			},
		},
		{
			Name:        "Neovim",
			Description: "LazyVim with 29+ plugins, Harpoon, Oil, Flash",
			EmbedDir:    "configs/nvim",
			DetectCmd:   "nvim",
			Targets: []Target{
				{Source: ".", Dest: filepath.Join(configDir, "nvim"), IsDir: true},
			},
		},
		{
			Name:        "Zsh",
			Description: "Shell config + Powerlevel10k theme",
			EmbedDir:    "configs/zsh",
			DetectCmd:   "zsh",
			Targets: []Target{
				{Source: "zshrc", Dest: filepath.Join(home, ".zshrc")},
				{Source: "p10k.zsh", Dest: filepath.Join(home, ".p10k.zsh")},
			},
		},
		{
			Name:        "Atuin",
			Description: "Shell history sync/search baseline config",
			EmbedDir:    "configs/atuin",
			DetectCmd:   "atuin",
			Targets: []Target{
				{Source: "config.toml", Dest: filepath.Join(configDir, "atuin", "config.toml")},
			},
		},
		{
			Name:        "Cheatsheet",
			Description: "Filterable popup opened from tmux prefix workflow",
			EmbedDir:    "configs/cheatsheet",
			Targets: []Target{
				{Source: "tmux-cheatsheet", Dest: filepath.Join(binDir, "tmux-cheatsheet")},
			},
		},
	}
}
