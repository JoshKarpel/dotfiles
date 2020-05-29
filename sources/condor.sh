#!/usr/bin/env bash

alias cq="condor_q"
alias cwq="condor_watch_q"
alias cs="condor_status"
alias cw="condor_who -quick"

function check_htmap_usage() {
  condor_q -all -const "IsHTMapJob" $@
}

function condor_where() {
  condor_q $@ -af JobBatchName ClusterId ProcId JobStatus LastRemoteHost
}
