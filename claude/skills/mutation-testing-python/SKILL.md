---
name: mutation-testing-python
description: >
  Run and act on mutation testing for Python with mutmut 3.x: configure it, drive a
  package's surviving mutants to zero, tell a real test hole from an equivalent mutant,
  write tests that kill mutants, and decide when (and how) to suppress one. Covers
  `[tool.mutmut]` config, pytest-xdist interaction, capping each mutant's memory so a
  runaway allocation can't take the machine down, the result cache that replays stale
  verdicts, `# pragma: no mutate` forms and placement, `do_not_mutate_patterns`, what
  mutmut never mutates, and a script that groups survivors by function and dumps their
  diffs. MUST be invoked when running mutmut, setting up mutation testing in a Python
  project, triaging or killing survivors, judging whether a mutant is equivalent, or
  improving a mutation score. SHOULD be invoked when asked whether a Python suite
  actually constrains behavior beyond line coverage.
when_to_use: >
  "mutation test this package", "kill the survivors", "why did this mutant survive",
  "is this mutant equivalent", "mutmut says 0.00 mutations/second", "set up mutmut",
  "add a no mutate pragma", "improve the mutation score", "coverage is 100% but is the
  suite any good". A project-level mutation-testing skill or doc, where one exists,
  holds that project's recipes and known equivalents; load this alongside it.
---

# Mutation testing Python with mutmut

This covers mutmut 3.x as a tool and a method: config, the triage loop, killing tests,
suppression, and the traps. It does not cover a given project's known equivalents or
wrapper recipes. Look for those first (a `docs/**/mutation*` file, a project skill, a
`mutate` recipe in the task runner) and treat them as authoritative for that project.

Everything mutmut-specific below was verified against mutmut 3.7.0. Check the installed
version (`uv pip show mutmut`); on another version, re-check a claim against the
installed source before relying on it. The relevant files are `mutmut/__main__.py`
(cache and run loop), `mutmut/mutation/mutators.py` (what gets mutated, and how), and
`mutmut/mutation/pragma_handling.py` and `file_mutation.py` (what gets skipped).

## The goal

**Zero non-equivalent survivors**, with every equivalent survivor written down beside
the reason no test can catch it. The project doc listing those is what stops the next
run from re-litigating them. A mutation score is not the goal: a number without the
list of what survived and why says nothing about which holes remain.

## Configuration

mutmut reads `[tool.mutmut]` from `pyproject.toml` if that table exists, otherwise
`[mutmut]` from `setup.cfg`, and only from the current working directory. In a monorepo
that means running it from inside each package. A minimal block:

```toml
[tool.mutmut]
source_paths = ["src"]
pytest_add_cli_args_test_selection = ["tests/"]
pytest_add_cli_args = ["-n0"]  # only needed when pytest addopts enable xdist
```

- **xdist must be off.** mutmut records which tests reach which function from
  in-process trampoline hits, and xdist workers never report them back. With `-n` on,
  stats collection finds nothing and stops with "could not find any test case for any
  mutant". Override the project's `addopts` with `-n0`.
- **Exclude `mutants/` everywhere.** mutmut copies the source _and the tests_ into
  `./mutants/`, so a later `pytest` collects both copies and fails on duplicate module
  names. Add it to pytest's `--ignore-glob`, the type checker's and linter's excludes,
  and `.gitignore`.
