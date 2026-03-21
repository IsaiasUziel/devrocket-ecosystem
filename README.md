# 🚀 DevRocket Ecosystem

> An opinionated, batteries-included terminal development environment.  
> Ghostty + Tmux + Neovim (LazyVim) + Zsh — configured to work together seamlessly.

<!-- TODO: Add screenshot here -->
<!-- ![DevRocket Ecosystem](./assets/screenshot.png) -->

## ✨ What's Inside

| Tool | Config | Highlights |
|------|--------|------------|
| **Ghostty** | Terminal emulator | Kanagawa theme, custom shaders, optimized keybindings |
| **Tmux** | Terminal multiplexer | Prefix `C-a`, seamless navigation with Neovim, popup cheatsheet |
| **Neovim** | Editor (LazyVim) | 29+ plugins, Harpoon2, Oil.nvim, Flash.nvim, LSP |
| **Zsh** | Shell | Powerlevel10k, autocomplete, syntax highlighting, Atuin, zoxide |
| **Cheatsheet** | Tmux popup | Filterable keybinding reference with category cycling (Alt+c) |

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│  Ghostty (Terminal Emulator)            │ ← Layer 1: OS input
│  ┌─────────────────────────────────────┐│
│  │  Tmux (Multiplexer) prefix: C-a    ││ ← Layer 2: Sessions, windows, panes
│  │  ┌─────────────────────────────────┐││
│  │  │  Zsh + Neovim/LazyVim          │││ ← Layer 3: Shell or Editor
│  │  └─────────────────────────────────┘││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

Each keystroke flows **DOWN** through layers. If Ghostty captures it, Tmux never sees it.
Understanding this saves hours of debugging.

## 📋 Prerequisites

This project is a **config overlay** — it assumes you already have the tools installed.

### Recommended: Install via [Gentleman.Dots](https://github.com/Gentleman-Programming/Gentleman.Dots)

```bash
brew tap Gentleman-Programming/homebrew-tap
brew install gentleman-dots
gentleman-dots
```

### Required Tools

