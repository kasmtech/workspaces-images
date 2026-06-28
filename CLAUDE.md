# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Workspaces Images is the catalog of pre-built Kasm workspace images (applications and full desktops) published to DockerHub and Quay. Each image layers application-specific install scripts on top of a base image from [workspaces-core-images](https://gitlab.com/kasm-technologies/internal/workspaces-core-images).

## Repository Layout

```
dockerfile-kasm-<name>      # Flat Dockerfile per image at repo root
src/
  ubuntu/install/<app>/     # Install scripts for Ubuntu-based images
  common/                   # Shared scripts used across distros
  alpine/, opensuse/, ...   # Distro-specific install scripts
ci-scripts/
  template-vars.yaml        # Image manifest: name, base, dockerfile, changeFiles, runset
  template-gitlab.py        # Generates gitlab-ci.yml from template-vars.yaml
  build.sh                  # Builds + pushes to cache registry
  test.sh                   # Runs post-build smoke tests via AWS/curl
  manifest.sh               # Creates and pushes multi-arch manifests
  weekly-manifest.sh        # Scheduled rolling-tag manifest updates
```

## Building Images Locally

```bash
# Build a single image (run from repo root)
sudo docker build -t kasmweb/firefox:dev -f dockerfile-kasm-firefox .

# Run it locally
sudo docker run --rm -it --shm-size=512m -p 6901:6901 -e VNC_PW=password kasmweb/firefox:dev
# Access via browser: https://<IP>:6901  (user: kasm_user, password: password)
```

The `BASE_TAG` build arg controls which core image tag is pulled (default: `develop`). Override with `--build-arg BASE_TAG=<tag>` to build against a specific core release.

## Adding a New Image

1. Create `dockerfile-kasm-<name>` at the repo root. Use an existing dockerfile as a template — the pattern is:
   - Set `ARG BASE_IMAGE` / `ARG BASE_TAG` and `FROM kasmweb/$BASE_IMAGE:$BASE_TAG`
   - Add install scripts under `src/<distro>/install/<name>/`
   - Copy scripts into `$INST_SCRIPTS`, run them, then delete them
   - Fix ownership with `chown 1000:0 $HOME` and run `set_user_permission.sh`
   - End with `USER 1000`

2. Add an entry to `ci-scripts/template-vars.yaml`:
   ```yaml
   - name: <name>
     runset: set-a          # or set-b — distributes load across CI run sets
     singleapp: true        # false for full desktop images
     base: core-ubuntu-jammy  # or core-ubuntu-noble, core-debian-bookworm, etc.
     dockerfile: dockerfile-kasm-<name>
     changeFiles:
       - dockerfile-kasm-<name>
       - src/ubuntu/install/<name>/**
   ```

3. The CI pipeline is generated — do **not** edit `gitlab-ci.yml` directly; edit `template-vars.yaml` and `template-gitlab.py` instead.

## CI/CD

The pipeline runs in two stages:

1. **template** — `template-gitlab.py` reads `template-vars.yaml` and generates `gitlab-ci.yml` as a CI artifact.
2. **run** — triggers a child pipeline from the generated `gitlab-ci.yml`.

Key CI variables (set in GitLab or pipeline triggers):
- `BASE_TAG` — core image tag to build against (default: `develop`)
- `USE_PRIVATE_IMAGES` — set to `1` to pull from private registry
- `KASM_RELEASE` — release version string for test installer
- `RUN_SET` — restrict CI to `set-a` or `set-b` image subsets
- `MIRROR_ORG_NAME` — DockerHub org for mirror pushes (default: `kasmtech`)

On `develop` and `release/*` branches, images are pushed publicly to DockerHub and Quay. Feature branches push only to an internal cache registry tagged `<arch>-<name>-<branch>-<pipeline_id>`.

## Image Naming Conventions

- Single-app images use `singleapp: true` and strip the XFCE panel for a focused UI.
- Desktop images (`singleapp: false`) ship the full XFCE desktop environment.
- Base image names follow `core-<distro>-<codename>` (e.g. `core-ubuntu-jammy`, `core-ubuntu-noble`, `core-debian-bookworm`).
- Published tags: `kasmweb/<name>:<branch>` for branch builds, `kasmweb/<name>:<version>` for releases.

## Distro Support

Install scripts are organized under `src/<distro>/install/<app>/`. Ubuntu scripts (jammy/noble) are the most common. When adding support for a new distro, add scripts under the appropriate `src/<distro>/` subtree and reference them in the dockerfile.
