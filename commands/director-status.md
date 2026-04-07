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

Format a concise status report:

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
