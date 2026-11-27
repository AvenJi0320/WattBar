#!/bin/bash
set -euo pipefail

name="${1:?usage: capture-fixtures.sh <name>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/Tests/WattBarCoreTests/Fixtures"
mkdir -p "$dir"

raw="$(mktemp -d)"
trap 'rm -rf "$raw"' EXIT
export CLANG_MODULE_CACHE_PATH="${WATTBAR_CACHE_DIR:-/tmp/wattbar-cache}/clang"

ioreg -a -r -c AppleSmartBattery > "$raw/battery.plist"
ioreg -a -r -c IOUSBHostDevice > "$raw/usb.plist"
ioreg -a -r -c AppleTCControllerType10 > "$raw/ports.plist"

for kind in battery usb ports; do
    swift "$root/scripts/sanitize-fixture.swift" "$kind" "$raw/$kind.plist" "$dir/${kind}_${name}.plist"
done

ls -la "$dir"
