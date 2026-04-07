---
description: "Show current director mode status"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)", "Bash(test:*)", "Bash(cat:*)", "Read"]
hide-from-slash-command-tool: "true"
---

# Director Status

Show the current state of director mode:

## Step 1: Check State

```bash
test -f "$HOME/.claude/director-mode.local.md" && echo "ACTIVE" || echo "NOT_ACTIVE"
```

If NOT_ACTIVE, tell the user "No active director session." and stop.

## Step 2: Read State File

```bash
cat "$HOME/.claude/director-mode.local.md"
```

Parse and display:
- Worker target session
- Current phase
- Iteration count
- Time since started
- Time since last check

## Step 3: Capture Worker Snapshot

Get a fresh snapshot of the worker:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/capture-worker.sh"
```

Show the last 20 lines of the worker's output to give the user a quick view of what the worker is currently doing.

## Step 4: Report

Parse the `sequencing` field from the state file to determine if task sequencing is active.

**Without sequencing**, format a concise status report:

```
Director Mode Status
====================
Worker:    <session-name>
Phase:     <current-phase>
Iteration: <N>
Uptime:    <duration>
Last check: <timestamp>

Worker snapshot (last 20 lines):
<captured output>
```

**With sequencing**, include sub-task progress. Read the `## Sub-tasks` section from the state file body and include it in the report:

```
Director Mode Status
====================
Worker:    <session-name>
Phase:     <current-phase>
Iteration: <N>
Uptime:    <duration>
Last check: <timestamp>

Task Sequencing: Sub-task <current+1> of <total> [<status>]
  1. [DONE] Set up project structure
  2. [IN_PROGRESS] Implement auth endpoints
  3. [PENDING] Add CRUD operations
  4. [PENDING] Write tests

Worker snapshot (last 20 lines):
<captured output>
```

If `clearing` is `true`, append "Clearing worker context before next sub-task..." to the phase line.
