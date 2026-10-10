#!/usr/bin/env bash
# Launch audio_eq on Linux with working audio, no sudo required.
#
# Prefers system libmpv; falls back to the rootless stack from
# tool/setup-linux-audio.sh. Run from the repo root.
set -euo pipefail

cd "$(dirname "$0")/.."

if ldconfig -p 2>/dev/null | grep -q libmpv; then
  exec ./build/linux/x64/debug/bundle/audio_eq "$@"
fi

STACK="${HOME}/.local/share/audio_eq/libs/usr/lib64"
if [ -f "${STACK}/libmpv.so.2" ]; then
  export LD_LIBRARY_PATH="${STACK}:${LD_LIBRARY_PATH:-}"
  exec ./build/linux/x64/debug/bundle/audio_eq "$@"
fi

echo "No system libmpv and no local stack. Run: bash tool/setup-linux-audio.sh" >&2
echo "Starting anyway — demo playback will show a notice, everything else works." >&2
exec ./build/linux/x64/debug/bundle/audio_eq "$@"
