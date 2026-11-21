---
paths:
  - "bin/claude-*"
  - "claude/settings.json"
---

# Claude Code Hooks

Hooks are registered in `claude/settings.json` and implemented as scripts in `bin/`.
Read those two for which hooks exist, what events they fire on, and what each one
does. What follows is only what neither source states.

## Design Constraints

- Hooks run in non-interactive shell subprocesses, so functions defined in
  `sources/` (e.g. `exists`) are _not_ available. Shared logic needed by hooks must
  be a standalone script in `bin/`, not a sourced function.
- Hooks registered together in one group run in parallel, with no guaranteed order.
  `claude-stop` is therefore an orchestrator rather than a group: it runs its checks
  in sequence and announces the stop only when none of them blocked, so an
  announcement means Claude is actually stopping rather than retrying after a block.
- Stop hooks return JSON: `additionalContext` carries a message to Claude, and the TUI
  shows it too, while `systemMessage` is a brief indicator for the user alone.
- Text a hook emits, whether context, a block reason, or a refusal, puts each paragraph on
  one line. The TUI wraps it to the terminal's width, so a hard wrap at the source's width
  shows up as ragged lines. In Python, adjacent string literals keep the source wrapped
  while the output stays unwrapped.
- A hook that auto-approves has to prove the _whole_ command is safe, while one that
  blocks needs only a single bad segment. `claude-gh-api-check` and
  `claude-awk-check` are both built around that asymmetry: `allow` requires every
  segment to be read-only, and anything unproven emits nothing so the call falls
  through to the normal prompt.
- `claude-prompt-snapshot` is the shared answer to "did this prompt change the
  repo?". Registered on `UserPromptSubmit`, it records `HEAD` and a change-set
  fingerprint (the tracked diff against `HEAD` plus the untracked file list) under
  the git directory, keyed by `prompt_id`, and the stop checks compare against
  that. Comparing `HEAD` as well matters because a turn that ends in a commit
  leaves the tree clean, and comparing against the prompt's start rather than the
  last nudge is what keeps edits made between prompts from counting. A `!` command's
  turn fires no `UserPromptSubmit`, so a prompt without a snapshot adopts the
  worktree's last stop as its start; only with no earlier stop does it count as
  changed. It also holds
  the once-per-prompt record every asking check shares (`ask`), which is what lets
  the question gate in `claude-stop` skip the model call once no check can still
  ask. The plan in `plans/letting-claude-commit-and-push.md` diagrams the whole
  stop sequence.
- `claude-stop-precommit` records the fingerprint it last passed, and
  `claude-stop-commit` asks for a commit only over that exact tree. The precommit
  check reports each failing state once per prompt and then goes quiet, so without
  the match the sequence would reach the commit check over a state pre-commit
  never passed.
- A hook whose only job is a side effect still has to keep all three channels clean:
  the event decides how stdout is read (on `PreToolUse` a JSON object there is a
  permission decision), stderr surfaces in the TUI, and a non-zero exit reads as a
  hook error. `claude-sound` therefore swallows the failure of a player that is
  installed but has no audio server to reach, which is every headless VM.
- The `deny` list in `settings.json` stays thin on purpose. `claude-rm-scope-check`
  decides whether an `rm` escapes the work area, so `deny` keeps only the
  never-in-scope catastrophic backstops it can't reason about.
