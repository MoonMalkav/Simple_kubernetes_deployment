#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVERS_DIR="${REPO_ROOT}/servers"

. "${SCRIPT_DIR}/lib/logging.sh"
. "${SCRIPT_DIR}/lib/servers.sh"

server_list_file="$(mktemp)"
get_servers "${SERVERS_DIR}" > "${server_list_file}"
server_count="$(wc -l < "${server_list_file}" | tr -d ' ')"

if [ "${server_count}" -eq 0 ]; then
    log ERROR "No server definitions found."
    rm -f "${server_list_file}"
    exit 1
fi

while IFS= read -r server_dir; do
    server_name="$(basename "${server_dir}")"

    jq -n \
        --arg name "${server_name}" \
        --arg path "${server_dir}" \
        --arg values "${server_dir}/values.yaml" \
        --arg html "${server_dir}/html" \
        --arg config "${server_dir}/config" \
        '{
            name: $name,
            path: $path,
            values: $values,
            html: $html,
            config: $config
        }'
done < "${server_list_file}" | jq -s . > servers.json

rm -f "${server_list_file}"

log INFO "Discovered ${server_count} server definition(s)."

cat servers.json
