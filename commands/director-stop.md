---
description: "Stop director mode and clean up"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)", "Bash(/opt/homebrew/bin/tmux:*)", "Bash(rm:*)", "Bash(test:*)", "Read"]
hide-from-slash-command-tool: "true"
---

# Director Stop

Gracefully shut down director mode:

## Step 1: Check State

Check if director mode is active:

```bash
test -f "$HOME/.claude/director-mode.local.md" && echo "ACTIVE" || echo "NOT_ACTIVE"
```

If NOT_ACTIVE, tell the user "No active director session found." and stop.

## Step 2: Read State

Read the state file to get the worker target and current phase:

```bash
cat "$HOME/.claude/director-mode.local.md"
```

## Step 3: Notify Worker (Optional)

If the worker is mid-task, send a gentle stop message:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/send-to-worker.sh" "Please finish your current step and then stop. The director is shutting down."
```

## Step 4: Restore Tmux

Reset the tmux window name and status bar color:

```bash
/opt/homebrew/bin/tmux -S "${TMUX%%,*}" rename-window ""
/opt/homebrew/bin/tmux -S "${TMUX%%,*}" set-option -u status-style
```

## Step 5: Clean Up State

Remove the state file:

```bash
rm "$HOME/.claude/director-mode.local.md"
```

## Step 6: Cancel Loop

If a ralph-loop or loop is active, cancel it:

```bash
test -f .claude/ralph-loop.local.md && rm .claude/ralph-loop.local.md || true
```

Report: "Director mode stopped. Worker session is now unmanaged."
