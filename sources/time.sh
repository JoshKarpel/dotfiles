#!/usr/bin/env bash

function now() {
  date +%s
}

function when() {
  ~/.python/bin/python -c "import humanize, datetime; dt=datetime.datetime.fromtimestamp($1/1000 if len('$1') == len('1619385800593') else $1); print(dt); print(humanize.naturaltime(datetime.datetime.now() - dt))"
}

function humanize() {
  ~/.python/bin/python -c "import humanize, datetime; print(humanize.naturaldelta(datetime.timedelta(seconds=$1)))"
}
