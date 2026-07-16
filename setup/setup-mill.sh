#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

mill_version="$(tr -d '[:space:]' < "${ROOT_DIR}/SVM/.mill-version")"
[[ -n "${mill_version}" ]] || die "SVM/.mill-version is empty"
mill_sha256="5218590f7266596a7c3d5377d0fc967918ea0424cd8c230c2eb07b800c412690"

tool_dir="${ROOT_DIR}/.tools/bin"
mill_path="${tool_dir}/mill"
ensure_dir "${tool_dir}"

version_matches() {
  (
    cd "${ROOT_DIR}/SVM"
    "$1" --version 2>/dev/null
  ) | grep -Fq "${mill_version}"
}

if [[ -x "${mill_path}" ]] && version_matches "${mill_path}"; then
  log "Mill ${mill_version} is already installed at ${mill_path}"
elif command -v mill >/dev/null 2>&1 && version_matches "$(command -v mill)"; then
  ln -sfn "$(command -v mill)" "${mill_path}"
  log "using system Mill ${mill_version}"
else
  url="https://repo.maven.apache.org/maven2/com/lihaoyi/mill-dist/${mill_version}/mill-dist-${mill_version}.jar"
  log "downloading Mill ${mill_version}"
  curl --fail --location --retry 3 --output "${mill_path}.tmp" "${url}"
  printf '%s  %s\n' "${mill_sha256}" "${mill_path}.tmp" | sha256sum --check --status ||
    die "Mill ${mill_version} checksum verification failed"
  chmod +x "${mill_path}.tmp"
  mv "${mill_path}.tmp" "${mill_path}"
  version_matches "${mill_path}" || die "downloaded Mill does not report version ${mill_version}"
fi
