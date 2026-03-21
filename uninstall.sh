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

# ─── Utility functions ────────────────────────────────────────────────────────

info()    { echo -e "${BLUE}${ARROW}${RESET} $1"; }
success() { echo -e "${GREEN}${CHECK}${RESET} $1"; }
warn()    { echo -e "${YELLOW}${WARN}${RESET} $1"; }
error()   { echo -e "${RED}${CROSS}${RESET} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    fi
}

# ─── Managed symlink list ─────────────────────────────────────────────────────

# Populated after brew prefix detection
build_managed_links() {
    MANAGED_LINKS=(
        "$HOME/.config/ghostty/config"
        "$HOME/.config/ghostty/themes"
        "$HOME/.config/ghostty/shaders"
        "$HOME/.tmux.conf"
        "$HOME/.config/nvim"
        "$HOME/.zshrc"
        "$HOME/.p10k.zsh"
    )
}

# ─── Backup restoration map ───────────────────────────────────────────────────
# Maps backup filename → original destination path
# Used to restore files from the most recent backup dir.
declare -A RESTORE_MAP=(
    ["config"]="$HOME/.config/ghostty/config"
    ["themes"]="$HOME/.config/ghostty/themes"
    ["shaders"]="$HOME/.config/ghostty/shaders"
    [".tmux.conf"]="$HOME/.tmux.conf"
    ["tmux.conf"]="$HOME/.tmux.conf"
    ["nvim"]="$HOME/.config/nvim"
    [".zshrc"]="$HOME/.zshrc"
    ["zshrc"]="$HOME/.zshrc"
    [".p10k.zsh"]="$HOME/.p10k.zsh"
    ["p10k.zsh"]="$HOME/.p10k.zsh"
)

# ─── Remove symlinks ──────────────────────────────────────────────────────────

remove_managed_symlinks() {
    info "Removing managed symlinks..."
    local removed=0

    for link in "${MANAGED_LINKS[@]}"; do
        if [[ -L "$link" ]]; then
            # Only remove if it actually points into our repo
            local target_real
            target_real="$(readlink "$link")"
            if [[ "$target_real" == "$SCRIPT_DIR"* ]]; then
                rm "$link"
                success "Removed symlink: ${DIM}$link${RESET}"
                removed=$((removed + 1))
            else
                warn "Skipped: ${DIM}$link${RESET} (points elsewhere — not ours)"
            fi
        elif [[ -e "$link" ]]; then
            warn "Skipped: ${DIM}$link${RESET} (not a symlink — won't touch it)"
        else
            info "Already absent: ${DIM}$link${RESET}"
        fi
    done

    # Also check cheatsheet in both possible locations
    for cheat_path in "$BREW_PREFIX/bin/tmux-cheatsheet" "$HOME/.local/bin/tmux-cheatsheet"; do
        if [[ -L "$cheat_path" ]]; then
            local target_real
            target_real="$(readlink "$cheat_path")"
            if [[ "$target_real" == "$SCRIPT_DIR"* ]]; then
                rm "$cheat_path"
                success "Removed symlink: ${DIM}$cheat_path${RESET}"
                removed=$((removed + 1))
            else
                warn "Skipped: ${DIM}$cheat_path${RESET} (points elsewhere — not ours)"
            fi
        fi
    done

    if [[ $removed -eq 0 ]]; then
        info "No managed symlinks found to remove."
    else
        success "$removed symlink(s) removed."
    fi
}

# ─── Backup restoration ───────────────────────────────────────────────────────

restore_latest_backup() {
    local backup_base="$HOME/.devrocket-backup"

    if [[ ! -d "$backup_base" ]]; then
        info "No backup directory found at $backup_base — nothing to restore."
        return
    fi

    # Find the most recent timestamped backup dir
    local latest_backup
    latest_backup="$(ls -td "$backup_base"/*/ 2>/dev/null | head -1 || true)"

    if [[ -z "$latest_backup" ]]; then
        info "No backup sets found in $backup_base — nothing to restore."
        return
    fi

    info "Restoring from: ${DIM}$latest_backup${RESET}"

    local restored=0
    local skipped=0

    for file in "$latest_backup"*; do
        # Guard: nothing matched the glob
        [[ -e "$file" ]] || continue

        local name
        name="$(basename "$file")"

        # Look up the restore destination
        local dest="${RESTORE_MAP[$name]:-}"

        if [[ -z "$dest" ]]; then
            warn "No restore mapping for backup file: ${DIM}$name${RESET} — skipping"
            skipped=$((skipped + 1))
            continue
        fi

        # Safety: never overwrite a file that is NOT a symlink from our install
        # (i.e., user manually placed something there after uninstall started)
        if [[ -e "$dest" ]] && [[ ! -L "$dest" ]]; then
            warn "Destination already exists (non-symlink): ${DIM}$dest${RESET} — skipping restore"
            skipped=$((skipped + 1))
            continue
        fi

        # Remove dangling symlink if present
        if [[ -L "$dest" ]]; then
            rm "$dest"
        fi

        # Ensure parent directory exists
        mkdir -p "$(dirname "$dest")"

        # Restore
        cp -r "$file" "$dest"
        success "Restored: ${DIM}$name → $dest${RESET}"
        restored=$((restored + 1))
    done

    echo ""
    if [[ $restored -gt 0 ]]; then
        success "$restored file(s) restored from backup."
    fi
    if [[ $skipped -gt 0 ]]; then
        warn "$skipped file(s) skipped during restore (see warnings above)."
    fi
    if [[ $restored -eq 0 ]] && [[ $skipped -eq 0 ]]; then
        info "Backup directory was empty — nothing to restore."
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo -e "${BOLD}DevRocket Ecosystem — Uninstaller${RESET}"
    echo ""
    echo -e "This will remove all ${CYAN}DevRocket Ecosystem${RESET} symlinks and restore backups."
    echo ""

    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""

    detect_brew_prefix
    build_managed_links

    remove_managed_symlinks
    echo ""
    restore_latest_backup

    echo ""
    warn "~/.zshrc.local was NOT removed (contains your private data)"
    echo ""
    echo -e "${GREEN}${BOLD}✓ DevRocket Ecosystem uninstalled.${RESET}"
    echo ""
    echo -e "  ${DIM}You may want to restart your shell or run:${RESET}"
    echo -e "  ${CYAN}exec \$SHELL${RESET}"
    echo ""
}

main "$@"
