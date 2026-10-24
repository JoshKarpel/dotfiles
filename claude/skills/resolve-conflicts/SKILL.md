---
name: resolve-conflicts
description: >
  Bring a branch up to date with the branch it merges into (find the target,
  fetch, merge) and resolve git conflicts by working out what each side meant.
  MUST be invoked whenever git reports conflicts, from a merge, rebase,
  cherry-pick, revert, or stash pop, before editing any conflicted file. MUST
  also be invoked when asked to update, sync, or catch a branch up with main or
  its base, to merge the base branch in, or to fix a PR that "has conflicts that
  must be resolved".
argument-hint: "[target-branch]"
---

# Resolve Conflicts

Two situations lead here: a conflict is already in progress, or the branch needs
updating from its merge target. Check `git status` to see which.

- A merge, rebase, cherry-pick, or revert in progress: go straight to
  [Resolve each conflict](#resolve-each-conflict).
- Nothing in progress: [update the branch](#update-the-branch) first.

## Update the Branch

Merge, never rebase, unless I ask for a rebase: the branch may already be pushed
and reviewed.

Stop and tell me if there are uncommitted changes to tracked files. A merge on
top of them makes the resolution impossible to separate from the work in
progress.

### Find the merge target

Take the first that applies, and say which one decided it:

1. A target given explicitly, as an argument (`$ARGUMENTS`) or in the request.
2. The base of this branch's open PR: `gh pr view --json baseRefName,isCrossRepository`.
   For a stacked PR this is the parent branch, not the default branch.
3. The repository's default branch: `gh repo view --json defaultBranchRef`.

With no PR, check the branch point before trusting the default branch:
`git log --oneline --decorate origin/<default>..HEAD` showing another branch's
tip partway down means this branch is stacked on it. Ask me which to merge
rather than guessing.

The remote is the one pointing at the target's repository: usually `origin`, but
in a fork (`isCrossRepository` is true) it's the remote for the parent
repository, typically `upstream`. Check `git remote -v` rather than assuming.

### Fetch and merge

```bash
git fetch <remote>
git merge <remote>/<target>
```

Merge the remote-tracking ref, not a local branch of the same name, which may be
stale.

## Resolve Each Conflict

`git diff --name-only --diff-filter=U` lists the conflicted files. For each one,
work out what each side was trying to do before editing anything. The hunks
carry the base version too (zdiff3). For a merge,
`git log --oneline HEAD...MERGE_HEAD -- <file>` names the commits on either side
that touched it; in a rebase or cherry-pick, `git show REBASE_HEAD` or
`git show CHERRY_PICK_HEAD` is the commit being replayed. Read those commits when
the intent isn't obvious from the hunk.

During a rebase the sides swap: `HEAD` ("ours") is the branch being rebased
onto, and "theirs" is the commit being replayed.

- Both changes apply (the usual case): keep both, combined so each still does
  what its commit meant. A rename on one side and a new caller on the other means
  the new caller uses the new name.
- Lockfiles: never hand-merge. Take the target's version, then regenerate it
  with the project's tool (`uv lock`, `cargo update -w`, `npm install`, etc.) so
  it reflects this branch's manifest changes too.
- Generated files: take either side and regenerate from source.
- Genuinely incompatible changes to the same behavior, where picking one
  means discarding the other's intent: stop and ask me, showing both sides and
  what each commit was for. Don't pick a winner.

Never resolve a file wholesale with `--ours` or `--theirs` when both sides made
real changes to it.

Stage each file as it's resolved, then confirm nothing is left:
`git diff --name-only --diff-filter=U` is empty and `git diff --cached --check`
reports no leftover conflict markers.

## Check the Result

A clean textual merge can still be broken: a function renamed on one side and
called by its old name in code the other side added. This applies just as much
when git reported no conflicts at all, which is where it goes unchecked. Run the
project's checks (build, type checker, tests, and its pre-commit hooks if it has
them) and fix what the merge broke, staging the fixes. Fix only breakage the
merge caused; report pre-existing failures rather than fixing them.

Three gaps the checks don't cover on their own:

- **Pre-commit during a merge sees only the conflicted files**, so a generator
  hook or a linter never runs over everything the merge brought in. Run it over
  the whole merge instead:
  `git diff --name-only -z HEAD...MERGE_HEAD | xargs -0 pre-commit run --files`
  (or against the target ref once the merge is committed).
- **Callers the other side added.** Where either side changed a signature,
  grep for every call site on the other side, including tests, examples,
  benchmarks, and docs snippets the type checker never sees.
- **Prose that describes the other side's code.** Docs, plans, `CLAUDE.md`, and
  changelog entries name functions, modules, and behavior that the merge may
  have renamed, made private, or made false. Grep the identifiers they name
  against the merged tree, and re-run any probes a plan embeds. A branch that
  only changes a plan still needs this: "only a doc changed" is the wrong
  inference when the doc describes code that just moved under it.

## Hand Off

Report:

- the target and what decided it, when this was a branch update,
- each conflicted file and how it was resolved, calling out any judgment call,
- anything else changed to fix the merge, and the check results.

If the operation is still in progress, end with the commands to finish or back
out of it: `git commit --no-edit` or `git merge --abort` for a merge,
`git rebase --continue` or `git rebase --abort` for a rebase, and likewise for a
cherry-pick or revert.
