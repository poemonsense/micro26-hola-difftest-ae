#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

ensure_dir "${ROOT_DIR}/build"
bash "${SCRIPT_DIR}/build-nutshell.sh"

configs=()
if [[ -n "${AE_CONFIGS:-}" ]]; then
  read -r -a configs <<< "${AE_CONFIGS}"
else
  while IFS=$'\t' read -r id _; do
    [[ "${id}" == "id" ]] && continue
    configs+=("${id}")
  done < "${manifest_file}"
fi

log "building ${#configs[@]} RCache configurations serially"
for id in "${configs[@]}"; do
  bash "${SCRIPT_DIR}/build-config.sh" "${id}"
done
log "all requested emulators are built"
