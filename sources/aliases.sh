#!/usr/bin/env bash

# auto color on everything
alias ls="ls --color=auto"
alias ll="ls -lh --color=auto"
alias la="ls -lha --color=auto"
alias dir="dir --color=auto"
alias vdir="vdir --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"

# move/copy verbose by default
alias cp="cp -v"
alias mv="mv -v"

# rm is always recursive
alias rm="rm -r"

# mkdir is always verbose and full path
alias mkdir="mkdir -v -p"

# cd
alias ~="cd ~"
alias ..="cd .."
alias cd..="cd .." # typos...

# procs
alias pt="procs -t"

# tar
alias mktar="tar -cvf"
alias untar="tar -xvf"

# wsl clock drift
alias fix-clock-drift="sudo ntpdate -sb time.nist.gov"

# just
alias j="just"

# watchfiles
alias w="uvx watchfiles"
