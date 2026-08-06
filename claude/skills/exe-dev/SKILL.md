---
name: exe-dev
description: >
  Work with exe.dev: VMs and the `ssh exe.dev` CLI, `*.exe.xyz` hostnames and
  HTTPS proxies, sharing and custom domains, integrations (GitHub, LLM, Slack,
  AWS/GCP workload identity), teams, billing, the HTTPS API, and the Shelley
  agent. Pulls the live docs from exe.dev at use time, so answers track the
  current product instead of a stale copy or model memory. MUST be invoked
  whenever exe.dev, `ssh exe.dev`, an exe VM, `*.exe.xyz`, exe.dev sharing, or
  Shelley comes up: answering questions about how exe.dev works or what it
  costs, creating/resizing/deleting/sharing a VM, deploying or running a
  service on one, wiring up a custom domain or integration, debugging SSH,
  scp, proxy, or dev-server-host errors against a VM, or writing scripts
  against the exe.dev CLI or HTTPS API.
allowed-tools: Bash(curl -sS https://exe.dev/*) Bash(exe-dev lobby help*) WebFetch
---

# exe.dev

exe.dev serves its documentation as raw markdown, so the current docs are one
`curl` away. Fetch them; never answer from memory, and never treat this file as
the reference. exe.dev ships often, so anything recalled rather than fetched is
a guess about a moving target.

## Fetch the docs

Start with the index, which lists every page with a one-line summary:

```bash
curl -sS https://exe.dev/llms.txt
```

Pick the pages that match the question and fetch each one, one `curl` per page,
with no pipe into `head`, `grep`, or similar. The pages are already markdown and
already short; truncating or filtering them loses the part you needed.

```bash
curl -sS https://exe.dev/docs/proxy.md
```

Every documentation URL ends in `.md` and returns the page verbatim. Prefer
`curl` over `WebFetch` for these: `WebFetch` summarizes through a small model,
which is the wrong trade for reference text you are about to quote or follow
exactly. Use `WebFetch` for `https://blog.exe.dev/`, which is HTML rather than
markdown.

`https://exe.dev/llms-full.txt` is every doc concatenated, around 65k tokens.
Reach for it only when a question genuinely spans the whole corpus, such as
"where is X mentioned"; otherwise the index plus two or three pages costs a
fraction of it.

Fetch again in a later session rather than relying on what a previous one
found. That is the entire point of this skill.

## Ask the CLI, not the docs, for the CLI

The lobby prints its own current surface, which beats any page describing it:

```bash
exe-dev lobby help
exe-dev lobby help <command>
```

Many commands take `--json`, which is the right form when the output feeds a
script or another command.

## Two SSH destinations

The single most common source of confusion, and worth knowing before any fetch:

- `exe-dev lobby <command>` reaches the lobby, which manages VM lifecycle,
  sharing, integrations, and billing. It runs its own command set, not a shell,
  and does not support `scp` or `sftp`.
- `exe-dev ssh <vm>` reaches a VM. It is ordinary SSH: shell, `scp`, `sftp`,
  port forwarding, all against the hostname `<vm>.exe.xyz`.

An `scp` or "command not found" failure against `exe.dev` is almost always a
command aimed at the wrong one of those two.

The docs write those as `ssh exe.dev <command>` and `ssh <vm>.exe.xyz`, and
they are the same two destinations. Prefer the `exe-dev` forms, from this
dotfiles repo, which check the key the far end presents against the
fingerprint exe.dev publishes before connecting, where plain `ssh` from a
machine that has not reached that host before offers an unrecognised key and
takes a yes for verification. One published fingerprint covers both, since
exe.dev terminates SSH for every `<vm>.exe.xyz` at the same front door and
proxies inward, whichever public address the hostname resolves to.

A box's own name is the exception, and `exe-dev ssh` refuses it. On a VM,
`/etc/hosts` points that one hostname at the box itself, so it reaches the VM's
own sshd rather than the front door, and that sshd authorizes only exe.dev's
proxy. Every other VM is reached the same way from a VM as from a laptop.

Both forward their trailing arguments verbatim, so anything a doc page writes
as `ssh exe.dev X` runs as `exe-dev lobby X`, and `ssh <vm>.exe.xyz X` runs as
`exe-dev ssh <vm> X`.

## Confirm before mutating

Lobby commands that destroy, resize, rename, or expose a VM (`rm`, `resize`,
`rename`, `share`, `domain`, `grant-support-root`) change real infrastructure
and some are irreversible. Read the command's help, state what you are about to
run and to which VM, and get an explicit go-ahead. Read-only commands (`ls`,
`stat`, `whoami`, `help`) need no such ceremony.

## Docs to reach for by name

The index carries the full map. These three are worth knowing without it:

- `https://exe.dev/docs/release-notes.md` when behavior does not match what a
  page or a previous session described.
- `https://exe.dev/docs/faq/` pages for agent-hostile specifics: host keys,
  choosing an SSH key, `scp`, cross-VM networking, and the
  `allowedDevOrigins` / `server.allowedHosts` settings that Next.js and Vite
  need before they will answer on an `exe.xyz` hostname.
- `https://exe.dev/docs/api.md` and `https://exe.dev/docs/https-api.md` for
  programmatic access, over screen-scraping the CLI.

## Deploying a service, and redeploying it

exe.dev has no CD product: a VM is a persistent computer, so deployment is
whatever it would be on a box you own. The docs cover the pieces (`--setup-script`
at first boot, `share port`, custom domains, VM bearer tokens from
`ssh-key generate-api-key --vm`); what no page states is how a *change* reaches a
box that is already running.

Prefer pulling on a timer over pushing from CI. A systemd timer on the VM polls
the remote ref and, when it has moved, pulls, reinstalls, and restarts the
service unit. The alternative, a CI job that reaches in over SSH or POSTs to a
deploy endpoint, puts a credential for the VM into CI and converges only when CI
happens to run. The poll converges from any starting state, needs no inbound
credential, and keeps the deploy machinery off whatever the service itself is
doing.

Two details make it cheap. A GitHub integration attached to the VM serves the
repo at `https://github.int.exe.xyz/<owner>/<repo>.git`, so the pull needs no
token on the VM. And systemd is PID 1 on the exeuntu image, so the timer and the
service are both units and "redeploy" is `systemctl restart`.

Put the same clone-and-install in `new --setup-script` so a fresh VM, or a `cp`
of an existing one, comes up already running instead of needing a first deploy by
hand.

## Non-interactive SSH

Agents run SSH without a TTY, where a host key prompt hangs with no output.
`exe-dev ssh <vm> <command>` settles the key against the published fingerprint
instead of prompting, which is why it is the form to reach a VM with here
rather than `-o StrictHostKeyChecking=accept-new`, which accepts whatever the
far end happens to offer. Pass an explicit `timeout` to any `ssh` call that
might block regardless.
