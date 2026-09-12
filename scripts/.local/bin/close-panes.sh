#!/usr/bin/env bash

#fail explicitly if any command or pipeline fails
set -euo pipefail

if [[ -n "${TMUX:-}" ]]; then
    cd "$(tmux display -p "#{pane_current_path}")"
fi

current_pane=$(tmux display -p "#{pane_id}")
for pane in $(tmux list-panes -F "#{pane_id}")
do
    if [[ "$pane" != "$current_pane" ]]; then
        tmux kill-pane -t "$pane"
    fi
done

