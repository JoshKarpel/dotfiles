#!/usr/bin/env bash

DULL=0
BRIGHT=1

FG_BLACK=30
FG_RED=31
FG_GREEN=32
FG_YELLOW=33
FG_BLUE=34
FG_VIOLET=35
FG_CYAN=36
FG_WHITE=37

FG_NULL=00

BG_BLACK=40
BG_RED=41
BG_GREEN=42
BG_YELLOW=43
BG_BLUE=44
BG_VIOLET=45
BG_CYAN=46
BG_WHITE=47

BG_NULL=00

# ANSI Escape Commands
export ESC="\033"
export NORMAL="$ESC[m"
export RESET="$ESC[${DULL};${FG_WHITE};${BG_NULL}m"
export UNDERLINED="$ESC[4m"
export REVERSED="$ESC[7m"

export BLACK="$ESC[${DULL};${FG_BLACK}m"
export RED="$ESC[${DULL};${FG_RED}m"
export GREEN="$ESC[${DULL};${FG_GREEN}m"
export YELLOW="$ESC[${DULL};${FG_YELLOW}m"
export BLUE="$ESC[${DULL};${FG_BLUE}m"
export VIOLET="$ESC[${DULL};${FG_VIOLET}m"
export CYAN="$ESC[${DULL};${FG_CYAN}m"
export WHITE="$ESC[${DULL};${FG_WHITE}m"

# BRIGHT TEXT
export BRIGHT_BLACK="$ESC[${BRIGHT};${FG_BLACK}m"
export BRIGHT_RED="$ESC[${BRIGHT};${FG_RED}m"
export BRIGHT_GREEN="$ESC[${BRIGHT};${FG_GREEN}m"
export BRIGHT_YELLOW="$ESC[${BRIGHT};${FG_YELLOW}m"
export BRIGHT_BLUE="$ESC[${BRIGHT};${FG_BLUE}m"
export BRIGHT_VIOLET="$ESC[${BRIGHT};${FG_VIOLET}m"
export BRIGHT_CYAN="$ESC[${BRIGHT};${FG_CYAN}m"
export BRIGHT_WHITE="$ESC[${BRIGHT};${FG_WHITE}m"

export COLORS=($RED $GREEN $YELLOW $BLUE $VIOLET $CYAN)
export BRIGHT_COLORS=($BRIGHT_RED $BRIGHT_GREEN $BRIGHT_YELLOW $BRIGHT_BLUE $BRIGHT_VIOLET $BRIGHT_CYAN)
