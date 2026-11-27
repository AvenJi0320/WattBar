#!/bin/bash
# Builds build/WattBar-<version>.dmg: a drag-to-install disk image containing
# WattBar.app and an Applications shortcut. Uses only built-in macOS tools.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/WattBar.app"

if [[ "${1:-}" != "--skip-build" ]]; then
    "$root/scripts/bundle.sh"
fi
[[ -d "$app" ]] || { echo "missing $app; run scripts/bundle.sh first" >&2; exit 1; }

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
dmg="$root/build/WattBar-${version}.dmg"
volume="WattBar ${version}"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/WattBar.app"
ln -s /Applications "$staging/Applications"

tmp_dmg="$staging/out.dmg"
mkdir "$staging/root"
mv "$staging/WattBar.app" "$staging/Applications" "$staging/root/"
cp "$root/LICENSE" "$staging/root/LICENSE.txt"
hdiutil create \
    -volname "$volume" \
    -srcfolder "$staging/root" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$tmp_dmg" >/dev/null

hdiutil verify "$tmp_dmg" >/dev/null
mv -f "$tmp_dmg" "$dmg"
echo "Built $dmg"
shasum -a 256 "$dmg"
