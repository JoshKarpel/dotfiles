---
paths:
  - "bin/claude-shell"
  - "claude/settings.json"
  - "install.sh"
---

# Claude Code Shell Prefix

`CLAUDE_CODE_SHELL_PREFIX` in `claude/settings.json` names `bin/claude-shell`,
and Claude Code runs every Bash tool command, every hook, and every stdio MCP
server through it, handing over the whole command as one argument. Settings
hot-reload, so a change to the prefix reaches running sessions too, and a broken
`claude-shell` breaks every Bash call and every hook at once. Read and Edit do
not go through it, so a session can still repair it.

Its job today is memory. Without swap, a runaway command does not get
OOM-killed: the kernel evicts page cache, every process on the box refaults its
own code, and the VM thrashes until it is unreachable. On a systemd machine
`claude-shell` puts each command in a scope inside `claude-work.slice`, which
`do_claude_work_slice` in `install.sh` caps as a percentage of RAM. The cap
leaves room for what is _not_ in the slice, the Claude Code processes
themselves, zellij, and your own shells, so the session that started a runaway
stays responsive enough to explain the exit 137 and fix the cause. It is on the
slice rather than on each scope because a cap only has to protect the headroom,
and a slice-wide one also stops several agents' commands crowding it out together.

`systemd-run --scope` execs in place, so the command keeps the caller's working
directory, environment, standard streams, exit status, and PID, and Claude Code
stopping it reaches it directly. Commands typed into a pane by hand and the
Claude Code processes themselves are both outside the cap.

The prefix is the one place every command Claude runs passes through, so it is
where anything else about running them belongs. Filtering output through it, such
as the masking `claude-redact-secrets` does as a hook, has to account for the
stdio MCP servers that pass through it too, whose stdout is a JSON-RPC stream
rather than output to rewrite.
