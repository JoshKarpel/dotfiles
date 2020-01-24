#!/usr/bin/env bash

# conda
alias ca="conda activate"
alias cu="conda update -y --all"
alias ci="conda install -y"
alias ce="conda env list"
alias cr="conda env remove -n"
alias cla="conda clean -y --all"

function cn() {
  # we actually want to split elements here, so that you can pass the name as
  # well as packages to install immediately
  conda create --yes --name $@ && conda activate $1
}
