#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Summarize a scalene JSON profile into a readable report of CPU and memory hotspots.

Usage:
    uv run profile_scalene.py scalene-profile.json
    uv run profile_scalene.py scalene-profile.json --top 20
    uv run profile_scalene.py scalene-profile.json --lines    # show line-level detail
    uv run profile_scalene.py scalene-profile.json --memory   # emphasize memory
"""
import argparse
import json
import sys
from pathlib import Path


def pct_bar(python_pct: float, native_pct: float, width: int = 20) -> str:
    total = python_pct + native_pct
    if total <= 0:
        return " " * width
    py_chars = round(python_pct / 100 * width)
    nat_chars = round(native_pct / 100 * width)
    return ("P" * py_chars + "C" * nat_chars).ljust(width)


def main():
    parser = argparse.ArgumentParser(description="Summarize a scalene JSON profile")
    parser.add_argument("profile", help="Path to scalene JSON file")
    parser.add_argument("--top", type=int, default=15, help="Entries to show per section (default: 15)")
    parser.add_argument("--memory", action="store_true", help="Sort by memory instead of CPU")
    args = parser.parse_args()

    data = json.loads(Path(args.profile).read_text())

    elapsed = data.get("elapsed_time_sec", 0)
    max_mb = data.get("max_footprint_mb", 0)
    print(f"\n{'='*70}")
    print(f"Scalene profile summary")
    print(f"Elapsed: {elapsed:.2f}s  |  Peak memory: {max_mb:.1f} MB")
    print(f"P = Python CPU time, C = native/C CPU time")
    print(f"{'='*70}")

    function_rows = []
    line_rows = []

    for filepath, fdata in data.get("files", {}).items():
        short_path = str(Path(filepath))
        file_cpu = fdata.get("percent_cpu_time", 0)

        for func in fdata.get("functions", []):
            py_pct = func.get("n_cpu_percent_python", 0)
            c_pct = func.get("n_cpu_percent_c", 0)
            avg_mb = func.get("n_avg_mb", 0)
            copy_mb_s = func.get("n_copy_mb_s", 0)
            name = func.get("line", "?")
            lineno = func.get("lineno", 0)
            total_cpu = py_pct + c_pct
            if total_cpu > 0.01 or avg_mb > 0.01:
                function_rows.append({
                    "name": name,
                    "file": short_path,
                    "lineno": lineno,
                    "py_pct": py_pct,
                    "c_pct": c_pct,
                    "total_cpu": total_cpu,
                    "avg_mb": avg_mb,
                    "copy_mb_s": copy_mb_s,
                })

        for line_data in fdata.get("lines", []):
            py_pct = line_data.get("n_cpu_percent_python", 0)
            c_pct = line_data.get("n_cpu_percent_c", 0)
            avg_mb = line_data.get("n_avg_mb", 0)
            total_cpu = py_pct + c_pct
            if total_cpu > 0.1 or avg_mb > 0.1:
                line_rows.append({
                    "line": line_data.get("line", "").rstrip(),
                    "file": short_path,
                    "lineno": line_data.get("lineno", 0),
                    "py_pct": py_pct,
                    "c_pct": c_pct,
                    "total_cpu": total_cpu,
                    "avg_mb": avg_mb,
                })

    sort_key = "avg_mb" if args.memory else "total_cpu"
    function_rows.sort(key=lambda r: r[sort_key], reverse=True)
    line_rows.sort(key=lambda r: r[sort_key], reverse=True)

    print(f"\n--- Top {args.top} functions by {'memory' if args.memory else 'CPU'} ---")
    print(f"{'CPU%':>6}  {'[P=py C=native]':<22}  {'AvgMB':>7}  {'Copy MB/s':>10}  function (file:line)")
    print(f"{'-'*6}  {'-'*22}  {'-'*7}  {'-'*10}  {'-'*40}")
    for r in function_rows[: args.top]:
        bar = pct_bar(r["py_pct"], r["c_pct"])
        print(
            f"{r['total_cpu']:5.1f}%  [{bar}]  {r['avg_mb']:>7.1f}  {r['copy_mb_s']:>10.1f}"
            f"  {r['name']}  ({r['file']}:{r['lineno']})"
        )

    if True:
        print(f"\n--- Top {args.top} lines by {'memory' if args.memory else 'CPU'} ---")
        print(f"{'CPU%':>6}  {'[P=py C=native]':<22}  {'AvgMB':>7}  line")
        print(f"{'-'*6}  {'-'*22}  {'-'*7}  {'-'*50}")
        for r in line_rows[: args.top]:
            bar = pct_bar(r["py_pct"], r["c_pct"])
            location = f"{r['file']}:{r['lineno']}"
            code = r["line"][:50].strip()
            print(f"{r['total_cpu']:5.1f}%  [{bar}]  {r['avg_mb']:>7.1f}  {location}  {code!r}")

    async_rows = []
    for filepath, fdata in data.get("files", {}).items():
        for func in fdata.get("functions", []):
            await_pct = func.get("n_async_await_percent", 0)
            if await_pct > 1:
                async_rows.append({
                    "name": func.get("line", "?"),
                    "file": str(Path(filepath)),
                    "lineno": func.get("lineno", 0),
                    "await_pct": await_pct,
                    "concurrency_mean": func.get("n_async_concurrency_mean", 0),
                    "concurrency_peak": func.get("n_async_concurrency_peak", 0),
                })

    if async_rows:
        async_rows.sort(key=lambda r: r["await_pct"], reverse=True)
        print(f"\n--- Async functions with significant await time ---")
        print(f"{'await%':>7}  {'concur_mean':>12}  {'concur_peak':>12}  function")
        print(f"{'-'*7}  {'-'*12}  {'-'*12}  {'-'*40}")
        for r in async_rows:
            print(
                f"{r['await_pct']:6.1f}%  {r['concurrency_mean']:>12.1f}  {r['concurrency_peak']:>12.1f}"
                f"  {r['name']}  ({r['file']}:{r['lineno']})"
            )


if __name__ == "__main__":
    main()
