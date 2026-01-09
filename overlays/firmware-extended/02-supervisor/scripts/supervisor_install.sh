#!/usr/bin/env bash

# Install Supervisor, a process control system, on the target system.
# Docs: https://supervisord.org/
# Repo: https://github.com/Supervisor/supervisor

ROOT_DIR="$(realpath "$(dirname "$0")/../../../..")"

set -eo pipefail

echo ">> Installing Supervisor"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <rootfs-dir>"
  exit 1
fi

PKG_NAME=supervisor
PKG_VER=4.3.0
PKG_URL="https://files.pythonhosted.org/packages/source/s/$PKG_NAME/$PKG_NAME-$PKG_VER.tar.gz"
PKG_SHA="4a2bf149adf42997e1bb44b70c43b613275ec9852c3edacca86a9166b27e945e"
TARGET_DIR="$ROOT_DIR/tmp/$PKG_NAME"

if [[ -d "$TARGET_DIR" ]]; then
  rm -rf "$TARGET_DIR"
fi
mkdir -p "$TARGET_DIR"

if [ ! -f "$ROOT_DIR/tmp/$PKG_NAME-$PKG_VER.tar.gz" ]; then
  echo ">> Downloading $PKG_NAME-$PKG_VER.tar.gz"
  wget -O "$ROOT_DIR/tmp/$PKG_NAME-$PKG_VER.tar.gz" "$PKG_URL"
fi

echo "$PKG_SHA  $ROOT_DIR/tmp/$PKG_NAME-$PKG_VER.tar.gz" | sha256sum --check --status
tar -xzf "$ROOT_DIR/tmp/$PKG_NAME-$PKG_VER.tar.gz" -C "$TARGET_DIR" --strip-components=1

echo ">> Building and installing Supervisor"
cp -r "$TARGET_DIR" "$1/tmp/$PKG_NAME"
"$ROOT_DIR/scripts/helpers/chroot_firmware.sh" "$1" sh -c "cd /tmp/$PKG_NAME && python3 setup.py build"
"$ROOT_DIR/scripts/helpers/chroot_firmware.sh" "$1" sh -c "cd /tmp/$PKG_NAME && python3 setup.py install --prefix=/usr --install-scripts=/usr/sbin"

install -d "$1/var/log/$PKG_NAME"

echo ">> Validate binaries..."
test -f "$1/usr/sbin/supervisord" || { echo "ERROR: supervisord not found"; exit 1; }
test -f "$1/usr/sbin/supervisorctl" || { echo "ERROR: supervisorctl not found"; exit 1; }

echo ">> Supervisor installation complete."
