#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"
ensure_dir "${ROOT_DIR}/evaluation"

log_2port="${ROOT_DIR}/results/raw/c512k-w8-b2-p2-r1/stderr.log"
log_3port="${ROOT_DIR}/results/raw/c512k-w8-b4-p3-r1/stderr.log"
[[ -s "${log_2port}" ]] || die "Figure 14 2-port counter log is missing"
[[ -s "${log_3port}" ]] || die "Figure 14 3-port counter log is missing"

python3 "${ROOT_DIR}/SVM/scripts/plot.py" \
  "${log_2port}" \
  --other-logfile "${log_3port}" \
  --mode ports \
  --xmax "${FIGURE14_XMAX:-305}" \
  --output "${ROOT_DIR}/evaluation/figure14.pdf" \
  > "${ROOT_DIR}/evaluation/figure14-plot.log"
python3 "${SCRIPT_DIR}/generate.py" figure14 > "${ROOT_DIR}/evaluation/figure14.txt"
