#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HELM_DIR="${REPO_ROOT}/helm"
CHART_DIR="${HELM_DIR}/apache"

. "${SCRIPT_DIR}/lib/logging.sh"

SERVER_NAME="${1:?Missing server name}"
VALUES_FILE="${2:?Missing values file}"
RUNTIME_VALUES="${3:?Missing runtime values file}"
NAMESPACE="${4:-${NAMESPACE:-}}"

if [ -z "${NAMESPACE}" ]; then
    log ERROR "Missing namespace. Pass it as argument 4 or set NAMESPACE."
    exit 1
fi

log INFO "==============================================================="
log INFO "Deploying release: ${SERVER_NAME}"
log INFO "Namespace: ${NAMESPACE}"
log INFO "Values file: ${VALUES_FILE}"
log INFO "Runtime values: ${RUNTIME_VALUES}"

if [ ! -d "${CHART_DIR}" ]; then
    log ERROR "Missing chart directory: ${CHART_DIR}"
    exit 1
fi

if [ ! -f "${VALUES_FILE}" ]; then
    log ERROR "Missing values file: ${VALUES_FILE}"
    exit 1
fi

if [ ! -f "${RUNTIME_VALUES}" ]; then
    log ERROR "Missing runtime values file: ${RUNTIME_VALUES}"
    exit 1
fi

deploy_overrides="$(mktemp)"
cat > "${deploy_overrides}" <<EOF
httpRoute:
    enabled: false
    annotations: {}
    parentRefs: []
    hostnames: []
    rules: []
EOF

status="deployed"

if helm status "${SERVER_NAME}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
        desired_manifest="$(mktemp)"
        current_manifest="$(mktemp)"

        helm template "${SERVER_NAME}" "${CHART_DIR}" \
            --namespace "${NAMESPACE}" \
            -f "${VALUES_FILE}" \
            -f "${RUNTIME_VALUES}" \
            -f "${deploy_overrides}" > "${desired_manifest}"

        helm get manifest "${SERVER_NAME}" \
            --namespace "${NAMESPACE}" > "${current_manifest}"

        if cmp -s "${desired_manifest}" "${current_manifest}"; then
                log INFO "No manifest changes detected. Skipping helm upgrade."
                status="unchanged"
        else
                log INFO "Manifest changes detected. Running helm upgrade."
                helm upgrade "${SERVER_NAME}" "${CHART_DIR}" \
                    --namespace "${NAMESPACE}" \
                    -f "${VALUES_FILE}" \
                    -f "${RUNTIME_VALUES}" \
                    -f "${deploy_overrides}"
        fi

        rm -f "${desired_manifest}" "${current_manifest}"
else
        log INFO "Release not found in namespace. Running helm install."
        helm install "${SERVER_NAME}" "${CHART_DIR}" \
            --namespace "${NAMESPACE}" \
            -f "${VALUES_FILE}" \
            -f "${RUNTIME_VALUES}" \
            -f "${deploy_overrides}"
fi

rm -f "${deploy_overrides}"

jq -n \
  --arg release "${SERVER_NAME}" \
  --arg namespace "${NAMESPACE}" \
  --arg chart "${CHART_DIR}" \
  --arg valuesFile "${VALUES_FILE}" \
    --arg runtimeValues "${RUNTIME_VALUES}" \
    --arg status "${status}" \
  --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
      release: $release,
      namespace: $namespace,
      chart: $chart,
      valuesFile: $valuesFile,
      runtimeValues: $runtimeValues,
            status: $status,
      timestamp: $timestamp
   }' > deployment.json

cat deployment.json

log INFO "Deployment completed successfully."
log INFO "==============================================================="
