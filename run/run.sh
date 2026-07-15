#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

configs=()
if [[ -n "${AE_CONFIGS:-}" ]]; then
  read -r -a configs <<< "${AE_CONFIGS}"
else
  while IFS=$'\t' read -r id _; do
    [[ "${id}" == "id" ]] && continue
    configs+=("${id}")
  done < "${manifest_file}"
fi

for id in "${configs[@]}"; do
  [[ -x "${ROOT_DIR}/build/build-${id}/emu" ]] || die "emulator is missing for ${id}; run build/build.sh first"
done

jobs="${AE_RUN_JOBS:-4}"
[[ "${jobs}" =~ ^[1-9][0-9]*$ ]] || die "AE_RUN_JOBS must be a positive integer"
ensure_dir "${ROOT_DIR}/results/raw"
log "running ${#configs[@]} configurations with ${jobs} parallel jobs"
printf '%s\0' "${configs[@]}" | xargs -0 -n 1 -P "${jobs}" bash "${SCRIPT_DIR}/run-config.sh"

for figure in figure11 figure12 figure13 figure14 table4; do
  rm -rf "${ROOT_DIR}/results/${figure}"
  ensure_dir "${ROOT_DIR}/results/${figure}"
done

while IFS=$'\t' read -r id _ _ _ _ _ _ figures _; do
  [[ "${id}" == "id" ]] && continue
  [[ -f "${ROOT_DIR}/results/raw/${id}/success" ]] || continue
  IFS=',' read -r -a figure_list <<< "${figures}"
  for figure in "${figure_list[@]}"; do
    [[ "${figure}" =~ ^figure1[1-4]$ ]] || continue
    ln -s "../raw/${id}" "${ROOT_DIR}/results/${figure}/${id}"
  done
done < "${manifest_file}"

printf '%s\n' \
  'Table 4 is derived directly from the checked-out SVM Scala sources by' \
  'report/report-table4.sh; it does not require a simulator run.' \
  > "${ROOT_DIR}/results/table4/README.txt"
log "all requested simulations completed"