- **Cap each mutant's memory.** A mutant can turn a loop that must advance into one that
  appends forever, at hundreds of megabytes a second. mutmut's only per-mutant limit is
  `RLIMIT_CPU`, so memory runs out long before the timeout fires: a few such mutants in
  parallel exhaust a small VM, and one without swap hangs. Cap the address space in the
  child, from a `conftest.py` hook. Each mutant's child sets `MUTANT_UNDER_TEST` and then
  calls `pytest.main` (verified in 3.8.0), so the hook runs once per mutant and never
  in the stats pass or the baseline. A capped runaway raises `MemoryError`, fails its
  tests, and counts as killed:

  ```python
  def pytest_configure(config: pytest.Config) -> None:
      if "__mutmut_" in os.environ.get("MUTANT_UNDER_TEST", "") and sys.platform == "linux":
          cap_address_space(headroom=1 << 30)


  def cap_address_space(headroom: int) -> None:
      pages = int(Path("/proc/self/statm").read_text().split()[0])
      _, hard = resource.getrlimit(resource.RLIMIT_AS)
      resource.setrlimit(resource.RLIMIT_AS, (pages * resource.getpagesize() + headroom, hard))
  ```

  Make the cap relative to the child's current size, since the child forks from a parent
  that has already imported everything, and leave generous headroom, since `RLIMIT_AS`
  counts virtual size, not resident memory. A cap set too tight makes ordinary tests fail
  and kills mutants that a test never caught. Linux enforces `RLIMIT_AS`; macOS doesn't.
- **POSIX only.** mutmut forks a child per mutant.
- In `setup.cfg`, list values split on newlines only. An indented continuation bakes the
  indent into the value, so a set of skip regexes is one alternation (`a|b`), not a list.
- Other keys worth knowing: `do_not_mutate` (file globs), `do_not_mutate_patterns` (see
  below), `mutate_only_covered_lines`, `timeout_multiplier`, `debug = true` (shows which
  tests ran), and `type_check_command` (see below).

## Commands

| Command | Does |
|---|---|
| `mutmut run` | Run every mutant without a cached verdict |
| `mutmut run 'pkg.mod.x_fn__mutmut_*'` | Re-run the named mutants (globs work), cached or not |
| `mutmut results` | List mutants that were not killed; `--all true` lists every one |
| `mutmut show <name>` | Print one mutant's diff (reads `./mutants/`) |
| `mutmut tests-for-mutant <name>` | Tests mutmut will run against that mutant |
| `mutmut browse` | Interactive TUI over the results |
| `mutmut apply <name>` | Writes the mutant _into your source tree_; avoid |

Mutant names are `<module>.x_<function>__mutmut_<n>`, or
`<module>.xǁ<Class>ǁ<method>__mutmut_<n>` for a method.

## Method

1. **Run** the package. A big package takes many minutes: run it in the background.
2. **Collect the survivors** while `./mutants/` is warm:

   ```bash
   uv run ${CLAUDE_SKILL_DIR}/scripts/survivors.py --out <dir>
   ```

   It prints survivor counts per function (where the holes cluster) and writes every
   survivor's diff to one `<module>.diff` per module. Pass `--mutmut "<prefix>"` when the
   project wraps mutmut (`--mutmut "just mutate my-pkg"`), and positional globs to
   narrow it. It calls `show` once per mutant, sequentially by default; `--jobs N` is
   safe only for a prefix that doesn't write and delete a config file per call.
3. **Triage each survivor** as killable or equivalent. Call it equivalent only if you
   can state exactly why no observable behavior changes. When that rests on how a
   library or the runtime behaves, probe it, and run the control case too (show that the
   value that _should_ differ does). Read
   [references/equivalent-mutants.md](references/equivalent-mutants.md) for the shapes
   that recur, and for the near neighbours of each that are _not_ equivalent.
4. **Write the killing tests** (patterns below), and record the equivalents in the
   project's doc.
5. **Confirm with a cold run**: `rm -rf mutants`, then a full `mutmut run`. That run is
   the source of truth, not the new test passing (see the cache trap below for why a
   warm re-run proves nothing).

To judge whether a refactor weakened the suite, diff the survivor _sets_ against a
worktree at the pre-change commit, not the survivor counts, which hide a new survivor
behind a newly-killed one.

For a large residue, fan out one subagent per source module, each owning a distinct test
file so their edits don't collide, and verify centrally with one serial mutmut run.

Subagents can't each run mutmut (see "One mutmut run at a time" under Traps), so each
checks its kills by hand against a private copy of the source:

