#!/bin/bash -x
set -eE

# Script to test is it all dependencies installed through `type` command
# The dependency list is passed as a single positional parameter

# Source configuration if available
[ -f "./lazyconfig" ] && source ./lazyconfig

# Ensure HOMEDIR is set
export HOMEDIR="${HOMEDIR:-$HOME}"

# array to test for dependencies
nuclei_templates(){
    while read line; do
        if [[ ! -d "${HOMEDIR}/${line}" ]]; then
            echo "[ERROR] No ${HOMEDIR}/${line} directory found!"
            exit 1
        fi
    done < "$1"
}

notification(){
    echo
    echo "nuclei-templates directories successfully tested"
}

main(){
    # Entry point
    nuclei_templates $1
    notification
}

main $1
exit 0
