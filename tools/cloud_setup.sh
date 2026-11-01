#!/usr/bin/env bash
# Installs headless Godot for cloud sessions. Safe to run repeatedly.
set -euo pipefail
GODOT_VERSION="4.7.2"
if command -v godot >/dev/null 2>&1 && godot --headless --version 2>/dev/null | grep -q "^${GODOT_VERSION}"; then
  exit 0
fi
tmp="$(mktemp -d)"
curl -sSL -o "$tmp/godot.zip" \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
unzip -q "$tmp/godot.zip" -d "$tmp"
install -m 0755 "$tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot
rm -rf "$tmp"
godot --headless --version
