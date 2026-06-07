---
name: hook-creator
description: >
  Guide for designing and writing Claude Code hooks. Use when creating a new
  hook, adding hooks to settings.json, debugging hook behavior, understanding
  what hook events are available and what JSON they receive, or implementing
  patterns like behavior correction, pre-stop checklists, context injection,
  side effects, and permission control.
---

# Claude Code Hooks

Hooks are shell scripts (or prompt/agent handlers) that fire at lifecycle events
in a Claude Code session. They let you enforce behavior, inject context, play
sounds, run side effects, and more.

**Fetch the [upstream reference](https://docs.claude.ai/en/docs/claude-code/hooks)
before writing or modifying any hooks.**

Do not rely on memory for event types, JSON schemas, exit code semantics,
`stop_hook_active`, `async`, permission decision format, `$CLAUDE_ENV_FILE`, or
`settings.json` structure: always fetch first.

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
- **Scripts**: reference via `$CLAUDE_PROJECT_DIR` so the path works regardless of cwd:

```json
{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/my-hook.sh" }
```

**Rule of thumb**: if you'd want the hook on a fresh machine or in a new project, it's global. If it only makes sense inside one repo, it's project-local.

## Hook Mechanics

### Exit Codes — the Core API

| Exit | Meaning |
|------|---------|
| `0` | Success. stdout parsed for JSON or used as plain-text context (SessionStart, UserPromptSubmit). |
| `2` | **Blocking**: prevents the action and feeds **stderr** back to Claude. |
| Other non-zero | Non-blocking error; first line of stderr shown in verbose mode only. |

**Always send exit 2 messages to stderr via heredoc:**

```bash
cat >&2 <<EOF
Something is still failing. Fix the issues before proceeding:

$DETAILS
EOF
exit 2
```

### stop_hook_active — Loop Prevention

`Stop` and `SubagentStop` events include `"stop_hook_active": true/false`. When
`true`, Claude is already continuing because a previous Stop hook blocked it.
**Always check this field and exit 0 when it's true**, or you'll create an
infinite loop.

```bash
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0
```

### Hooks in a Group Run in Parallel

All hooks within a single `hooks: [...]` array fire at the same time; ordering
is not guaranteed. If one hook must run before another, combine them into a
single script.

## Patterns

### 1. Behavior Correction (PreToolUse)

Block a tool call and tell Claude to do it differently. Exit 2 sends stderr to Claude; it then reconsiders.

Example: `claude-uv-check` — blocks bare `python` in uv projects:
```bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if ! is-uv-project; then
  exit 0
fi
if echo "$COMMAND" | grep -q 'python' && ! echo "$COMMAND" | grep -q 'uv'; then
  echo "Use 'uv run python' instead of 'python' directly." >&2
  exit 2
fi
exit 0
```

Use `matcher` to scope to specific tools:
```json
{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "my-hook" }] }
```

### 2. Pre-Stop Work (Stop)

Do work before Claude stops (staging, linting) and optionally block with
feedback. Must guard against `stop_hook_active`.

Example: `claude-stop-precommit` — stages tracked changes and runs the pre-commit loop:
```bash
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
git add --update  # stage tracked modifications only — not untracked files

[[ -f "$REPO_ROOT/.pre-commit-config.yaml" || -f "$REPO_ROOT/.pre-commit-config.yml" ]] || exit 0

if is-uv-project 2>/dev/null; then
  RUNNER="uv run pre-commit"
elif command -v pre-commit &>/dev/null; then
  RUNNER="pre-commit"
elif command -v uv &>/dev/null; then
  RUNNER="uvx pre-commit"
else
  exit 0
fi

$RUNNER run > /dev/null 2>&1 || true  # first run: auto-fix
git add --update                       # re-stage auto-fixes

if OUTPUT=$($RUNNER run 2>&1); then
  exit 0
fi

cat >&2 <<EOF
pre-commit is still failing after auto-fixing. Fix the issues before committing:

$OUTPUT
EOF
exit 2
```

Key preferences:
- Use `git add --update` not `git add -A`: handle untracked files separately
  with a dedicated hook
- Run pre-commit twice: first run auto-fixes, second run validates

### 3. Context Injection (SessionStart)

Print text to stdout (exit 0) and Claude sees it as context. Bail silently when not applicable.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -f "$REPO_ROOT/some-config" ]] || exit 0

cat <<EOF
Context about this project's tooling...
EOF
```

### 4. Side Effects / Async (Stop, Notification)

For fire-and-forget work use `"async": true`:
```json
{ "type": "command", "command": "my-hook", "async": true }
```

### 5. Permission Control (PreToolUse JSON output)

Return a JSON decision from stdout to allow/deny/ask:
```bash
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "Use the project makefile instead."}}'
exit 0
```

## settings.json Structure

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "my-hook" }]
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

## Hook Script Boilerplate

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
# COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
# CWD=$(echo "$INPUT" | jq -r '.cwd')
# STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

exit 0
```

Hooks run in **non-interactive** subprocesses: shell functions sourced at startup
are not available. Any shared logic must be a standalone executable in `bin/`.
