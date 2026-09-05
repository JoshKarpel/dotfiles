# fauxto

Faux auto: run every Bash command from a generated script file, so one allow
rule covers the commands the permission matcher can't analyze.

This covers what the plugin does, how to turn it on, and what it costs.
It does not cover Claude Code's permission system generally; see
[Configure permissions](https://code.claude.com/docs/en/permissions).

## The problem

Claude Code auto-approves a Bash command only when it can statically prove the
command matches an allow rule.
A command carrying a pipe, a command substitution, or a variable expansion
can't be proven, so it prompts, and no number of allow rules changes that:
the refusal is about the command's _shape_, not its content.
Auto mode's classifier is the intended answer, and where managed settings set
`permissions.disableAutoMode` there is no classifier to fall back on.

## How it works

A `PreToolUse` hook writes the command verbatim to
`<root>/<session>/cmd-<hash>.sh` and rewrites the tool input to
`bash <that path>`.
Every Bash call then reaches the permission system in one fixed,
metacharacter-free shape, which a single rule covers:

```json
{ "permissions": { "allow": ["Bash(bash /tmp/claude-fauxto-1000/*)"] } }
```

Substitute your own uid.
`FAUXTO_ROOT` overrides the root if you want it somewhere else; the default is
`${TMPDIR:-/tmp}/claude-fauxto-$UID`.
The `claude-` prefix is load-bearing: `claude-rm-scope-check` treats
`/tmp/claude-*` as scratch space, so generated scripts stay deletable.

The hook returns no permission decision of its own.
It normalizes the form of the call and leaves the decision to the permission
system, which is what keeps this a rule you wrote rather than a hook that says
yes to everything.
Set `FAUXTO=off` to disable the rewrite without disabling the plugin.

## Install

The plugin lives under `claude/skills/`, so `bin/link-claude` deploys it:
any folder under a skills directory holding a `.claude-plugin/plugin.json`
loads as `<name>@skills-dir` with no marketplace and no install step.
Elsewhere, copy the directory into `~/.claude/skills/`.

It ships disabled (`defaultEnabled: false`, Claude Code v2.1.154+).
Turn it on with `/plugin`, or `claude plugin enable fauxto@skills-dir`, or an
`enabledPlugins` entry in `settings.json`.
Then add the allow rule above.

Without that rule the plugin makes things worse rather than better:
every command prompts, and prompts with an opaque hash instead of the command
text.

An admin can block this deployment path with `strictKnownMarketplaces`, or by
adding `{"source": "skills-dir"}` to `blockedMarketplaces` in managed settings.
`allowManagedHooksOnly` and `strictPluginOnlyCustomization` also govern whether
plugin hooks load at all.

## What it gives up

**Deny rules stop seeing the command.**
A `deny` entry for `Bash(git push*)` does not match
`bash /tmp/claude-fauxto-1000/.../cmd-1a2b3c.sh`.
This is the real cost, and it is not recoverable by reading the script
afterwards, because by then it has already run.
`no-rewrite-patterns.txt` is the counterweight: a command matching any regex
there is left alone and faces the normal flow in its original text.
Add to it anything you rely on a deny rule to stop.

**Other `PreToolUse` hooks are unaffected.**
Hooks in a matcher group all receive the original, unrewritten command, so
command-inspecting hooks such as `claude-rm-scope-check` keep working as
written.

**The transcript shows a hash.**
The hook copies the original command into the tool input's `description` so the
UI still shows what ran, but the command line itself is a path.
The scripts stay on disk for the session, so `cat <root>/<session>/*.sh` is the
audit trail.

**Persistent shell state is not a concern here.**
Claude Code resets the working directory between Bash calls and does not carry
exported variables across them, so running the command in a subshell loses
nothing.
Verify with two calls (`cd /tmp && pwd`, then `pwd`) if that ever changes.

## Verify

Run the hook's self-tests, which is what `claude-hook-selftests` and pre-commit
do:

```bash
CLAUDE_HOOK_SELFTEST=1 hooks/fauxto-rewrite
```

End-to-end, with the plugin enabled and the allow rule in place, ask for a
command the matcher can't prove, such as `whoami | tr a-z A-Z`.
It should run without a prompt, and the corresponding `cmd-<hash>.sh` should
hold that exact pipeline.
