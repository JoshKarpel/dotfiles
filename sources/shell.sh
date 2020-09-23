#!/usr/bin/env bash

# shell detection
function shell() {
  ps -p $$ -o comm -h | tail -n 1 | sed 's/-//'
}
