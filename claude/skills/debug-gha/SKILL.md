---
name: debug-gha
description: >
  Debug GitHub Actions (GHA) workflow run failures. Use when a CI/CD run
  failed, a workflow is broken, steps are erroring, a job was cancelled or
  timed out, or the user wants to investigate what happened in a specific run.
  Covers fetching logs, reading job/step output, and identifying root causes.
---

# Debug GitHub Actions Runs

## What GitHub Actions Is

GitHub Actions is GitHub's CI/CD platform. Workflows are YAML files in `.github/workflows/`. Each workflow:

- Has **triggers** (`on:`) — push, pull_request, schedule, workflow_dispatch, etc.
- Defines **jobs** — parallel or sequential units of work, each running on a runner (e.g. `ubuntu-latest`)
- Each job has **steps** — either shell `run:` commands or reusable `uses:` actions

Conclusion values you'll see: `success`, `failure`, `cancelled`, `skipped`, `timed_out`, `action_required`.

Logs are retained for 90 days by default; older runs will return HTTP 410 when fetching logs.

## Debugging Workflow

**Step 1 — Run the debug script** (always use `uv` to invoke it):

```bash
uv run ~/.claude/skills/debug-gha/scripts/debug-run.py [run-id]
# for a different repo: -R OWNER/REPO
# for full logs:        --log
# auto-selects latest failed run if no run-id given
```

This prints the run metadata, all jobs with their conclusions, any failed steps, and the failed-step logs. If the user isn't asking about the latest failing run, you may need to discover the right run ID first with `gh run list` (supports `--workflow`, `--branch`, `--status`, `--limit`).

**Step 2 — Read the failed step logs.** Look for:
- The actual error message (usually near the bottom of the failing step's output)
- Which step number failed and what it was doing
- Whether it's a flaky network issue, a real code failure, or a misconfigured action

**Step 3 — Look at the workflow YAML** if the logs suggest a configuration issue:

```bash
ls .github/workflows/
# then read the relevant file
```

**Step 4 — Additional targeted commands** when you need more:

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

- [GitHub Actions docs](https://docs.github.com/en/actions) — authoritative reference
- [Workflow syntax reference](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions) — all YAML keys explained
- [Contexts and expressions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/accessing-contextual-information-about-workflow-runs) — `${{ github.* }}`, `env.*`, `secrets.*`, etc.
- [GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners) — what's installed on ubuntu-latest, etc.
- [gh run commands](https://cli.github.com/manual/gh_run) — full `gh run` CLI reference

## Fixes

*(Document fixes here when specific failure patterns and solutions are found.)*
