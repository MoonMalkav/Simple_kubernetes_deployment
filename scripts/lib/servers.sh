#!/bin/sh

get_servers() {
    servers_dir="$1"

    for item in "${servers_dir}"/*; do
        [ -d "${item}" ] || continue
        server_name="$(basename "${item}")"
        [ "${server_name}" = "_template" ] && continue
        printf '%s\n' "${item}"
    done
}
