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

## Step 4: Send Task to Worker

First, capture the worker pane to check its current state:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/capture-worker.sh" "WORKER_SESSION_NAME"
```

Then send the task to the worker. If the worker is at an idle prompt, send the task directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "WORKER_SESSION_NAME" "TASK_TEXT"
```

If this is a complex task, instruct the worker to plan first by prepending "Plan first, then implement: " to the task.

## Step 5: Start the Director Loop

Now start a recurring loop to monitor the worker. Use the `/loop` skill with a 30-second interval, invoking the `/director-check` command each iteration:

```
/loop 30s /director-check
```

Tell the user director mode is active and they can:
- `/director-status` — check current state
- `/director-stop` — graceful shutdown
- `/director-check` — run a single manual check
