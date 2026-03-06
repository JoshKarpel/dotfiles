---
name: handle-pr-review
description: Fetch and address GitHub PR review comments and feedback on the current branch. Use when asked to handle review comments, address reviewer feedback, fix review threads, check what reviewers said, work through unresolved comments, or respond to PR review requests. Also use when the user says "review comments", "PR feedback", or "address comments".
---

# Handle PR Review Comments

Fetch PR review data and address reviewer feedback locally in the code. **Never write back to GitHub** — no `gh pr comment`, no `gh pr review`, no posting replies. All work happens in local files only.

## Workflow

File reads during fixing are the main source of context growth — keep those in subagents. Fetch and triage happen here in the main context.

### Step 1: Fetch

Run the fetch script directly:

```bash
~/.claude/skills/handle-pr-review/scripts/fetch-pr-comments.py --no-diff --unresolved-only
# or, to specify a PR:
~/.claude/skills/handle-pr-review/scripts/fetch-pr-comments.py --no-diff --unresolved-only --number 42
```

If diff context is needed to understand a specific thread, fetch it in a subagent for that thread only (see step 3).

### Step 2: Triage

With the compact list in hand:
- Group threads that share a pattern (e.g. "add type annotations everywhere", "consistent naming") — they'll be handled in one fix subagent
- Flag any threads where the reviewer's intent is unclear — **ask the user** before proceeding, don't guess
- For ≤3 simple, independent threads you may work inline instead of spawning fix subagents

### Step 3: Fix subagents

For each thread or group, spawn a subagent with a self-contained task:

> Address this PR review thread:
> - File: `path/to/file.py`, line N
> - Reviewer's comment: "<paste full comment text here>"
>
> Read the file, understand the context, make the change that addresses the feedback, and return one sentence describing exactly what you changed. If the change affects other files (e.g. a renamed symbol), handle those too.

Spawn independent threads in parallel. For groups, give the subagent all threads in the group at once.

### Step 4: Summarize

After all fix subagents complete, list each thread and what was done (or why it was skipped).
