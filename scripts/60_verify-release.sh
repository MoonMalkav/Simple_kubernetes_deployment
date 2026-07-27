#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

. "${SCRIPT_DIR}/lib/logging.sh"

RELEASE_NAME="${1:?Missing release name}"
NAMESPACE="${2:-apache}"

log INFO "==============================================================="
log INFO "Verifying release: ${RELEASE_NAME}"
log INFO "Namespace: ${NAMESPACE}"

log INFO "Checking deployment rollout."

DEPLOY_NAME=$(kubectl get deployments \
  --namespace "${NAMESPACE}" \
  -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "${DEPLOY_NAME}" ]; then
  log ERROR "No deployment found for release ${RELEASE_NAME} in namespace ${NAMESPACE}"
  exit 1
fi

log INFO "Found deployment: ${DEPLOY_NAME}"

kubectl rollout status \
  "deployment/${DEPLOY_NAME}" \
  --namespace "${NAMESPACE}" \
  --timeout=300s

log INFO "Checking pod count."

POD_COUNT=$(
  kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
    --no-headers 2>/dev/null | wc -l
)

if [ "${POD_COUNT}" -eq 0 ]; then
  log ERROR "No pods found for release ${RELEASE_NAME}"
  exit 1
fi

log INFO "Found ${POD_COUNT} pod(s)."

log INFO "Checking pod readiness."

NOT_READY=$(
  kubectl get pods \
    --namespace "${NAMESPACE}" \
    -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
    -o jsonpath='{range .items[*]}{.status.containerStatuses[*].ready}{"\n"}{end}' \
    | grep -vc '^true$' || true
)

if [ "${NOT_READY}" -gt 0 ]; then
  log ERROR "One or more pods are not ready."
  exit 1
fi

log INFO "All pods are ready."

jq -n \
  --arg release "${RELEASE_NAME}" \
  --arg namespace "${NAMESPACE}" \
  --arg pods "${POD_COUNT}" \
  '{
      release: $release,
      namespace: $namespace,
      podCount: ($pods | tonumber),
      status: "verified"
   }' > verification.json

cat verification.json

log INFO "Verification completed successfully."
log INFO "==============================================================="
