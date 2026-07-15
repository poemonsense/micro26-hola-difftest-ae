#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
export PATH="${ROOT_DIR}/.tools/bin:${PATH}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[micro2026ae] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

ensure_dir() {
  mkdir -p "$1"
}

copy_source_tree() {
  local source="$1"
  local destination="$2"
  ensure_dir "${destination}"
  (
    cd "${source}"
    tar --exclude='.git' --exclude='./build' --exclude='./out' -cf - .
  ) | (
    cd "${destination}"
    tar -xf -
  )
}

submodule_commit() {
  git -c safe.directory='*' -C "${ROOT_DIR}/$1" rev-parse HEAD
}

manifest_file="${ROOT_DIR}/experiments/configs.tsv"

manifest_row() {
  local wanted="$1"
  awk -F '\t' -v wanted="${wanted}" '
    NR == 1 { next }
    $1 == wanted { print; found = 1; exit }
    END { if (!found) exit 1 }
  ' "${manifest_file}" || die "unknown experiment configuration: ${wanted}"
}
