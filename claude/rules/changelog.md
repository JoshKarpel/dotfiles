---
paths:
  - "**/*CHANGELOG*"
  - "**/*changelog*"
---

# Changelogs

A changelog records what changed *between releases*, so a `Fixed` entry is a
claim that someone on the previous release could have hit the bug. Before
writing one, check whether the code it fixes has actually shipped: compare
against the last tag (`git show <last-tag>:CHANGELOG.md`, or whether the file
even existed there). A fix to code introduced in the same unreleased version
changed nothing for any reader. If it altered a reader-facing property, fold
that property into the feature's own `Added`/`Changed` entry; if it didn't,
it belongs nowhere.

The failure mode is an unreleased block that accretes one entry per commit and
reads as a development diary: notes on how the feature got written, rather than
a list of what changed. This is accretive editing (see the durable-docs rule),
arriving one release at a time.