```bash
cp -r src <scratch>/copy  # no trailing slash, and <scratch>/copy must not exist yet
find <scratch>/copy -name __pycache__ -type d -prune -exec rm -r {} +
# hand-apply one mutant to the copy, then:
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=<scratch>/copy \
  uv run pytest <test> -p no:cacheprovider -o pythonpath=<scratch>/copy
```

- **Bytecode off, or the verdict can be wrong.** Python reuses a cached `.pyc` when the
  source's size and mtime match its header, and the mtime is whole seconds. Applying the
  next mutant to the same file within a second, at the same size (`<` for `>`), loads the
  previous mutant's bytecode, so the verdict is the previous mutant's: a survivor can
  report killed, or a kill survived.
- **Prove the copy is what gets imported.** A wrong path fails silently: the editable
  install imports the real source, every mutant survives, and the unmutated copy still
  passes. `PYTHONPATH` precedes the editable install's entry, but pytest's own
  `pythonpath` setting inserts ahead of both, hence the `-o` override; a `python -c`
  check of `<pkg>.__file__` misses that, since it never loads pytest. So run two
  controls before trusting a verdict: the unmutated copy passes, and a mutant mutmut
  reports killed fails.
- **Edit the copy by hand.** `patch` has to place a `mutmut show` hunk by its context,
  since the line numbers count from the function rather than the file. A method's diff
  never applies, because `show` prints the method dedented to column 0, and a function's
  can apply with fuzz, which ignores context lines and can land the hunk in the wrong
  place.
- **A function the module calls at import keeps its unmutated result** under mutmut,
  whose child for each mutant forks from a parent that has already imported everything
  (see "Empty process-global memos" below). To match it, append the mutated function as
  a redefinition at the end of the module rather than editing it in place, and for a
  method assign it onto the class. A reference captured at import (a dispatch dict, a
  decorator registry) still holds the original after that, where under mutmut it holds
  the trampoline and reaches the mutant, so a function both called and captured at
  import can't be matched by hand: leave its verdict to the central run.
- `-p no:cacheprovider` keeps concurrent subagents from writing the project's shared
  `.pytest_cache`. Restore each file from `src` after its mutant.

## Writing tests that kill mutants

- **Assert the exact output.** One assertion on a whole parsed value, response, or
  emitted frame kills every literal, key, and field mutant inside it. "It didn't raise"
  kills almost nothing.
- **Hit the exact boundary.** `>=` versus `>` diverges only at equality, so drive the
  input (or an injected clock) to exactly the threshold. Check that the two branches
  actually return different things there: `if x > LIMIT: return LIMIT` survives `>=`
  because at `x == LIMIT` both arms return `LIMIT`. That one is equivalent.
- **Anchor message matches where the text is the contract.** `pytest.raises(match=...)`
  is `re.search`, so `"XXat least one sinkXX"` still matches `"at least one sink"`. Use
  `match=r"^...$"`.
- **Use distinct, non-default values** for every input, so a dropped or swapped argument
  can't coincide with the right answer.
- **Pin scheduling properties, not just results**, where a mutant changes _when_ work
  happens (a `continue` that becomes `break` in a fill loop delays work but finishes).
- **Empty process-global memos before the test that pins them.** Each mutant runs in a
  child forked from a parent that already ran the stats pass, so an `lru_cache` or
  module-level dict is warm, and the body behind it never runs again: every mutant of
  that body survives. Clear it in an autouse fixture, have the test assert it starts
  cold (`cache_info().currsize == 0`), then assert the built value _and_ that a second
  call returns the same object (which kills a mutant that rebuilds instead of reading
  back).
- **No `sleep` to synchronize.** mutmut's baseline runs single-process, so a race that
  `-n auto` hides can fail it; synchronize on a real signal.

## What mutmut never mutates

A mutation score is silent about all of these, so cover them some other way:

- **Module-level code**, including constants: mutants are generated only inside
  top-level functions and methods. A literal hoisted to a module constant has no
  mutants at all.
- **Decorated functions and classes**, unless the only decorator is `@staticmethod` or
  `@classmethod`. A `@functools.cache`'d function, a route handler, and a `@property`
  are all skipped whole.
