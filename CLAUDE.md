# Director Mode — Conventions

## Tmux

- Binary: `/opt/homebrew/bin/tmux` (hardcoded)
- Socket: `TMUX_SOCKET="${TMUX%%,*}"` — always pass `-S "$TMUX_SOCKET"`
- `send-keys -l` for literal text (avoids semicolon issues)
- Send `Enter` as a separate `send-keys` call (key name, not literal)

## Shell Scripts

- All scripts: `set -euo pipefail`
- Read worker target from argument, fall back to state file
- State file: `./director-mode.local.md` (in project CWD, not `~/.claude/` which triggers sensitive-file dialogs)

## State File

YAML frontmatter (structured) + markdown body (free-form). Updated via `sed -i ''` (macOS, no backup suffix).

Fields: `active`, `worker_target`, `task`, `phase`, `iteration`, `started_at`, `last_check`, `session_id`, `sequencing`, `current_subtask`, `subtask_count`, `retry_count`, `max_retries`, `clearing`, `last_capture_hash`, `stale_count`

Projects using director mode should add `*.local.md` to `.gitignore`.

## Command Frontmatter

- `allowed-tools` — restricts available tools
- `hide-from-slash-command-tool: "true"` — all commands use skill routing
- `argument-hint` — placeholder text for command argument

## Adding a Command

1. Create `commands/<name>.md` with frontmatter (`description`, `allowed-tools`, `hide-from-slash-command-tool`)
2. Write step-by-step prompt instructions
3. Reference scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/`

## Adding a Script

1. Create `scripts/<name>.sh` with `set -euo pipefail`
2. Use `TMUX_BIN="/opt/homebrew/bin/tmux"` and `TMUX_SOCKET="${TMUX%%,*}"`
3. Accept arguments or fall back to state file
4. Guard hook already allows `${CLAUDE_PLUGIN_ROOT}/scripts/*`

## Adding an Agent

1. Create `agents/<name>.md` with frontmatter (`name`, `description`, `model`, `tools`)
2. Define input format, process, response format, safety rules
3. Spawn from command prompts via the `Agent` tool

## Versioning

- Version lives in 3 files: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `skills/director-mode/SKILL.md`
- **Before every `git push`**: bump the patch version in all 3 files and add a CHANGELOG.md entry
- A PreToolUse hook on Bash will block pushes if the latest commit is not a version bump
- CHANGELOG.md follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format
- Use semantic versioning: patch for fixes, minor for features, major for breaking changes

## Adding a Phase

1. Add phase to classification table in `skills/director-mode/SKILL.md`
2. Add detection indicators to `commands/director-check.md` Step 4
3. Add action handler to `commands/director-check.md` Step 5
4. Update `commands/director-status.md` to display it
