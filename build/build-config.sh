#!/usr/bin/env bash

set -Eeuo pipefail
[[ $# -eq 1 ]] || { printf 'usage: %s CONFIG_ID\n' "$0" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

id="$1"
row="$(manifest_row "${id}")"
IFS=$'\t' read -r _ size ways banks ports refill replacement figures expected <<< "${row}"

require_command make
require_command mill
require_command python3
require_command tar

if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
  riscv_cross="riscv64-unknown-elf-"
elif command -v riscv64-linux-gnu-gcc >/dev/null 2>&1; then
  riscv_cross="riscv64-linux-gnu-"
else
  die "a RISC-V cross compiler is required for the SVM bootrom"
fi

base_dir="${ROOT_DIR}/build/build-nutshell/workspace/NutShell"
[[ -s "${base_dir}/build/rtl/SimTop.sv" ]] || die "run build/build-nutshell.sh first"
[[ -s "${ROOT_DIR}/SVM/riscv/encoding.h" ]] || die "Spike sources are missing; run setup/setup.sh first"

out_dir="${ROOT_DIR}/build/build-${id}"
workspace="${out_dir}/workspace"
dut_dir="${workspace}/NutShell"
svm_dir="${workspace}/SVM"
generated_dir="${workspace}/generated"
fingerprint="$({
  printf '%s\n' "${row}"
  printf 'nutshell=%s\n' "$(submodule_commit NutShell)"
  printf 'svm=%s\n' "$(submodule_commit SVM)"
  sha256sum "${SCRIPT_DIR}/build-config.sh" "${ROOT_DIR}/SVM/scripts/syngm.py"
} | sha256sum | awk '{print $1}')"

if [[ "${FORCE_REBUILD:-0}" != "1" ]] &&
   [[ -x "${out_dir}/emu" ]] &&
   [[ -s "${out_dir}/workspace/SVM/bootrom/bootrom.txt" ]] &&
   [[ -f "${out_dir}/runtime-root.txt" ]] &&
   [[ "$(<"${out_dir}/runtime-root.txt")" == "${ROOT_DIR}" ]] &&
   [[ -f "${out_dir}/success" ]] &&
   [[ "$(<"${out_dir}/fingerprint")" == "${fingerprint}" ]]; then
  log "reusing emulator for ${id}"
  exit 0
fi

log "building ${id}: ${size}, ${ways}-way, ${banks}-bank, ${ports}-port, refill=${refill}, replacement=${replacement}"
rm -rf "${out_dir}"
ensure_dir "${dut_dir}"
ensure_dir "${svm_dir}"

copy_source_tree "${ROOT_DIR}/NutShell" "${dut_dir}"
ensure_dir "${dut_dir}/build"
cp -a "${base_dir}/build/." "${dut_dir}/build/"
copy_source_tree "${ROOT_DIR}/SVM" "${svm_dir}"

# SVM and NutShell pin the same difftest revision. This fallback also makes a
# partially initialized developer checkout usable; setup.sh initializes it in
# a clean recursive clone.
if [[ ! -f "${svm_dir}/difftest/src/main/scala/Difftest.scala" ]]; then
  ensure_dir "${svm_dir}/difftest"
  copy_source_tree "${ROOT_DIR}/NutShell/difftest" "${svm_dir}/difftest"
fi

args=(
  NutShell
  --dut-path "${dut_dir}"
  --cache-size "${size}"
  --cache-ways "${ways}"
  --cache-banks "${banks}"
  --cache-sram-ports "${ports}"
  --cache-replacement "${replacement}"
  --image "${dut_dir}/ready-to-run/linux.bin"
  --output "${generated_dir}"
)
if [[ "${refill}" != "none" ]]; then
  args+=(--cache-refill-on-miss "${refill}")
fi

python3 "${svm_dir}/scripts/syngm.py" "${args[@]}"
if [[ "${riscv_cross}" == "riscv64-linux-gnu-" ]]; then
  sed -i 's|-Wl,--no-gc-sections|-Wl,--no-gc-sections -Wl,--build-id=none|' "${svm_dir}/bootrom/Makefile"
fi
if ! command -v hexdump >/dev/null 2>&1; then
  sed -i 's#hexdump -v -e .*#od -An -tx8 -w8 -v $< | tr -d " " > $@#' "${svm_dir}/bootrom/Makefile"
fi
sed -i "s|make -C bootrom|make -C bootrom CROSS=${riscv_cross}|" "${generated_dir}/build_ref.sh"
(
  cd "${generated_dir}"
  bash ./build.sh
) >"${out_dir}/build.log" 2>&1

[[ -x "${dut_dir}/build/emu" ]] || die "${id} did not produce an emulator"
grep -q '^#define SVM_ENABLE_PERF_COUNTERS 1$' "${svm_dir}/bootrom/generated-perf.h" ||
  die "${id} did not enable SVM performance counters"
install -m 0755 "${dut_dir}/build/emu" "${out_dir}/emu"
cp "${svm_dir}/bootrom/generated-perf.h" "${out_dir}/generated-perf.h"
cp "${svm_dir}/bootrom/generated-assertion.h" "${out_dir}/generated-assertion.h"
cp "${svm_dir}/bootrom/bootrom.txt" "${out_dir}/bootrom.txt"
cp -a "${generated_dir}" "${out_dir}/generated-scripts"
printf '%s\n' "${row}" > "${out_dir}/config.tsv"
printf '%s\n' "${ROOT_DIR}" > "${out_dir}/runtime-root.txt"
printf '%s\n' "${fingerprint}" > "${out_dir}/fingerprint"
sha256sum "${out_dir}/emu" > "${out_dir}/emu.sha256"
touch "${out_dir}/success"

if [[ "${KEEP_BUILD_WORK:-0}" != "1" ]]; then
  rm -rf "${workspace}"
  ensure_dir "${workspace}/SVM/bootrom"
  cp "${out_dir}/bootrom.txt" "${workspace}/SVM/bootrom/bootrom.txt"
fi
log "emulator for ${id} is ready"
