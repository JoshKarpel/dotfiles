---
paths:
  - "**/*.md"
---

# Markdown Style Guide

## Headings and Structure

- **Don't use `---` horizontal rules between sections.**
  Headings (`##`, `###`, etc.) already provide clear visual separation;
  adding `---` is redundant noise.
- Don't skip heading levels (e.g. `##` → `####`). Step down one level at a time.
- One blank line before a heading, one blank line after.

## Line Length

- Keep lines short: aim for ~80 characters, hard limit ~100.
- Wrap bullet list items onto continuation lines (indent 2 spaces) rather than
  letting them run long. Long bullets are hard to read in narrow windows and
  hard to edit in-place.
- Break at natural break points: after a period, comma, or closing parenthesis.
  Try not to break mid-phrase or mid-clause.
- Prose paragraphs should also be wrapped, not left as single long lines.

## Code Blocks

- Always specify a language on fenced code blocks
  (` ```python `, ` ```bash `, etc.). Use `text` if there's no applicable language.

## Lists

- Use `-` for unordered lists, not `*` or `+`.
- Prefer a flat bullet list over a nested one when nesting doesn't add meaning.
- Don't add blank lines between short list items; do add blank lines between
  items that are themselves multi-line or contain sub-blocks.

## Inline Formatting

- Use `**bold**` for emphasis that matters, sparingly. Don't bold for decoration.
- Use backticks for all code, filenames, CLI flags, and identifiers,
  even short ones like `True` or `-v`.
- **No em dashes.** Prefer a colon when introducing or appending a clause;
  otherwise use a comma or parentheses.
- **Prefer inline links** placed on a natural word or phrase rather than appended
  at the end of a line. Write `[uv](https://...)` not `uv — [docs](https://...)`.

## Tense

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
