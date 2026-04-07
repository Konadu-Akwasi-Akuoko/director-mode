#!/bin/bash

# Initialize director mode:
# 1. Set tmux window name to "director-mode"
# 2. Set status bar color to red (visual indicator)
# 3. Create state file tracking director state

set -euo pipefail

TMUX_BIN="/opt/homebrew/bin/tmux"
TMUX_SOCKET="${TMUX%%,*}"

WORKER_TARGET="${1:?Usage: setup-director.sh WORKER_SESSION_NAME TASK [--sequencing]}"
TASK="${2:?Usage: setup-director.sh WORKER_SESSION_NAME TASK [--sequencing]}"

# Check for --sequencing flag
SEQUENCING="false"
if [[ "${3:-}" == "--sequencing" ]]; then
  SEQUENCING="true"
fi

# Set tmux window name for easy identification
"$TMUX_BIN" -S "$TMUX_SOCKET" rename-window "director-mode"

# Set status bar to red so user can visually see director is active
"$TMUX_BIN" -S "$TMUX_SOCKET" set-option status-style "bg=red,fg=white"

# Create state file
STATE_DIR="$HOME/.claude"
STATE_FILE="$STATE_DIR/director-mode.local.md"
mkdir -p "$STATE_DIR"

cat > "$STATE_FILE" <<EOF
---
active: true
worker_target: "$WORKER_TARGET"
task: "$TASK"
phase: "initializing"
iteration: 0
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
last_check: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id: "${CLAUDE_CODE_SESSION_ID:-unknown}"
sequencing: $SEQUENCING
current_subtask: 0
subtask_count: 0
retry_count: 0
max_retries: 1
clearing: false
---

Director mode active.
Worker: $WORKER_TARGET
Task: $TASK

## Sub-tasks
(none — populated during director-start if task decomposition is active)

## Completed Summaries
(populated as sub-tasks complete)
EOF

echo "Director mode initialized."
echo "  Worker target: $WORKER_TARGET"
echo "  State file: $STATE_FILE"
echo "  Tmux status: RED (director active)"
