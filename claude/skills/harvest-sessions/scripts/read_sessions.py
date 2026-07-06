#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Extract high-signal conversation from Claude Code session transcripts.

Claude Code stores each session as a `.jsonl` file under
`~/.claude/projects/<encoded-path>/`, where `<encoded-path>` is the project's
absolute path with every non-alphanumeric character replaced by `-`
(`/home/jtk/projects/without` -> `-home-jtk-projects-without`).

This walks those transcripts, keeps the conversational text from both roles
(user corrections and assistant insights), labels each by role, strips the noise
that shares the `user` role (tool results, slash-command output, pasted skill and
system content, interrupt markers), de-duplicates, and prints what remains in
conversation order per session. The output is the raw material for mining
conventions, corrections, recurring friction, and insights the assistant
surfaced but never got codified. With `--tools`, it also surfaces each tool call
and any tool errors or denials, so you can see how tools were used and where they
tripped (the raw material for guardrail hooks). Reason over it; don't transcribe it.

Run with uv (the shebang handles this): the script has no third-party deps.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

NOISE_MARKERS = (
    "<command-name>",
    "<command-message>",
    "<command-args>",
    "<local-command-stdout>",
    "<local-command-caveat>",
    "Base directory for this skill:",
    "[Request interrupted",
)


def encode_project(path: Path) -> str:
    return re.sub(r"[^A-Za-z0-9]", "-", str(path))


def find_project_dir(project: Path, base: Path) -> Path:
    exact = base / encode_project(project)
    if exact.is_dir():
        return exact
    suffix = "-" + re.sub(r"[^A-Za-z0-9]", "-", project.name)
    candidates = sorted(
        d for d in base.iterdir() if d.is_dir() and d.name.endswith(suffix)
    )
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        raise SystemExit(
            f"No session directory for {project}.\n"
            f"Looked for {encode_project(project)} under {base}.\n"
            f"Available: {', '.join(sorted(d.name for d in base.iterdir() if d.is_dir()))}"
        )
    raise SystemExit(
        "Ambiguous project match; pass --project with a full path. Candidates:\n"
        + "\n".join(d.name for d in candidates)
    )


def text_of(content: object) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [
            block.get("text", "")
            for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        ]
        return "\n".join(parts)
    return ""


def is_tool_result(content: object) -> bool:
    return isinstance(content, list) and any(
        isinstance(block, dict) and block.get("type") == "tool_result"
        for block in content
    )


def keep_user(text: str) -> bool:
    if text.startswith("<") or text.startswith("Caveat:"):
        return False
    return not any(marker in text for marker in NOISE_MARKERS)


def summarize_tool_use(block: dict) -> str:
    name = block.get("name", "?")
    inp = block.get("input")
    if not isinstance(inp, dict):
        return name
    for key in ("command", "file_path", "path", "query", "pattern", "url"):
        value = inp.get(key)
        if value:
            return f"{name}: {str(value).splitlines()[0]}"
    return name


def result_text(block: dict) -> str:
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            b.get("text", "")
            for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        )
    return ""


ERROR_MARKERS = ("hook error", "denied", "InputValidationError", "tool_use_error")


def is_error_result(block: dict) -> bool:
    if block.get("is_error"):
        return True
    return any(marker in result_text(block) for marker in ERROR_MARKERS)


def session_messages(
    path: Path, roles: set[str], min_len: int, include_tools: bool
) -> list[tuple[str, str]]:
    kept: list[tuple[str, str]] = []
    for line in path.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        role = entry.get("type")
        if role not in roles or entry.get("isMeta"):
            continue
        message = entry.get("message")
        if not isinstance(message, dict):
            continue
        content = message.get("content")
        if role == "user" and is_tool_result(content):
            if include_tools:
                for block in content:
                    if (
                        isinstance(block, dict)
                        and block.get("type") == "tool_result"
                        and is_error_result(block)
                    ):
                        text = result_text(block).strip()
                        if text:
                            kept.append(("error", text))
            continue
        text = text_of(content).strip()
        if len(text) >= min_len and (role != "user" or keep_user(text)):
            kept.append((role, text))
        if include_tools and isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_use":
                    kept.append(("tool", summarize_tool_use(block)))
    return kept


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract high-signal conversation from Claude Code session transcripts.",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=None,
        help="Project path to analyze (default: all projects).",
    )
    parser.add_argument(
        "--sessions",
        type=int,
        default=0,
        help="Only the N most recently modified transcripts (default: 0 = all).",
    )
    parser.add_argument(
        "--tools",
        action="store_true",
        help="Also surface tool calls and tool errors/denials, to learn how tools "
        "were used and where they tripped.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List sessions (id, timestamp, message count, first user message) "
        "instead of dumping their content. Use to assign sessions to subagents.",
    )
    parser.add_argument(
        "--session",
        default=None,
        help="Dump only the session whose id starts with this prefix "
        "(the per-session view a subagent analyzes).",
    )
    parser.add_argument(
        "--min-len",
        type=int,
        default=3,
        help="Drop messages shorter than this many characters (default: 3).",
    )
    parser.add_argument(
        "--max-chars",
        type=int,
        default=4000,
        help="Truncate each printed message to this many characters (default: 4000).",
    )
    parser.add_argument(
        "--projects-dir",
        type=Path,
        default=Path.home() / ".claude" / "projects",
        help="Root of the Claude Code project transcripts.",
    )
    args = parser.parse_args()

    base = args.projects_dir
    if args.project is not None:
        dirs = [find_project_dir(args.project.resolve(), base)]
    else:
        dirs = sorted(
            d for d in base.iterdir() if d.is_dir() and any(d.glob("*.jsonl"))
        )
        if not dirs:
            raise SystemExit(f"No project transcripts under {base}.")
    multi = len(dirs) > 1

    transcripts = sorted(
        ((d.name, p) for d in dirs for p in d.glob("*.jsonl")),
        key=lambda item: item[1].stat().st_mtime,
        reverse=True,
    )
    if args.session:
        transcripts = [t for t in transcripts if t[1].stem.startswith(args.session)]
        if not transcripts:
            raise SystemExit(f"No session matching '{args.session}'.")
    elif args.sessions > 0:
        transcripts = transcripts[: args.sessions]

    if args.list:
        for label, transcript in transcripts:
            messages = session_messages(
                transcript, {"user", "assistant"}, args.min_len, False
            )
            first_user = next((text for role, text in messages if role == "user"), "")
            snippet = " ".join(first_user.split())[:80]
            when = datetime.fromtimestamp(transcript.stat().st_mtime).strftime(
                "%Y-%m-%d %H:%M"
            )
            prefix = f"{label}  " if multi else ""
            print(
                f"{prefix}{transcript.stem[:8]}  {when}  {len(messages):4d} msgs  {snippet}"
            )
        return 0

    roles = {"user", "assistant"}
    seen: set[tuple[str, str]] = set()
    total = 0
    for label, transcript in transcripts:
        tag = f"{label} | " if multi else ""
        session_id = transcript.stem[:8]
        for role, text in session_messages(transcript, roles, args.min_len, args.tools):
            total += 1
            key = (role, text[:200])
            if key in seen:
                continue
            seen.add(key)
            print(f"\n=== [{tag}{session_id} | {role} | {len(text)} chars] ===")
            print(text[: args.max_chars])

    print(
        f"\n\n{len(transcripts)} transcripts | {total} messages | {len(seen)} unique",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
