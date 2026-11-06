# Designs

The questions a design has to answer, whether you're writing it or reviewing
someone else's, and how to lay out the document so it supports a decision.

## Establish the Problem Before the Solution

- **Say what the proposal accomplishes.** What is wrong today, and how does the
  new shape fix it? A restructuring with no stated pain gets a question, not a
  review. Ask, too, whether it's worth building at all, given what else the
  same effort could buy.
- **Prove the simpler option fails.** The standing objection to any complex
  design is "why not something simpler?" Answer it with evidence that the
  simple version violates a requirement often enough to matter.
- **Compare against the real status quo,** warts included, not an idealized
  version. It is usually the next-best alternative.
- **Ask for the evidence.** Has the problem actually happened? Where does the
  number come from? Would the fix have helped in the cases cited? An example
  that doesn't show the claimed problem is a finding.
- **Check that the problems are what they appear.** Two stated problems may be
  one, coupled, or unrelated to the solution. A process gap may be a testing
  gap; a change may be about who does the work rather than what work needs
  doing. Stripping the domain vocabulary shows what a proposal really is, and
  sometimes that it's scoped too narrowly.
- **Separate impossible from expensive.** "No structural reason we can't, just
  effort" is a different objection from "this can't work."
- **Say when the question isn't technical.** If the decision turns on
  ownership, incentives, or politics, name that rather than arguing it as
  engineering.

## Interrogate the Mechanism

- **Ask what happens on partial failure, at every boundary:** the upload that
  fails halfway, the batch where some items fail, the crash mid-run, the
  dependency that's down at startup.
- **Ask what grows without bound,** and what state survives between runs:
  where results are written back, and whether the next run can see them.
- **Surface hidden runtime dependencies.** "This is a network call, right?"
  catches a coupling the diagram didn't show.
- **Ask what the substrate does at its limits** (eviction at maximum memory,
  maximum stream length, pod and node caps), and read the real numbers.
- **Size before reaching for machinery.** One worker handles hundreds of
  concurrent I/O-bound requests; check whether extra queues, autoscalers, or
  services buy anything at the stated load.
- **Ask what it adds over the incumbent.** Why can't the existing system, or
  the caller, do this? What does it do that a dashboard or library wouldn't?
  List its anti-capabilities, what it must never be able to do, beside its
  capabilities.
- **Add the option nobody listed:** a library instead of a service, one shared
  artifact instead of several, an in-place change instead of a new version, the
  same bucket instead of a sync step.
- **Ask why it's hard to undo.** Reversibility is asymmetric: dropping a field
  is easy, adding a required one once there are users is not. Spend scrutiny
  where reversal is expensive.
- **Ask how it's enforced.** Prefer a programmatic mechanism to a written
  policy, which counts but is the weakest mechanism there is. Will anyone hold
  the line under pressure? A review step needs stated bounds on acceptable
  change, and a soft limit should be stated as soft.
- **Test categories with a counterexample.** If the same thing lands on either
  side of a proposed boundary depending on the caller, the property is
  contextual, not intrinsic.
- **Check ownership and reach.** Does the team assigned a duty have the data
  and control to do it? Does the proposal depend on changing a system its
  authors don't control? Negotiate a hard external constraint before designing
  around it.
- **Trace requirements to their source.** Is the requirement actually mandated,
  and does the simplest existing mechanism already satisfy it?
- **Name costs imposed on others.** Pushing work onto another team may be
  fine, but call it out.

## Lay Out the Document for a Decision

- **Define the load-bearing terms first,** and disambiguate words that mean
  something else elsewhere in the organization.
- **Discuss the alternatives you rejected** and what the chosen design costs
  next to each, with space in proportion to how close each came. Drop
  dominated options.
- **Give every pro and con a magnitude.** "Provisioning takes time" says
  nothing; "minutes, not days" lets the reader weigh it.
- **Fix the appetite, then cut scope to fit.** Separate rabbit holes
  (challenges the work must overcome) from no-gos (ones it will avoid), and
  say up front what happens if the appetite proves too small: pause and
  reconsider, don't quietly extend.
- **Keep the undecided visible.** Say what you decided not to do, give each
  open question an owner, and put deferred ideas in a "future improvements"
  section rather than dropping them.
- **Lay out a decision someone else owns; don't make it.** Where the team that
  owns a choice hasn't settled it, set out the options and what each costs, and
  stop there: no ranking, no "leans toward", no filling in the owner's own doc.
  The owner holds context you lack, and a lean written into a shared document
  gets cited later as though it were the decision.
- **Label extensibility as extensibility.** When a structure could absorb
  future requirements, say those requirements don't exist yet, so reviewers
  don't argue them as scope.
- **Say what doesn't go away:** the costs that remain even if the proposal
  lands, which shrink its value.
- **Link a prototype rather than describing it at length,** and prefer prose
  and diagrams to deeply nested bullets.
