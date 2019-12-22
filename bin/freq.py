#!/usr/bin/env python

import argparse
import re
from pathlib import Path
import collections
import os


def parse_args():
    parser = argparse.ArgumentParser(description="Count frequencies of words.")

    parser.add_argument("paths", nargs="*")

    args = parser.parse_args()

    if len(args.paths) == 0:
        args.paths.append(Path.cwd())
    args.paths = [Path(p) for p in args.paths]

    for path in args.paths:
        if not path.exists():
            raise Exception(f"{path} does not exist")

    return args


def main():
    args = parse_args()

    files = []
    for path in args.paths:
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            files.extend(walk(path))

    words = sum(
        (collections.Counter(parse(file)) for file in files), collections.Counter()
    )

    most = len(str(max(words.values())))
    for k, v in sorted(words.items(), key=lambda x: x[1]):
        print(f"{v:{most}} {k}")


def walk(dir):
    for root, dirs, files in os.walk(dir, topdown=False):
        for name in files:
            yield (Path(root) / name).absolute()


RE_WORDS = re.compile(r"\w+")


def parse(file):
    words = []
    with file.open() as f:
        for line in f:
            words.extend(RE_WORDS.findall(line))

    return words


if __name__ == "__main__":
    main()
