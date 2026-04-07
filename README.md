# Director Mode

One Claude Code instance orchestrates another via tmux, acting as a human-in-the-loop proxy. The **Director** reads the worker's terminal output, answers its questions, approves plans, and monitors progress — all autonomously.

## Prerequisites

- **macOS** (tmux binary path is hardcoded to `/opt/homebrew/bin/tmux`)
- **tmux** installed via Homebrew
- **Two Claude Code sessions** running in separate tmux sessions on the same tmux server (same socket)

## Installation

```
/plugin install director-mode@akwasi-automation-hub
```

## Quick Start

1. **Create two tmux sessions** (in separate terminals):
   ```bash
   tmux new-session -s director
   ```
   ```bash
   tmux new-session -s worker
   ```

2. **Launch Claude Code in both sessions.**

3. **In the director session**, start director mode with a task:
   ```
   /director-start Build a REST API with authentication and CRUD endpoints
   ```

4. **Pick the worker session** when prompted (the other session where Claude Code is running).

5. **The director takes over.** It sends the task to the worker, monitors progress via a 30-second polling loop, answers the worker's questions, and reports back when done.

## Commands

| Command | Description |
|---------|-------------|
| `/director-start <task>` | Initialize director mode, select a worker session, and send the task |
| `/director-check` | Run a single director loop iteration (normally called by the loop) |
| `/director-status` | Show current phase, iteration count, worker snapshot, and sequencing progress |
| `/director-stop` | Graceful shutdown: notify worker, reset tmux visuals, remove state file |

## Architecture

### Director Loop

Each iteration follows a five-step cycle:

```
Capture --> Classify --> Act --> Update State --> Yield
```

1. **Capture** — Run `capture-worker.sh` to grab the last 200 lines of the worker's tmux pane
2. **Classify** — Determine the worker's current phase from terminal output
3. **Act** — Take the appropriate action for the detected phase
4. **Update** — Write the new phase and timestamp to the state file
5. **Yield** — Return control to the loop scheduler (30-second interval via `/loop`)

### State Machine Phases

| Phase | Trigger | Director Action |
|-------|---------|-----------------|
| IDLE | `>` prompt, waiting for input | Send the task |
| PLANNING | Plan text visible | Wait |
| ASKING | Worker asks a question | Spawn decision-maker agent, send answer |
| AWAITING_APPROVAL | Plan approval prompt | Review and approve |
| IMPLEMENTING | Tool calls, file edits in progress | Monitor; nudge if stuck |
| DONE | Completion message, back to prompt | Capture results, report to user |
| ERROR | Error messages, stack traces | Diagnose, send corrective guidance |
| PERMISSION_PROMPT | Allow/Deny dialog | Send `y` for safe operations |
| CLEARING | Waiting for `/clear` to complete (sequencing) | Verify idle, send next sub-task |
| ALL_DONE | All sub-tasks completed (sequencing) | Report full completion to user |

### Guard Hook

A `PreToolUse` hook (`director-guard.sh`) prevents the director from directly reading, writing, or editing project files. The director interacts with the codebase exclusively through the worker. Allowed operations: tmux commands, state file access, plugin scripts, CLAUDE.md/memory reads, and agent spawning.

### Decision-Maker Agent

When the worker asks a question, the director delegates to a `decision-maker` subagent rather than answering directly. This keeps the director's context window clean. The subagent reads project context (CLAUDE.md, memory files) and returns a concise answer or `ESCALATE:` if the question requires human judgment.

## Task Sequencing

For complex tasks that could exhaust the worker's context window, the director decomposes the task into 2-7 sequential sub-tasks. Each sub-task runs in a clean worker context.

### Flow

1. **Decompose** — Director evaluates task complexity and breaks it into ordered sub-tasks
2. **Send sub-task 1** — Only the first sub-task is sent (not the full task)
3. **Monitor** — Normal director loop runs until sub-task completes
4. **Clear** — Director captures a completion summary, sends `/clear` to the worker
5. **Advance** — After verifying the worker is idle, director sends the next sub-task with context from prior completions
6. **Repeat** — Steps 3-5 repeat until all sub-tasks are done

### Context Budgeting

Each sub-task runs in a fresh worker context, keeping token usage under ~200k per sub-task. Completed summaries from prior sub-tasks are included as context in subsequent sub-task messages, providing continuity without carrying full conversation history.

### Error Handling

If a sub-task fails, the director retries once. If it fails again, it escalates to the user with options to skip the sub-task or stop entirely.

## Project Structure

```
director-mode/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest (name, version, description)
│   └── marketplace.json     # Marketplace metadata
├── agents/
│   └── decision-maker.md    # Subagent: answers worker questions using project context
├── commands/
│   ├── director-start.md    # /director-start — init, session selection, task dispatch
│   ├── director-check.md    # /director-check — single loop iteration (capture/classify/act)
│   ├── director-status.md   # /director-status — show phase, progress, worker snapshot
│   └── director-stop.md     # /director-stop — graceful shutdown and cleanup
├── hooks/
│   ├── hooks.json           # Hook registration (PreToolUse matcher for guard)
│   └── director-guard.sh    # Blocks direct file access when director mode is active
├── scripts/
│   ├── check-tmux-prereqs.sh    # Verify tmux binary, session, and 2+ sessions exist
│   ├── list-tmux-sessions.sh    # List sessions with commands and paths for selection
│   ├── setup-director.sh        # Create state file, set tmux visuals (red status bar)
│   ├── capture-worker.sh        # Capture last 200 lines of worker pane output
│   ├── send-to-worker.sh        # Send literal text + Enter to worker pane
│   └── update-subtask-status.sh # Update sub-task status in state file body
├── CLAUDE.md                        # Developer conventions and guide
├── skills/
│   └── director-mode/
│       ├── SKILL.md             # Main skill definition (cardinal rules, loop, phases)
│       └── references/
│           ├── decision-making.md  # Decision framework for the decision-maker agent
│           └── tmux-patterns.md    # Tmux command patterns (-l flag, capture, socket)
└── README.md
```

