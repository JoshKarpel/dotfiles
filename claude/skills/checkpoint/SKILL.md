---
name: checkpoint
description: Distill the current branch's working memory into its journal at branch-journals/<branch>.md — decisions and the why behind them, open questions, dead-ends not to revisit, and next steps, richer than a commit message. MUST be invoked when the user says "checkpoint", "update the journal", "save working memory", or "note this for later". The journal is git-ignored and ephemeral (it dies with the branch); it is resurfaced at session start by the `claude-branch-journal` command.
---

# Checkpoint

Capture the branch's working memory: the reasoning, open threads, and rejected
approaches that won't survive in commit messages or the diff, into a per-branch
journal that a future session reads back at startup.

## Where it goes

`branch-journals/<branch>.md` at the repo root, git-ignored globally and never
committed. Get the exact path with:

```bash
claude-branch-journal path
```

Write with the normal file tools; parent directories are created for you (branch
names with `/` become folders). The file is disposable: it serves the branch and
is discarded when the branch is deleted. Durable knowledge graduates into docs or
the PR description, not here.

## What to write

Read the existing journal first (`claude-branch-journal show`, or read the file), then
**prepend** a new block so the newest state sits at the top. Stamp it with the
commit it follows, for provenance:

```bash
git rev-parse --short HEAD   # the commit this checkpoint follows; "uncommitted" if none yet
```

Block template:

```markdown
## <short-sha> — <one line: what this stretch of work is about>

### State
Where things stand: done, in progress, blocked.

### Decisions
Choices made and *why*. The rationale is the point; it's what the diff can't show.

### Open questions
Unresolved threads to pick up next.

### Dead-ends
Approaches tried and rejected, and why, so they aren't re-explored. Highest-value
section: be specific.

### Next
Concrete next actions.
```

Keep it distilled, not a transcript. Trim or fold older blocks once they're fully
superseded. Omit any section that has nothing real in it.

## Voice

This is a working, discussion-oriented document, so it is exempt from the
reference-doc present-tense rule (see the markdown Tense rule): narrating history,
dead-ends, and "we tried X, it didn't work because Y" is exactly its job.
