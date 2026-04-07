#!/bin/bash

# Check prerequisites for director mode:
# 1. tmux binary exists
# 2. We are inside a tmux session
# 3. At least 2 tmux sessions exist (director + worker)

set -euo pipefail

TMUX_BIN="/opt/homebrew/bin/tmux"

# Check tmux binary
if [[ ! -x "$TMUX_BIN" ]]; then
  echo "FAIL: tmux not found at $TMUX_BIN"
  exit 1
fi

# Check we're inside tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "FAIL: Not inside a tmux session. Start Claude Code inside tmux first."
  exit 1
fi

# Extract socket path from $TMUX (format: /path/to/socket,pid,window)
TMUX_SOCKET="${TMUX%%,*}"

# Count sessions
SESSION_COUNT=$("$TMUX_BIN" -S "$TMUX_SOCKET" list-sessions 2>/dev/null | wc -l | tr -d ' ')

if [[ "$SESSION_COUNT" -lt 2 ]]; then
  echo "FAIL: Need at least 2 tmux sessions (found $SESSION_COUNT). Create a worker session first."
  echo ""
  echo "  To create a worker session:"
  echo "    $TMUX_BIN new-session -d -s worker"
  echo "    Then launch Claude Code in it."
  exit 1
fi

echo "OK: tmux ready ($SESSION_COUNT sessions available)"
exit 0
