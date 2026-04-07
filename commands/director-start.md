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
   sed -i '' "s/^subtask_count: .*/subtask_count: N/" "./director-mode.local.md"
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

## Step 3.75: Gather Requirements

Before sending the task to the worker, proactively identify and resolve all ambiguities.
This prevents the worker from stalling on questions while the user is away.

### Read Project Context

Read CLAUDE.md, package.json/pyproject.toml, README, and other project metadata to pre-answer common questions about conventions, tech stack, and architecture.

### Identify Gaps

Analyze the task (and sub-tasks if sequencing). Identify:
1. Missing technical decisions (framework, library, architecture choices)
2. Ambiguous requirements (scope, priorities, edge cases)
3. Environment unknowns (database, deployment target, auth strategy)
4. Style/convention gaps not covered by CLAUDE.md

### Ask All Questions at Once

If gaps remain after reading context, use AskUserQuestion to ask ALL questions in a single batch.
Do not ask one at a time — batch them so the user can answer everything before stepping away.

### Build Task Brief

Compile: original task + CLAUDE.md conventions + user answers into a comprehensive task brief.
Append the brief to the state file body under `## Task Brief`:

```bash
cat >> "./director-mode.local.md" <<'BRIEF'

## Task Brief
<compiled brief here>
BRIEF
```

### Signal Readiness

Tell the user: "I have everything I need. You can step away now --
I will handle this autonomously and report results when done."

## Step 4: Send Task to Worker

First, rename both sessions for visual identification.

Rename the worker's Claude Code session:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "WORKER_SESSION_NAME" "/rename WORKER"
```

Wait 3 seconds for the rename to process, then rename the director's own session:
```
/rename DIRECTOR
```

Now capture the worker pane to check its current state:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/capture-worker.sh" "WORKER_SESSION_NAME"
```

Then send the task to the worker. Use the task brief from Step 3.75 (not the raw task) so the worker has full context. If the worker is at an idle prompt:

**Without sequencing** — send the full task brief directly:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "WORKER_SESSION_NAME" "TASK_BRIEF_TEXT"
```

**With sequencing** — send only sub-task 1, prefixed with context from the brief:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "WORKER_SESSION_NAME" "Sub-task 1 of N: <sub-task 1 description>. Overall goal: TASK_TEXT. Context: <relevant brief details>"
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
