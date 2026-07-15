#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common.sh"

command -v dpkg-query >/dev/null 2>&1 ||
  die "setup-system.sh requires an Ubuntu/Debian environment with dpkg-query"

declare -A package_set=()
add_package() {
  package_set["$1"]=1
}
add_if_missing() {
  command -v "$1" >/dev/null 2>&1 || add_package "$2"
}

add_if_missing curl curl
add_if_missing dtc device-tree-compiler
add_if_missing g++ build-essential
add_if_missing git git
add_if_missing java openjdk-17-jdk-headless
add_if_missing make build-essential
add_if_missing pkg-config pkg-config
add_if_missing riscv64-unknown-elf-gcc gcc-riscv64-unknown-elf
add_if_missing riscv64-unknown-elf-objcopy binutils-riscv64-unknown-elf
add_if_missing tar tar
[[ -x /usr/bin/time ]] || add_package time

if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import matplotlib' >/dev/null 2>&1 || add_package python3-matplotlib
else
  add_package python3
  add_package python3-matplotlib
fi
if command -v pkg-config >/dev/null 2>&1; then
  pkg-config --exists zlib || add_package zlib1g-dev
  pkg-config --exists libzstd || add_package libzstd-dev
else
  add_package zlib1g-dev
  add_package libzstd-dev
fi

missing=()
if ((${#package_set[@]})); then
  mapfile -t missing < <(printf '%s\n' "${!package_set[@]}" | sort)
fi

if ((${#missing[@]})); then
  if [[ "$(id -u)" -eq 0 ]]; then
    apt=(apt-get)
  elif command -v sudo >/dev/null 2>&1; then
    apt=(sudo apt-get)
  else
    die "missing packages (${missing[*]}) and neither root nor sudo is available"
  fi
  export DEBIAN_FRONTEND=noninteractive
  "${apt[@]}" update
  "${apt[@]}" install -y --no-install-recommends "${missing[@]}"
else
  log "all system packages are already installed"
fi

for command in bash git make g++ java python3 riscv64-unknown-elf-gcc tar; do
  require_command "${command}"
done
[[ -x /usr/bin/time ]] || die "GNU time is required at /usr/bin/time"

# xs-env supplies a recent Verilator. Installing Ubuntu's older package would
# mask toolchain problems and is deliberately avoided.
require_command verilator
verilator_version="$(verilator --version | awk '{print $2; exit}')"
minimum_verilator="5.048"
[[ "$(printf '%s\n%s\n' "${minimum_verilator}" "${verilator_version}" | sort -V | head -n 1)" == "${minimum_verilator}" ]] ||
  die "Verilator ${minimum_verilator} or newer is required; found ${verilator_version}"
log "using Verilator ${verilator_version} from the xs-env image"
