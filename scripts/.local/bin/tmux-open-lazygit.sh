#!/usr/bin/env bash

set -euo pipefail

width=${1:-90%}
height=${2:-90%}

# Get the tmux pane's working directory (if inside tmux)
if [[ -n "${TMUX:-}" ]]; then
    cd "$(tmux display -p "#{pane_current_path}")"
fi

tmux popup -d '#{pane_current_path}' -w$width -h$height -E "lazygit"
