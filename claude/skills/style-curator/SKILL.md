---
name: style-curator
description: >
  Ingest new style material (articles, docs, snippets, reference links, code
  review feedback) and fold it into the `style-*` skill family. Use when the
  user shares a new convention, style guide, blog post, library doc, or
  reference and wants it captured, when deciding whether guidance belongs in
  an existing `style-*` skill or needs a new one, or when auditing or
  refreshing `style-*` skills with fresh material.
---

# Style Curator

Takes in new style-relevant material, researches it, and decides whether it
belongs in an existing `style-*` skill or needs a new one.

## Workflow

### 1. Read the material

Fetch URLs, read pasted text, or read referenced files in full. Pull out the
concrete, actionable conventions, not just "this seems useful." Vague
inspiration isn't skill content; a specific, reasoned rule is.

### 2. Verify before recording

Per `skill-creator`'s "Qualifications" principle, don't transcribe claims you
haven't checked. If the material asserts that a tool behaves a certain way or
a pattern works, try it or cross-check current docs. Blog posts and forum
answers drift out of date faster than official references do.

### 3. Survey the existing `style-*` skills

```bash
ls claude/skills/ | grep '^style-'
```

Read each candidate's frontmatter `description` (and skim its body if the
topic is ambiguous) to judge fit. Match on both axes:

- **Format or language**: is this Dockerfile, shell, Python, markdown, etc.?
- **Topic**: does it extend something a skill already covers, or is it a
  genuinely new area for that format?

### 4a. If it fits an existing skill, edit it in place

- Find the right spot: an existing `##` heading to extend, or a new heading
  that matches the skill's existing structure and voice.
- Match the target skill's example density and tone, don't import the source
  material's style wholesale.
- If the addition is long or variant-specific (one apt vs. dnf vs. uv recipe,
  say), put it in `references/` and link it from `SKILL.md`, the way
  `style-dockerfile` and `style-github-actions` do (progressive disclosure).
- Run the proposed edit past the user before writing it. They may want it
  trimmed, placed elsewhere, or skipped.

### 4b. If it doesn't fit any existing skill, propose a new one

- Defer to `skill-creator` for the mechanics (frontmatter shape, template,
  `references/` layout, discoverability tips).
- Name it `style-<topic>` to stay in the family (`style-rust`, `style-yaml`),
  and open with the same "Adopt Project Conventions First" section every
  other `style-*` skill carries (every one but `style-programming`, which
  *is* that section).
- Per `CLAUDE.md`, new skills live in `claude/skills/` in this repo, never
  directly under `~/.claude/`, so they travel with the dotfiles and get
  symlinked into place by `install.sh`.
- Propose the name, scope, and outline to the user before writing files.

### 5. Prune as you go

Apply `skill-creator`'s "Valuable Knowledge" filter: keep only what's
non-obvious, durable, and actionable. A style skill that restates what any
competent engineer already knows is a tax on every future session that loads
it, not an asset.
