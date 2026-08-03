# Writing

How to make a case in prose and back it up: argument, evidence, and scope. It
applies to any prose you write, including chat replies, docs, design docs,
READMEs, PR and issue bodies, review comments, and commit messages.

## Argument

- **Concede, then turn.** Grant the objection in its strongest form before
  answering it. `Although X, Y`, or a flat statement followed by `However`.
  A reader who sees their own position stated fairly will follow you through
  the turn; one who sees it strawmanned stops reading and starts arguing.
- **Voice the objection you expect.** Where a reader will push back, say the
  pushback out loud, then answer it. This is the same move applied to an
  argument you can predict but nobody has made yet.
- **Pose the real question, then answer it.** State the question in plain
  words, as a sentence, before working toward the answer. Questions work as
  section headings, as pivots, and as the frame for a whole document. A
  document that never states its question makes the reader reverse-engineer
  one.
- **Hedge the specific claim, then commit to the rest.** "This is untested on
  Windows" is a hedge; "there are tradeoffs to consider" is an evasion wearing
  a hedge's clothes. A qualifier that covers everything commits to nothing.
  See the tradeoffs rule: if you can't name what a choice costs, you haven't
  made it.
- **Name the limits in the main text.** What didn't work, what's untested, what
  you don't understand. Not in a footnote, not in a trailing caveat nobody
  reads. Stating the limits plainly is what earns belief in the parts you
  didn't qualify.

## Evidence

- **Show the artifact.** Put the real code, real terminal output, or real
  numbers immediately after the abstract claim, then add one sentence directing
  attention at what to notice in it. An example the reader has to interpret
  unaided is doing half its job.
- **Credit prior work on the link.** Where an idea, algorithm, or approach came
  from somewhere else, name the source inline where you use it.
- **Assertive prose raises the cost of being wrong.** Writing that states
  things plainly and qualifies only the specific claim makes an invented
  specific read as authoritative. A wrong flag name or half-remembered API is
  more convincing in good prose than in bad, and therefore worse. Check
  specifics against the source before writing them down, per the
  verify-empirically rule.

## Diction

- **Name the concrete thing.** Where a precise term exists, an evocative one is
  a downgrade: `seam`, `surface`, `layer`, and `boundary` all read as insight
  while telling the reader less than `trait`, `function signature`,
  `constructor argument`, or `the HTTP handler` would. Reach for the
  abstraction only when you mean several concrete things at once and the
  generalization is the point.
- **A term of art brings its condition with it.** Michael Feathers defines a
  `seam` as a place where you can alter behavior without editing in that place,
  and every seam has an enabling point. Using it for any interface, type, or
  module boundary asserts that condition where it doesn't hold, so the reader
  who knows the term is misled and the one who doesn't learns nothing.

## Scope and register

- **Open with what the document covers, and what it doesn't.** An explicit
  scope line up front costs one sentence and saves the reader deciding whether
  the answer they want is further down.
- **A review comment or issue leads with the finding.** State the plan or the
  root cause bare, in the first line, and close with the explicit ask. The
  reasoning goes between them, not in front.

## Pronouns

The split is load-bearing, so keep it consistent within a document:

- `I` for stance, preference, and admission: what you think and what you got
  wrong.
- `we` for walking the reader through an artifact, and for the project as a
  collective actor.
- `you` for the reader's own actions, actual or hypothetical.
