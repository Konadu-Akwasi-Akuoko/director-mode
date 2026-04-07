# Task Sequencing — Reference

For complex tasks that could exhaust the worker's context window, the director decomposes the task into 2-7 sequential sub-tasks. Each sub-task runs in a clean worker context.

## Decomposition

During `/director-start`, evaluate whether the task is complex enough to warrant sequencing. Indicators of complexity:
- Multiple distinct deliverables (e.g., "auth + CRUD + tests")
- Tasks spanning different domains (frontend + backend + database)
- Tasks that would require reading/writing many files

If sequencing is warranted, break the task into 2-7 ordered sub-tasks and write them to the state file body under `## Sub-tasks`. Pass `--sequencing` to `setup-director.sh`.

## Sub-task Execution Flow

1. Send sub-task N to the worker, prefixed with: `"Sub-task N of M: <description>. Context from prior sub-tasks: <summaries>"`
2. Monitor via the normal director loop until the worker reaches DONE
3. Capture a completion summary from the worker's final output
4. Update sub-task status to `[DONE]` and append summary to `## Completed Summaries`
5. Send `/clear` to the worker and set `clearing: true` in state
6. Enter CLEARING phase: poll until worker shows idle prompt
7. Advance `current_subtask`, mark next sub-task `[IN_PROGRESS]`, send it to worker
8. Repeat until all sub-tasks are done, then set `phase: all_done`

## CLEARING Phase

The CLEARING phase is a transitional state between sub-tasks:

1. Set `clearing: true` in state file
2. Send `/clear` to the worker
3. Each check iteration: capture worker pane, look for idle prompt
4. If idle: set `clearing: false`, advance to next sub-task
5. If not idle after 3 iterations: resend `/clear`

## Context Budgeting

Each sub-task gets a fresh worker context (~200k token budget). Prior sub-task results are passed as compressed summaries, not full conversation history. This allows complex multi-step tasks to complete without context exhaustion.

## Error Handling with Sequencing

When a sub-task fails:
1. Increment `retry_count` in state file
2. If `retry_count <= max_retries`: send `/clear`, retry the sub-task
3. If `retry_count > max_retries`: escalate to the user with options:
   - **Skip**: Mark sub-task `[FAILED]`, advance to next
   - **Stop**: Halt sequencing, report partial progress

Use `update-subtask-status.sh` to update sub-task markers:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/update-subtask-status.sh" 2 DONE "Implemented auth endpoints with JWT tokens."
```
