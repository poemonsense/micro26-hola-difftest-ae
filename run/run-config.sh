#!/usr/bin/env bash

set -Eeuo pipefail
[[ $# -eq 1 ]] || { printf 'usage: %s CONFIG_ID\n' "$0" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

id="$1"
row="$(manifest_row "${id}")"
IFS=$'\t' read -r _ _ _ _ _ _ _ figures expected <<< "${row}"
build_dir="${ROOT_DIR}/build/build-${id}"
emu="${build_dir}/emu"
image="${ROOT_DIR}/NutShell/ready-to-run/linux.bin"
out_dir="${ROOT_DIR}/results/raw/${id}"

[[ -x "${emu}" ]] || die "emulator is missing for ${id}"
[[ -f "${build_dir}/runtime-root.txt" ]] || die "runtime path metadata is missing for ${id}; rebuild this configuration"
[[ "$(<"${build_dir}/runtime-root.txt")" == "${ROOT_DIR}" ]] ||
  die "${id} was built at $(<"${build_dir}/runtime-root.txt"); rebuild after moving the repository to ${ROOT_DIR}"
[[ -s "${build_dir}/workspace/SVM/bootrom/bootrom.txt" ]] ||
  die "Verilator runtime bootrom is missing for ${id}; rebuild this configuration"
[[ -s "${image}" ]] || die "Linux image is missing: ${image}"

fingerprint="$({
  cat "${build_dir}/emu.sha256"
  sha256sum "${image}" "${SCRIPT_DIR}/run-config.sh"
} | sha256sum | awk '{print $1}')"
if [[ "${FORCE_RERUN:-0}" != "1" ]] &&
   [[ -f "${out_dir}/success" ]] &&
   [[ -f "${out_dir}/fingerprint" ]] &&
   [[ "$(<"${out_dir}/fingerprint")" == "${fingerprint}" ]]; then
  log "reusing simulation result for ${id}"
  exit 0
fi

rm -rf "${out_dir}"
ensure_dir "${out_dir}"
printf '%s\n' "${row}" > "${out_dir}/config.tsv"
start_epoch="$(date +%s)"
printf '%s\n' "${start_epoch}" > "${out_dir}/started-at-epoch.txt"
timeout_seconds="${AE_RUN_TIMEOUT:-3600}"
child_pid=""

cleanup_child() {
  if [[ -n "${child_pid}" ]] && kill -0 "${child_pid}" 2>/dev/null; then
    kill -TERM -- "-${child_pid}" 2>/dev/null || true
    sleep 1
    kill -KILL -- "-${child_pid}" 2>/dev/null || true
  fi
}
trap cleanup_child EXIT INT TERM HUP

log "running ${id}"
set +e
setsid timeout --preserve-status "${timeout_seconds}" \
  "${emu}" -i "${image}" -e 0 \
  >"${out_dir}/stdout.log" 2>"${out_dir}/stderr.raw.log" &
child_pid=$!
wait "${child_pid}"
status=$?
child_pid=""
set -e
mv "${out_dir}/stderr.raw.log" "${out_dir}/stderr.log"
printf '%s\n' "${status}" > "${out_dir}/exit-status.txt"

if [[ "${expected}" == "good" ]]; then
  [[ "${status}" -eq 0 ]] || die "${id} exited with status ${status}"
  grep -q 'HIT GOOD TRAP' "${out_dir}/stdout.log" || die "${id} did not reach HIT GOOD TRAP"
elif [[ "${expected}" == "abort" ]]; then
  grep -Eq 'REF aborts with code|Assertion [0-9]+ failed|cannot find a replacement' \
    "${out_dir}/stdout.log" "${out_dir}/stderr.log" ||
    die "${id} did not produce the expected cache-capacity abort"
else
  die "unsupported expected result for ${id}: ${expected}"
fi

end_epoch="$(date +%s)"
printf '%s\n' "$((end_epoch - start_epoch))" > "${out_dir}/elapsed-seconds.txt"
printf '%s\n' "${fingerprint}" > "${out_dir}/fingerprint"
touch "${out_dir}/success"
log "finished ${id} in $((end_epoch - start_epoch)) seconds"
