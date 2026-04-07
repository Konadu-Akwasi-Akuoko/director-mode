#!/bin/bash

# List all tmux sessions with their names and running commands.
# Output format: one session per line, suitable for interactive selection.

set -euo pipefail

TMUX_BIN="/opt/homebrew/bin/tmux"

if [[ -z "${TMUX:-}" ]]; then
  echo "ERROR: Not inside a tmux session." >&2
  exit 1
fi

TMUX_SOCKET="${TMUX%%,*}"
CURRENT_SESSION=$("$TMUX_BIN" -S "$TMUX_SOCKET" display-message -p '#S')

echo "Available tmux sessions:"
echo "========================"

"$TMUX_BIN" -S "$TMUX_SOCKET" list-sessions -F '#{session_name}|#{session_windows}|#{session_activity}' | while IFS='|' read -r name windows activity; do
  # Get the command running in the active pane
  pane_cmd=$("$TMUX_BIN" -S "$TMUX_SOCKET" list-panes -t "$name" -F '#{pane_current_command}' 2>/dev/null | head -1)
  pane_path=$("$TMUX_BIN" -S "$TMUX_SOCKET" list-panes -t "$name" -F '#{pane_current_path}' 2>/dev/null | head -1)

  marker=""
  if [[ "$name" == "$CURRENT_SESSION" ]]; then
    marker=" (THIS SESSION)"
  fi

  echo "  $name — $pane_cmd in $pane_path ($windows windows)$marker"
done
