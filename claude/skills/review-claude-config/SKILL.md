---
name: review-claude-config
description: >
  Review the user's Claude Code configuration (settings.json permissions,
  hooks, skills, rules, CLAUDE.md, bin/ hook scripts) and surface concrete
  opportunities to improve, refine, consolidate, remove, or add to it. MUST be
  invoked when the user asks to review/audit/critique their Claude config,
  asks "what could be better about my setup", wants to prune dead or redundant
  config, or wants ideas for new hooks/skills/rules/permissions. SHOULD be
  invoked proactively when work repeatedly trips over a missing guardrail or a
  repeated manual step that config could automate.
---

# Review Claude Config

Survey the whole Claude Code config surface in the dotfiles repo, then surface
opportunities for improvement. This skill is an **auditor and orchestrator**:
it finds and prioritizes opportunities, then hands the actual edits off to the
specialized skills (`update-config`, `hook-creator`, `rule-curator`,
`skill-creator`). It does not edit config directly.

## 1. Run the inventory first

Before reasoning about anything, get the mechanical facts. Run with `uv` (not
`python3`):

```bash
uv run /home/jtk/.claude/skills/review-claude-config/scripts/inventory.py
```

It locates this dotfiles repo from its own location and reports, only for the
config that lives in this repo: every hook command and whether it resolves to a
`bin/` script, every `bin/claude-*` script and whether anything still
references it (orphan detection), exact-duplicate and subsumed permission
entries, allow/deny overlaps, and component counts. Config installed under
`~/.claude` that doesn't come from this repo is out of scope. It makes no
judgments and changes nothing.

Use its output as ground truth. Do not guess at what hooks or permissions
exist from memory; read the report.

## 2. The config surface

Everything lives in `claude/` in the dotfiles repo and is symlinked into
`~/.claude/` by `bin/link-claude`. **Edit the source in `claude/`, never the
symlinks under `~/.claude/`.** Hook scripts live in `bin/` (on PATH as
`dotfiles/bin`), not under `claude/`.

- `claude/settings.json` — permissions, hooks wiring, env, model, statusline.
- `.claude/settings.local.json` — project-scoped overrides for this repo.
- `claude/CLAUDE.md` — global instructions for all projects. (The repo also
  has its own project `CLAUDE.md` at the root.)
- `claude/rules/*.md` — auto-loaded guidance, globally or `paths:`-scoped.
- `claude/skills/*/SKILL.md` — skills, some with `scripts/`, `references/`.
- `bin/claude-*` — the hook scripts referenced from `settings.json`.

## 3. What to look for

Read the actual files; the rubric below is what to weigh, not a checklist to
mechanically tick. Lead with high-confidence, high-value findings.

- **Permissions.** Beyond the script's dupe/subsumption flags: is anything in
  `allow` broader than it needs to be (a blanket `Bash(foo *)` where only one
  subcommand is ever used)? Are there read-only commands still prompting that
  belong in `allow` (see the `fewer-permission-prompts` skill)? Does `deny`
  cover the genuinely destructive cases? Project overrides in
  `settings.local.json` that have become permanent probably belong in the
  global file.
- **Hooks.** Any hook command the script flagged as missing is broken. Beyond
  that: is each hook still earning its place, or has it become noise? Is there
  a repeated manual correction or guardrail that a new hook could automate?
  Use the `hook-creator` skill for the event/JSON details.
- **Rules.** Look for overlap (two rules covering the same ground), staleness
  (advice that no longer matches how the user works), and missing `paths:`
  scoping that makes a narrow rule load globally. Flag rules that just restate
  what any competent engineer knows: they tax every session that loads them.
- **Skills.** Weak or keyword-thin `description`s hurt discoverability (the
  single most important skill property). Look for skills that overlap, that
  have gone stale, or for recurring multi-step workflows that deserve a new
  skill. Check that bundled scripts still match what `SKILL.md` claims.
- **CLAUDE.md.** Is anything here better expressed as a path-scoped rule, a
  hook (for things the harness must enforce, not just request), or a skill?

## 4. Search the web for ideas

Don't audit only against what already exists; the config can lag behind what
the tooling now supports. Actively look outward:

- Check the current Claude Code docs for features, hook events, or
  settings that aren't being used yet. The `claude-code-guide` agent and
  `code.claude.com/docs` are the authoritative sources; prefer them over
  memory, which goes stale as the product ships.
- Web-search for community patterns: useful hooks, skill ideas, permission
  setups, and config conventions others have published. Bring back concrete,
  verified ideas, not vague inspiration.

Treat external ideas as candidates to evaluate against how the user actually
works, not mandates to adopt.

## 5. Present findings, then hand off

Report opportunities grouped by component, each with a one-line rationale and a
rough priority. Get the user's buy-in before changing anything. When they pick
something to act on, route it to the skill that owns that surface:

- permissions / `settings.json` / hooks wiring -> `update-config`
- new or changed hook script -> `hook-creator`
- rules -> `rule-curator`
- skills -> `skill-creator`

Per the user's CLAUDE.md, don't commit or push; leave that to them.
