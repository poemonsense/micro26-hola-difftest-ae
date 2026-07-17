#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

[[ -d "${ROOT_DIR}/.git" ]] || die "top-level Git metadata is missing; clone the artifact repository before setup"
if [[ "$(stat -c '%u' "${ROOT_DIR}")" != "$(id -u)" ]]; then
  for safe_path in "${ROOT_DIR}" "${ROOT_DIR}/NutShell" "${ROOT_DIR}/NutShell/difftest" "${ROOT_DIR}/SVM" "${ROOT_DIR}/SVM/difftest"; do
    if ! git config --global --get-all safe.directory | grep -Fxq "${safe_path}"; then
      git config --global --add safe.directory "${safe_path}"
    fi
  done
fi
git -c safe.directory='*' -C "${ROOT_DIR}" submodule sync --recursive
git -c safe.directory='*' -C "${ROOT_DIR}" submodule update --init

log "initializing the NutShell source environment"
make -C "${ROOT_DIR}/NutShell" init
log "initializing the SVM source environment"
git -c safe.directory='*' -C "${ROOT_DIR}/SVM" submodule update --init
if [[ -f "${ROOT_DIR}/SVM/riscv/encoding.h" ]]; then
  log "reusing the initialized Spike sources"
else
  make -C "${ROOT_DIR}/SVM" riscv
fi

[[ -f "${ROOT_DIR}/NutShell/ready-to-run/linux.bin" ]] || die "NutShell Linux image is missing"
[[ -f "${ROOT_DIR}/NutShell/difftest/emu.mk" ]] || die "NutShell difftest submodule is not initialized"
[[ -f "${ROOT_DIR}/SVM/src/main/scala/SVM.scala" ]] || die "SVM submodule is not initialized"

actual_nutshell="$(submodule_commit NutShell)"
actual_svm="$(submodule_commit SVM)"
expected_nutshell="c1394855f28b301f5b2cb835ffa642e97bec43c4"
expected_svm="5e24ddad569a1b60ea0dccd9a29eeee48b568523"
[[ "${actual_nutshell}" == "${expected_nutshell}" ]] || die "unexpected NutShell commit: ${actual_nutshell}"
[[ "${actual_svm}" == "${expected_svm}" ]] || die "unexpected SVM commit: ${actual_svm}"
log "submodule revisions match the evaluated artifact"
