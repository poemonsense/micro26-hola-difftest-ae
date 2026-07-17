#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"
ensure_dir "${ROOT_DIR}/evaluation"
rm -f "${ROOT_DIR}/evaluation/figure12.txt"
python3 "${SCRIPT_DIR}/generate.py" figure12 > "${ROOT_DIR}/evaluation/figure12.md"
