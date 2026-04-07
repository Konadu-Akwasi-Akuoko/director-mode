#!/bin/bash

# Director Guard Hook (PreToolUse)
# Prevents the director from directly interacting with project files.
# Only active when running in the "director-mode" tmux window.
#
# ALLOWS: tmux commands, state file access, CLAUDE.md reads, memory reads, plugin source reads
# BLOCKS: Read/Write/Edit on project source files, non-tmux Bash commands

set -euo pipefail

STATE_FILE="./director-mode.local.md"

# If director mode is not active, allow everything
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

TMUX_BIN="/opt/homebrew/bin/tmux"

# If not in tmux, allow everything
if [[ -z "${TMUX:-}" ]]; then
  exit 0
fi

TMUX_SOCKET="${TMUX%%,*}"

# Only guard the director window (named "director-mode" by setup-director.sh)
# Worker, third sessions, etc. pass through freely
CURRENT_WINDOW=$("$TMUX_BIN" -S "$TMUX_SOCKET" display-message -p '#W' 2>/dev/null || echo "")
if [[ "$CURRENT_WINDOW" != "director-mode" ]]; then
  exit 0
fi

# Read hook input
HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input // {} | tostring')

# --- ALLOW LIST ---

case "$TOOL_NAME" in
  Bash)
    COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""')

    # Allow tmux commands
    if echo "$COMMAND" | grep -q '/opt/homebrew/bin/tmux\|tmux '; then
      exit 0
    fi

    # Allow commands on director state files
    if echo "$COMMAND" | grep -qE '(director-mode\.local\.md|ralph-loop\.local\.md)'; then
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
    if echo "$COMMAND" | grep -qE '^(test|cat) .*(director-mode|ralph-loop)'; then
      exit 0
    fi

    # Allow date commands (used for timestamp updates)
    if echo "$COMMAND" | grep -qE '^date '; then
      exit 0
    fi

    # Allow cleanup script
    if echo "$COMMAND" | grep -q "cleanup-director"; then
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

    # Allow reading the plugin's own source files
    if echo "$FILE_PATH" | grep -q "${CLAUDE_PLUGIN_ROOT:-__no_match__}"; then
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
