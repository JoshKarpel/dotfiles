---
paths:
  - "bin/**"
---

# Arguments in `bin/` Scripts

Every script in `bin/` answers `-h` and `--help` by printing its help and exiting 0,
and rejects any argument it doesn't recognize
by naming itself and the argument on stderr and exiting 2,
both before it reads stdin or touches anything.
That makes `--help` safe to guess and a mistyped flag harmless,
which matters most for the scripts that do damage when they run:
a script that ignores its arguments treats `tidy --help` as `tidy`.
The help check also comes before a self-test block.
`claude-tab-status` rejects with exit 1 instead,
since Claude Code reads exit 2 from a `UserPromptSubmit` hook as blocking the prompt.

- **The help is the header comment.**
  Bash scripts print it with the `sed` in the block `bin/is-exe-dev` carries,
  which reads from line 2 to the first line that isn't a comment,
  so the header runs unbroken from line 2 and says what arguments the script takes.
  A blank line ends it, keeping the code comments below out of the help.
  Python scripts pass the module docstring to `argparse`
  (`bin/claude-rm-scope-check` is the stdlib exemplar)
  or get help from `typer`.
  Either way the text a reader sees in the source is the text `--help` prints,
  so the two can't drift.
- **A script that takes no arguments rejects all of them,**
  with the `(($#))` guard that follows the help block in `bin/is-exe-dev`.
  One that takes arguments keeps its own parser
  and gives it a catch-all branch that exits 2.
- **A wrapper passes its other arguments through** to the tool it wraps
  (`claude-shell`, `claude-exe-dev`, `perf`, `exe-dev lobby`),
  and the wrapped tool does the rejecting.
- **Through git, only `-h` reaches the script.**
  `git land --help` is `git help land`, which looks for a `git-land` man page,
  so a `git-*` script is reached with `git land -h`.

`bin/check-bin-help` runs from pre-commit on the changed scripts under `bin/`,
and on all of them in CI.
It runs a script with `--help` only once the source shows it handles the flag,
then requires exit 0 and some output.
Rejecting unknown arguments isn't checked by machine,
since running a script with a bogus argument would run it for real
in exactly the case the check exists to catch,
so that half is for review.
