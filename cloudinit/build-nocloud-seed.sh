#!/usr/bin/env bash
set -euo pipefail

# Build NoCloud seed ISO with proper 'cidata' label
# Requirements: genisoimage or xorriso
# Usage: ./build-nocloud-seed.sh ./cloudinit ./out/seed.iso

CLOUDINIT_DIR=${1:-./data}
OUT_ISO=${2:-./cloud-init-seed.iso}

mkdir -p "$(dirname "$OUT_ISO")"

# Prefer xorriso if available for reproducibility, else fallback to genisoimage
if command -v xorriso >/dev/null 2>&1; then
  # xorriso variant
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT
  install -D -m 0644 "$CLOUDINIT_DIR/user-data"    "$TMPDIR/user-data"
  install -D -m 0644 "$CLOUDINIT_DIR/meta-data"    "$TMPDIR/meta-data"
  # network-config is optional but recommended
  if [ -f "$CLOUDINIT_DIR/network-config" ]; then
    install -D -m 0644 "$CLOUDINIT_DIR/network-config" "$TMPDIR/network-config"
  fi

  xorriso -as mkisofs -V cidata -volset cidata -J -l -r -iso-level 3 \
    -o "$OUT_ISO" \
    "$TMPDIR"
else
  # genisoimage variant
  if ! command -v genisoimage >/dev/null 2>&1; then
    echo "Error: install xorriso or genisoimage" >&2
    exit 1
  fi
  genisoimage -output "$OUT_ISO" -volid cidata -joliet -rock \
    "$CLOUDINIT_DIR/user-data" "$CLOUDINIT_DIR/meta-data" ${CLOUDINIT_DIR}/network-config 2>/dev/null || \
  genisoimage -output "$OUT_ISO" -volid cidata -joliet -rock \
    "$CLOUDINIT_DIR/user-data" "$CLOUDINIT_DIR/meta-data"
fi

echo "Created NoCloud seed: $OUT_ISO"
