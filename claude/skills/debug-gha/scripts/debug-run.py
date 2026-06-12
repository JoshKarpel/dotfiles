#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""Fetch GitHub Actions run summary and failed logs for debugging."""

import argparse
import json
import subprocess
import sys


def gh(*args: str, repo: str | None = None, allow_failure: bool = False) -> str:
    cmd = ["gh", *args]
    if repo:
        cmd.extend(["-R", repo])
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        if allow_failure:
            return f"(error fetching logs: {result.stderr.strip()})"
        print(f"gh error: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    return result.stdout


def gh_json(*args: str, repo: str | None = None) -> dict | list:
    return json.loads(gh(*args, repo=repo))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_id", nargs="?", help="Run ID (default: latest non-success run)")
    parser.add_argument("-R", "--repo", help="Repo in OWNER/REPO format (default: current repo)")
    parser.add_argument("--log", action="store_true", help="Show full logs instead of failed-only")
    parser.add_argument("--workflow", help="Filter by workflow name when auto-selecting run")
    parser.add_argument("--branch", help="Branch to filter runs by (default: current branch)")
    args = parser.parse_args()

    repo = args.repo

    if args.run_id:
        run_id = args.run_id
    else:
        if args.branch:
            branch = args.branch
        else:
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                capture_output=True, text=True,
            )
            branch = result.stdout.strip() if result.returncode == 0 else None

        list_args = ["run", "list", "--status", "failure", "--limit", "1",
                     "--json", "databaseId,workflowName,displayTitle,headBranch,createdAt"]
        if branch:
            list_args += ["--branch", branch]
        if args.workflow:
            list_args += ["--workflow", args.workflow]
        runs = gh_json(*list_args, repo=repo)
        if not runs:
            print("No failed runs found.")
            sys.exit(0)
        r = runs[0]
        run_id = str(r["databaseId"])
        print(f"Latest failed run: {run_id} - {r['displayTitle']} ({r['workflowName']})\n")

    run = gh_json(
        "run", "view", run_id,
        "--json", "attempt,conclusion,status,workflowName,displayTitle,headBranch,jobs,url",
        repo=repo,
    )

    print(f"Run:      {run['displayTitle']} [{run_id}]")
    print(f"Workflow: {run['workflowName']}")
    print(f"Branch:   {run['headBranch']}")
    print(f"Status:   {run['status']} / {run['conclusion']}")
    print(f"URL:      {run['url']}")
    print()

    ICON = {"success": "✓", "skipped": "○", "cancelled": "○"}
    print("Jobs:")
    for job in run.get("jobs", []):
        icon = ICON.get(job["conclusion"], "✗")
        print(f"  {icon} {job['name']} (ID {job['databaseId']}) - {job['conclusion']}")
        for step in job.get("steps", []):
            if step["conclusion"] not in ("success", "skipped"):
                print(f"      ✗ step {step['number']}: {step['name']} - {step['conclusion']}")
    print()

    if args.log:
        print("=== Full Logs ===")
        print(gh("run", "view", run_id, "--log", repo=repo, allow_failure=True))
    else:
        print("=== Failed Step Logs ===")
        logs = gh("run", "view", run_id, "--log-failed", repo=repo, allow_failure=True)
        if logs.strip():
            print(logs)
        else:
            print("(no failed step logs; run may have been cancelled or timed out without step failures)")
        print()
        print("Tips:")
        print("  --log                        full logs for this run")
        print("  gh run view --job <id> --log  logs for one specific job")
        print("  gh run view <run-id> --web   open in browser")
        print("  gh run rerun <run-id> --failed  re-run only failed jobs")


if __name__ == "__main__":
    main()
