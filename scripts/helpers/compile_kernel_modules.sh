#!/bin/bash

set -xeo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <kernel-config> <temp-dir> <output-dir>"
  exit 1
fi

KERNEL_CONFIG="$(realpath "$1")"
TEMP_DIR="$(realpath -m "$2")"
OUT_DIR="$(realpath -m "$3")"

source ./vars.mk

if [[ ! -d "$TEMP_DIR/.git" ]]; then
  git init "$TEMP_DIR"
fi

pushd "$TEMP_DIR"

if ! git checkout -f "$KERNEL_SHA"; then
  git remote set-url origin "$KERNEL_GIT_URL" || git remote add origin "$KERNEL_GIT_URL"
  git fetch --progress origin "$KERNEL_SHA"
  git checkout "$KERNEL_SHA"
fi

if [[ ! -f .config ]]; then
  cp "$KERNEL_CONFIG" .config
fi

kernel_make() {
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$@"
}

module_make() {
  local dir="$1"
  shift 1
  make -C "$dir" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$@"
}

kernel_module_make() {
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$@" modules
}

scripts/config --file ".config" \
  --module CONFIG_TUN \
  --module CONFIG_WIREGUARD \
  --module CONFIG_MT7921U \
  --module CONFIG_MT7663U \
  --module CONFIG_MT76x0U \
  --module CONFIG_MT76x2U \
  --module CONFIG_MT7601U
:| kernel_make olddefconfig
kernel_make modules_prepare

# All network drivers
kernel_make M=drivers/net -j5

# Individual modules
# kernel_make drivers/net/tun.ko
# kernel_make drivers/net/wireguard/wireguard.ko
# kernel_make drivers/net/wireless/mediatek/mt76/mt7921/mt7921u.ko

if [[ -n "$OUT_DIR" ]]; then
  mkdir -p "$OUT_DIR"
  # do not overwrite existing modules
  find . -type f -name '*.ko' -exec cp -vn '{}' "$OUT_DIR/" ';'
fi

exit 0

###

if [[ ! -d rtl8851bu ]]; then
  git clone https://github.com/fofajardo/rtl8851bu.git rtl8851bu --depth=1
fi

:| module_make rtl8851bu KSRC="$PWD" USER_EXTRA_CFLAGS="-Wno-error -DREGULATORY_IGNORE_STALE_KICKOFF=0" -j5
