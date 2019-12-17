#!/usr/bin/env bash

function path_prefix {
    [[ -n $1 ]] || { echo "ERROR: missing argument for path_prefix"; return 1; }
    
    export PATH=$1:$PATH
}

function path_postfix {
    [[ -n $1 ]] || { echo "ERROR: missing argument for path_postfix"; return 1; }
    
    export PATH=$PATH:$1
}

function path_display {
    IFS=':' read -r -a paths <<< "$PATH"
    for index in "${!paths[@]}"; do
        echo "$index!${paths[index]}"
    done | tac | column -t -s "!"
}
