#!/bin/bash

# Capture the worker's tmux pane output.
# Uses -J to join wrapped lines and -S -200 to get last 200 lines of scrollback.
# Reads worker target from state file or accepts as argument.

set -euo pipefail

TMUX_BIN="/opt/homebrew/bin/tmux"
TMUX_SOCKET="${TMUX%%,*}"

# Accept target as argument or read from state file
if [[ -n "${1:-}" ]]; then
  WORKER_TARGET="$1"
else
  STATE_FILE="./director-mode.local.md"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: No active director session and no target specified." >&2
    exit 1
  fi
  WORKER_TARGET=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^worker_target:' | sed 's/worker_target: *//' | sed 's/^"\(.*\)"$/\1/')
fi

if [[ -z "$WORKER_TARGET" ]]; then
  echo "ERROR: No worker target found." >&2
  exit 1
fi

# Capture pane: -p prints to stdout, -J joins wrapped lines, -S -200 gets scrollback
"$TMUX_BIN" -S "$TMUX_SOCKET" capture-pane -p -J -t "$WORKER_TARGET" -S -200
