#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"
ensure_dir "${ROOT_DIR}/evaluation"
python3 "${SCRIPT_DIR}/generate.py" figure13 > "${ROOT_DIR}/evaluation/figure13.txt"
