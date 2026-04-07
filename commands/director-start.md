---
description: "Start director mode — select a worker session and send it a task"
argument-hint: "<TASK>"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)", "Bash(/opt/homebrew/bin/tmux:*)", "Bash(sed:*)", "Bash(test:*)", "Bash(cat:*)", "Agent", "Read", "Skill"]
hide-from-slash-command-tool: "true"
---

# Director Start

You are initializing **director mode**. Follow these steps precisely:

## Step 1: Check Prerequisites

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/check-tmux-prereqs.sh"
```

If the prereq check fails, report the error and stop. Do not proceed.

## Step 2: List Available Sessions

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/list-tmux-sessions.sh"
```

Show the user the list of available tmux sessions and ask them to pick which one is the **worker** (the session where the other Claude Code instance is running). The current session will be the director — do NOT select it as the worker.

## Step 3: Initialize Director

Once the user picks a worker session name, run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-director.sh" "WORKER_SESSION_NAME" "TASK_TEXT"
```

Replace `WORKER_SESSION_NAME` with the user's choice and `TASK_TEXT` with the task from $ARGUMENTS.

## Step 3.5: Decompose Task (if complex)

Evaluate whether the task is complex enough to warrant sequencing. A task warrants sequencing if it has:
- Multiple distinct deliverables (e.g., "auth + CRUD + tests")
- Work spanning different domains (frontend, backend, database, tests)
- Enough scope that the worker might exhaust its context window

If sequencing is warranted:

1. Break the task into 2-7 ordered sub-tasks. Each sub-task should be self-contained and produce a concrete deliverable.
2. Show the sub-task list to the user and ask for confirmation.
3. Re-run setup with the `--sequencing` flag:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/setup-director.sh" "WORKER_SESSION_NAME" "TASK_TEXT" --sequencing
   ```
4. Update the state file's `subtask_count` field:
   ```bash
   sed -i '' "s/^subtask_count: .*/subtask_count: N/" "$HOME/.claude/director-mode.local.md"
   ```
5. Replace the `## Sub-tasks` section in the state file body with the numbered sub-task list, each prefixed with `[PENDING]`:
   ```
   ## Sub-tasks
   1. [PENDING] Set up project structure and dependencies
   2. [PENDING] Implement authentication endpoints
   3. [PENDING] Add CRUD operations
   4. [PENDING] Write tests
   ```
6. Mark the first sub-task as `[IN_PROGRESS]`:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/update-subtask-status.sh" 1 IN_PROGRESS
   ```

## Step 4: Send Task to Worker

First, capture the worker pane to check its current state:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/capture-worker.sh" "WORKER_SESSION_NAME"
```

Then send the task to the worker. If the worker is at an idle prompt:

**Without sequencing** — send the full task directly:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "WORKER_SESSION_NAME" "TASK_TEXT"
```

**With sequencing** — send only sub-task 1, prefixed with context:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "WORKER_SESSION_NAME" "Sub-task 1 of N: <sub-task 1 description>. Overall goal: TASK_TEXT"
```

If this is a complex task (sequencing or not), instruct the worker to plan first by prepending "Plan first, then implement: " to the message.

## Step 5: Start the Director Loop

Now start a recurring loop to monitor the worker. Use the `/loop` skill with a 30-second interval, invoking the `/director-check` command each iteration:

```
/loop 30s /director-check
```

Tell the user director mode is active and they can:
- `/director-status` — check current state
- `/director-stop` — graceful shutdown
- `/director-check` — run a single manual check
