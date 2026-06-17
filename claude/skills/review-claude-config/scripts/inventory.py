# /// script
# requires-python = ">=3.11"
# ///
"""Mechanical inventory and consistency checks for this repo's Claude config.

Operates only on config that lives in this dotfiles repo, the source of truth
that bin/link-claude symlinks into ~/.claude. Anything installed under ~/.claude
that does not come from this repo is out of scope. Reports the cross-cutting
facts that are tedious and error-prone to eyeball by hand: hook/script wiring,
orphaned bin scripts, permission redundancy, and component counts. Makes no
judgments and changes nothing.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Config:
    repo_root: Path
    claude_dir: Path
    bin_dir: Path
    settings_path: Path
    local_settings_path: Path | None


def find_repo_root(start: Path) -> Path:
    for parent in start.resolve().parents:
        if (parent / ".git").is_dir():
            return parent
    raise SystemExit(f"{start} is not inside a git repo")


def resolve_config() -> Config:
    root = find_repo_root(Path(__file__))
    claude_dir = root / "claude"
    local = root / ".claude" / "settings.local.json"
    return Config(
        repo_root=root,
        claude_dir=claude_dir,
        bin_dir=root / "bin",
        settings_path=claude_dir / "settings.json",
        local_settings_path=local if local.exists() else None,
    )


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def hook_commands(settings: dict) -> list[tuple[str, str]]:
    """(event, command) for every configured hook command."""
    out: list[tuple[str, str]] = []
    for event, groups in settings.get("hooks", {}).items():
        for group in groups:
            for hook in group.get("hooks", []):
                cmd = hook.get("command")
                if cmd:
                    out.append((event, cmd))
    return out


def first_token(command: str) -> str:
    return command.strip().split()[0]


def repo_references(config: Config, name: str) -> int:
    """Count tracked files (excluding the script itself) that mention name.

    A bare substring match would let a longer name (claude-stop-precommit)
    inflate a shorter one (claude-stop) and mask a true orphan, so require the
    match not be followed by another name character.
    """
    pattern = re.escape(name) + r"(?![\w-])"
    result = subprocess.run(
        ["git", "-C", str(config.repo_root), "grep", "-lP", pattern],
        capture_output=True,
        text=True,
    )
    files = [f for f in result.stdout.splitlines() if f]
    return sum(1 for f in files if Path(f).name != name)


def report_hooks(config: Config, settings: dict) -> list[str]:
    lines = ["## Hooks", ""]
    for event, command in hook_commands(settings):
        script = config.bin_dir / first_token(command)
        status = "ok (bin/)" if script.exists() else "NOT a bin/ script (external or missing)"
        lines.append(f"- {event}: `{command}` -> {status}")
    lines.append("")
    return lines


def report_orphans(config: Config) -> list[str]:
    lines = ["## bin/ scripts: reference check", ""]
    for name in sorted(p.name for p in config.bin_dir.glob("claude-*")):
        count = repo_references(config, name)
        marker = "" if count else "  <- ORPHAN: not referenced anywhere in repo"
        lines.append(f"- {name}: {count} referencing file(s){marker}")
    lines.append("")
    return lines


def normalize_bash_prefix(entry: str) -> str | None:
    m = re.fullmatch(r"Bash\((.*)\)", entry)
    if not m:
        return None
    inner = m.group(1)
    return inner[:-1] if inner.endswith("*") else inner


def find_redundant(entries: list[str]) -> list[tuple[str, str]]:
    """Pairs (narrow, broad) where broad's prefix already subsumes narrow."""
    prefixes = {e: normalize_bash_prefix(e) for e in entries}
    redundant: list[tuple[str, str]] = []
    for narrow, np in prefixes.items():
        if np is None:
            continue
        for broad, bp in prefixes.items():
            if broad == narrow or bp is None:
                continue
            if narrow != broad and np.startswith(bp) and len(bp) < len(np):
                redundant.append((narrow, broad))
                break
    return redundant


def report_permissions(settings: dict, label: str) -> list[str]:
    perms = settings.get("permissions", {})
    lines = [f"## Permissions ({label})", ""]
    for bucket in ("allow", "deny", "ask"):
        entries = perms.get(bucket, [])
        lines.append(f"### {bucket}: {len(entries)} entries")
        dupes = sorted({e for e in entries if entries.count(e) > 1})
        if dupes:
            lines.append(f"- exact duplicates: {', '.join('`' + d + '`' for d in dupes)}")
        for narrow, broad in find_redundant(entries):
            lines.append(f"- `{narrow}` is subsumed by broader `{broad}`")
        lines.append("")
    allow = set(perms.get("allow", []))
    deny = set(perms.get("deny", []))
    overlap = allow & deny
    if overlap:
        lines.append(f"### allow/deny overlap: {', '.join('`' + o + '`' for o in sorted(overlap))}")
        lines.append("")
    return lines


def report_inventory(config: Config) -> list[str]:
    rules = sorted(config.claude_dir.glob("rules/*.md"))
    skills = sorted(p.parent.name for p in config.claude_dir.glob("skills/*/SKILL.md"))
    return [
        "## Inventory",
        "",
        f"- rules: {len(rules)}",
        f"- skills ({len(skills)}): {', '.join(skills)}",
        "",
    ]


def main() -> None:
    argparse.ArgumentParser(description=__doc__).parse_args()

    config = resolve_config()
    settings = load_json(config.settings_path)

    out = [
        "# Claude config inventory",
        "",
        f"- repo root: `{config.repo_root}`",
    ]
    if config.local_settings_path:
        out.append(f"- project overrides: `{config.local_settings_path}`")
    out.append("")
    out += report_hooks(config, settings)
    out += report_orphans(config)
    out += report_permissions(settings, "global settings.json")
    if config.local_settings_path:
        out += report_permissions(load_json(config.local_settings_path), "project settings.local.json")
    out += report_inventory(config)

    print("\n".join(out))


if __name__ == "__main__":
    main()
