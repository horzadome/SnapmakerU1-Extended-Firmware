#!/bin/bash

set -eo pipefail

# Script receives rootfs path but we don't need it - boot.img is separate
ROOT_DIR="$(realpath "$(dirname "$0")/../../../..")"
OVERLAY_DIR="$(realpath "$(dirname "$0")/..")"
LOGO_FILE="$OVERLAY_DIR/logo_extended.bmp"

echo ">> Replacing boot logo"

# Build rkresource tool if not already built
if [[ ! -f "$ROOT_DIR/tools/rkresources/rkresource" ]]; then
    echo "[+] Building rkresource tool..."
    make -C "$ROOT_DIR/tools/rkresources"
fi

# boot.img is in rk-unpacked/, not in the rootfs squashfs
BOOT_IMG="$ROOT_DIR/tmp/firmware/rk-unpacked/boot.img"
if [[ ! -f "$BOOT_IMG" ]]; then
    echo "[!] Error: boot.img not found at $BOOT_IMG"
    exit 1
fi

# Check if our custom logo exists
if [[ ! -f "$LOGO_FILE" ]]; then
    echo "[!] Error: Custom logo not found at $LOGO_FILE"
    exit 1
fi

# Create working directory
WORK_DIR="$ROOT_DIR/tmp/boot-logo-work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "[+] Extracting boot FIT image..."
# boot_fit.sh extract handles both: extracting FIT components and resources
"$ROOT_DIR/scripts/boot_fit.sh" extract "$BOOT_IMG" "$WORK_DIR/extracted/"

echo "[+] Listing current boot logo files..."
ls -lh "$WORK_DIR/extracted/resources/"*.bmp || true

echo "[+] Replacing boot logo with custom logo..."
# Replace the main boot logo (logo.bmp is typically the one shown during boot)
cp "$LOGO_FILE" "$WORK_DIR/extracted/resources/logo.bmp"

echo "[+] Repacking boot resources and FIT image..."
# boot_fit.sh repack handles both: repacking resources, then repacking FIT image
"$ROOT_DIR/scripts/boot_fit.sh" repack "$WORK_DIR/extracted/" "$WORK_DIR/boot-new.img"

echo "[+] Replacing boot.img in rk-unpacked..."
cp "$WORK_DIR/boot-new.img" "$BOOT_IMG"

echo "[+] Cleaning up working directory..."
# rm -rf "$WORK_DIR"

echo "[✓] Boot logo replacement complete!"
