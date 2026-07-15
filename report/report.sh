#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

ensure_dir "${ROOT_DIR}/evaluation"
for target in figure11 figure12 figure13 figure14 table4; do
  bash "${SCRIPT_DIR}/report-${target}.sh"
done
log "reports are available under ${ROOT_DIR}/evaluation"
