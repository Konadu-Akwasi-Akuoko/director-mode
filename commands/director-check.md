---
description: "Run a single director mode check iteration (used by the loop)"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)", "Bash(/opt/homebrew/bin/tmux:*)", "Bash(sed:*)", "Bash(test:*)", "Bash(cat:*)", "Bash(date:*)", "Agent", "Read"]
hide-from-slash-command-tool: "true"
---

# Director Check — Single Iteration

You are the director. Run ONE check iteration on your worker.

## Step 1: Verify Active

```bash
test -f "$HOME/.claude/director-mode.local.md" && echo "ACTIVE" || echo "NOT_ACTIVE"
```

If NOT_ACTIVE, say "Director mode is not active." and stop.

## Step 2: Read State

Read the state file:

```bash
cat "$HOME/.claude/director-mode.local.md"
```

Extract: worker_target, task, phase, iteration.

## Step 3: Capture Worker

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/capture-worker.sh"
```

## Step 4: Classify Worker Phase

Analyze the captured output. Look for these indicators:

- **IDLE**: `>` prompt visible, "How can I help?", waiting cursor
- **PLANNING**: Plan text, numbered steps, "Plan:" header
- **ASKING**: Question marks, "?" in output, asks for clarification, "Which...", "Should I..."
- **AWAITING_APPROVAL**: Plan summary shown, accept/reject prompt
- **IMPLEMENTING**: Tool calls visible (Read, Write, Edit, Bash), spinners, file paths in output
- **DONE**: Completion message, summary of work, back to `>` prompt after having done work
- **ERROR**: Error messages, stack traces, "failed", "error"
- **PERMISSION_PROMPT**: "Allow"/"Deny" dialog, tool permission request

## Step 5: Act Based on Phase

### IDLE
The worker is waiting. Send the task:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "THE_TASK_TEXT"
```

### PLANNING
Worker is creating a plan. Do nothing — wait for the next iteration.

### ASKING
The worker has a question. Extract the question from the output, then spawn the `decision-maker` agent:

```
Spawn the decision-maker agent with:
- Question: [extracted question]
- Project directory: [worker's working directory]
- Original task: [task from state file]
```

If the decision-maker returns `ESCALATE: ...`, report the question to the user and pause.
Otherwise, send the answer to the worker.

### AWAITING_APPROVAL
The worker has a plan ready. Review it briefly — does it make sense for the task? If yes:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "yes"
```

### IMPLEMENTING
Worker is actively working. Do nothing — wait for the next iteration.
If the output looks stuck (identical to last capture for 3+ iterations), send:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "Continue with the task. If stuck, try a different approach."
```

### DONE
Worker completed the task. Capture final output and report a summary to the user.

### ERROR
Worker hit an error. Analyze the error and send corrective guidance:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "Error detected: [brief description]. Try: [suggestion]."
```

### PERMISSION_PROMPT
Worker needs tool permission. Send approval:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "y"
```

## Step 6: Update State

Increment the iteration counter and update phase/timestamp:

```bash
sed -i '' "s/^phase: .*/phase: \"NEW_PHASE\"/" "$HOME/.claude/director-mode.local.md"
sed -i '' "s/^last_check: .*/last_check: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$HOME/.claude/director-mode.local.md"
sed -i '' "s/^iteration: .*/iteration: NEW_COUNT/" "$HOME/.claude/director-mode.local.md"
```

## Step 7: Report

Briefly report what you observed and what action you took. Example:
"Iteration 5: Worker is IMPLEMENTING — editing src/api.ts. No intervention needed."
