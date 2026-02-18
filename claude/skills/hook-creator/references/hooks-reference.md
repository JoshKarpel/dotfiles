# Claude Code Hooks Reference

Full technical reference for all hook events and their JSON input schemas.

## Common Fields (All Events)

```json
{
  "session_id": "abc123",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "cwd": "/home/user/my-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse"
}
```

`permission_mode` values: `"default"`, `"plan"`, `"acceptEdits"`, `"dontAsk"`, `"bypassPermissions"`

## Event Types

### SessionStart
Fires when a session begins or resumes. Supports matchers on `source`.

```json
{
  "hook_event_name": "SessionStart",
  "source": "startup"
}
```

`source` values: `"startup"`, `"resume"`, `"clear"`, `"compact"`

**stdout behavior**: Plain-text stdout (exit 0) is added to Claude's context. Also accepts `hookSpecificOutput.additionalContext`.

**Special**: `$CLAUDE_ENV_FILE` env var is only available to SessionStart hooks. Write `export VAR=value` lines to persist env vars for all subsequent Bash calls in the session. Use `>>` (append) to avoid overwriting other hooks.

---

### UserPromptSubmit
Fires when user submits a prompt, before Claude processes it. Does NOT support matcher.

```json
{
  "hook_event_name": "UserPromptSubmit",
  "prompt": "Write a function to calculate factorial"
}
```

Exit 2 blocks prompt processing and erases the prompt. Plain-text stdout (exit 0) is added as context Claude sees.

---

### PreToolUse
Fires before a tool call executes. Supports matchers on tool name.

```json
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_use_id": "toolu_01ABC123...",
  "tool_input": { ... }
}
```

`tool_input` schemas by tool:
- **Bash**: `command` (string), `description` (string?), `timeout` (number ms?), `run_in_background` (boolean?)
- **Write**: `file_path` (string), `content` (string)
- **Edit**: `file_path` (string), `old_string` (string), `new_string` (string), `replace_all` (boolean?)
- **Read**: `file_path` (string), `offset` (number?), `limit` (number?)
- **Glob**: `pattern` (string), `path` (string?)
- **Grep**: `pattern` (string), `path` (string?), `glob` (string?), `output_mode` (string?), `-i` (boolean?), `multiline` (boolean?)
- **WebFetch**: `url` (string), `prompt` (string)
- **WebSearch**: `query` (string), `allowed_domains` (array?), `blocked_domains` (array?)
- **Task**: `prompt` (string), `description` (string), `subagent_type` (string), `model` (string?)

MCP tools: `tool_name` follows pattern `mcp__<server>__<tool>`.

**JSON output** (exit 0): Use `hookSpecificOutput` to control permission decision:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Shown to user for allow/ask; shown to Claude for deny",
    "updatedInput": { "command": "modified command" },
    "additionalContext": "Context injected for Claude before tool runs"
  }
}
```
`permissionDecision`: `"allow"` (bypass permission system), `"deny"` (block), `"ask"` (show user dialog).

---

### PermissionRequest
Fires when a permission dialog appears. Supports matchers on tool name.

```json
{
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf node_modules" },
  "permission_suggestions": [
    { "type": "toolAlwaysAllow", "tool": "Bash" }
  ]
}
```

**JSON output**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": { "command": "modified" }
    }
  }
}
```
For deny: `"behavior": "deny"`, add `"message"` (tells Claude why), optionally `"interrupt": true`.

---

### PostToolUse
Fires after a tool call succeeds. Supports matchers on tool name. Cannot block (tool already ran).

```json
{
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_use_id": "toolu_01ABC123...",
  "tool_input": { "file_path": "/path/file.txt", "content": "..." },
  "tool_response": { "filePath": "/path/file.txt", "success": true }
}
```

