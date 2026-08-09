#!/usr/bin/env bash
# The `hooks.notify` command for this repository's escapement loops: mail the run's note to
# whoever owns this VM, through the exe.dev gateway.
#
# Escapement runs this on the server once a run has something to say, with everything about the
# run in the environment under `ESCAPEMENT_`. `SUBJECT` and `BODY` hold the whole note as prose,
# which is all an email needs; the rest (RUN, BRANCH, WORKTREE, RESUME, COST_USD, and the others)
# is there for a hook that wants to say something narrower.
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
