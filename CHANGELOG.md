# Changelog

All notable changes to the director-mode plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/).

## [0.2.5] - 2026-04-08

### Fixed

- Registered guard hook statically in `hooks/hooks.json` instead of dynamically via `settings.local.json`. The empty `"hooks": {}` record failed Claude Code's Zod schema validation. Removed ~50 lines of dynamic install/cleanup machinery.

### Removed

- Dynamic hook installation from `setup-director.sh` (jq writes to `settings.local.json`)
- Dynamic hook cleanup from `cleanup-director.sh` (now a no-op stub)
- `cleanup-director.sh` call from `director-stop.md` Step 5

## [0.2.4] - 2026-04-08

### Fixed

- Added missing `hooks` record to `hooks/hooks.json`. Claude Code requires this key even when hooks are installed dynamically; its absence caused a plugin load error.

### Changed

- Added `marketing/` to `.gitignore`

## [0.2.3] - 2026-04-07

### Fixed

- Converted version-bump PreToolUse hook from prompt-type to command-type. Prompt hooks cannot run `git log` to verify commit state, causing every `git push` to be blocked. New command hook (`scripts/check-version-bump.sh`) runs actual shell logic.

## [0.2.2] - 2026-04-07

### Fixed

- Guard hook and setup script no longer depend on `CLAUDE_PLUGIN_ROOT` env var, which is unavailable at hook runtime. Both now derive the plugin root from the script's own filesystem location (`$0`). Fixes the guard blocking its own scripts (`send-to-worker.sh`, `capture-worker.sh`, `update-subtask-status.sh`).

## [0.2.1] - 2026-04-07

### Fixed

- Moved version-bump PreToolUse hook from plugin `hooks.json` (ships to users) to project `.claude/settings.json` (dev workflow only)
- Cleaned up `hooks.json` to only contain the description (guard is dynamic)

## [0.2.0] - 2026-04-07

### Breaking

- State file moved from `~/.claude/director-mode.local.md` to `./director-mode.local.md` (CWD). Existing state files in `~/.claude/` are no longer recognized.

### Added

- **Requirements gathering** (Step 3.75 in director-start): reads project context, identifies ambiguities, batches all questions upfront, compiles a task brief before sending to worker. Prevents stalling while user is away.
- **Dynamic hook installation**: guard hook is now installed into `.claude/settings.local.json` only when director mode is active. Zero overhead when inactive.
- **Visual session rename**: director session shows "DIRECTOR" and worker shows "WORKER" in Claude Code's status line via `/rename`.
- `scripts/cleanup-director.sh` — removes guard hook from project settings on stop.
- `references/task-sequencing.md` — extracted detailed sequencing docs from SKILL.md.
- `.gitignore` for `*.local.md` and `.DS_Store`.
- SKILL.md trigger phrases: "delegate to the other session", "multi-session", "send this to the other claude", "supervise the worker".
- References section in SKILL.md listing all available reference files.

### Fixed

- State file no longer in `~/.claude/` — avoids Anthropic's sensitive-file permission dialogs that blocked worker operations.
- Guard hook now uses tmux window name matching instead of session_id — worker and third-party sessions are never blocked.
- Agent frontmatter: `tools:` corrected to `allowed-tools:` in decision-maker.md.
- Removed no-op sed line in update-subtask-status.sh.
- TASK variable sanitized (double quotes escaped) before writing to YAML frontmatter.

### Changed

- `hooks.json` emptied — guard is installed dynamically, not statically.
- SKILL.md slimmed down — task sequencing details moved to reference file.

## [0.1.0] - 2026-04-06

### Added

- Initial release: director mode plugin for Claude Code.
- Core director loop with phase classification (IDLE, PLANNING, ASKING, IMPLEMENTING, DONE, ERROR, PERMISSION_PROMPT).
- Decision-maker subagent for answering worker questions autonomously.
- Task sequencing for complex multi-step tasks with `/clear` between sub-tasks.
- Guard hook preventing director from directly accessing project files.
- Tmux-based communication via send-to-worker.sh and capture-worker.sh.
