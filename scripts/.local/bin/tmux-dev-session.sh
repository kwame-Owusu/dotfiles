#!/usr/bin/env bash

set -euo pipefail

# tmux-dev.sh — spin up a preconfigured tmux session with multiple windows/panes.
#
# Usage:
#   ./tmux-dev.sh [session-name] [project-dir]
#
# Defaults:
#   session-name = "dev"
#   project-dir  = current directory
#
# If the session already exists, this just attaches (or switches) to it
# instead of recreating it, so it's safe to run repeatedly.
 
SESSION="${1:-dev}"
PROJECT_DIR="${2:-$(pwd)}"
TMUX="${TMUX:-}"
 
# If the session already exists, just attach/switch to it.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
  exit 0
fi
 
cd "$PROJECT_DIR" || exit 1
 
# Window 1: editor 
tmux new-session -d -s "$SESSION" -n editor -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:editor" 'nvim .' C-m   # swap for your editor of choice
 
# Window 2: plain 
SHELL_NAME="$(basename "${SHELL:-sh}")"
tmux new-window -t "$SESSION" -n "$SHELL_NAME" -c "$PROJECT_DIR"
 
# Window 3: opencode 
tmux new-window -t "$SESSION" -n opencode -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:opencode" 'opencode' C-m
 
# Land on the editor window/pane when we attach
tmux select-window -t "$SESSION:editor"
 
# Attach (or switch, if already inside tmux)
if [ -n "$TMUX" ]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
 

