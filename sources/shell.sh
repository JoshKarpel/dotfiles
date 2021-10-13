#!/usr/bin/env bash

function shell() {
  ps -p $$ -o comm -h | tail -n 1 | sed 's/-//'
}
