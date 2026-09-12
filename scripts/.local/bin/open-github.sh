#!/usr/bin/env bash
# Open the GitHub remote of the current Git repo in your Windows browser (WSL-compatible)
set -euo pipefail

# Get the tmux pane's working directory (if inside tmux)
if [[ -n "${TMUX:-}" ]]; then
    cd "$(tmux display -p "#{pane_current_path}")"
fi

# Get the Git remote URL
url=$(git remote get-url origin 2>/dev/null || true)

if [[ $url == *github.com* ]]; then
    # Convert SSH URL to HTTPS form
    if [[ $url == git@* ]]; then
        url="${url#git@}"
        url="${url/:/\/}"
        url="https://$url"
    fi

    # Strip trailing .git
    url="${url%.git}"

    # Open in browser depending on environment
    if command -v explorer.exe >/dev/null; then
        explorer.exe "$url"
    elif command -v xdg-open >/dev/null; then
        xdg-open "$url"
    elif command -v open >/dev/null; then
        open "$url"
    else
        echo "No compatible browser command found."
        exit 1
    fi
else
    echo "This repository is not hosted on GitHub."
fi

