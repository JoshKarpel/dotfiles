---
name: style-curator
description: >
  Ingest new style material (articles, docs, snippets, reference links, code
  review feedback) and fold it into the `style-*` rule family. MUST be invoked when the
  user shares a new convention, style guide, blog post, library doc, or
  reference and wants it captured, when deciding whether guidance belongs in
  an existing `style-*` rule or needs a new one, or when auditing or
  refreshing `style-*` rules with fresh material.
---

# Style Curator

Takes in new style-relevant material, researches it, and decides whether it
belongs in an existing `style-*` rule or needs a new one.

## Workflow

### 1. Read the material

Fetch URLs, read pasted text, or read referenced files in full. Pull out the
concrete, actionable conventions, not just "this seems useful." Vague
inspiration isn't rule content; a specific, reasoned rule is.

### 2. Verify before recording

Don't transcribe claims you haven't checked. If the material asserts that a
tool behaves a certain way or a pattern works, try it or cross-check current
docs. Blog posts and forum answers drift out of date faster than official
references do.

### 3. Survey the existing `style-*` rules

```bash
ls claude/rules/ | grep '^style-'
```

Read each candidate's `paths` frontmatter and skim its body to judge fit.
Match on both axes:

- **Format or language**: is this Dockerfile, shell, Python, markdown, etc.?
- **Topic**: does it extend something a rule already covers, or is it a
  genuinely new area for that format?

### 4a. If it fits an existing rule, edit it in place

- Find the right spot: an existing `##` heading to extend, or a new heading
  that matches the rule's existing structure and voice.
- Match the target rule's example density and tone; don't import the source
  material's style wholesale.
- Run the proposed edit past the user before writing it. They may want it
  trimmed, placed elsewhere, or skipped.

### 4b. If it doesn't fit any existing rule, propose a new one

- Name it `style-<topic>.md` to stay in the family (`style-rust.md`,
  `style-yaml.md`), placed in `claude/rules/`.
- Add YAML frontmatter with `paths:` globs that match the relevant file types
  so the rule loads automatically when Claude works with those files.
- Per `CLAUDE.md`, new rules live in `claude/rules/` in this repo, never
  directly under `~/.claude/`, so they travel with the dotfiles and get
  symlinked into place by `bin/link-claude`.
- Propose the name, scope, `paths` globs, and outline to the user before
  writing files.

### 5. Prune as you go

Keep only what's non-obvious, durable, and actionable. A style rule that
restates what any competent engineer already knows is a tax on every future
session that loads it, not an asset.
