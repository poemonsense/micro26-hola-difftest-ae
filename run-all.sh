#!/usr/bin/env bash

set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v docker >/dev/null 2>&1 || {
  printf 'error: Docker is required to run the artifact evaluation\n' >&2
  exit 1
}

uid="$(id -u)"
gid="$(id -g)"
image="${AE_IMAGE:-hola-ae-env:ubuntu-24.04-${uid}-${gid}}"
container_name="${AE_CONTAINER_NAME:-hola-ae}"

printf '[micro2026ae] [1/2] building non-root evaluation image %s\n' "${image}"
build_args=(
  --build-arg "AE_UID=${uid}"
  --build-arg "AE_GID=${gid}"
  --tag "${image}"
  --file "${ROOT_DIR}/docker/Dockerfile"
  "${ROOT_DIR}/docker"
)
docker build --pull "${build_args[@]}"

printf '[micro2026ae] [2/2] running artifact evaluation as UID:GID %s:%s\n' "${uid}" "${gid}"
exec docker run --rm --name "${container_name}" \
  --user "${uid}:${gid}" \
  -v "${ROOT_DIR}:/ae" -w /ae \
  "${image}" \
  bash -lc './artifact-evaluation.sh'
