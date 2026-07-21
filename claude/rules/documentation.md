# Writing Documentation

Guidance for the *prose* in durable docs: READMEs, API references, guides,
design and philosophy docs, reports, issue and PR text, and docstrings. It applies
wherever that prose lives, including docstrings embedded in source files.

The boundary against the comments rule is audience, not file type: a docstring
documents an interface for the people who use it, so it follows this rule; a
code comment addresses the next person reading the implementation, so it follows
the comments rule. For markdown *formatting* (headings, line length, code
blocks), see the markdown rule.

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
document's job, not a blanket ban on the past tense.

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

When the change itself is worth communicating, it belongs in a changelog, a
release announcement, or a prominent callout, not scattered through the prose
as parentheticals and corrections.

## Reports Assembled Incrementally

A report is often written in passes: draft a section, discover you need more
data or research or thinking, go do it, revise. The finished report must read
as if you had all the data from the start. It presents the current state of
your knowledge, not the archaeology of how you assembled it.

The failure mode is the drafting process leaking into the artifact:

- "Initially the data suggested X, but after more samples we found Y" should
  just be "the data shows Y".
- "We didn't have the Q3 numbers at first, so this uses Q2" should be deleted
  and the analysis presented on the Q3 numbers.
- "After further investigation" and "upon revisiting" narrate the journey; the
  report is the destination.

Apply the same test as Updating Existing Text: a sentence that only makes sense
as a record of how the report came together is scaffolding, so cut it. And the
same exception as Tense and Voice: when the process itself is the point (a
methodology section, a research log, a retrospective), narrating it is correct.

## Volatile Metrics

Don't bake volatile metrics into durable docs: an exact test count, file count,
or coverage percentage is stale the moment the next change lands. State the
property ("tests pass", "fully typed"), not the number.
