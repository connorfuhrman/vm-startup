# Determinate Nix container image

An optimized base Nix OCI image (Docker/Podman compatible), similar in role to the official [`nixos/nix`](https://hub.docker.com/r/nixos/nix) image, but built with and containing **Determinate Nix** — the `nix` CLI plus `determinate-nixd`.

The image is defined entirely as a Nix flake (`flake.nix` + `nix/container.nix`). There is no Dockerfile.

## Local build

Build the container for your current system:

```bash
nix build .#container
```

Or target a specific platform explicitly:

```bash
nix build .#packages.x86_64-linux.container
nix build .#packages.aarch64-linux.container
```

Both `packages.<system>.container` and `packages.<system>.default` refer to the same derivation. Supported systems are `x86_64-linux` and `aarch64-linux`.

Load and run the image (Docker or Podman):

```bash
docker load < result   # path may be result itself or a tarball inside result/
docker run -it --rm --privileged determinate-nix:<version>
```

The image is tagged `determinate-nix:<version>`, where `<version>` comes from the Determinate Nix package version baked into the flake. Nix inside containers typically needs `--privileged` and a writable `/tmp`.

## What's in the image

- **Determinate Nix** — `nix` CLI with flakes and `nix-command` enabled
- **determinate-nixd** — Determinate's Nix daemon
- **Minimal Unix tooling** aligned with the official Nix image: Bash, coreutils, tar/gzip/xz, grep/sed/awk, curl/wget, git, findutils, shadow (for user/group files), CA certificates, and related utilities
- **`/etc/nix/nix.conf`** — includes the FlakeHub binary cache (`https://cache.flakehub.com`) as a substituter
- **32 `nixbld` build users** — UID/GID layout compatible with Nix multi-user builds
- **`sandbox = false`** — required for running Nix builds inside unprivileged or semi-privileged containers

Environment variables set `NIX_PATH`, SSL cert paths, and a profile snippet under `/etc/profile.d/nix.sh` so interactive shells pick up Nix automatically.

## CI (Buildkite)

Continuous integration is defined in [`.buildkite/pipeline.yml`](.buildkite/pipeline.yml).

### Pipeline overview

1. **Flake check** — `nix flake check --system x86_64-linux`
2. **Build** (parallel, per architecture) — `nix build .#packages.<system>.container`, upload `images/determinate-nix-<system>.tar.gz`
3. **Smoke test** (after the matching build) — download the artifact, load with Docker or Podman, verify `nix --version`, `determinate-nixd`, and `nix run nixpkgs#hello`. Soft-fails if the runtime cannot load the image.
4. **On `master` only** — collect image tarballs as artifacts, then run [`publish.sh`](.buildkite/scripts/publish.sh)

### Agent requirements

Build steps need Linux agents with Nix (or permission to install Determinate Nix via [`bootstrap-nix.sh`](.buildkite/scripts/bootstrap-nix.sh)). Smoke tests need **Docker** or **Podman**. Queues currently used:

| Queue | Used for |
|-------|----------|
| `linux-medium` | x86_64-linux build and smoke |
| `mac-mini-aarch64-linux` | aarch64-linux build and smoke |

### ARM64 agents

The aarch64 steps only run when the pipeline env `BUILD_ARM64=1` is set, so default CI finishes on x86_64 without waiting on `mac-mini-aarch64-linux`. Enable that env (and keep an ARM agent on the queue) when you want the extra architecture.

### Cancel superseded builds

The Buildkite pipeline has **Cancel Intermediate Builds** and **Skip Intermediate Builds** enabled (`cancel_running_branch_builds` and `skip_queued_branch_builds`). A newer push to the same branch cancels in-flight jobs from older commits and skips queued intermediates, so ARM waits and other long jobs do not pile up.

### Publishing to a registry

On the **`master`** branch, the publish step downloads both architecture tarballs and calls `publish.sh`. **Publishing is a no-op** until registry variables are configured — the script exits successfully with instructions when they are missing.

To enable pushes, set these **pipeline or environment** variables in Buildkite:

| Variable                   | Required | Description                                      |
|----------------------------|----------|--------------------------------------------------|
| `IMAGE_REGISTRY`           | yes      | Registry host, e.g. `ghcr.io/my-org`             |
| `IMAGE_NAME`               | yes      | Image name, e.g. `determinate-nix`               |
| `IMAGE_TAG`                | no       | Defaults to `BUILDKITE_COMMIT`, or `latest`        |
| `IMAGE_REGISTRY_USER`      | no       | Username for `docker login` / `podman login`     |
| `IMAGE_REGISTRY_PASSWORD`  | no       | Password or token for registry login             |

When configured, the script loads each tarball, pushes per-arch tags (`:<tag>-amd64`, `:<tag>-arm64`), and creates a multi-arch manifest at `:<tag>`. If only one architecture tarball is present, it publishes a single-arch tag instead.

Per-arch image tarballs are always uploaded as build artifacts (`images/determinate-nix-x86_64-linux.tar.gz` and `images/determinate-nix-aarch64-linux.tar.gz`) even when publishing is disabled.

### Default branch: `main` vs `master`

This repository's Git default branch is **`main`**, but the collect-artifacts and publish steps are gated on **`build.branch == "master"`**. CI will build and smoke-test on every branch, but **registry publishing will not run on `main`** until you either:

- Rename the GitHub default branch to `master`, or
- Change the `if: build.branch == "master"` conditions in `.buildkite/pipeline.yml` to match your default branch (e.g. `main`).
