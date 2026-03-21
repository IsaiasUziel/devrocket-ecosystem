#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Emoji/symbols
CHECK="✓"
WARN="⚠"
CROSS="✗"
ARROW="→"
ROCKET="🚀"

# ─── Utility functions ────────────────────────────────────────────────────────

info()    { echo -e "${BLUE}${ARROW}${RESET} $1"; }
success() { echo -e "${GREEN}${CHECK}${RESET} $1"; }
warn()    { echo -e "${YELLOW}${WARN}${RESET} $1"; }
error()   { echo -e "${RED}${CROSS}${RESET} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.devrocket-backup/$(date +%Y-%m-%d_%H%M%S)"

# ─── Banner ───────────────────────────────────────────────────────────────────

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo ' ____             ____            _        _   '
    echo '|  _ \  _____   _|  _ \ ___   ___| | _____| |_ '
    echo '| | | |/ _ \ \ / / |_) / _ \ / __| |/ / _ \ __|'
    echo '| |_| |  __/\ V /|  _ < (_) | (__|   <  __/ |_ '
    echo '|____/ \___| \_/ |_| \_\___/ \___|_|\_\___|\__|'
    echo '                                                '
    echo -e " E C O S Y S T E M${RESET}"
}

# ─── OS detection ─────────────────────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin*) OS="macos" ;;
        Linux*)  OS="linux" ;;
        *)       error "Unsupported OS: $(uname -s)"; exit 1 ;;
    esac
    info "Detected OS: ${BOLD}${OS}${RESET}"
}

# ─── Homebrew prefix detection ────────────────────────────────────────────────

detect_brew_prefix() {
    if command -v brew &>/dev/null; then
        BREW_PREFIX="$(brew --prefix)"
    elif [[ -d "/opt/homebrew" ]]; then
        BREW_PREFIX="/opt/homebrew"
    elif [[ -d "/usr/local/Cellar" ]]; then
        BREW_PREFIX="/usr/local"
    elif [[ -d "$HOME/.linuxbrew" ]]; then
        BREW_PREFIX="$HOME/.linuxbrew"
    else
        BREW_PREFIX="/usr/local"
        warn "Homebrew not detected, using default prefix: $BREW_PREFIX"
    fi
    info "Homebrew prefix: ${BOLD}${BREW_PREFIX}${RESET}"
}

# ─── Prerequisites check ──────────────────────────────────────────────────────

check_prerequisites() {
    info "Checking prerequisites..."

    local missing=0

    # Check Gentleman.Dots (optional but recommended)
    if ! command -v gentleman-dots &>/dev/null; then
        warn "Gentleman.Dots not found. Recommended for base tool installation."
        warn "  Install: ${CYAN}https://github.com/Gentleman-Programming/Gentleman.Dots${RESET}"
        echo ""
    else
        success "Gentleman.Dots detected"
    fi

    # Required tools
    for tool in tmux nvim fzf zsh; do
        if command -v "$tool" &>/dev/null; then
            success "$tool $( "$tool" --version 2>/dev/null | head -1 || echo 'detected')"
        else
            warn "$tool not found — its configs will be skipped"
            missing=$((missing + 1))
        fi
    done

    # Ghostty (special — may not be in PATH on macOS)
    if command -v ghostty &>/dev/null || [[ -d "/Applications/Ghostty.app" ]]; then
        success "Ghostty detected"
    else
        warn "Ghostty not found — its configs will be skipped"
        missing=$((missing + 1))
    fi

    if [[ $missing -gt 0 ]]; then
        echo ""
        warn "${missing} tool(s) not found. Their configs will be skipped."
        echo ""
    fi
}

# ─── Backup function ──────────────────────────────────────────────────────────

backup() {
    local target="$1"
    if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$(basename "$target")"
        cp -r "$target" "$backup_path"
        info "Backed up: ${DIM}$target → $backup_path${RESET}"
    fi
}

# ─── Symlink function (idempotent) ────────────────────────────────────────────

create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]]; then
        local current_target
        current_target="$(readlink "$target")"
        if [[ "$current_target" == "$source" ]]; then
            success "Already linked: ${DIM}$target${RESET}"
            return
        fi
        # Symlink points elsewhere — back it up
        backup "$target"
        rm "$target"
    elif [[ -e "$target" ]]; then
        # Regular file/directory — back it up
        backup "$target"
        rm -rf "$target"
    fi

    ln -sf "$source" "$target"
    success "Linked: ${DIM}$target → $source${RESET}"
}

# ─── Per-tool install functions ───────────────────────────────────────────────

