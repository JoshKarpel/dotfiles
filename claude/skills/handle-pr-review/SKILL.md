---
name: handle-pr-review
description: Fetch and address GitHub PR review comments and feedback on the current branch. Use when asked to handle review comments, address reviewer feedback, fix review threads, check what reviewers said, work through unresolved comments, or respond to PR review requests. Also use when the user says "review comments", "PR feedback", or "address comments".
---

# Handle PR Review Comments

Fetch PR review data and address reviewer feedback locally in the code. **Never write back to GitHub** — no `gh pr comment`, no `gh pr review`, no posting replies. All work happens in local files only.

## Fetching Review Data

```bash
claude/skills/handle-pr-review/scripts/fetch-pr-comments.py
claude/skills/handle-pr-review/scripts/fetch-pr-comments.py --unresolved-only
claude/skills/handle-pr-review/scripts/fetch-pr-comments.py --no-diff
claude/skills/handle-pr-review/scripts/fetch-pr-comments.py --number 42
```

The script is directly executable (uses `uv run` via shebang). It auto-detects the PR from the current branch. Use `--number` to override. Use `--unresolved-only` to focus on threads that still need attention. Use `--no-diff` to skip the diff (saves context when you only need comments).

## Workflow

1. **Fetch** the review data using the script above (start with `--unresolved-only` unless the user wants everything)
2. **Triage** the threads:
   - If multiple threads share a pattern (e.g., "add type annotations", "use consistent naming"), group them and address as a batch
   - Otherwise, work through threads one by one
3. **For each thread or group**:
   - Read the reviewer's comment carefully
   - Read the referenced file and surrounding context
   - Make the code change that addresses the feedback
   - If the reviewer's intent is unclear or you disagree with the suggestion, **ask the user** — don't guess
4. **Summarize** what was done at the end: list each thread and what change was made (or why it was skipped)
