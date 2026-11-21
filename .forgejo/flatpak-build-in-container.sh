#!/usr/bin/env bash
# The inside of flatpak-publish.sh: build, export a bundle and, with
# UPLOAD=1, upload it to $INCOMING/<app>/<arch>/ for
# quine-global/flatpak-repo to publish.
set -euo pipefail

MANIFEST=build-aux/flatpak/io.github.kolunmi.Bazaar.flathub.yaml
APP=io.github.kolunmi.Bazaar

dnf -y -q install flatpak flatpak-builder ostree rclone git >/dev/null

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# A writable copy: the manifest's bazaar module is `dir: ../..`, this
# checkout, and /src is mounted read-only.
mkdir -p /work
cp -a /src /work/src

# Separate build directory from KeyMaker's and Quple's in the shared cache
# volume; it sits beside the state directory because flatpak-builder needs
# both on the same filesystem.
ARCH=$(flatpak --default-arch)
echo "== building $APP for $ARCH"
flatpak-builder --disable-rofiles-fuse --force-clean \
  --state-dir=/cache/state \
  --install-deps-from=flathub \
  --default-branch=stable \
  --repo=/work/build-repo \
  "/cache/build-$APP" "/work/src/$MANIFEST"

flatpak build-bundle /work/build-repo /work/app.flatpak "$APP" stable --arch="$ARCH"

if [ "$UPLOAD" != 1 ]; then
  echo "== built; not uploading (only pushes to quine upload)"
  exit 0
fi

name="$(date -u +%Y%m%dT%H%M%SZ)-${COMMIT:0:12}.flatpak"
echo "== uploading $APP/$ARCH/$name"
rclone copyto /work/app.flatpak "$INCOMING/$APP/$ARCH/$name"
