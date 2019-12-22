#!/usr/bin/env bash

function cn() {
  conda create -y -n $@ && conda activate $1
}
