#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

log "checking Ubuntu system dependencies"
bash "${SCRIPT_DIR}/setup-system.sh"
log "checking source submodules"
bash "${SCRIPT_DIR}/setup-submodules.sh"
log "checking the Mill launcher"
bash "${SCRIPT_DIR}/setup-mill.sh"
log "checking Python reporting dependencies"
bash "${SCRIPT_DIR}/setup-python.sh"
log "setup complete"
