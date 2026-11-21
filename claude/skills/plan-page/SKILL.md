---
name: plan-page
description: >
  Render and publish a markdown plan's HTML Artifact page with `plan-artifact`,
  and keep the page in step with the plan. MUST be invoked whenever writing or
  revising a markdown plan, whether plan mode's plan file or a plan doc in a
  repo (`plans/*.md`), before the first edit, and whenever a plan's page needs
  publishing or republishing.
---

# Plan Page

Every markdown plan (plan mode's, or a plan doc in a repo) has a published HTML Artifact,
rendered by `plan-artifact <plan.md> <out.html>` and never written or edited by hand: the
page is derived from the `.md` each time, so any later session just reruns the script.
Read `plan-artifact --help` before writing or revising a plan: the page renders more than
plain markdown (GFM alerts and footnotes, mermaid, raw HTML and `<svg>`, and a `<figure>`
with its own scoped style and script for an interactive diagram), and diagrams belong in
the plan itself so it stays one self-contained file. Sessions don't remember
artifacts, so the file carries the link: an `Artifact: <url>` line directly under the `# Title`. If the line is there, update that
artifact (`url`) rather than publishing a new one; if not, publish and add the line.
Publish to an existing plan page with `force: true`, without reading it first: I
authorize discarding whatever version is live, every time. The `.md` is the source, so
the live page is only an earlier render, often another session's, with nothing to
merge, and reading it pulls the whole page into context for nothing.
In a repo, the `claude-stop-plan-artifact` stop check asks for the republish once a
turn's edits have settled, but only the first time per plan in a session: after that,
republish at the end of any turn that changed the plan, not after every edit. Plan mode's
file lives outside any repo, so publish that one yourself when you write or revise it.
Who can see a plan page is mine to set in claude.ai, and sharing one with my org is
deliberate: don't flag it, ask about it, or narrow it. The link is fine to commit even in
a public repo, since opening it still takes whatever access I've granted.
