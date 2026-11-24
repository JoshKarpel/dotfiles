---
paths:
  - "**/*.md"
  - "**/*.mdx"
---

# Markdown Style Guide

## Headings and Structure

- **Don't use `---` horizontal rules between sections.**
  Headings (`##`, `###`, etc.) already provide clear visual separation;
  adding `---` is redundant noise.
- Don't skip heading levels (e.g. `##` → `####`). Step down one level at a time.
- One blank line before a heading, one blank line after.

## Line Breaks

Break prose by meaning, not by width,
following [Semantic Line Breaks](https://sembr.org/).
The payoff is in the diff:
a reworded clause changes one line instead of reflowing the paragraph,
so review shows what actually changed.

- Break after every sentence.
- Break after an independent clause (at a comma, semicolon, or colon)
  when the sentence is long enough to need it.
  A dependent clause or a closing parenthesis is a break point too,
  where it clarifies the structure or keeps the line short.
- Never break inside a phrase, a hyphenated word, a link, or inline code.
- In a bullet that opens with a bolded lead sentence,
  put the lead on a line of its own and the body on continuation lines
  (indented 2 spaces).
- Aim for lines under about 80 characters.
  Width is the tiebreaker, not the rule:
  a line holding a long URL or code span may run past it,
  and a short sentence stays on one line rather than being split to look even.

## Code Blocks

- Always use fenced code blocks (` ``` `), never indented ones. Fences are
  explicit, survive copy-paste, and carry a language tag.
- Always specify a language on fenced code blocks
  (` ```python `, ` ```bash `, etc.). Use `text` if there's no applicable language.

## Lists

- Use `-` for unordered lists, not `*` or `+`.
- Prefer a flat bullet list over a nested one when nesting doesn't add meaning.
- Don't add blank lines between short list items; do add blank lines between
  items that are themselves multi-line or contain sub-blocks.

## Inline Formatting

- Use `**bold**` to mark the **first** use of a term you're defining, once, and
  then never again for that term. That's the job it does well. Don't bold for
  decoration or general emphasis.
- Use `_italics_` (underscores, not asterisks) to stress a single pivotal word:
  `_not_`, `_at runtime_`. Stressing a whole phrase stresses nothing.
- Use backticks for all code, filenames, CLI flags, and identifiers,
  even short ones like `True` or `-v`.
- **No em dashes.** Prefer a colon when introducing or appending a clause;
  otherwise use a comma, parentheses, a spaced hyphen (` - `), or a new
  sentence.
- **Prefer inline links** placed on a natural word or phrase rather than appended
  at the end of a line. Write `[uv](https://...)` not `uv — [docs](https://...)`.
