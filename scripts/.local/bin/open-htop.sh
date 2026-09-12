#!/usr/bin/env bash

#fail explicitly if any command or pipeline fails
set -euo pipefail

if [[ -n "${TMUX:-}" ]]; then
    cd "$(tmux display -p "#{pane_current_path}")"
fi

if command -v htop > /dev/null; then
    tmux split-window -h
    htop
else
    echo "htop command not installed"
fi


