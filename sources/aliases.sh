#!/usr/bin/env bash

# auto color on everything
alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias vdir="vdir --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep--color=auto"

# move/copy verbose by default
alias cp="cp -v"
alias mv="mv -v"

# rm is always recursive
alias rm="rm -v -r"

# mkdir is always verbose and full path
alias mkdir="mkdir -v -p"

# cd
alias ~="cd ~"
alias ..="cd .."
alias cd..="cd .." # typos...

# ls
alias ll="el"
alias la="ea"

# exa
alias el="exa -l"
alias et="exa -lT"
alias ea="exa -la"

# procs
alias pt="procs -t"

# tar
alias mktar="tar -cvf"
alias untar="tar -xvf"

# tree defaults to 5 levels deep
alias tree="tree -L 5"

# screen
alias s="screen"

# wsl clock drift
alias fix-clock-drift="sudo ntpdate -sb time.nist.gov"

# pre-commit
alias pcr="pre-commit run"
alias pci="pre-commit install"
alias pca="pre-commit run -a"
alias pcaa="pre-commit autoupdate"
