# Tmux Patterns for Director Mode

## Sending Commands

Always use `-l` (literal) flag to avoid tmux interpreting special characters:

```bash
# CORRECT: literal text + separate Enter
/opt/homebrew/bin/tmux send-keys -t $TARGET -l -- "your command text here"
/opt/homebrew/bin/tmux send-keys -t $TARGET Enter

# WRONG: semicolons break without -l
/opt/homebrew/bin/tmux send-keys -t $TARGET "SELECT * FROM users;" Enter
```

Characters that break without `-l`: `;` `\` and key names like `Enter`, `Escape`, `C-c`.

## Capturing Output

```bash
# Get last 200 lines, joined wrapped lines, printed to stdout
/opt/homebrew/bin/tmux capture-pane -p -J -t $TARGET -S -200
```

Flags:
- `-p` — print to stdout (instead of paste buffer)
- `-J` — join wrapped lines (prevents mid-word splits)
- `-S -200` — start 200 lines back in scrollback
- `-t $TARGET` — target session:window.pane

## Socket Handling

The `$TMUX` env var format is `/path/to/socket,pid,window`. Extract socket:
```bash
TMUX_SOCKET="${TMUX%%,*}"
/opt/homebrew/bin/tmux -S "$TMUX_SOCKET" <command>
```

## Sending Special Keys

```bash
# Cancel current operation
/opt/homebrew/bin/tmux send-keys -t $TARGET C-c

# Send Escape (e.g., to dismiss prompts)
/opt/homebrew/bin/tmux send-keys -t $TARGET Escape
```

## Waiting for Output

Poll with a capture-pane loop. Look for stable output (same content across two captures ~2s apart) to detect idle state.
