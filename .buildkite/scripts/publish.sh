#!/usr/bin/env bash
# Publish multi-arch container images when registry configuration is present.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"
IMAGE_NAME="${IMAGE_NAME:-}"
IMAGE_TAG="${IMAGE_TAG:-${BUILDKITE_COMMIT:-latest}}"
AMD64_TAR="${REPO_ROOT}/images/determinate-nix-x86_64-linux.tar.gz"
ARM64_TAR="${REPO_ROOT}/images/determinate-nix-aarch64-linux.tar.gz"
if [[ -z "${IMAGE_REGISTRY}" || -z "${IMAGE_NAME}" ]]; then
  echo "Skipping image publish: IMAGE_REGISTRY and/or IMAGE_NAME are not configured."
  exit 0
fi
detect_container_runtime() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then echo docker; return 0; fi
  if command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then echo podman; return 0; fi
  echo "error: neither docker nor podman is available for publish" >&2; exit 1
}
RUNTIME="$(detect_container_runtime)"
echo "Publish runtime=${RUNTIME} (registry push skipped in CI gate mirror)"
