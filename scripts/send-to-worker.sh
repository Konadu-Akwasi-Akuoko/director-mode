#!/bin/bash

# Send text to the worker's tmux pane.
# Uses -l (literal) to avoid semicolon interpretation issues.
# Sends Enter as a separate call.
#
# Usage: send-to-worker.sh [WORKER_TARGET] TEXT
#   If WORKER_TARGET is omitted, reads from state file.

set -euo pipefail

TMUX_BIN="/opt/homebrew/bin/tmux"
TMUX_SOCKET="${TMUX%%,*}"

# Parse arguments: if 2 args, first is target; if 1 arg, read target from state
if [[ $# -ge 2 ]]; then
  WORKER_TARGET="$1"
  shift
  TEXT="$*"
elif [[ $# -eq 1 ]]; then
  STATE_FILE="$HOME/.claude/director-mode.local.md"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: No active director session and no target specified." >&2
    exit 1
  fi
  WORKER_TARGET=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^worker_target:' | sed 's/worker_target: *//' | sed 's/^"\(.*\)"$/\1/')
  TEXT="$1"
else
  echo "Usage: send-to-worker.sh [WORKER_TARGET] TEXT" >&2
  exit 1
fi

if [[ -z "$WORKER_TARGET" ]]; then
  echo "ERROR: No worker target found." >&2
  exit 1
fi

# Send literal text (avoids semicolon parsing issues)
"$TMUX_BIN" -S "$TMUX_SOCKET" send-keys -t "$WORKER_TARGET" -l -- "$TEXT"

# Send Enter separately (Enter is a key name, not literal text)
"$TMUX_BIN" -S "$TMUX_SOCKET" send-keys -t "$WORKER_TARGET" Enter