| Tool | Install |
|------|---------|
| [Ghostty](https://ghostty.org) | Download from website |
| [Tmux](https://github.com/tmux/tmux) | `brew install tmux` |
| [Neovim](https://neovim.io) | `brew install neovim` |
| [fzf](https://github.com/junegunn/fzf) | `brew install fzf` |
| [Zsh](https://www.zsh.org) | Usually pre-installed on macOS |
| [fd](https://github.com/sharkdp/fd) | `brew install fd` |
| [bat](https://github.com/sharkdp/bat) | `brew install bat` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `brew install zoxide` |
| [Atuin](https://atuin.sh) | `brew install atuin` |

## 🚀 Installation

### Via Homebrew (recommended)

```bash
brew tap IsaiasUziel/devrocket-ecosystem
brew install devrocket-ecosystem
```

### Run the installer

```bash
devrocket-ecosystem
```

### From Source

```bash
git clone https://github.com/IsaiasUziel/devrocket-ecosystem.git
cd devrocket-ecosystem
make build
./bin/devrocket-ecosystem
```

The TUI installer will:
1. ✅ Detect your OS and Homebrew prefix
2. ✅ Check for installed tools (skips configs for missing tools)
3. ✅ Backup your existing configs to `~/.devrocket-backup/`
4. ✅ Copy configs from the embedded binary to your config locations
5. ✅ Create `~/.zshrc.local` for your private aliases

### After installing:

1. **Restart Ghostty** to apply terminal config
2. Run `tmux source ~/.tmux.conf` to reload tmux
3. Press `C-a + I` inside tmux to install TPM plugins
4. Open `nvim` and wait for LazyVim to sync plugins
5. Edit `~/.zshrc.local` for your private aliases (passwords, SSH, etc.)

## 📁 What Gets Installed

The TUI installer copies configs from the embedded binary (no internet required after install):

| Component | Target (system) |
|-----------|-----------------|
| **Ghostty** | `~/.config/ghostty/` |
| **Tmux** | `~/.tmux.conf` |
| **Neovim** | `~/.config/nvim/` |
| **Zsh** | `~/.zshrc`, `~/.p10k.zsh` |
| **Cheatsheet** | `$BREW_PREFIX/bin/tmux-cheatsheet` |

Each component can be individually selected or deselected in the TUI before installing.

## ⌨️ Key Bindings

### Tmux (prefix: `C-a`)

#### Fast Navigation (NO prefix — 1 keystroke!)

| Key | Action |
|-----|--------|
| `Alt+1-9` | Jump to window by number |
| `Alt+n` / `Alt+p` | Next / previous window |
| `Alt+t` | New window |
| `Alt+w` | Close window |
| `Alt+g` | Floating scratch popup |
| `Alt+c` | **Cheatsheet popup** |
| `Ctrl+h/j/k/l` | Navigate panes ↔ Neovim splits (seamless) |

#### With Prefix (`C-a`)

| Key | Action |
|-----|--------|
| `C-a → v` | Split vertical |
| `C-a → d` | Split horizontal |
| `C-a → z` | Zoom pane (toggle) |
| `C-a → s` | Session picker |
| `C-a → w` | Window picker |
| `C-a → [` | Copy mode (vi keys) |

### Neovim / LazyVim (leader: `Space`)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find buffers |
| `<leader>1-5` | Harpoon: jump to bookmarked file |
| `<leader>ha` | Harpoon: add file |
| `-` | Oil: navigate filesystem |
| `s` | Flash: jump navigation |
| `gpd` | Preview definition |
| `<leader>z` | Zen mode |
| `<leader>gg` | LazyGit |

### Cheatsheet Popup

Press **`Alt+c`** anywhere in tmux to open the filterable cheatsheet.

| Key | Action |
|-----|--------|
| Type anything | Filter entries |
| `Tab` | Cycle to next category |
| `Shift+Tab` | Cycle to previous category |
| `ESC` | Close |

Categories: ALL → TMUX → NVIM → VIM-MOTIONS → ZSH → GHOSTTY → TIPS

## 🔒 Private Config

Your private aliases, passwords, and SSH configs go in `~/.zshrc.local` — this file is **never committed** to the repo.

The installer creates it from `zsh/zshrc.local.example`:

```bash
# ~/.zshrc.local — your private config

# Database aliases
alias db='mysql -u root -pYOUR_PASSWORD'

# SSH
alias ssh-dev='ssh -i ~/.ssh/mykey user@your-server'

# Project shortcuts
alias myproject='cd ~/path/to/project'

# API Keys
export OPENAI_API_KEY="sk-..."
```

## 🗑️ Uninstall

Run `devrocket-ecosystem` and select **Uninstall** from the main menu.

This will:
- Remove all configs managed by the installer
- Restore your original configs from backup (if backup was enabled)
- **Preserve** `~/.zshrc.local` (your private data is safe)

## 🎨 Theme

The entire ecosystem uses the **Kanagawa Dragon** color scheme:
- Ghostty: Custom Gentleman theme with Kanagawa colors
- Tmux: `tmux-kanagawa` plugin (dragon variant)
- Neovim: `gentleman-kanagawa-blur` colorscheme
- Terminal: 50+ custom GLSL shaders

## 🙏 Credits

- [Gentleman.Dots](https://github.com/Gentleman-Programming/Gentleman.Dots) — Base tooling and inspiration
- [Kanagawa](https://github.com/rebelot/kanagawa.nvim) — Color scheme
- [LazyVim](https://www.lazyvim.org/) — Neovim distribution
- [Ghostty](https://ghostty.org) — Terminal emulator
- [TPM](https://github.com/tmux-plugins/tpm) — Tmux Plugin Manager

## 📄 License

MIT — See [LICENSE](./LICENSE)
