---
paths:
  - "**/*.md"
  - "**/*.mdx"
  - "**/*.rst"
---

# Writing Documentation

Guidance for the *prose* in durable docs: READMEs, API references, guides,
design and philosophy docs, issue and PR text. For markdown *formatting*
(headings, line length, code blocks), see the markdown rule.

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

## Volatile Metrics

Don't bake volatile metrics into durable docs: an exact test count, file count,
or coverage percentage is stale the moment the next change lands. State the
property ("tests pass", "fully typed"), not the number.
