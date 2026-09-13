#!/usr/bin/env bash
# Bootstrap Determinate Nix on CI agents that may not have Nix pre-installed.
# Safe to source: uses return when sourced, exit when executed directly.
set -euo pipefail

source_nix_profile() {
  if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    return 0
  fi
  if [[ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
    return 0
  fi
  return 1
}

_bootstrap_nix_die() {
  local code="${1:-1}"
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return "${code}"
  fi
  exit "${code}"
}

_bootstrap_nix_main() {
  if command -v nix >/dev/null 2>&1; then
    echo "Nix already installed: $(nix --version)"
    source_nix_profile || true
    return 0
  fi
  echo "Nix not found; installing Determinate Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
  if ! source_nix_profile; then
    echo "error: Nix was installed but profile could not be sourced" >&2
    _bootstrap_nix_die 1
  fi
  if ! command -v nix >/dev/null 2>&1; then
    echo "error: nix is not on PATH after installation" >&2
    _bootstrap_nix_die 1
  fi
  echo "Determinate Nix installed: $(nix --version)"
}

_bootstrap_nix_main
