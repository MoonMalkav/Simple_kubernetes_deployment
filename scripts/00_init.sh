#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

. "${SCRIPT_DIR}/lib/logging.sh"

trap 'log ERROR "Deployment flow failed at line ${LINENO}"' ERR

NAMESPACE="${1:-${NAMESPACE:-}}"

if [[ -z "${NAMESPACE}" ]]; then
  log ERROR "Missing namespace. Pass it as first argument or set NAMESPACE."
  exit 1
fi

cd "${REPO_ROOT}"

"${SCRIPT_DIR}/10_bootstrap-tools.sh"
"${SCRIPT_DIR}/20_validate.sh"
"${SCRIPT_DIR}/30_discover-servers.sh"

mapfile -t servers < <(jq -c '.[]' servers.json)

if [[ ${#servers[@]} -eq 0 ]]; then
    log ERROR "No servers discovered in servers.json"
    exit 1
fi

for server_json in "${servers[@]}"; do
    server_name="$(jq -r '.name' <<<"${server_json}")"
    server_path="$(jq -r '.path' <<<"${server_json}")"
    values_file="$(jq -r '.values' <<<"${server_json}")"
    html_dir="$(jq -r '.html' <<<"${server_json}")"
    config_dir="$(jq -r '.config' <<<"${server_json}")"

    log INFO "---------------------------------------------------------------"
    log INFO "Processing server: ${server_name}"

    "${SCRIPT_DIR}/40_generate-runtime-values.sh" \
      "${server_name}" \
      "${server_path}" \
      "${values_file}" \
      "${html_dir}" \
      "${config_dir}"

    runtime_values="$(jq -r '.runtimeValues' runtime.json)"

    "${SCRIPT_DIR}/50_deploy-release.sh" "${server_name}" "${values_file}" "${runtime_values}" "${NAMESPACE}"
    "${SCRIPT_DIR}/60_verify-release.sh" "${server_name}" "${NAMESPACE}"
done

log INFO "Deployment flow completed successfully."
