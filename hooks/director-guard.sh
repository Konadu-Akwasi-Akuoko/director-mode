#!/bin/bash

# Director Guard Hook (PreToolUse)
# Prevents the director from directly interacting with project files.
# Only active when director-mode state file exists.
#
# ALLOWS: tmux commands, state file access, CLAUDE.md reads, memory reads
# BLOCKS: Read/Write/Edit on project source files, non-tmux Bash commands

set -euo pipefail

STATE_FILE="$HOME/.claude/director-mode.local.md"

# If director mode is not active, allow everything
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Verify this session owns the director state
STATE_SESSION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^session_id:' | sed 's/session_id: *//' | sed 's/^"\(.*\)"$/\1/')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
  # Different session owns the director state — do not guard this session
  exit 0
fi

# Read hook input
HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input // {} | tostring')

# Extract the worker's project path from state file
WORKER_TARGET=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" | grep '^worker_target:' | sed 's/worker_target: *//' | sed 's/^"\(.*\)"$/\1/')

# --- ALLOW LIST ---

# Always allow: Agent tool (subagent spawning)
# The matcher only fires for Read|Write|Edit|Bash|MultiEdit, so Agent is never checked.

case "$TOOL_NAME" in
  Bash)
    COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""')

    # Allow tmux commands
    if echo "$COMMAND" | grep -q '/opt/homebrew/bin/tmux\|tmux '; then
      exit 0
    fi

    # Allow commands on director state files
    if echo "$COMMAND" | grep -qE '(director-mode\.local\.md|ralph-loop\.local\.md|\.claude/)'; then
      exit 0
    fi

    # Allow the plugin's own scripts
    if echo "$COMMAND" | grep -q "${CLAUDE_PLUGIN_ROOT:-__no_match__}/scripts/"; then
      exit 0
    fi

    # Allow sed on state files
    if echo "$COMMAND" | grep -qE '^sed .*(director-mode|ralph-loop)'; then
      exit 0
    fi

    # Allow test/cat on state files
    if echo "$COMMAND" | grep -qE '^(test|cat) .*(director-mode|ralph-loop|\.claude/)'; then
      exit 0
    fi

    # Block everything else
    jq -n '{
      "decision": "block",
      "reason": "Director mode: You must not run commands directly. Send them to the worker via send-to-worker.sh instead."
    }'
    exit 0
    ;;

  Read)
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""')

    # Allow reading state files
    if echo "$FILE_PATH" | grep -qE '(director-mode\.local\.md|ralph-loop\.local\.md)'; then
      exit 0
    fi

    # Allow reading CLAUDE.md files (needed for decision context)
    if echo "$FILE_PATH" | grep -qE '(CLAUDE\.md|MEMORY\.md)'; then
      exit 0
    fi

    # Allow reading memory files
    if echo "$FILE_PATH" | grep -q '\.claude/projects/.*/memory/'; then
      exit 0
    fi

    # Allow reading plugin files
    if echo "$FILE_PATH" | grep -q '\.claude/plugins/'; then
      exit 0
    fi

    # Block reading project source files
    jq -n '{
      "decision": "block",
      "reason": "Director mode: You must not read project files directly. Ask the worker to check this file instead."
    }'
    exit 0
    ;;

  Write|Edit|MultiEdit)
    FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""')

    # Allow writing state files
    if echo "$FILE_PATH" | grep -qE '(director-mode\.local\.md|ralph-loop\.local\.md)'; then
      exit 0
    fi

    # Block everything else
    jq -n '{
      "decision": "block",
      "reason": "Director mode: You must not write files directly. Send instructions to the worker instead."
    }'
    exit 0
    ;;
esac

# Default: allow
exit 0
