#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

. "${SCRIPT_DIR}/lib/logging.sh"

SERVER_NAME="${1:?Missing server name}"
SERVER_PATH="${2:?Missing server path}"
VALUES_FILE="${3:?Missing values file}"
HTML_DIR="${4:?Missing html directory}"
CONFIG_DIR="${5:?Missing config directory}"

if [ "$#" -ge 6 ] && [ -n "${6}" ]; then
  RUNTIME_VALUES="${6}"
  RUNTIME_DIR="$(dirname "${RUNTIME_VALUES}")"
  mkdir -p "${RUNTIME_DIR}"
else
  RUNTIME_DIR="$(mktemp -d)"
  RUNTIME_VALUES="${RUNTIME_DIR}/${SERVER_NAME}-runtime-values.yaml"
fi

log INFO "Generating runtime values for ${SERVER_NAME}"

cat > "${RUNTIME_VALUES}" <<EOF
htdocs:
  enabled: true
  files:
EOF

for file in "${HTML_DIR}"/*; do
  [ -f "${file}" ] || continue

    filename="$(basename "${file}")"

    {
        echo "    ${filename}: |"
        sed 's/^/      /' "${file}"
    } >> "${RUNTIME_VALUES}"
done

cat >> "${RUNTIME_VALUES}" <<EOF

apacheConfig:
  enabled: true
  files:
EOF

for file in "${CONFIG_DIR}"/*; do
  [ -f "${file}" ] || continue

    filename="$(basename "${file}")"

    {
        echo "    ${filename}: |"
        sed 's/^/      /' "${file}"
    } >> "${RUNTIME_VALUES}"
done

log INFO "Runtime values generated: ${RUNTIME_VALUES}"

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg name "${SERVER_NAME}" \
    --arg path "${SERVER_PATH}" \
    --arg values "${VALUES_FILE}" \
    --arg runtimeValues "${RUNTIME_VALUES}" \
    '{
        name: $name,
        path: $path,
        values: $values,
        runtimeValues: $runtimeValues
     }' > runtime.json
else
  log WARN "jq not found; writing runtime.json with printf fallback"
  esc_name="$(printf '%s' "${SERVER_NAME}" | sed 's/"/\\"/g')"
  esc_path="$(printf '%s' "${SERVER_PATH}" | sed 's/"/\\"/g')"
  esc_values="$(printf '%s' "${VALUES_FILE}" | sed 's/"/\\"/g')"
  esc_runtime="$(printf '%s' "${RUNTIME_VALUES}" | sed 's/"/\\"/g')"
  printf '{"name":"%s","path":"%s","values":"%s","runtimeValues":"%s"}\n' \
    "${esc_name}" "${esc_path}" "${esc_values}" "${esc_runtime}" > runtime.json
fi

cat runtime.json
