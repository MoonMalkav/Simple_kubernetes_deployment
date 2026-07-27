#!/bin/sh

log() {
    level=""
    message=""
    timestamp=""

    if [ "$#" -gt 1 ]; then
        level="$1"
        shift
        message="$*"
    else
        level="INFO"
        message="$1"
    fi

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s [%s] %s\n' "${timestamp}" "${level}" "${message}"
}