install_ghostty() {
    if ! command -v ghostty &>/dev/null && [[ ! -d "/Applications/Ghostty.app" ]]; then
        warn "Skipping Ghostty configs (not installed)"
        return
    fi

    echo ""
    info "${BOLD}Installing Ghostty configs...${RESET}"

    create_symlink "$SCRIPT_DIR/ghostty/config" "$HOME/.config/ghostty/config"

    # Themes — symlink entire directory
    if [[ -d "$SCRIPT_DIR/ghostty/themes" ]]; then
        create_symlink "$SCRIPT_DIR/ghostty/themes" "$HOME/.config/ghostty/themes"
    fi

    # Shaders — symlink entire directory
    if [[ -d "$SCRIPT_DIR/ghostty/shaders" ]]; then
        create_symlink "$SCRIPT_DIR/ghostty/shaders" "$HOME/.config/ghostty/shaders"
    fi
}

install_tmux() {
    if ! command -v tmux &>/dev/null; then
        warn "Skipping Tmux configs (not installed)"
        return
    fi

    echo ""
    info "${BOLD}Installing Tmux configs...${RESET}"

    create_symlink "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"

    # Install TPM if not present
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        info "TPM (Tmux Plugin Manager) not found."
        read -p "  Install TPM? This requires internet. (Y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            info "Installing TPM..."
            if git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" 2>/dev/null; then
                success "TPM installed"
            else
                warn "Failed to clone TPM. Install manually: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
            fi
        else
            warn "Skipped TPM. Install manually later: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
        fi
    else
        success "TPM already installed"
    fi
}

install_nvim() {
    if ! command -v nvim &>/dev/null; then
        warn "Skipping Neovim configs (not installed)"
        return
    fi

    echo ""
    info "${BOLD}Installing Neovim configs...${RESET}"

    create_symlink "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
}

install_zsh() {
    if ! command -v zsh &>/dev/null; then
        warn "Skipping Zsh configs (not installed)"
        return
    fi

    echo ""
    info "${BOLD}Installing Zsh configs...${RESET}"

    create_symlink "$SCRIPT_DIR/zsh/zshrc" "$HOME/.zshrc"
    create_symlink "$SCRIPT_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"

    # Create .zshrc.local from example (only if doesn't exist)
    if [[ ! -f "$HOME/.zshrc.local" ]]; then
        cp "$SCRIPT_DIR/zsh/zshrc.local.example" "$HOME/.zshrc.local"
        success "Created ~/.zshrc.local from template"
        warn "Edit ~/.zshrc.local to add your private aliases and credentials"
    else
        success "~/.zshrc.local already exists (preserved)"
    fi
}

install_cheatsheet() {
    echo ""
    info "${BOLD}Installing Cheatsheet popup...${RESET}"

    local bin_dir="$BREW_PREFIX/bin"

    if [[ -d "$bin_dir" ]] && [[ -w "$bin_dir" ]]; then
        create_symlink "$SCRIPT_DIR/cheatsheet/tmux-cheatsheet" "$bin_dir/tmux-cheatsheet"
    else
        # Fallback to ~/.local/bin
        mkdir -p "$HOME/.local/bin"
        create_symlink "$SCRIPT_DIR/cheatsheet/tmux-cheatsheet" "$HOME/.local/bin/tmux-cheatsheet"
        warn "Installed to ~/.local/bin/ — make sure it's in your PATH"
    fi
}

# ─── Post-install guidance ────────────────────────────────────────────────────

post_install() {
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}${BOLD}  ${ROCKET} DevRocket Ecosystem installed!${RESET}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Next steps:${RESET}"
    echo ""
    echo -e "  1. ${CYAN}Restart Ghostty${RESET} to apply terminal config"
    echo -e "  2. ${CYAN}tmux source ~/.tmux.conf${RESET} to reload tmux"
    echo -e "  3. Press ${CYAN}C-a + I${RESET} inside tmux to install plugins (TPM)"
    echo -e "  4. Open ${CYAN}nvim${RESET} and wait for LazyVim to sync plugins"
    echo -e "  5. Edit ${CYAN}~/.zshrc.local${RESET} for your private aliases"
    echo -e "  6. Press ${CYAN}Alt+c${RESET} in tmux for the cheatsheet popup"
    echo ""
    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "  ${DIM}Backups saved to: $BACKUP_DIR${RESET}"
    fi
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    echo ""
    print_banner
    echo ""

    detect_os
    detect_brew_prefix
    echo ""
    check_prerequisites

    echo -e "${BOLD}Starting installation...${RESET}"

    install_ghostty
    install_tmux
    install_nvim
    install_zsh
    install_cheatsheet

    post_install
}

main "$@"
