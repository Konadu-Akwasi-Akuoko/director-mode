#!/bin/bash

# Remove the director guard hook from project settings.
# Called by director-stop to restore zero-overhead state.

set -euo pipefail

SETTINGS_FILE=".claude/settings.local.json"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  exit 0
fi

# Remove the hooks.PreToolUse key, keep everything else
jq 'del(.hooks.PreToolUse)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

# If .hooks is now empty, remove it too
if [[ "$(jq '.hooks | length' "$SETTINGS_FILE" 2>/dev/null)" == "0" ]]; then
  jq 'del(.hooks)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
  mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
fi
