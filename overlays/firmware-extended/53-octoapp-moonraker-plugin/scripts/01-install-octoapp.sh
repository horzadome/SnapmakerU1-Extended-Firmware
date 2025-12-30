#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$0")/../../../..")"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <rootfs-dir>"
  exit 1
fi

set -eo pipefail


GIT_URL=https://github.com/crysxd/OctoApp-Plugin.git
GIT_SHA=17dfd704160be61d0a53bf3ad3e366d376bb3cd6
CLONE_DIR="$ROOT_DIR/tmp/octoapp"
TARGET_DIR="$1"

echo ">> Installing OctoApp Moonraker Plugin"

if [[ ! -d "$CLONE_DIR" ]]; then
  git clone "$GIT_URL" "$CLONE_DIR" --recursive
fi
git -C "$CLONE_DIR" fetch --all --tags
git -C "$CLONE_DIR" checkout "$GIT_SHA"

mkdir -p "$TARGET_DIR/home/lava/octoapp"
cp -r "$CLONE_DIR"/* "$TARGET_DIR/home/lava/octoapp/"
chown -R 1000:1000 "$TARGET_DIR/home/lava/octoapp"

echo "[+] Installing OctoApp Python dependencies from requirements.txt. This take about 10 minutes."
"$ROOT_DIR/scripts/helpers/chroot_firmware.sh" "$TARGET_DIR" /usr/bin/pip3 install -r /home/lava/octoapp/requirements.txt
"$ROOT_DIR/scripts/helpers/chroot_firmware.sh" "$TARGET_DIR" /usr/bin/pip3 install -r /home/lava/octoapp/requirements_try.txt || echo "[!] Some OctoApp optional packages failed to install (expected, continuing...)"

echo "[+] OctoApp Moonraker Plugin installed successfully"
