#!/bin/sh
set -eu
#Designate the script directory and the root of the repository
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SERVERS_DIR="${REPO_ROOT}/servers"
HELM_DIR="${REPO_ROOT}/helm"
# Importing functions from lib folder
. "${SCRIPT_DIR}/lib/logging.sh"
. "${SCRIPT_DIR}/lib/servers.sh"
#Error handling: If any command fails, log the error and exit
log INFO "==============================================================="
log INFO "Validating deployment in Kubernetes cluster CCE."

#Check if the servers directory exists
if [ ! -d "${SERVERS_DIR}" ]; then
  log ERROR "Missing servers directory: ${SERVERS_DIR}"
  exit 1
fi

server_list_file="$(mktemp)"
get_servers "${SERVERS_DIR}" > "${server_list_file}"
server_count="$(wc -l < "${server_list_file}" | tr -d ' ')"

if [ "${server_count}" -eq 0 ]; then
  log ERROR "No server definitions found."
  rm -f "${server_list_file}"
  exit 1
fi

log INFO "Found ${server_count} server definition(s)."
#Check if the html, config directories and values.yaml file exist for each server
while IFS= read -r server_dir; do
  server_name="$(basename "${server_dir}")"
  log INFO "Validating server: ${server_name}"
  [ -d "${server_dir}/html" ] || { log ERROR "Missing directory: ${server_dir}/html"; rm -f "${server_list_file}"; exit 1; }
  [ -d "${server_dir}/config" ] || { log ERROR "Missing directory: ${server_dir}/config"; rm -f "${server_list_file}"; exit 1; }
  [ -f "${server_dir}/html/index.html" ] || { log ERROR "Missing file: ${server_dir}/html/index.html"; rm -f "${server_list_file}"; exit 1; }
  [ -f "${server_dir}/values.yaml" ] || { log ERROR "Missing file: ${server_dir}/values.yaml"; rm -f "${server_list_file}"; exit 1; }
done < "${server_list_file}"
rm -f "${server_list_file}"
#Check if the Helm chart directory exists
CHART_DIR="${HELM_DIR}/apache"
if [ ! -d "${CHART_DIR}" ]; then
  log ERROR "Missing Helm chart directory: ${CHART_DIR}"
  exit 1
fi
log INFO "Found Helm chart directory: ${CHART_DIR}"
#Check if the Helm chart has a Chart.yaml file
log INFO "Validating Helm chart directory."
if [ ! -f "${CHART_DIR}/Chart.yaml" ]; then
  log ERROR "Missing Helm Chart.yaml"
  exit 1
fi
log INFO "Running Helm lint validation."
lint_overrides="$(mktemp)"
cat > "${lint_overrides}" <<EOF
httpRoute:
  enabled: false
  annotations: {}
  parentRefs: []
  hostnames: []
  rules: []
EOF

if ! helm lint "${CHART_DIR}" -f "${lint_overrides}"; then
  rm -f "${lint_overrides}"
  log ERROR "Helm lint validation failed."
  exit 1
fi
rm -f "${lint_overrides}"
log INFO "Helm lint validation successful."
log INFO "==============================================================="
