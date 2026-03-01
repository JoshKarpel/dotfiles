#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# ///
"""Fetch GitHub PR review comments and metadata via GraphQL.

Auto-detects the PR from the current branch. Outputs structured markdown
to stdout for Claude to consume.
"""

import argparse
import json
import subprocess
import sys

GRAPHQL_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      title
      url
      state
      author { login }
      reviewDecision
      additions
      deletions
      changedFiles
      headRefName
      baseRefName
      body
      reviewThreads(first: 100) {
        totalCount
        pageInfo { hasNextPage }
        nodes {
          isResolved
          isOutdated
          path
          line
          resolvedBy { login }
          comments(first: 50) {
            totalCount
            pageInfo { hasNextPage }
            nodes {
              author { login }
              body
              createdAt
              path
              line
            }
          }
        }
      }
      reviews(first: 20) {
        totalCount
        pageInfo { hasNextPage }
        nodes {
          author { login }
          state
          body
          submittedAt
        }
      }
      comments(first: 50) {
        totalCount
        pageInfo { hasNextPage }
        nodes {
          author { login }
          body
          createdAt
        }
      }
    }
  }
}
"""


def run_gh(*args: str) -> str:
    result = subprocess.run(
        ["gh", *args],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error running gh {' '.join(args)}:", file=sys.stderr)
        print(result.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def detect_pr_number() -> int:
    data = json.loads(run_gh("pr", "view", "--json", "number"))
    return data["number"]


def detect_repo() -> tuple[str, str]:
    data = json.loads(run_gh("repo", "view", "--json", "owner,name"))
    return data["owner"]["login"], data["name"]


def fetch_pr_data(owner: str, name: str, number: int) -> dict:
    variables = json.dumps({"owner": owner, "name": name, "number": number})
    raw = run_gh(
        "api", "graphql",
        "-f", f"query={GRAPHQL_QUERY}",
        "-f", f"variables={variables}",
    )
    data = json.loads(raw)
    if "errors" in data:
        for err in data["errors"]:
            print(f"GraphQL error: {err.get('message', err)}", file=sys.stderr)
        sys.exit(1)
    return data["data"]["repository"]["pullRequest"]


def fetch_diff(number: int) -> str:
    return run_gh("pr", "diff", str(number))


def format_truncation_warnings(pr: dict) -> list[str]:
    warnings = []
    for field, label in [
        ("reviewThreads", "review threads"),
        ("reviews", "reviews"),
        ("comments", "general comments"),
    ]:
        section = pr.get(field, {})
        if section.get("pageInfo", {}).get("hasNextPage"):
            total = section.get("totalCount", "?")
            warnings.append(f"- {label}: showing first page of {total} total")
    # Check nested thread comments
    for thread in pr.get("reviewThreads", {}).get("nodes", []):
        comments = thread.get("comments", {})
        if comments.get("pageInfo", {}).get("hasNextPage"):
            path = thread.get("path", "unknown")
            total = comments.get("totalCount", "?")
            warnings.append(
                f"- Thread at {path}: showing first page of {total} comments"
            )
    return warnings


def format_output(pr: dict, diff: str | None, unresolved_only: bool) -> str:
    lines: list[str] = []

    # Header
    lines.append(f"# PR #{pr['url'].split('/')[-1]}: {pr['title']}")
    lines.append("")
    lines.append(f"- **Author**: {pr['author']['login']}")
    lines.append(f"- **State**: {pr['state']}")
    lines.append(f"- **Review decision**: {pr.get('reviewDecision') or 'PENDING'}")
    lines.append(f"- **Branch**: {pr['headRefName']} -> {pr['baseRefName']}")
    lines.append(f"- **URL**: {pr['url']}")
    lines.append(
        f"- **Changes**: +{pr['additions']} -{pr['deletions']} "
        f"across {pr['changedFiles']} files"
    )
    lines.append("")

    # Truncation warnings
    warnings = format_truncation_warnings(pr)
    if warnings:
        lines.append("**Warning: results truncated**")
        lines.extend(warnings)
        lines.append("")

    # Description
    body = (pr.get("body") or "").strip()
    if body:
        lines.append("## Description")
        lines.append("")
        lines.append(body)
        lines.append("")

    # Reviews
    reviews = pr.get("reviews", {}).get("nodes", [])
    reviews_with_body = [r for r in reviews if (r.get("body") or "").strip()]
    if reviews_with_body:
        lines.append("## Reviews")
        lines.append("")
        for review in reviews_with_body:
            author = review["author"]["login"]
            state = review["state"]
            submitted = review.get("submittedAt", "")
            lines.append(f"### {author} — {state} ({submitted})")
            lines.append("")
            lines.append(review["body"].strip())
            lines.append("")

    # Review threads
    threads = pr.get("reviewThreads", {}).get("nodes", [])
    unresolved = [t for t in threads if not t["isResolved"]]
    resolved = [t for t in threads if t["isResolved"]]

    if unresolved_only:
        thread_groups = [("Unresolved Threads", unresolved)]
    else:
        thread_groups = [
            ("Unresolved Threads", unresolved),
            ("Resolved Threads", resolved),
        ]

    for section_title, thread_list in thread_groups:
        if not thread_list:
            continue
        lines.append(f"## {section_title} ({len(thread_list)})")
        lines.append("")
        for i, thread in enumerate(thread_list, 1):
            path = thread.get("path", "unknown")
            line_num = thread.get("line")
            location = f"{path}:{line_num}" if line_num else path
            outdated = " [OUTDATED]" if thread.get("isOutdated") else ""
            resolved_by = ""
            if thread.get("isResolved") and thread.get("resolvedBy"):
                resolved_by = f" (resolved by {thread['resolvedBy']['login']})"

            lines.append(f"### Thread {i}: `{location}`{outdated}{resolved_by}")
            lines.append("")

            comments = thread.get("comments", {}).get("nodes", [])
            for comment in comments:
                author = comment["author"]["login"]
                created = comment.get("createdAt", "")
                lines.append(f"**{author}** ({created}):")
                lines.append("")
                lines.append(comment["body"].strip())
                lines.append("")

    # General comments
    general_comments = pr.get("comments", {}).get("nodes", [])
    if general_comments and not unresolved_only:
        lines.append(f"## General Comments ({len(general_comments)})")
        lines.append("")
        for comment in general_comments:
            author = comment["author"]["login"]
            created = comment.get("createdAt", "")
            lines.append(f"**{author}** ({created}):")
            lines.append("")
            lines.append(comment["body"].strip())
            lines.append("")

    # Diff
    if diff is not None:
        lines.append("## Diff")
        lines.append("")
        lines.append("```diff")
        lines.append(diff)
        lines.append("```")
        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Fetch GitHub PR review comments and metadata."
    )
    parser.add_argument(
        "--number", type=int, default=None,
        help="PR number (auto-detected from current branch if omitted)",
    )
    parser.add_argument(
        "--no-diff", action="store_true",
        help="Skip fetching the PR diff",
    )
    parser.add_argument(
        "--unresolved-only", action="store_true",
        help="Only show unresolved review threads",
    )
    args = parser.parse_args()

    # Detect PR and repo
    number = args.number or detect_pr_number()
    owner, name = detect_repo()

    # Fetch data
    pr = fetch_pr_data(owner, name, number)

    diff = None
    if not args.no_diff:
        diff = fetch_diff(number)

    # Format and print
    output = format_output(pr, diff, args.unresolved_only)
    print(output)


if __name__ == "__main__":
    main()
