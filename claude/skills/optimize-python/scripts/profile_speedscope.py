#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Summarize a speedscope JSON profile (produced by austin2speedscope) into a
readable report of hotspots, showing self-time and inclusive-time per function.

Usage:
    uv run profile_speedscope.py profile.json
    uv run profile_speedscope.py profile.json --all        # include stdlib/frozen frames
    uv run profile_speedscope.py profile.json --top 20     # show more entries
    uv run profile_speedscope.py profile.json --chains     # show top call chains too
"""
import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


STDLIB_MARKERS = ("<frozen ", "<string>", "lib/python3", "lib/python")


def is_stdlib(frame: dict) -> bool:
    f = frame.get("file", "")
    return any(m in f for m in STDLIB_MARKERS)


def fmt_frame(frame: dict) -> str:
    name = frame.get("name", "?")
    file = frame.get("file", "?")
    line = frame.get("line", "?")
    path = Path(file)
    short = str(path) if path.parts and path.parts[0] == "/" else file
    if len(short) > 60:
        short = "..." + short[-57:]
    return f"{name}  ({short}:{line})"


def main():
    parser = argparse.ArgumentParser(description="Summarize a speedscope JSON profile")
    parser.add_argument("profile", help="Path to speedscope JSON file")
    parser.add_argument("--all", action="store_true", help="Include stdlib/frozen frames")
    parser.add_argument("--top", type=int, default=15, help="Number of entries to show (default: 15)")
    parser.add_argument("--chains", action="store_true", help="Show top call chains")
    args = parser.parse_args()

    data = json.loads(Path(args.profile).read_text())
    frames = data["shared"]["frames"]

    for i, profile in enumerate(data["profiles"]):
        if profile.get("type") != "sampled":
            continue

        samples = profile["samples"]
        weights = profile["weights"]
        total_us = sum(weights)

        self_time: dict[int, int] = defaultdict(int)
        incl_time: dict[int, int] = defaultdict(int)

        for stack, weight in zip(samples, weights):
            if not stack:
                continue
            leaf = stack[-1]
            self_time[leaf] += weight
            for idx in set(stack):
                incl_time[idx] += weight

        name = profile.get("name", f"Profile {i}")
        unit = profile.get("unit", "microseconds")
        print(f"\n{'='*70}")
        print(f"Profile: {name}")
        print(f"Total time: {total_us/1000:.1f}ms  |  Samples: {len(samples)}")
        print(f"{'='*70}")

        def pct(us: int) -> str:
            return f"{100*us/total_us:5.1f}%"

        def rows(time_dict: dict[int, int], label: str) -> None:
            print(f"\n--- Top {args.top} by {label} ---")
            print(f"{'%':>6}  {'time':>8}  frame")
            print(f"{'-'*6}  {'-'*8}  {'-'*50}")
            ranked = sorted(time_dict.items(), key=lambda x: x[1], reverse=True)
            shown = 0
            for idx, us in ranked:
                if shown >= args.top:
                    break
                frame = frames[idx]
                if not args.all and is_stdlib(frame):
                    continue
                ms = us / 1000
                print(f"{pct(us)}  {ms:>7.1f}ms  {fmt_frame(frame)}")
                shown += 1

        rows(self_time, "self time")
        rows(incl_time, "inclusive time")

        if args.chains:
            print(f"\n--- Top {args.top} call chains (by weight) ---")
            chain_weights: dict[tuple, int] = defaultdict(int)
            for stack, weight in zip(samples, weights):
                if not args.all:
                    filtered = [i for i in stack if not is_stdlib(frames[i])]
                else:
                    filtered = list(stack)
                if filtered:
                    key = tuple(filtered)
                    chain_weights[key] += weight
            ranked = sorted(chain_weights.items(), key=lambda x: x[1], reverse=True)
            for chain, us in ranked[: args.top]:
                ms = us / 1000
                print(f"\n  {pct(us)}  {ms:.1f}ms")
                for idx in chain:
                    print(f"    {fmt_frame(frames[idx])}")


if __name__ == "__main__":
    main()
