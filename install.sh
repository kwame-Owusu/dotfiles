#!/usr/bin/env bash
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
BACKUP_DIR="${HOME}/.dotfiles-backup"
PACKAGES=(zsh bash git tmux envman scripts)

log() { printf '\033[1;34m[dotfiles]\033[0m %s\n' "$*"; }

if [ ! -d "$DOTFILES/zsh" ]; then
    echo "error: $DOTFILES does not look like this dotfiles repo."
    echo "clone it first:  git clone git@github.com:kwame-Owusu/dotfiles.git \"$DOTFILES\""
    exit 1
fi

# 1. Make sure GNU Stow is installed
if ! command -v stow >/dev/null 2>&1; then
    log "stow not found, installing..."
    if command -v brew >/dev/null 2>&1; then
        # Homebrew (macOS or Linuxbrew) installs to the user prefix - no sudo needed
        brew install stow
    elif [ "$(uname)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y stow
    elif [ "$(uname)" = "Linux" ] && command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm stow
    elif [ "$(uname)" = "Linux" ] && command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y stow
    else
        echo "Install stow manually (e.g. brew install stow or your distro's package manager)."; exit 1
    fi
fi

# 2. Move any existing files/symlinks out of the way (except ones already
#    pointing into our repo) so stow can create clean symlinks.
mkdir -p "$BACKUP_DIR"
backed_up=0
for pkg in "${PACKAGES[@]}"; do
    pkg_dir="$DOTFILES/$pkg"
    while IFS= read -r -d '' file; do
        rel="${file#"$pkg_dir"/}"
        target="$HOME/$rel"
        if [ -e "$target" ] || [ -L "$target" ]; then
            existing="$(readlink "$target" 2>/dev/null || true)"
            if [ -n "$existing" ] && [[ "$existing" == "$DOTFILES"* ]]; then
                continue
            fi
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            mv "$target" "$BACKUP_DIR/$rel"
            backed_up=$((backed_up + 1))
            log "moved ~/$rel -> $BACKUP_DIR/$rel"
        fi
    done < <(find "$pkg_dir" -type f -print0)
done
[ "$backed_up" -gt 0 ] && log "backed up $backed_up file(s) to $BACKUP_DIR"

# 3. Symlink every package into $HOME
for pkg in "${PACKAGES[@]}"; do
    log "stowing $pkg"
    stow -d "$DOTFILES" -t "$HOME" "$pkg"
done

log "Done. All configs are symlinked into $DOTFILES."
log "Optional: install oh-my-zsh (sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\") and tmux TPM plugins."
