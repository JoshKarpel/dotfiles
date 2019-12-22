#!/usr/bin/env bash

function cn() {
  conda create --yes --name $@ && conda activate $1
}
