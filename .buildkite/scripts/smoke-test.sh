#!/usr/bin/env bash
# Load a built container image and run basic Determinate Nix smoke checks inside it.
set -euo pipefail

SYSTEM="${1:?usage: smoke-test.sh <system> [image-tarball-path]}"
IMAGE_TAR="${2:-images/determinate-nix-${SYSTEM}.tar.gz}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAR="${REPO_ROOT}/${IMAGE_TAR#${REPO_ROOT}/}"

detect_container_runtime() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo docker
    return 0
  fi
  if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
    echo podman
    return 0
  fi
  echo "error: neither docker nor podman is available and functional" >&2
  exit 1
}

run_in_container() {
  local runtime="$1"
  local image_ref="$2"
  shift 2

  # Nix inside containers typically needs elevated privileges and a writable /tmp.
  "${runtime}" run --rm \
    --privileged \
    --network=bridge \
    -e NIX_CONFIG="experimental-features = nix-command flakes" \
    "${image_ref}" \
    bash -euo pipefail -c "$*"
}

if [[ ! -f "${IMAGE_TAR}" ]]; then
  echo "error: image tarball not found: ${IMAGE_TAR}" >&2
  exit 1
fi

RUNTIME="$(detect_container_runtime)"
IMAGE_TAG="determinate-nix-smoke:${SYSTEM}"

echo "Loading ${IMAGE_TAR} with ${RUNTIME}..."
LOAD_OUTPUT="$("${RUNTIME}" load -i "${IMAGE_TAR}")"
echo "${LOAD_OUTPUT}"

# docker/podman load prints: Loaded image: <name>:<tag>
LOADED_REF="$(echo "${LOAD_OUTPUT}" | awk '/Loaded image:/ { print $3; exit }')"
if [[ -z "${LOADED_REF}" ]]; then
  echo "error: could not parse loaded image reference from ${RUNTIME} load output" >&2
  exit 1
fi

"${RUNTIME}" tag "${LOADED_REF}" "${IMAGE_TAG}"
echo "Tagged loaded image as ${IMAGE_TAG}"

echo "Checking nix --version..."
run_in_container "${RUNTIME}" "${IMAGE_TAG}" 'nix --version'

echo "Checking determinate-nixd..."
run_in_container "${RUNTIME}" "${IMAGE_TAG}" '
  if command -v determinate-nixd >/dev/null 2>&1; then
    determinate-nixd --help >/dev/null 2>&1 || determinate-nixd --version || true
  else
    echo "error: determinate-nixd not found in PATH" >&2
    exit 1
  fi
'

echo "Checking nix run nixpkgs#hello..."
run_in_container "${RUNTIME}" "${IMAGE_TAG}" 'nix run nixpkgs#hello'

echo "Smoke tests passed for ${SYSTEM}"
