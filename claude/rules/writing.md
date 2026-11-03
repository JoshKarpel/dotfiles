# Writing

How to make a case in prose and back it up: argument, evidence, and scope. It
applies to any prose you write, including chat replies, docs, design docs,
READMEs, PR and issue bodies, review comments, and commit messages.

## Argument

- **Concede, then turn.** For a genuine tradeoff, grant the objection in its
  strongest form before answering it: `Although X, Y`, or a flat statement
  followed by `However`. A reader who sees their own position stated fairly
  will follow you through the turn; one who sees it strawmanned stops reading
  and starts arguing. Make the same move for pushback you can predict but
  nobody has made yet: say it out loud, then answer it. Where correctness is
  at stake, skip this: a wrong technical claim isn't an objection to weigh but
  an error to name as one, so lead with what's correct and say why the
  alternative is wrong.
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
- **Show the arithmetic, and grade it.** Put an estimate's derivation inline
  and say what kind of number it is: an upper bound, a crude figure on list
  prices, a saving that doesn't stack with the one above. Reach it from two
  independent directions where you can. Prefer unit costs (per request, per
  node-month) to a flat total that growth will invalidate, and multiply small
  per-unit costs out (a tenth of a second across two thousand tests is over
  three minutes). Give engineering effort in engineer-time per period, which
  others can convert to money.
- **Link every external reference.** A tool, library, issue, PR, commit, doc
  page, or spec gets a link where it's mentioned, so the reader needn't search.
- **Credit prior work on the link.** Where an idea, algorithm, or approach came
  from somewhere else, name the source inline where you use it.
- **Assertive prose raises the cost of being wrong.** Writing that states
  things plainly and qualifies only the specific claim makes an invented
  specific read as authoritative. A wrong flag name or half-remembered API is
  more convincing in good prose than in bad, and therefore worse. Check
  specifics against the source before writing them down, per the
  verify-empirically rule.
- **Keep what the sources say apart from what you worked out.** When the reader
  will take a claim as sourced (slides, a write-up, an issue citing a thread),
  every claim has to trace to a source you can point at; your own derivation is
  either labeled as yours or left out. The two blur easily after an
  investigation, and a measured, confident finding of your own reads exactly like
  a quotation once it's on the page.
- **Quote exactly, and copy identifiers from the source.** A quotation keeps its
  typos (mark them with `[sic]` if they matter), and a hash, issue number, URL,
  or topic ID is pasted from the page, never typed from memory or shortened.
- **"The source doesn't say" requires having read all of it.** A forum thread,
  an issue, or an API listing is often paginated, and a fetch or a `head` shows
  the first page as if it were the whole. Check the page or post count, or
  `--paginate`, before telling anyone a topic isn't discussed.

## Every Paragraph Argues

- **Cut framing that carries no claim.** "What is proposed, in one paragraph."
  "This is the chapter that ties it together." Signposting like this reads as
  machine-written and makes the document harder to read straight through. If a
  reader can't say what a paragraph argues, delete it or give it a claim.
- **Tie each motivation to the decision it justifies.** A reason that holds
  equally for the rejected option isn't a reason for this one. If the link is
  indirect, write it down.
- **Make the document self-contained.** The readers it must convince weren't
  in the meetings, so carry the meetings' conclusions into the text. Citing
  your own other document as authority is circular; argue the point on its
  merits.
- **Label unreviewed analysis as unreviewed,** in the main text: generated
  reports or unchecked numbers go out as a starting point for discussion.

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
- **Declare your stake in a perspective piece.** Open an opinion document with
  who is speaking, their vested interest, and what they don't know, so the
  reader can discount accordingly.
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
