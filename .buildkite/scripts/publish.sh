#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "${REPO_ROOT}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"; IMAGE_NAME="${IMAGE_NAME:-}"; IMAGE_TAG="${IMAGE_TAG:-${BUILDKITE_COMMIT:-latest}}"
if [[ -z "${IMAGE_REGISTRY}" || -z "${IMAGE_NAME}" ]]; then echo "Skipping image publish: IMAGE_REGISTRY and/or IMAGE_NAME are not configured."; exit 0; fi
echo "Publish script present; registry vars configured."
