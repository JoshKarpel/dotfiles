#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Group mutmut's surviving mutants by function and dump their diffs per module.

Triage needs two views of a run that mutmut gives one mutant at a time: where the
survivors cluster (a count per function), and every survivor's diff, read a module at
a time. This collects both from `mutmut results` and `mutmut show`, so it has to run
while the `mutants/` directory from that run is still on disk: `show` reads it.

mutmut is reached through `--mutmut`, a command prefix, rather than imported, so the
script works however a project wraps it (`uv run mutmut`, a `just` recipe that writes
the config first, a different working directory). Any prefix that accepts `results`
and `show <name>` as trailing arguments will do.
"""

import argparse
import fnmatch
import re
import shlex
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

RESULT_LINE = re.compile(r"^\s*(?P<name>[\w.]+__mutmut_\d+): (?P<status>.+?)\s*$")
MUTANT_SUFFIX = re.compile(r"__mutmut_\d+$")


def parse_results(text: str) -> list[tuple[str, str]]:
    """The (mutant name, status) pairs in `mutmut results` output, ignoring other lines."""
    return [(m["name"], m["status"]) for line in text.splitlines() if (m := RESULT_LINE.match(line))]


def function_of(mutant: str) -> str:
    """`pkg.mod.x_fn__mutmut_3` -> `pkg.mod.x_fn`: the key survivors cluster under."""
    return MUTANT_SUFFIX.sub("", mutant)


def module_of(mutant: str) -> str:
    """`pkg.mod.x_fn__mutmut_3` -> `pkg.mod`; a method (`pkg.mod.xǁClsǁmeth__mutmut_3`) splits the same way."""
    return function_of(mutant).rsplit(".", 1)[0]


def run_mutmut(prefix: list[str], *args: str) -> str:
    """Run one mutmut subcommand, failing loudly with its output if it fails."""
    done = subprocess.run([*prefix, *args], capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit(f"`{shlex.join([*prefix, *args])}` exited {done.returncode}:\n{done.stdout}{done.stderr}")
    return done.stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "patterns",
        nargs="*",
        help="fnmatch globs on mutant names to keep (e.g. 'pkg.mod.*'); default: all",
    )
    parser.add_argument(
        "--mutmut",
        default="uv run mutmut",
        help="command prefix that runs mutmut in the right directory with the right config "
        "(default: %(default)r)",
    )
    parser.add_argument(
        "--status",
        action="append",
        help="statuses to collect, repeatable (default: 'survived' and 'no tests')",
    )
    parser.add_argument("--out", type=Path, help="directory for the per-module diff files (default: a new temp dir)")
    parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="concurrent `show` calls (default: %(default)s). Raise it only when the prefix is safe to run "
        "in parallel: a wrapper that writes and deletes a config file per call is not",
    )
    args = parser.parse_args()

    prefix = shlex.split(args.mutmut)
    statuses = set(args.status or ["survived", "no tests"])

    results = parse_results(run_mutmut(prefix, "results", "--all", "true"))
    if not results:
        sys.exit("`mutmut results` listed no mutants: is there a `mutants/` directory from a run here?")
    wanted = [
        (name, status)
        for name, status in results
        if status in statuses and (not args.patterns or any(fnmatch.fnmatch(name, p) for p in args.patterns))
    ]

    print(f"{len(wanted)} of {len(results)} mutants with status in {sorted(statuses)}")
    if not wanted:
        return
    for status, count in Counter(status for _, status in wanted).most_common():
        print(f"  {count:5d} {status}")
    print("\nby function:")
    for function, count in Counter(function_of(name) for name, _ in wanted).most_common():
        print(f"  {count:5d} {function}")

    out = args.out or Path(tempfile.mkdtemp(prefix="mutmut-survivors-"))
    out.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        diffs = dict(zip(wanted, pool.map(lambda pair: run_mutmut(prefix, "show", pair[0]), wanted)))

    # Each `show` output already opens with a `# <name>: <status>` line, so it heads its own section.
    by_module: dict[str, list[str]] = defaultdict(list)
    for (name, _), diff in diffs.items():
        by_module[module_of(name)].append(diff.rstrip() + "\n")
    for module, sections in sorted(by_module.items()):
        (out / f"{module}.diff").write_text("\n".join(sections))

    print(f"\ndiffs for {len(by_module)} modules in {out}")


if __name__ == "__main__":
    main()
