#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${TMUX:-}" ]]; then
    cd "$(tmux display -p "#{pane_current_path}")"
fi

if command -v lista > /dev/null; then
    tmux split-window -h
    lista
else
    echo "lista not installed"
fi

