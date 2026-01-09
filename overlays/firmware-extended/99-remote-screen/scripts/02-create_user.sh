#!/bin/bash

ROOT_DIR="$(realpath "$(dirname "$0")/../../../..")"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <rootfs-dir>"
  exit 1
fi

set -eo pipefail

echo ">> Creating unprivileged 'remote_screen' user and group"
# Find a free UID/GID between 100 and 999
NEW_UID=""
for uid in $(seq 100 999); do
    if ! grep -q "^[^:]*:[^:]*:$uid:" "$1/etc/passwd" && ! grep -q "^[^:]*:[^:]*:$uid:" "$1/etc/group"; then
        NEW_UID=$uid
        break
    fi
done

if [[ -z "$NEW_UID" ]]; then
    echo "Error: No free UID/GID found in range 100-999"
    exit 1
fi

"$ROOT_DIR/scripts/helpers/chroot_firmware.sh" "$1" /usr/sbin/adduser -H -D -s /sbin/nologin -u "$NEW_UID" remote_screen

echo ">> Adding 'remote_screen' user to video and input groups"
sed -i '/^video:/ { s/:$/:remote_screen/; t; s/$/,remote_screen/ }' "$1/etc/group"
sed -i '/^input:/ { s/:$/:remote_screen/; t; s/$/,remote_screen/ }' "$1/etc/group"
