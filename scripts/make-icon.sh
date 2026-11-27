#!/bin/bash
# Regenerates Assets/AppIcon.icns and Assets/AppIcon.png from scripts/make-icon.swift.
# iconutil reports "Invalid Iconset" inside restricted sandboxes; run it from a normal terminal.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cache="${WATTBAR_CACHE_DIR:-/tmp/wattbar-cache}"
mkdir -p "$cache/clang" "$root/Assets"
export CLANG_MODULE_CACHE_PATH="$cache/clang"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swiftc -module-cache-path "$cache/clang" "$root/scripts/make-icon.swift" -o "$work/make-icon"
"$work/make-icon" "$work/AppIcon.iconset" "$root/Assets/AppIcon.png"
iconutil -c icns "$work/AppIcon.iconset" -o "$root/Assets/AppIcon.icns"
echo "Wrote $root/Assets/AppIcon.icns"
