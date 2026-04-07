#!/bin/bash

# Update a sub-task's status in the director-mode state file body.
# Finds the line matching "N. [STATUS]" or "N. **[STATUS]**" and replaces the status marker.
# Optionally appends a summary to the Completed Summaries section.
#
# Usage: update-subtask-status.sh <number> <PENDING|IN_PROGRESS|DONE|FAILED> [summary]

set -euo pipefail

SUBTASK_NUM="${1:?Usage: update-subtask-status.sh <number> <PENDING|IN_PROGRESS|DONE|FAILED> [summary]}"
NEW_STATUS="${2:?Usage: update-subtask-status.sh <number> <PENDING|IN_PROGRESS|DONE|FAILED> [summary]}"
SUMMARY="${3:-}"

STATE_FILE="$HOME/.claude/director-mode.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: State file not found at $STATE_FILE" >&2
  exit 1
fi

# Validate status
case "$NEW_STATUS" in
  PENDING|IN_PROGRESS|DONE|FAILED) ;;
  *)
    echo "ERROR: Invalid status '$NEW_STATUS'. Use PENDING, IN_PROGRESS, DONE, or FAILED." >&2
    exit 1
    ;;
esac

# Update the sub-task line: "N. [OLD_STATUS] description" -> "N. [NEW_STATUS] description"
# Matches patterns like "1. [PENDING] Set up project" or "1. **[PENDING]** Set up project"
sed -i '' "s/^${SUBTASK_NUM}\. \[.*\]/&/" "$STATE_FILE"
sed -i '' "s/^${SUBTASK_NUM}\. \[[A-Z_]*\]/${SUBTASK_NUM}. [${NEW_STATUS}]/" "$STATE_FILE"

# Update YAML frontmatter fields
if [[ "$NEW_STATUS" == "IN_PROGRESS" ]]; then
  sed -i '' "s/^current_subtask: .*/current_subtask: $((SUBTASK_NUM - 1))/" "$STATE_FILE"
fi

if [[ "$NEW_STATUS" == "DONE" || "$NEW_STATUS" == "FAILED" ]]; then
  # Increment retry_count back to 0 on completion
  sed -i '' "s/^retry_count: .*/retry_count: 0/" "$STATE_FILE"
fi

# Append summary to Completed Summaries section if provided
if [[ -n "$SUMMARY" && "$NEW_STATUS" == "DONE" ]]; then
  # Find the "## Completed Summaries" line and append after it
  sed -i '' "/^## Completed Summaries$/a\\
\\
### Sub-task ${SUBTASK_NUM}\\
${SUMMARY}" "$STATE_FILE"
fi

echo "Sub-task $SUBTASK_NUM status updated to $NEW_STATUS"
