#!/usr/bin/env bash
# The `notify_command` this machine's escapement server is configured with: mail a note to
# whoever owns this VM, through the exe.dev gateway.
#
# The server's own configuration names it rather than a loop file, because escapement fires it in
# the server's process against every target it watches, which is a wider grant than one repository
# should hold. It lives in this repository all the same: reaching a person is a fact about the
# machine, and this is where the machine's configuration is kept.
#
# Escapement runs it once a note is waiting, with everything about that note in the environment
# under `ESCAPEMENT_`. `SUBJECT` and `BODY` hold the whole note as prose, which is all an email
# needs; the rest (RUN, BRANCH, WORKTREE, RESUME, COST_USD, and the others) is there for a hook
# that wants to say something narrower, and a note about a target rather than a run carries only
# the few of them that mean anything.
#
# The owner address is asked of the reflection integration rather than written down here: a VM
# changes hands and is renamed, and a baked-in address sends somebody else's review notes to the
# wrong inbox.

set -euo pipefail

owner=$(curl -sf https://reflection.int.exe.xyz/email | jq -r .email)

jq -n \
  --arg to "$owner" \
  --arg subject "$ESCAPEMENT_SUBJECT" \
  --arg body "$ESCAPEMENT_BODY" \
  '{to: $to, subject: $subject, body: $body}' |
curl -sf http://169.254.169.254/gateway/email/send \
  -H 'content-type: application/json' \
  --data-binary @-
