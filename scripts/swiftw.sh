#!/bin/bash
# Wrapper for running SwiftPM inside restricted sandboxes (e.g. Codex).
# Usage: scripts/swiftw.sh build | test | run ...
set -euo pipefail

cache="${WATTBAR_CACHE_DIR:-/tmp/wattbar-cache}"
mkdir -p "$cache/clang"
export CLANG_MODULE_CACHE_PATH="$cache/clang"

command="${1:?usage: swiftw.sh <build|test|run> [args]}"
shift

exec swift "$command" \
    --disable-sandbox \
    --cache-path "$cache/spm" \
    --config-path "$cache/spm-config" \
    --security-path "$cache/spm-security" \
    --manifest-cache none \
    "$@"
