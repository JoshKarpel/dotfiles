# Durable Docs

Guidance for the *prose* in durable docs: READMEs, API references, guides,
design and philosophy docs, reports, issue and PR text, and docstrings. It
applies wherever that prose lives, including docstrings embedded in source
files, since a docstring documents an interface for the people who use it.

## Tense and Voice

Reference docs (READMEs, API references, guides) describe the present state of
the code as if it always was. Don't narrate the process that produced it: no
"recently", "now refactored to", "carried over from the last checkpoint", or
"deferred for now". That scaffolding is working-context that rots as the code
moves on; it belongs in commit messages and PR descriptions, not in durable
reference docs. This is the comments rule (capture the non-obvious *why*, never
the history of how it got here) applied to prose. Write section and issue titles
in the imperative ("Add X", "Fix Y"), not as status reports.

This applies to docs that describe *what is*. Explicitly historical or
discussion-oriented docs are the opposite case: a changelog, an ADR, a design
retrospective, or a migration note exists precisely to record what changed, when,
and why, so narrating history there is the point, not scaffolding. Judge by the
document's job, not a blanket ban on the past tense. When narrating that history,
frame it around systems rather than people (see the blameless rule).

## Updating Existing Text

When updating prose, replace obsolete text with accurate text rather than
preserving the obsolete text and adding a correction. The final document should
read as if it were written correctly from the beginning.

The failure mode is [accretive editing](https://justindfuller.com/programming/accretive-editing):
after the `foo` backend is replaced with `bar`, "authenticates with `foo`"
becomes "authenticates with `bar` but no longer supports `foo`", when it should
just become "authenticates with `bar`". The test is whether a reader who never
saw the old version would notice anything missing. If a sentence only makes
sense as a diff against text the reader can't see, delete the obsolete half.

The same holds for a report written in passes (draft, go get more data, revise):
it presents the current state of your knowledge, not the archaeology of how you
assembled it. "Initially the data suggested X, but after more samples we found
Y" should just be "the data shows Y". A note that the analysis uses Q2 because
the Q3 numbers weren't in yet should go, with the analysis redone on Q3. "After
further investigation" and "upon revisiting" narrate the journey; the report is
the destination. Where the process itself is the point (a methodology section, a
research log, a retrospective), narrating it is correct.

When the change itself is worth communicating, it belongs in a changelog, a
release announcement, or a prominent callout, not scattered through the prose
as parentheticals and corrections.

## Volatile Metrics

Don't bake volatile metrics into durable docs: an exact test count, file count,
or coverage percentage is stale the moment the next change lands. State the
property ("tests pass", "fully typed"), not the number.

## Don't Enumerate the Discoverable

Don't restate what a reader could recover from the source: the recipes
`just --list` prints, the scripts in `package.json`, the entries in a config file,
the contents of a `bin/` directory. Link the command or the file instead. A
hand-maintained copy drifts the moment someone adds an entry, and nothing fails
when it does. Worse is a **paragraph of behavior per item** (what each hook
matches, what each flag does): an untestable prose reimplementation, rotting
silently while the code stays correct.

The test is whether one command or one named file would tell the reader the same
thing. What survives it is what no single source states:

- Constraints invisible from any one file (a hook can't call the shell functions
  the repo defines, because it runs in a non-interactive subprocess).
- Rationale for a design that otherwise looks arbitrary (why one check runs in
  sequence rather than as a parallel group).
- Interactions between artifacts, where neither alone tells the story (a deny list
  stays thin _because_ another component does the reasoning).
- A pointer to an exemplar worth copying, rather than a description of it.

Where the toolchain can generate the list at build time (a docs-site plugin or
hook, an autodoc extension, a preprocessor), derive it from the source and render
it in full.
