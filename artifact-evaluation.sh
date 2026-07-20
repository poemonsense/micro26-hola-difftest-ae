#!/usr/bin/env bash

set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${ROOT_DIR}/setup/setup.sh"
bash "${ROOT_DIR}/build/build.sh"
bash "${ROOT_DIR}/run/run.sh"
bash "${ROOT_DIR}/report/report.sh"

printf 'Artifact evaluation complete. Reports: %s/evaluation\n' "${ROOT_DIR}"
