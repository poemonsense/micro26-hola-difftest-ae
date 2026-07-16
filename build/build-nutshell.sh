#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

require_command git
require_command make
require_command mill
require_command tar

out_dir="${ROOT_DIR}/build/build-nutshell"
workspace="${out_dir}/workspace"
dut_dir="${workspace}/NutShell"
fingerprint="$({
  printf 'nutshell=%s\n' "$(submodule_commit NutShell)"
  printf 'difftest=%s\n' "$(git -c safe.directory='*' -C "${ROOT_DIR}/NutShell/difftest" rev-parse HEAD)"
  sha256sum "${SCRIPT_DIR}/build-nutshell.sh"
} | sha256sum | awk '{print $1}')"

if [[ "${FORCE_REBUILD:-0}" != "1" ]] &&
   [[ -f "${out_dir}/success" ]] &&
   [[ -f "${dut_dir}/build/rtl/SimTop.sv" ]] &&
   [[ "$(<"${out_dir}/fingerprint")" == "${fingerprint}" ]]; then
  log "reusing NutShell DUT RTL from ${out_dir}"
  exit 0
fi

log "elaborating the shared NutShell DUT"
rm -rf "${out_dir}"
ensure_dir "${dut_dir}"
copy_source_tree "${ROOT_DIR}/NutShell" "${dut_dir}"

(
  cd "${dut_dir}"
  NOOP_HOME="${dut_dir}" make sim-verilog DIFFTEST_GOLDEN=1
) >"${out_dir}/build.log" 2>&1

[[ -s "${dut_dir}/build/rtl/SimTop.sv" ]] || die "NutShell did not generate SimTop.sv"
[[ -s "${dut_dir}/build/generated-src/difftest_profile.json" ]] || die "NutShell did not generate difftest_profile.json"
printf '%s\n' "${fingerprint}" > "${out_dir}/fingerprint"
touch "${out_dir}/success"
log "NutShell DUT RTL is ready"