Exit 2 shows stderr to Claude (but doesn't undo the tool call).

---

### PostToolUseFailure
Fires after a tool call fails. Supports matchers on tool name.

```json
{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_use_id": "toolu_01ABC123...",
  "tool_input": { "command": "npm test" },
  "error": "Command exited with non-zero status code 1",
  "is_interrupt": false
}
```

---

### Notification
Fires when Claude Code sends a notification. Supports matchers on `notification_type`. Cannot block.

```json
{
  "hook_event_name": "Notification",
  "message": "Claude needs your permission to use Bash",
  "title": "Permission needed",
  "notification_type": "permission_prompt"
}
```

`notification_type` values: `"permission_prompt"`, `"idle_prompt"`, `"auth_success"`, `"elicitation_dialog"`

Exit 2 shows stderr to user only (not Claude).

---

### SubagentStart
Fires when a subagent is spawned. Supports matchers on `agent_type`. Cannot block.

```json
{
  "hook_event_name": "SubagentStart",
  "agent_id": "agent-abc123",
  "agent_type": "Explore"
}
```

---

### SubagentStop
Fires when a subagent finishes. Supports matchers on `agent_type`. Supports `stop_hook_active`.

```json
{
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "def456",
  "agent_type": "Explore",
  "agent_transcript_path": "~/.claude/projects/.../subagents/agent-def456.jsonl"
}
```

---

### Stop
Fires when Claude finishes responding. Does NOT support matcher. Supports `stop_hook_active`.

```json
{
  "hook_event_name": "Stop",
  "stop_hook_active": true
}
```

Exit 2 prevents Claude from stopping and feeds stderr back to Claude. **Always guard with `stop_hook_active`.**

---

### TeammateIdle
Fires when a team agent is about to go idle. Does NOT support matcher. Only supports `type: "command"`.

```json
{
  "hook_event_name": "TeammateIdle",
  "teammate_name": "researcher",
  "team_name": "my-project"
}
```

---

### TaskCompleted
Fires when a task is being marked completed. Does NOT support matcher.

```json
{
  "hook_event_name": "TaskCompleted",
  "task_id": "task-001",
  "task_subject": "Implement user authentication",
  "task_description": "Add login and signup endpoints",
  "teammate_name": "implementer",
  "team_name": "my-project"
}
```

---

### PreCompact
Fires before context compaction. Supports matchers on `trigger`.

```json
{
  "hook_event_name": "PreCompact",
  "trigger": "manual",
  "custom_instructions": ""
}
```

`trigger` values: `"manual"`, `"auto"`

---

### SessionEnd
Fires when a session terminates. Supports matchers on `reason`. Cannot block.

```json
{
  "hook_event_name": "SessionEnd",
  "reason": "other"
}
```

`reason` values: `"clear"`, `"logout"`, `"prompt_input_exit"`, `"bypass_permissions_disabled"`, `"other"`

---

## Universal JSON Output Fields (exit 0, stdout)

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | If `false`, stops Claude entirely after the hook. `stopReason` shown to user (not Claude). |
| `stopReason` | — | Shown to user when `continue: false`. |
| `suppressOutput` | `false` | If `true`, hides stdout from verbose mode. |
| `systemMessage` | — | Warning message shown to the user. |

## Matcher Reference

| Event | Matches on | Example values |
|-------|-----------|----------------|
| PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest | tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| SessionStart | `source` | `startup`, `resume`, `clear`, `compact` |
| SessionEnd | `reason` | `clear`, `logout`, `other` |
| Notification | `notification_type` | `permission_prompt`, `idle_prompt` |
| SubagentStart, SubagentStop | `agent_type` | `Bash`, `Explore`, `Plan` |
| PreCompact | `trigger` | `manual`, `auto` |

Omit matcher, use `""`, or use `"*"` to match all.

## Hook Handler Types

- `type: "command"` — Shell script (default). Timeout: 600s.
- `type: "prompt"` — Single LLM call. Returns `{"ok": true/false, "reason": "..."}`. Timeout: 30s.
- `type: "agent"` — Subagent with tool access, up to 50 turns. Same response schema as prompt. Timeout: 60s.
- `"async": true` — Only for `type: "command"`. Runs in background, cannot block, delivers output on next turn.

`TeammateIdle` only supports `type: "command"`.
