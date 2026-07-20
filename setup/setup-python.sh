#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

require_command python3
python3 - <<'PY'
import matplotlib
print(f"matplotlib {matplotlib.__version__}")
PY
