#!/usr/bin/env bash
# Build the container flake output for the given Nix system and stage the image tarball.
set -euo pipefail

infer_system() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64) echo "x86_64-linux" ;;
    aarch64 | arm64) echo "aarch64-linux" ;;
    *)
      echo "error: unsupported machine architecture: ${machine}" >&2
      exit 1
      ;;
  esac
}

find_container_tarball() {
  local result_link="$1"
  local candidate

  if [[ ! -e "${result_link}" ]]; then
    echo "error: nix build out-link not found: ${result_link}" >&2
    exit 1
  fi

  # dockerTools image derivations usually expose a single tarball at the output root.
  if [[ -f "${result_link}" ]]; then
    echo "${result_link}"
    return 0
  fi

  for candidate in \
    "${result_link}/image.tar" \
    "${result_link}/image.tar.gz" \
    "${result_link}/image.tgz"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  # Fall back to any tarball under the derivation output.
  candidate="$(find -L "${result_link}" -maxdepth 2 -type f \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.tgz' \) | head -n 1 || true)"
  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  echo "error: could not locate container tarball under ${result_link}" >&2
  echo "Contents:" >&2
  find -L "${result_link}" -maxdepth 3 -type f >&2 || true
  exit 1
}

SYSTEM="${1:-$(infer_system)}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_LINK="${REPO_ROOT}/result-container"
ARTIFACT_DIR="${REPO_ROOT}/images"
ARTIFACT_PATH="${ARTIFACT_DIR}/determinate-nix-${SYSTEM}.tar.gz"

cd "${REPO_ROOT}"

echo "Building container for system=${SYSTEM}..."

if nix build --help 2>/dev/null | grep -q 'print-out-paths'; then
  nix build ".#packages.${SYSTEM}.container" --out-link "${OUT_LINK}" --print-build-logs
else
  nix build ".#packages.${SYSTEM}.container" --out-link "${OUT_LINK}"
fi

TARBALL_SRC="$(find_container_tarball "${OUT_LINK}")"
TARBALL_SRC="$(readlink -f "${TARBALL_SRC}")"
mkdir -p "${ARTIFACT_DIR}"

# Out-links are often named "result-container" even when they point at a gzip
# stream. Detect gzip by magic bytes so we never wrap an already-gzipped image.
if [[ "${TARBALL_SRC}" == *.tar.gz || "${TARBALL_SRC}" == *.tgz ]] \
  || [[ "$(od -An -tx1 -N2 "${TARBALL_SRC}" | tr -d ' \n')" == "1f8b" ]]; then
  cp -f "${TARBALL_SRC}" "${ARTIFACT_PATH}"
else
  gzip -c "${TARBALL_SRC}" > "${ARTIFACT_PATH}"
fi

echo "Container image staged at ${ARTIFACT_PATH} (from ${TARBALL_SRC})"
ls -lh "${ARTIFACT_PATH}"