- Type annotations, triple-quoted strings, non-trivial default argument values, calls to
  `len()` and `isinstance()`, and `__getattribute__`, `__setattr__`, `__new__`.

## Suppression

Prefer, in order: a killing test; restructuring so the mutant can't exist (delete a
no-op `case`, hoist a repeated literal into one local); a documented survivor; and only
then a suppression. A suppression stops measuring that code for good.

`# pragma: no mutate` comes in three forms, all honored by 3.7:

- **Trailing, on a simple statement line**: suppresses every mutant on that line. On a
  continuation line inside a multi-line literal or call it is silently ignored, so
  extract the value to a named local first. Keep the line inside the formatter's limit,
  or the formatter wraps it and moves the comment onto a continuation line.
- **Trailing on a `def` or `class` line with `block`** (`# pragma: no mutate block`):
  skips that whole function or class.
- **A `# pragma: no mutate start` / `# pragma: no mutate end` comment pair** on their own
  lines: suppresses the lines between them.

Because a pragma covers the whole line, it blinds the _killable_ mutants on that line
too: a truthiness-equivalent `False -> None` sits beside a real `False -> True`. Leave
those as documented survivors.

**Nothing suppresses a `match` case drop.** The trailing pragma on the `match` line does
not stop it, and neither does a pattern. Those always end up as documented survivors.

`do_not_mutate_patterns` is a list of regexes matched against each source line. It
skips only _expression_ mutants on matching lines: on `y = x + 1`, the `+` and `1`
mutants go but `y = None` stays, as do case drops and `continue`/`break` swaps. Use it
for a line shape that is unkillable everywhere (`assert_never`), not for one site.

`type_check_command` runs a type checker over the mutated tree and counts type-invalid
mutants as caught without running them. It catches a set almost disjoint from what
equivalence arguments and pragmas deal with (those are type-valid by nature), and it can
abort a whole run when the trampoline rewrite of `@overload` functions makes the checker
report an error it can't map to a mutant. Weigh both before enabling it.

## Traps

- **A warm re-run replays old verdicts.** Each mutant's result lives in
  `mutants/<source path>.meta`, keyed on the function's source; tests are not part of
  the key. After adding tests, a plain `mutmut run` skips every mutant whose source is
  unchanged and reports the same survivors at `0.00 mutations/second`. Naming mutants
  (`mutmut run 'pkg.mod.x_fn__mutmut_*'`) forces them to re-run, and brand-new test
  functions are picked up by an incremental stats pass, but an _edited existing_ test
  that now reaches a new function is not: the function-to-tests map in
  `mutants/mutmut-stats.json` still omits it (`mutmut tests-for-mutant` shows this). A
  named re-run is a fast check; `rm -rf mutants` and a full run is the confirmation.
- **Extract diffs before clearing the cache.** `mutmut show` reads `./mutants/`.
- **Mutant numbers are reassigned on every source edit.** After a source change,
  `x_fn__mutmut_4` is a different mutant. Never carry ids across a run that followed a
  source edit; re-extract.
- **Exit status 1 with "could not find any test case for any mutant" has two causes**: a
  package with nothing to mutate (the output says `0 files mutated`; mutmut has no knob
  to accept that) or tests that reach no mutated function (xdist on, a test selection
  that misses, an import-path mismatch). Read the counts before concluding which.
- **The mutmut baseline is stricter than the normal suite.** It runs single-process, and
  under mutmut's function trampoline an async generator's `aclose()`-triggered `finally`
  does not run, so a test asserting that teardown fails the baseline while passing
  normally. Deselect only such trampoline artifacts (a marker plus `-m "not <marker>"`
  in `pytest_add_cli_args`), fix any real race instead, and document a mutant whose only
  killer is deselected.
- **One mutmut run at a time**, and not alongside other heavy pytest runs (subagents
  included): mutmut runs one child per CPU (`--max-children` lowers it), and contention
  trips per-test timeouts in timing-sensitive tests, which then fail the baseline or
  count a mutant as killed for the wrong reason.
