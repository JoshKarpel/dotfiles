---
name: debug-gha
description: >
  Debug GitHub Actions (GHA) workflow run failures. MUST be invoked when a CI/CD run
  failed, a workflow is broken, steps are erroring, a job was cancelled or
  timed out, or the user wants to investigate what happened in a specific run.
  Covers fetching logs, reading job/step output, and identifying root causes.
---

# Debug GitHub Actions Runs

## Goal

The objective is to **fix** the failing run. Once you've diagnosed the cause, make
the edits that fix it, and validate them locally where you can — pre-commit, tests,
re-running the failing command — rather than relying on a fresh CI run to tell you
whether it worked.

Leave the change in the working tree for the user to review. Don't commit or push
to trigger a fresh run and "see if it's fixed" — that's the user's call to make.

## What GitHub Actions Is

GitHub Actions is GitHub's CI/CD platform. Workflows are YAML files in
`.github/workflows/`. Each workflow:

- Has **triggers** (`on:`) — push, pull_request, schedule, workflow_dispatch, etc.
- Defines **jobs** — parallel or sequential units of work, each running on a runner (e.g. `ubuntu-latest`)
- Each job has **steps** — either shell `run:` commands or reusable `uses:` actions

Conclusion values you'll see: `success`, `failure`, `cancelled`, `skipped`,
`timed_out`, `action_required`.

## Investigating

A good starting point is the debug script — one command surfaces most of what you
need (always invoke it with `uv`):

```bash
uv run ~/.claude/skills/debug-gha/scripts/debug-run.py [run-id]
# for a different repo: -R OWNER/REPO
# for full logs:        --log
# auto-selects latest failed run if no run-id given
```

It prints the run metadata, all jobs with their conclusions, any failed steps, and
the failed-step logs. If the user isn't asking about the latest failing run, find
the right run ID first with `gh run list` (supports `--workflow`, `--branch`,
`--status`, `--limit`).

From the failed-step logs, look for the actual error message (usually near the
bottom of the output), which step failed and what it was doing, and whether this
looks like a flaky network blip, a real code failure, or a misconfigured action.
If something points at a configuration problem, the workflow YAML lives in
`.github/workflows/`.

Other commands worth reaching for as the situation calls for them:

```bash
# Full log for one specific job (job ID from the script output)
gh run view --job <job-id> --log

# Open run in browser for GitHub's UI (nice for matrix runs)
gh run view <run-id> --web

# Re-run only failed jobs
gh run rerun <run-id> --failed

# Watch a running workflow
gh run watch <run-id>

# View annotations (linter errors, test failures reported inline)
gh api repos/{owner}/{repo}/check-runs/<job-id>/annotations
```

## Key Things to Look For

- **Step that failed**: the step name and number tell you where to look in the YAML
- **Exit code**: non-zero exit codes from shell `run:` steps cause failure
- **Missing secrets/env vars**: often shows as empty values or auth errors
- **Dependency failures**: a job with `needs:` won't run if the upstream job failed; its conclusion will be `skipped`
- **Timeout**: `timed_out` conclusion means the job hit its `timeout-minutes` limit (default 360 min)
- **Flaky vs. real**: check if prior runs of the same workflow passed on the same branch

## Reference Documentation

- [GitHub Actions docs](https://docs.github.com/en/actions): authoritative reference
- [Workflow syntax reference](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions):
  all YAML keys explained
- [Contexts and expressions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/accessing-contextual-information-about-workflow-runs):
  `${{ github.* }}`, `env.*`, `secrets.*`, etc.
- [GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners):
  what's installed on `ubuntu-latest`, etc.
- [gh run commands](https://cli.github.com/manual/gh_run): full `gh run` CLI reference
