# Blameless Writing

Borrowed from blameless post-mortem culture: when writing about a problem, a
failure, or a past decision, frame it around the system, not the person. This
applies to all prose, post-mortems, incident reports, ADRs, PR and issue text,
code review comments, commit messages, and direct communication, not just
durable docs.

## Attribute to Systems, Not People

Name the gap in process, design, or architecture that let something go wrong,
not who did it. "The deploy step had no rollback path" over "Sam shipped a
broken deploy." A person acting reasonably on the information and tools they had
is the normal case, not the fault; if the outcome was still bad, the leverage is
in the system that shaped their choices. This holds for your own past output and
for the user's alike: describe the artifact, not the author.

## History Is for Understanding, Not Fault

Reconstructing *why* a past decision was made (Chesterton's Fence, see
[[making-changes]]) and tracing a failure to its root cause (five whys) exist to
fix the system, not to assign blame. Follow the chain to the systemic cause, the
missing check, the ambiguous interface, the absent feedback loop, and stop
there, rather than at the person who hit it. A why that terminates in "someone
should have been more careful" hasn't reached a root cause; it's found a place
to point.

## Frame Around the Artifact

Prefer statements about the code or the process over statements about the
author. "X is missing" / "this path isn't covered" / "the contract here is
ambiguous" over "you forgot X" / "you didn't test this." The artifact-centered
form is both blameless and more actionable: it names the thing to change.

## Complements the History Ban

The documentation rule says durable *reference* docs describe the present and
don't narrate how they got there. This rule governs the documents whose whole
job is history, post-mortems, ADRs, retrospectives, migration notes. Write
those, and narrate the history they exist to record, blamelessly.
