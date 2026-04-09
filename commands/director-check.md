---
description: "Run a single director mode check iteration (used by the loop)"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)", "Bash(/opt/homebrew/bin/tmux:*)", "Bash(sed:*)", "Bash(test:*)", "Bash(cat:*)", "Bash(date:*)", "Agent", "Read"]
hide-from-slash-command-tool: "true"
---

# Director Check — Single Iteration

You are the director. Run ONE check iteration on your worker.

## Step 1: Verify Active

```bash
test -f "./director-mode.local.md" && echo "ACTIVE" || echo "NOT_ACTIVE"
```

If NOT_ACTIVE, say "Director mode is not active." and stop.

## Step 2: Read State

Read the state file:

```bash
cat "./director-mode.local.md"
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
- **IMPLEMENTING (background)**: Output contains "Backgrounded agent", "running in background", agent status notifications, or "agent completed" messages. The worker may appear idle (prompt visible) but background agents are still running. Treat as IMPLEMENTING — do NOT send new tasks or classify as DONE.
- **DONE**: Completion message, summary of work, back to `>` prompt after having done work AND no background agents are running
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
Worker is actively working. Track output staleness to detect stuck states:

1. Compute a hash of the captured output:
   ```bash
   CAPTURE_HASH=$(cat /tmp/director-worker-capture.txt | md5 -q)
   ```
2. Read `last_capture_hash` from the state file.
3. **If hashes match** — increment `stale_count`:
   ```bash
   CURRENT_STALE=$(sed -n 's/^stale_count: //p' "./director-mode.local.md")
   NEW_STALE=$((CURRENT_STALE + 1))
   sed -i '' "s/^stale_count: .*/stale_count: $NEW_STALE/" "./director-mode.local.md"
   ```
4. **If hashes differ** — reset `stale_count` to 0 and update the stored hash:
   ```bash
   sed -i '' "s/^stale_count: .*/stale_count: 0/" "./director-mode.local.md"
   sed -i '' "s/^last_capture_hash: .*/last_capture_hash: \"$CAPTURE_HASH\"/" "./director-mode.local.md"
   ```
5. **If `stale_count >= 3`** — the worker is stuck. Send a nudge and reset:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "Continue with the task. If stuck, try a different approach."
   ```
   ```bash
   sed -i '' "s/^stale_count: .*/stale_count: 0/" "./director-mode.local.md"
   ```

If `stale_count < 3`, do nothing — wait for the next iteration.

### DONE

Check if sequencing is active by reading the `sequencing` field from the state file.

**Without sequencing:** Worker completed the task. Capture final output, run the post-run review, then report a summary to the user.
   - **Post-run review**: Before reporting completion, invoke the director-review command:
     ```
     /director-mode:director-review
     ```

**With sequencing:** The current sub-task is complete. Transition to the CLEARING phase:

1. Capture a brief completion summary from the worker's output (2-3 sentences of what was accomplished)
2. Update the sub-task status and record the summary:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/update-subtask-status.sh" SUBTASK_NUM DONE "completion summary here"
   ```
3. Check if this was the last sub-task. If `current_subtask + 1 >= subtask_count`, set `phase: all_done`, run the post-run review, then report full completion to the user. Stop.
   - **Post-run review**: Before stopping, invoke the director-review command to analyze this session:
     ```
     /director-mode:director-review
     ```
     This writes a review file and updates the improvement backlog in the director-mode source repo.
4. Otherwise, send `/clear` to the worker:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "/clear"
   ```
5. Update state file:
   ```bash
   sed -i '' "s/^clearing: .*/clearing: true/" "./director-mode.local.md"
   sed -i '' "s/^phase: .*/phase: \"clearing\"/" "./director-mode.local.md"
   ```

### CLEARING

This phase handles the transition between sub-tasks during sequencing.

1. Capture the worker pane:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/capture-worker.sh"
   ```
2. Check if the worker shows an idle prompt (`>`, "How can I help?").
3. **If idle:**
   - Set `clearing: false`:
     ```bash
     sed -i '' "s/^clearing: .*/clearing: false/" "./director-mode.local.md"
     ```
   - Advance to the next sub-task:
     ```bash
     sed -i '' "s/^current_subtask: .*/current_subtask: NEXT_INDEX/" "./director-mode.local.md"
     ```
   - Mark the next sub-task as IN_PROGRESS:
     ```bash
     "${CLAUDE_PLUGIN_ROOT}/scripts/update-subtask-status.sh" NEXT_NUM IN_PROGRESS
     ```
   - Read the `## Completed Summaries` section from the state file to build context
   - Send the next sub-task to the worker with context from prior completions:
     ```bash
     "${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "Sub-task N of M: <description>. Context from completed sub-tasks: <summaries>"
     ```
   - Update phase back to active monitoring:
     ```bash
     sed -i '' "s/^phase: .*/phase: \"idle\"/" "./director-mode.local.md"
     ```
4. **If not idle:** Wait. If the worker has not become idle after 3 consecutive CLEARING iterations, resend `/clear`:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "/clear"
   ```

### ERROR

Check if sequencing is active.

**Without sequencing:** Analyze the error and send corrective guidance:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "Error detected: [brief description]. Try: [suggestion]."
```

**With sequencing:** Handle sub-task failure:

1. Increment `retry_count`:
   ```bash
   CURRENT_RETRY=$(sed -n 's/^retry_count: //p' "./director-mode.local.md")
   NEW_RETRY=$((CURRENT_RETRY + 1))
   sed -i '' "s/^retry_count: .*/retry_count: $NEW_RETRY/" "./director-mode.local.md"
   ```
2. Read `max_retries` from state file.
3. **If retry_count <= max_retries:** Send `/clear` to the worker, then retry the same sub-task.
4. **If retry_count > max_retries:** Escalate to the user. Report which sub-task failed and offer options:
   - **Skip:** Mark sub-task `[FAILED]` and advance to the next one
   - **Stop:** Halt sequencing entirely, report partial progress
   Update sub-task status:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/update-subtask-status.sh" SUBTASK_NUM FAILED
   ```

### PERMISSION_PROMPT
Worker needs tool permission. Send approval:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "y"
```

## Step 6: Update State

Increment the iteration counter and update phase/timestamp:

```bash
sed -i '' "s/^phase: .*/phase: \"NEW_PHASE\"/" "./director-mode.local.md"
sed -i '' "s/^last_check: .*/last_check: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "./director-mode.local.md"
sed -i '' "s/^iteration: .*/iteration: NEW_COUNT/" "./director-mode.local.md"
```

## Step 7: Report

Briefly report what you observed and what action you took. Example:
"Iteration 5: Worker is IMPLEMENTING — editing src/api.ts. No intervention needed."
