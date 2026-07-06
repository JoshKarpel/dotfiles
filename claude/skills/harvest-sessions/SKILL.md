---
name: harvest-sessions
description: >
  Review recent Claude Code sessions (one project or all) and turn recurring
  friction, corrections, insights, and tool-usage lessons into rules, skills, or
  hooks, for your global Claude config or a project's own local one. Fans out a
  subagent per session for open-ended analysis, then
  synthesizes cross-session themes. Ships a script that turns noisy jsonl
  transcripts into clean, labeled conversation. MUST be invoked when asked to
  review or analyze recent sessions, mine transcripts for rule or skill ideas,
  find "what I've been correcting Claude on", or turn session history into config
  improvements. Routes findings to the rule-curator, skill-creator, and
  hook-creator skills.
---

# Harvest Sessions

Turn what happened across many sessions into durable Claude config (rules, skills,
`CLAUDE.md`, hooks, etc.). The signal is spread
across the user's corrections, the insights the assistant surfaced, and how the
tools were actually used, far more than one context window can hold. So the shape
is **fan out, then synthesize**: a subagent reads each session in full and reports
back; the main agent finds the themes and acts on them.

## Decide the goal first

Settle what the harvest is *for* before analyzing, deducing it from the user's
request and asking if it's unclear; it changes how hard you generalize and where
the output lands:

- **Global Claude config** — lessons that apply to any project, destined for this
  dotfiles repo's rules, skills, hooks, `CLAUDE.md`, etc. Generalize hard: keep only
  what isn't
  tied to one project's domain, architecture, or vocabulary. A lesson that recurs
  *across different projects* is the strongest proof it belongs here, so scanning
  all projects (step 1) helps.
- **A project's local Claude config** — guidance for the repo you're working in,
  destined for its own `CLAUDE.md` and `.claude/` rules. Here project-specific detail is the
  point, so don't over-generalize it away. Scope the scan to that project (you'll
  be running from it).

When the request doesn't make the target obvious, ask which it is before spending
the analysis.

## 1. List the sessions and scope to the goal

The transcripts are the source of truth, not memory. List them (always run via
`uv`):

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/read_sessions.py --list  # every project
uv run ${CLAUDE_SKILL_DIR}/scripts/read_sessions.py --project . --list  # just this repo
```

With no `--project` it scans every project under `~/.claude/projects/` and prefixes
each line with its project; with `--project` it scopes to one repo. Each line is
`[project]  id  timestamp  message-count  first-user-message`. Match the scope to
the goal: all projects for a global harvest, the current repo for a project-specific
one. `--sessions N` limits to the N most recent.

## 2. Fan out: one subagent per session

Spawn a subagent (general-purpose) per session, or per small batch if there are
many. This keeps the megabytes of transcript out of the main context; each
subagent spends *its own* context reading one session deeply. Give each a
self-contained task like:

> Analyze one Claude Code session for lessons worth encoding into Claude config
> (rules, skills, hooks, CLAUDE.md, etc.).
> Read it (user/assistant text and tool calls/errors, labeled and in order) with:
>
> ```bash
> uv run ${CLAUDE_SKILL_DIR}/scripts/read_sessions.py --project <PROJECT> --session <ID> --tools
> ```
>
> Read the whole thing and report what a future Claude should learn from it. Look
> for: corrections the user made, preferences they stated, naming/vocabulary
> debates, friction hit more than once, insights you surfaced that aren't obvious,
> and tool-usage lessons (repeated wrong flags, denied commands, hook blocks).
> Don't work from a fixed checklist; report whatever is genuinely instructive.
>
> For each finding give: a one-line general principle, the evidence (quote the
> message(s), with role), and whether it's **general** (applies to any project) or
> **project-specific**. Return a short list; "nothing notable" is a fine answer.

The open-ended prompt matters: the subagent's judgment reading the actual session
beats any list of things to grep for. The script handles the mechanical cleanup;
the subagent handles the interpretation.

## 3. Synthesize across the reports

Collect the reports and look for **themes**: a lesson that shows up in several
sessions is structural, not a one-off, and is the strongest candidate. Then:

- **Filter to the goal** (see Decide the goal first): for a global harvest, drop
  project-specific findings; for a project-specific one, keep them.
- **Dedup against existing config.** Read the target config's rules and skills (this
  dotfiles repo for a global harvest; the project's `.claude/` and `CLAUDE.md` for a
  local one) and decide, per theme, whether it's already covered, an extension, or a
  real gap. A well-tended config already encodes most of what a mature project does,
  so expect most findings to be "already covered", say so, and note what works well.
- **Verify** any factual claim (a tool's behavior, a library gotcha) before acting
  on it; session-recalled facts drift.

## 4. Classify and route

Don't hand-write the rule or skill here; route to the specialist skill that owns
the house style and the existing-vs-new decision:

| Finding | Route to |
|---|---|
| A convention, preference, or style point | `rule-curator` skill |
| A repeatable multi-step workflow worth its own command | `skill-creator` skill |
| An automatic behavior, guardrail, or context injection | `hook-creator` skill |

## 5. Present, then implement

Show the user the surviving findings **ranked by value, each with its evidence**
(quoted session messages), so the recommendation is auditable. Note what's already
covered separately and briefly. Get buy-in on which to act on, then implement the
chosen ones through the routed skills.

## The script

`read_sessions.py` turns a session's noisy jsonl (mostly tool-result payloads and
file dumps) into clean, labeled conversation, so a subagent can read a whole
session cheaply.

- `--list` — one line per session, for assigning work in step 1.
- `--session <id>` — dump one session (the per-session subagent view).
- `--tools` — also include tool calls and tool errors/denials (the tool-usage
  signal); without it you get just user/assistant text.
- `--project` (omit to scan all projects), `--sessions N`, `--min-len`,
  `--max-chars` — scope and trim.

Output labels each line by role: `user`, `assistant`, `tool`, or `error`.

## Gotchas

- **The `user` role is noisy.** Tool results, slash-command output, pasted skill
  bodies, interrupt markers, and system reminders all arrive as `type: "user"`.
  The script filters these; a subagent reading raw jsonl instead would drown.
- **Path encoding.** The transcript dir is the project path with every
  non-alphanumeric char replaced by `-`. The script falls back to matching by
  basename when the exact path isn't resolvable, and lists candidates if
  ambiguous.
- **Dedup is by prefix** (first 200 chars, per role), so near-identical re-pastes
  collapse; two genuinely different messages sharing a long prefix would too.
- **Recency is by file mtime**, not conversation time: a resumed old session sorts
  as recent.
