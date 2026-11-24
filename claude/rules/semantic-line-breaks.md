---
paths:
  # The formats sembr.org lists as supporting semantic line breaks.
  - "**/*.md"
  - "**/*.mdx"
  - "**/*.markdown"
  - "**/*.adoc"
  - "**/*.asciidoc"
  - "**/*.tex"
  - "**/*.rst"
  - "**/*.org"
  - "**/*.typ"
  - "**/*.wiki"
  - "**/*.mediawiki"
  - "**/*.roff"
  - "**/*.man"
  - "**/*.txt"
  # Source files, for their comments and docstrings (Haddock among them).
  - "**/*.hs"
  - "**/*.py"
  - "**/*.rs"
  - "**/*.sh"
  - "**/*.js"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.go"
  - "**/*.sql"
  - "**/*.toml"
  - "**/*.yaml"
  - "**/*.yml"
  - "**/Dockerfile*"
  - "**/justfile"
---

# Semantic Line Breaks

Wherever a single newline doesn't change what the reader sees
(a markup language's rendered output, a comment, a docstring),
break prose by meaning, not by width,
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
- In a list item that opens with a bolded lead sentence,
  put the lead on a line of its own and the body on continuation lines,
  indented to align under the lead.
- Aim for lines under about 80 characters.
  Width is the tiebreaker, not the rule:
  a line holding a long URL or code span may run past it,
  and a short sentence stays on one line rather than being split to look even.

## In Code

Comments and docstrings follow the same breaks,
with each continuation line carrying the comment marker
(`#`, `//`, `///`) at the same indentation as the first.
The code's own line-length limit still binds,
so a deeply indented comment breaks sooner.
A one-sentence comment that fits on one line stays on one line.
