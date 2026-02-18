---
name: hook-creator
description: Guide for designing and writing Claude Code hooks. Use when creating a new hook, adding hooks to settings.json, debugging hook behavior, understanding what hook events are available and what JSON they receive, or implementing patterns like behavior correction, pre-stop checklists, context injection, side effects, and permission control.
---

# Claude Code Hooks

Hooks are shell scripts (or prompt/agent handlers) that fire at lifecycle events in a Claude Code session. They let you enforce behavior, inject context, play sounds, run side effects, and more.

The full event/schema reference is in [references/hooks-reference.md](references/hooks-reference.md). Read it before writing a new hook.

## When to Write a Hook

- **Claude keeps making a specific mistake** → PreToolUse behavior correction
- **You want a checklist before Claude finishes** → Stop with exit 2
- **Claude doesn't know about project tooling** → SessionStart context injection
- **You want audio/visual feedback** → Notification or Stop side effect
- **You want to gate a destructive action** → PreToolUse permission control
- **You want to inject per-project env vars** → SessionStart writing to `$CLAUDE_ENV_FILE`

## Where to Put Hooks

### Global (Personal) Hooks

Hooks that apply across all projects — personal workflow preferences, reminders, sounds — belong in the global config and should travel with your dotfiles.

- **Config**: `~/.claude/settings.json` (in this repo: `dotfiles/claude/settings.json`, synced by `install.sh`)
- **Scripts**: `dotfiles/bin/` — already on PATH, available everywhere, shared across machines, write in bash for maximum portability

### Project-Local Hooks

Hooks specific to a project's workflow — enforcing project conventions, injecting repo-specific context — belong in the repo so the whole team gets them.

- **Config**: `.claude/settings.json` at the project root (check this into version control)
- **Scripts**: potentially anywhere in the repo, but reference them via `$CLAUDE_PROJECT_DIR` so the path works regardless of cwd:

```json
{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/my-hook.sh" }
```

A `.claude/hooks/` directory is a reasonable convention for project-local hook scripts.

**Rule of thumb**: if you'd want the hook on a fresh machine or in a new project, it's global. If it only makes sense inside one repo, it's project-local.

## Hook Mechanics

### Exit Codes — the Core API

| Exit | Meaning |
|------|---------|
| `0` | Success. stdout is parsed for JSON output. |
| `2` | **Blocking**: for events that support it (PreToolUse, Stop, UserPromptSubmit, etc.), blocks the action and feeds **stderr** back to Claude. stdout is ignored. |
| Other non-zero | Non-blocking error; stderr only shown in verbose mode (Ctrl+O). |

### stdout vs stderr

- **stderr** is what Claude (or the user) sees on exit 2. Write human-readable guidance here.
- **stdout** on exit 0 is parsed for JSON. For `SessionStart` and `UserPromptSubmit`, plain-text stdout is added as context Claude can see.
- Shell profile startup text can corrupt JSON stdout — scripts must be clean.

### stop_hook_active — Loop Prevention

`Stop` and `SubagentStop` events include `"stop_hook_active": true/false`. When `true`, Claude is already continuing because a previous Stop hook blocked it. **Always check this field and exit 0 when it's true**, or you'll create an infinite loop.

```bash
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0
```

## Patterns

### 1. Behavior Correction (PreToolUse)

Block a tool call and tell Claude to do it differently. Fires before the tool runs, so you can catch it. Exit 2 sends stderr to Claude; it then reconsiders.

Example: `claude-head-tail-check` — blocks `head`/`tail` usage:
```bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if echo "$COMMAND" | grep -qE '\b(head|tail)\b'; then
  echo "Redirect full output to a file instead of using head/tail." >&2
  exit 2
fi
exit 0
```

Example: `claude-uv-check` — blocks bare `python` in uv projects:
```bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if echo "$COMMAND" | grep -q 'python' && ! echo "$COMMAND" | grep -q 'uv'; then
  echo "Use 'uv run python' instead of 'python' directly." >&2
  exit 2
fi
exit 0
```

Use the `matcher` field in settings.json to scope to specific tools:
```json
{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "my-hook" }] }
```

### 2. Pre-Stop Checklist (Stop)

Block Claude from stopping and give it a checklist. Must guard against `stop_hook_active`.

Example: `claude-followup-check`:
```bash
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0

cat >&2 <<'EOF'
Before stopping: run tests, update docs, stage changes.
EOF
exit 2
```

### 3. Context Injection (SessionStart)

Print text to **stdout** (exit 0) and Claude sees it as context for the session. Plain text works — no JSON needed.

Example: `claude-just-list` — lists available just recipes:
```bash
INPUT=$(cat)
JUST_OUTPUT=$(just --list --list-prefix='' --no-aliases 2>/dev/null) || exit 0
cat <<EOF
This project has a justfile. Prefer using just recipes:

$JUST_OUTPUT
EOF
```

For context injection, `hookSpecificOutput.additionalContext` is the JSON alternative, but plain stdout works fine for `SessionStart`.

### 4. Side Effects / Async (Stop, Notification)

For fire-and-forget work (playing sounds, logging, updating displays) use async hooks or just exit 0 after doing the work synchronously. Async hooks won't block Claude:

```json
{ "type": "command", "command": "my-hook", "async": true }
```

Example: `claude-sound stop` — plays a sound but only when `stop_hook_active` is true (meaning all blocking hooks have already cleared):
```bash
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" != "true" ]] && exit 0
paplay /usr/share/sounds/freedesktop/stereo/complete.oga
```

### 5. Permission Control (PreToolUse JSON output)

Instead of exit 2, return a JSON decision from stdout to allow/deny/ask:
```bash
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "Use the project makefile instead."}}'
exit 0
```

`permissionDecision` values: `"allow"`, `"deny"`, `"ask"`.

## settings.json Structure

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "my-hook" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "my-stop-hook" },
          { "type": "command", "command": "my-sound-hook", "async": true }
        ]
      }
    ]
  }
}
```

All matching hooks in a group run in **parallel**.

## Hook Script Boilerplate

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
# Parse what you need:
# COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
# CWD=$(echo "$INPUT" | jq -r '.cwd')

# ... logic ...

exit 0
```
