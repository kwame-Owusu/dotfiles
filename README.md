# dotfiles

Cross-platform dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).
Works on macOS and Linux/WSL.

## Layout

```
zsh/      -> ~/.zshrc, ~/.zshenv
bash/     -> ~/.bashrc, ~/.profile, ~/.bash_logout
git/      -> ~/.gitconfig, ~/.gitconfig-uni
tmux/     -> ~/.tmux.conf
envman/   -> ~/.config/envman/*
scripts/  -> ~/.local/bin/*.sh   (tmux helper scripts, on PATH)
```

Each directory is a "package": its contents mirror paths under `$HOME`
and get symlinked in with `stow`.

## Setup on a new machine

```bash
git clone git@github.com:kwame-Owusu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install.sh
```

`install.sh` will:

1. Install `stow` (via `apt`/`pacman`/`dnf` on Linux, or Homebrew on macOS).
2. Move any existing conflicting files to `~/.dotfiles-backup/`.
3. Symlink every package into `$HOME`.

Optional extras to install afterwards:

```bash
# oh-my-zsh (required for the shell to function)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# tmux TPM plugin (loading is already in .tmux.conf)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# brew packages (see hops.yml in the old repo for the list)
```

## Daily use

Edit a config anywhere and it is already tracked - there is no copying:

```bash
cd ~/.dotfiles
git add -A && git commit -m "..." && git push
```

On your other machine: `cd ~/.dotfiles && git pull` - your shell picks up
the symlinked files automatically.

## Platform notes

- `~/.zshrc` detects the OS to source the right Homebrew prefix
  (`/opt/homebrew` on macOS, `/home/linuxbrew` on Linux).
- `~/.gitconfig` uses the `gh` credential helper via PATH, so it works on
  both OSes once `gh` is installed.
- Machine-specific things like lock files, caches, and histories are never
  tracked (see `.gitignore`). Secrets live on each machine only - keep it
  that way.

## Secrets

Never commit: `~/.git-credentials`, `~/.config/gh/hosts.yml`,
`.bootdev.yaml`, `~/.ssh/`, `~/.aws`, `~/.azure`, `~/.docker/config.json`.
Listed in `.gitignore` and there by design.