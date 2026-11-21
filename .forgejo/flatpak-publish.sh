#!/usr/bin/env bash
# Builds Bazaar's Flatpak from this checkout and, with UPLOAD=1, uploads it
# as a bundle to s3://<bucket>/flatpak/incoming/, where
# quine-global/flatpak-repo's publish workflow picks it up, signs it into
# Quine Linux's Flatpak repo (flatpak.quineglobal.com) and uploads that.
# Quine Linux preinstalls Bazaar ("Central Package" in its menu) from there
# (quine-linux: overlay/etc/flatpak/preinstall.d/bazaar.preinstall),
# instead of Flathub's build.
#
# Run by .forgejo/workflows/flatpak.yml, once per architecture. On the
# runner it only starts a Fedora container: flatpak-builder needs to run
# privileged (bubblewrap), and the GNOME SDK (shared with KeyMaker's and
# Quple's builds) and build cache live under /var/cache/quine-flatpak/ so
# the next run doesn't download them again. Not in podman volumes: those
# sit on the containers disk, which on runner-arm64-linux (49 GB) the
# quine-linux live ISO build needs whole (2026-11-21). /var/cache is on
# the root disk.
#
# Environment: UPLOAD (1 to upload); MINIO_ENDPOINT, MINIO_BUCKET,
# MINIO_ACCESS_KEY, MINIO_SECRET_KEY (needed only to upload); GITHUB_SHA
# (the commit, for the bundle's name).
set -euo pipefail

UPLOAD="${UPLOAD:-0}"
if [ "$UPLOAD" = 1 ]; then
  : "${MINIO_ACCESS_KEY:?}" "${MINIO_SECRET_KEY:?}" "${MINIO_ENDPOINT:?}" "${MINIO_BUCKET:?}"
fi

cache=/var/cache/quine-flatpak
mkdir -p "$cache/sdk" "$cache/bazaar"

exec podman run --rm --privileged \
  -v "$PWD":/src:ro \
  -v "$cache/sdk":/var/lib/flatpak \
  -v "$cache/bazaar":/cache \
  -e UPLOAD="$UPLOAD" \
  -e COMMIT="${GITHUB_SHA:-unknown}" \
  -e RCLONE_CONFIG_STORE_TYPE=s3 \
  -e RCLONE_CONFIG_STORE_PROVIDER=Minio \
  -e RCLONE_CONFIG_STORE_ENDPOINT="${MINIO_ENDPOINT:-}" \
  -e RCLONE_CONFIG_STORE_ACCESS_KEY_ID="${MINIO_ACCESS_KEY:-}" \
  -e RCLONE_CONFIG_STORE_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY:-}" \
  -e INCOMING="store:${MINIO_BUCKET:-}/flatpak/incoming" \
  quay.io/fedora/fedora:latest \
  bash /src/.forgejo/flatpak-build-in-container.sh
