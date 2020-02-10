#!/usr/bin/env bash

alias cq="condor_q"
alias cwq="condor_watch_q"
alias cs="condor_status"

function check_htmap_usage() {
  condor_q -all -const "IsHTMapJob" $@
}
