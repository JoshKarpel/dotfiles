#!/usr/bin/env bash

# shell detection
function shell() {
  ps -p $$ -o comm -h
}
