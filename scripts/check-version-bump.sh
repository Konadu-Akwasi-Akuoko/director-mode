#!/bin/bash

# PreToolUse hook: block git push unless the latest commit is a version bump.
# Receives hook JSON on stdin from Claude Code's hook system.

set -euo pipefail

HOOK_INPUT=$(cat)

COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""')

# Only gate actual git push commands
if ! echo "$COMMAND" | grep -qE '^git push(\s|$)'; then
  exit 0
fi

LATEST_MSG=$(git log -1 --pretty=%B 2>/dev/null | head -1)

if [[ "$LATEST_MSG" =~ ^chore:\ bump\ version\ to ]]; then
  exit 0
fi

jq -n '{
  "decision": "block",
  "reason": "Version bump required before pushing. Bump patch version in .claude-plugin/plugin.json, .claude-plugin/marketplace.json, skills/director-mode/SKILL.md. Add CHANGELOG.md entry. Commit as: chore: bump version to X.Y.Z"
}'
