#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "${SCRIPT_DIR}/lib/logging.sh"

trap 'log ERROR "Bootstrap failed at line ${LINENO}"' ERR

log INFO "==============================================================="
log INFO "Checking required tools."

required_tools=(kubectl helm jq)

for tool in "${required_tools[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        log ERROR "Missing required tool: ${tool}"
        exit 1
    fi
    log INFO "Found tool: ${tool}"
done

log INFO "All required tools are available."
log INFO "==============================================================="
