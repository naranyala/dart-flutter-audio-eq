#!/usr/bin/env bash
# Bootstrap a rootless libmpv stack for audio_eq on Linux (no sudo).
#
# media_kit needs system libmpv, which locked-down machines may lack.
# This downloads the distro RPMs (mpv-libs + its unusual deps) and extracts
# them to ~/.local/share/audio_eq/libs. Re-run after OS upgrades.
# Idempotent: skips when the extracted libmpv already links cleanly.
#
# AlmaLinux/RHEL + EPEL layout is assumed; adapt the package list otherwise.
set -euo pipefail

DEST="${HOME}/.local/share/audio_eq/libs"
LIB="${DEST}/usr/lib64/libmpv.so.2"
PKGS="mpv-libs libcdio mujs lua uchardet libcaca libavdevice-free \
vapoursynth-libs compat-lua-libs libraw1394 libavc1394 libiec61883 \
libdc1394 mesa-libGLU freeglut libcdio-paranoia"

if [ -f "${LIB}" ] && \
   ! LD_LIBRARY_PATH="${DEST}/usr/lib64" ldd "${LIB}" 2>/dev/null | grep -q "not found"; then
  echo "libmpv stack already complete at ${DEST}"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${DEST}"

# shellcheck disable=SC2086
dnf download --destdir="${TMP}" ${PKGS}
for rpm in "${TMP}"/*.rpm; do
  rpm2cpio "${rpm}" | cpio -idm -D "${DEST}" >/dev/null 2>&1
done

if LD_LIBRARY_PATH="${DEST}/usr/lib64" ldd "${LIB}" 2>/dev/null | grep -q "not found"; then
  echo "STILL MISSING:" >&2
  LD_LIBRARY_PATH="${DEST}/usr/lib64" ldd "${LIB}" 2>/dev/null | grep "not found" >&2
  exit 1
fi
echo "libmpv stack ready at ${DEST}"
