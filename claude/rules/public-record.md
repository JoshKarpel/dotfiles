# The Public Record

What may go into anything that lands in a repository or on GitHub: commit
messages, PR and issue text, review comments, code comments, docs, and plans.
Secrets are the secrets rule's concern and a scanner's; this is the larger case
no scanner can catch, because it turns on where the text came from rather than
what it looks like.

## Write for Everyone Who Can Read It

The test for a piece of context is whether everyone who can read the repo
could already see it. A public repo's readers are everyone, so anything private
fails. A private work repo's readers are the organization, so naming another of
its repos or internal tools passes there, while a personal project or another
employer's work does not.

Readers widen: a repo is opened up, a fork is shared, a PR is linked from
elsewhere, and nobody rereads old commit messages before it happens. A push to
a public repo publishes at once, before anyone has looked at the text. When the
audience is uncertain, write for the wider one.

## Keep the Conversation's Context in the Conversation

What belongs in the record is what the repo's readers need: the change, the
reason for it, and the evidence it works. Context given in the conversation
that they couldn't already see stays there, however it shaped the work. These
fail the test most often:

- Projects the readers can't see, including their names: a private repo named
  in a public one, a personal project named in a work repo.
- Decision criteria resting on private business information (a customer, a
  cost, a contract, an employer's plans) that the readers don't share.
- Timelines, deadlines, and the order things will happen in. Even where the
  readers share them, they go stale, so they belong in the issue tracker rather
  than in a commit.
- Who asked for something, or why it matters to them, beyond what the change
  itself needs.

In a public repo, name another project only when it's public and the change
depends on it, such as a library the code calls or an upstream bug it works
around.

The reason survives the cut: "Batch the writes so a full sync stays under the
rate limit" carries the why without the private context that prompted it.

## Ask Rather Than Hope

When unsure whether something belongs in the record, ask before committing or
landing it. Once pushed to a public repo it is cached and indexed, and deleting
it afterwards doesn't take it back.