## Component Relationships

```
/director-start ──> check-tmux-prereqs.sh
                ──> list-tmux-sessions.sh
                ──> setup-director.sh ──> creates ./director-mode.local.md
                ──> send-to-worker.sh
                ──> /loop 30s /director-check

/director-check ──> reads state file (phase, worker_target, task)
                ──> capture-worker.sh ──> tmux capture-pane
                ──> classifies phase from output
                ──> acts: send-to-worker.sh | spawn decision-maker | wait
                ──> updates state file via sed

/director-stop  ──> send-to-worker.sh (optional stop message)
                ──> tmux rename-window, reset status-style
                ──> rm state file

director-guard.sh (PreToolUse hook — dynamically installed)
  ├── Fires on: Read, Write, Edit, Bash, MultiEdit
  ├── Checks: state file exists AND tmux window name is "director-mode"
  ├── Allows: tmux, plugin scripts, state files, CLAUDE.md, memory
  └── Blocks: everything else (project file access)
```

## Design Decisions

### Guard Hook Enforcement

The guard hook is the core safety mechanism. Without it, the director could read/write project files directly, defeating the purpose of the two-session architecture. The hook is dynamically installed into `.claude/settings.local.json` when director mode starts and removed when it stops — zero overhead when inactive. It uses tmux window name matching so it only guards the "director-mode" window — the worker and any other sessions pass through freely.

### Decision-Maker Delegation

Questions from the worker are handled by a dedicated subagent rather than inline by the director. This serves two purposes: (1) keeps the director's context window focused on orchestration, and (2) gives the decision-maker access to project context files without the guard hook interfering (it runs as a subagent spawn, which is always allowed).

### 30-Second Loop Interval

The polling interval balances responsiveness with context consumption. Each check iteration adds to the director's context. Faster polling would eat context faster. The `/loop` skill handles the scheduling.

### Task Sequencing

Complex tasks are decomposed into 2-7 sub-tasks with `/clear` sent between each. This prevents the worker from exhausting its context window on large tasks. The CLEARING phase handles the transition between sub-tasks.

## Testing

### Manual Testing

1. Create two tmux sessions: `tmux new-session -s director` and (in another terminal) `tmux new-session -s worker`
2. Launch Claude Code in both
3. In the director session: `/director-start <task>`
4. Observe: director selects worker, sends task, enters monitoring loop
5. Check: `/director-status` shows correct phase and worker snapshot

### Guard Hook Testing

The guard hook can be tested independently. First create a temporary state file so the hook activates, then pipe a simulated tool call:

```bash
# Create a temporary state file in CWD
cat > ./director-mode.local.md <<'EOF'
---
active: true
worker_target: "test-worker"
task: "test"
phase: "implementing"
iteration: 0
started_at: "2026-01-01T00:00:00Z"
last_check: "2026-01-01T00:00:00Z"
session_id: "test"
sequencing: false
current_subtask: 0
subtask_count: 0
retry_count: 0
max_retries: 1
clearing: false
---
EOF

# Simulate a blocked Read call — should output a JSON block decision
# Note: must be in a tmux window named "director-mode" for the guard to activate
echo '{"tool_name":"Read","tool_input":{"file_path":"/some/project/file.ts"}}' | \
  TMUX="/tmp/tmux-test,1234,0" \
  bash hooks/director-guard.sh

# Clean up
rm ./director-mode.local.md
```

### Task Sequencing Testing

1. Start with a multi-step task: `/director-start "Create a REST API with auth, CRUD, and tests"`
2. Verify decomposition: check state file for sub-tasks in the markdown body
3. Verify clearing: after sub-task 1 completes, director should send `/clear` then sub-task 2
4. Verify status: `/director-status` should show sub-task progress

## Limitations

- **macOS only** — The tmux binary path is hardcoded to `/opt/homebrew/bin/tmux` (Homebrew on Apple Silicon). Linux users would need to modify the path in all scripts.
- **Same tmux server required** — Both sessions must share the same tmux server. By default, `tmux new-session` connects to the default server, so separate terminals will share the same server automatically. Separate servers only occur when using explicit `-L` or `-S` flags.
- **No Windows support** — tmux is not available on Windows natively.
- **30-second polling** — The director checks the worker every 30 seconds. Fast-completing tasks may have unnecessary wait time.
- **Single worker** — The director manages one worker session at a time.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Konadu-Akwasi-Akuoko/director-mode&type=Date)](https://star-history.com/#Konadu-Akwasi-Akuoko/director-mode&Date)

## License

[MIT](LICENSE)
