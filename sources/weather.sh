#!/usr/bin/env bash

function w() {
  curl -s "wttr.in/${*// /+}"
}
