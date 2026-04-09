---
description: "Post-run analysis — reviews the director session and writes findings to the source repo"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*:*)", "Bash(date:*)", "Bash(cat:*)", "Bash(md5:*)", "Bash(mkdir:*)", "Bash(test:*)", "Bash(wc:*)", "Bash(basename:*)", "Agent", "Read", "Write", "Grep", "Glob"]
hide-from-slash-command-tool: "true"
---

# Director Review — Post-Run Analysis

You are running a **post-run review** of a completed director-mode session. This produces a review file and updates the improvement backlog in the director-mode source repo.

**Source repo** (hardcoded — NOT `${CLAUDE_PLUGIN_ROOT}` which resolves to the versioned cache):
```
DIRECTOR_MODE_REPO="/Users/akwasikonaduakuoko/Projects/AiAutomations/director-mode"
```

## Step 1: Read State File

```bash
cat "./director-mode.local.md"
```

Extract: `session_id`, `task`, `started_at`, `iteration`, `subtask_count`, `worker_target`, `sequencing`.

## Step 2: Determine Project Slug

Derive a short slug from the current working directory name for the review filename:

```bash
basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'
```

The review file will be named: `YYYY-MM-DD-<slug>.md` (using today's date).

## Step 3: Spawn Session Analyzer

Spawn the `session-analyzer` agent to parse the JSONL session logs:

```
Spawn the session-analyzer agent with:
- Director session ID: [session_id from state file]
- Project directory: [current working directory]
- Task description: [task from state file]
- Start time: [started_at from state file]
```

The agent returns a structured analysis with timeline, metrics, what worked, what failed, and user interventions.

## Step 4: Write Review File

Create the review file at:
```
DIRECTOR_MODE_REPO/reviews/YYYY-MM-DD-<slug>.md
```

Use this template, filling in data from the session analyzer:

```markdown
---
date: YYYY-MM-DD
project: <project name>
task: "<task description>"
duration_minutes: <N>
iterations: <N>
subtasks: <N>
user_interventions: <N unexpected>
verdict: success|partial|failure
---

# Director Mode Review: <project> — <date>

## Task
<task description>

## Run Metadata
<from session analyzer>

## Timeline
<from session analyzer>

## What Worked
<from session analyzer>

## What Failed
<from session analyzer — include severity, root cause, proposed fix>

## User Interventions
<from session analyzer — flag unexpected ones>

## Efficiency
<from session analyzer metrics>

## Proposed Fixes
<deduplicated list of actionable items with file paths and line numbers>
```

## Step 5: Update Improvement Backlog

Read the existing backlog at `DIRECTOR_MODE_REPO/improvement-backlog.md`.

For each issue found in Step 4:
1. **Check for duplicates** — if the issue description already exists in the backlog, increment its occurrence count and update the `last_seen` date
2. **If new** — append a new entry in this format:
   ```markdown
   - [ ] **[Severity]** Description of the issue
     - Proposed fix: `file:line` — what to change
     - First seen: YYYY-MM-DD (<project>)
     - Occurrences: 1
   ```

Keep the backlog sorted by severity (Critical > Medium > Low), then by occurrence count (descending).

## Step 6: Report

Summarize what was written:
- Review file path
- Number of issues found (by severity)
- Number of new vs. duplicate backlog items
- Key takeaway (1 sentence)
