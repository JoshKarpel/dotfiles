#!/usr/bin/env bash

function check_htmap_usage() {
  condor_q -all -const "IsHTMapJob" $@
}
