---
name: skill-creator
description: >
  Create, improve, and troubleshoot Claude Code agent skills. MUST be invoked when asked
  to make a new skill, write a SKILL.md file, improve skill discoverability,
  debug why a skill isn't activating, answer questions about skills, or review
  skill best practices.
---

# Skill Creator

Create well-structured Claude Code skills that are discoverable and effective.

## Skill Setup

```text
.claude/skills/my-skill-name/
├── SKILL.md                    # Required: main definition file
├── scripts/                    # Optional: automation scripts
│   └── build.py
├── assets/                     # Optional: templates, samples, data
│   └── template.html
└── references/                 # Optional: reference documentation
    └── api-guide.md
```

Use the template at [assets/SKILL.template.md](assets/SKILL.template.md) as a starting SKILL.md file.

Load the `style-markdown` skill when writing or editing SKILL.md files — they are markdown
and the same formatting rules apply.

Upstream documentation on skills is available [here](https://code.claude.com/docs/en/skills).
The rest of this document provides guidelines and best practices for creating high-quality
skills that are valuable to future Claudes and that have a high likelihood of being used.

## Writing Discoverable Descriptions

The only things Claude sees before using a skill are the name and description in the
frontmatter. Optimizing the description is key to making it discoverable. In general, Claude
is too conservative when deciding whether to use a skill. Maximize the likelihood of Claude
using the skill by writing a description that captures the full scope of both **what** the
skill does and **when** the skill should be used (and make sure to include *both*!). If Claude
loads a skill then decides not to use it, no big deal. If Claude doesn't load a skill and
spends time spiralling on an already solved task, the session is ruined. High skill
discoverability is *extremely important*.

Don't rely on users saying magic words. Think about what *situations* call for this skill,
including ones where Claude should decide to use it on its own, then write a description that
captures those scenarios.

Use RFC 2119 keywords in descriptions to eliminate rationalization. "Use when X" gives Claude
room to argue "this seems simple enough to skip." Replace it with "MUST be invoked when X" to
make the trigger mandatory. Use MUST for non-negotiable triggers, SHOULD for strong-but-optional
ones.

The combined `description` + `when_to_use` text is truncated at 1,536 characters in the skill
listing. Use `when_to_use` for additional trigger phrases and example requests that would
clutter the main description — it's appended to `description` and counts toward the same cap.
Use folded YAML (`description: >`) to keep long descriptions readable in the source file —
the `>` collapses the wrapped lines into one logical string, which satisfies the single-line
requirement while avoiding an unwieldy one-liner.

Here are some good examples of discoverable frontmatters:

```yaml
---
name: speedreader-web
description: >
  Handles SpeedReader server lifecycle (build, startup, shutdown) and web page
  rebuild/refresh. Use when you need to verify a web page works, view it, test
  UI interactions, or see how a page behaves. Also covers development tasks:
  creating, modifying, styling, reviewing.
---
```

```yaml
name: pdf
description: >
  Toolkit for viewing, reading, extracting text, creating, editing, converting,
  and transforming PDFs. Use whenever you need to work with or interact with
  PDF files.
```

If Claude isn't picking up a skill despite a good description, run `/doctor` to check whether
the description budget is overflowing and which skills are affected. The budget scales at 1%
of the model's context window; skills you invoke least lose their descriptions first.

## Frontmatter Fields

Key fields beyond `description` and `when_to_use`:

- `disable-model-invocation: true`: Only you can invoke the skill; Claude won't trigger it
  automatically. Use for side-effect workflows like `/deploy` or `/commit`.
- `user-invocable: false`: Only Claude can invoke. Use for background knowledge skills that
  aren't meaningful as direct commands.
- `allowed-tools`: Pre-approves listed tools while the skill is active, skipping per-use
  permission prompts. E.g. `allowed-tools: Bash(git *) Read`.
- `paths`: Glob patterns limiting when the skill auto-activates. E.g. `paths: "**/*.py"`
  to activate only when working with Python files.
- `context: fork` + `agent`: Runs the skill in an isolated subagent. Set `agent` to
  `Explore`, `Plan`, or a custom agent name.
- `hooks`: Scopes hooks to the skill's own lifecycle instead of registering them globally in
  `settings.json`. Useful for guardrails that should only bite while a specific workflow is
  active — e.g. a skill that blocks destructive commands (`rm -rf`, `DROP TABLE`) only while
  it's debugging, or restricts edits to a subset of directories only while it's running. This
  avoids the friction of a permanent, always-on hook while still providing guardrails when
  they matter.

## Skill Content Lifecycle

When invoked, rendered `SKILL.md` content enters the conversation and stays for the rest of
the session. After compaction:

- Each invoked skill is re-attached, keeping its first 5,000 tokens.
- All re-attached skills share a 25,000-token combined budget.
- Least-recently-invoked skills are dropped first if the budget overflows.

Keep `SKILL.md` under ~500 lines; move detailed reference material to supporting files in
the skill directory.

## Skill Categories

When you're hunting for the next skill worth writing, here are a few shapes that skills tend
to take in practice (loosely drawn from how Anthropic's own team uses them). Treat these as
food for thought rather than a taxonomy to satisfy — most real skills blend categories or
don't fit neatly into any of them, and that's fine:

1. **Library & API reference** — usage guides, gotchas, and code snippets for a tool,
   library, or API the model would otherwise have to rediscover each session (e.g.
   `hook-creator`, `python-profiling`).
2. **Product verification** — testing workflows, browser drivers, and assertion patterns for
   confirming that a change actually works.
3. **Data fetching & analysis** — connection libraries, query patterns, and dashboard/field
   mappings for pulling and interpreting data.
4. **Business process automation** — repetitive multi-step workflows with state tracked
   across runs (e.g. `handle-pr-review`).
5. **Code scaffolding** — generating framework boilerplate that follows your project's
   conventions.
6. **Code quality & review** — style enforcement, testing practices, and review guidance
   (e.g. the `style-*` family).
7. **CI/CD & deployment** — build, test, rollout, and rollback orchestration.
8. **Runbooks** — symptom-to-investigation mappings with structured reporting, for
   diagnosing recurring problems (e.g. `debug-gha`).
9. **Infrastructure operations** — maintenance procedures with safety guardrails for risky,
   hard-to-reverse operations.

If a recurring task in this repo seems to fit one of these shapes, that's a hint it might be
worth turning into a skill, not a rule that it must be.

## Patterns

### Toolbox

The toolbox pattern is implemented by skills that contain non-trivial automation scripts
(AKA "tools") and teach Claude how to use them. SKILL.md provides context and information
about how to properly use the tools; the tools themselves are python scripts that encapsulate
complexity and run commands without clogging up Claude's context window or making silly
mistakes. This helps keeps Claude focused on *when* and *how* to invoke tools rather than
repeatedly reimplementing their logic, which over the course of a long session substantially
increases reliability.

Bash is fine for simple wrappers (a few commands, no parsing). For anything with non-trivial
logic — parsing, data transformation, multi-step operations, error handling — prefer python.
Run shell commands with `subprocess.run`. Don't use shell commands for operations that could
be performed in python (file manipulation, hashing, regex, etc). When done properly, these
scripts are trivially portable across platforms.

Always use `uv` with inline dependencies. In the SKILL.md text, make it clear that the
scripts must be invoked with `uv`. If you're not *extremely clear* that Claude should use
`uv`, Claude **will** try to run the scripts with `python3` and then be confused when it
doesn't work.

Reference bundled scripts with `${CLAUDE_SKILL_DIR}` so the path resolves correctly regardless
of where the skill is installed (personal, project, or plugin). Example in SKILL.md:
`uv run ${CLAUDE_SKILL_DIR}/scripts/analyze.py`

Design the API of scripts with care. Always provide `--help`. Avoid exposing unneeded
configuration parameters. Scripts should create clean abstractions for Claude to consume.
As Claude works, contents of SKILL.md will fade but the script's API will remain, so make
sure it's good.

### Knowledge Injection

To summarize: Neo learns Kung Fu.

A knowledge injection is when you give Claude a batch of valuable knowledge that it didn't
have before that lets it do new things. Examples:

1. Teach Claude how to use a command line tool or python package (for ad-hoc scripting)
2. Give Claude a knowledge dump to make it instantly an expert on a topic
3. Guide Claude through a complex, nuanced workflow

Use `references/` to store documents. If appropriate, use progressive disclosure
(e.g. "Depending on the platform, read docs/gcp.md, docs/azure.md, or docs/aws.md").

### Gotchas

The highest-signal content in a skill is often a running list of the specific ways Claude has
gone wrong while using it: field names that differ between two systems it has to bridge,
data that's append-only where Claude expected to be able to mutate it, an API that behaves
unintuitively, a step that's easy to skip and breaks everything downstream. Keep this list —
inline in SKILL.md or as a dedicated `gotchas.md` referenced from it — and add to it whenever
Claude trips over something new.

### Dynamic Context Injection

Shell commands can be embedded in a skill file and are executed before the content reaches
Claude, substituting their output inline so skills arrive with live data already embedded.
Inline commands use an exclamation mark followed by the command wrapped in backticks. For
multi-line commands, open a fenced block with `!` as the language specifier (three backticks
immediately followed by `!`) instead of a language name. This is preprocessing only: Claude
sees the rendered result, not the command itself. Use `${CLAUDE_SKILL_DIR}` to reference
scripts bundled with the skill regardless of where it's installed.

### Parameterized Skills

Use `$ARGUMENTS` to capture text passed after the skill name when invoked:

```yaml
---
name: fix-issue
disable-model-invocation: true
---

Fix GitHub issue $ARGUMENTS following our coding standards.
```

Access individual arguments by position with `$0`, `$1`, etc. (shorthand for
`$ARGUMENTS[0]`, `$ARGUMENTS[1]`). For named arguments, declare them in frontmatter:

```yaml
---
arguments: [component, from_framework, to_framework]
---

Migrate the $component component from $from_framework to $to_framework.
```

## Principles

### Valuable Knowledge

A common pitfall is for Claude to create skills and fill them up with generated information
about how to complete a task. The problem with this is that the generated content is all
content that's already inside Claude's probability space. Claude is effectively telling itself
information that it *already knows*!

Instead, Claude should strive to document in SKILL.md only information that:

1. Is outside of Claude's training data (information that Claude had to learn through
   research, experimentation, or experience)
2. Is context specific (something that Claude knows **now**, but won't know **later** after
   its context window is cleared)
3. Aligns future Claude with current Claude (information that will guide future Claude in
   acting how we want it to act)

Claude should also avoid recording **derived data**. Lead a horse to water, don't teach it
how to drink. If there's an easily available source that will tell Claude all it needs to
know, point Claude at that source. If the information Claude needs can be trivially derived
from information Claude already knows or has already been provided, don't provide the derived
data.

Before finalizing a skill, revisit this section. Often cruft will creep in over the course
of writing the skill. A strong editing pass at the end is recommended.

### Automation

Over the course of a long session, Claude **will** screw up even simple tasks. Typos,
forgotten flags, wrong directories, skipped steps. By pushing tasks into automation, we
substantially improve long-term reliability. The goal is to reduce the surface area for
Claude to make mistakes.

Good automation is:

1. **Single-touch**: Fold setup and teardown into the tool itself. If we can perform a step
   in python instead of making Claude do it manually, do it in python. Always. One command
   should do the whole job.

2. **Clean primitives**: Expose composable operations that can be combined. Avoid tools that
   do too much or have complex interdependencies. The goal is to expose a simple API to
   Claude that frees up Claude's attention for higher-value activities.

3. **Repo-specific**: The most powerful automation is usually repo-specific because that's
   where the low-hanging fruit is. Generic tools already exist; the unique workflows and pain
   points in your repo are where automation pays off most. Teaching Claude how to use a
   generic tool in your repo is high-leverage.

### Avoid Railroading

Automation (above) is for the mechanical, order-dependent parts of a workflow — the parts
where judgment doesn't help and slip-ups are costly. Don't extend that same rigidity into
prose instructions for the parts of the task that benefit from Claude reading the situation.
An overly prescriptive skill — rigid step-by-step scripts for things that actually call for
judgment — fights the model instead of informing it. Give Claude the information,
constraints, and context it needs, then trust it to figure out how to apply them; it adapts
to the specifics of a situation better than a procedure written in advance can.

### Qualifications

Claude can't create a skill if Claude doesn't already know how to do the skill. Before
creating a skill, Claude should experiment with the workflows itself. Research CLIs and
libraries, download them, try things out, see what's possible, think of things to try and
see if they work. Then write the skill using that research and experience. Make sure not to
include speculation!

This is related to Valuable Knowledge. Skills must add value. The best way to do that is to
invest time and effort up front in creating the skill so that when Claude loads it later the
skill is a value add rather than a drag on the context window.
