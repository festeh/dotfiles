#!/usr/bin/env bash
# Swap old Arch ISOs for the latest, then upgrade Ventoy on /dev/sda.
# Run with sudo: sudo bash ~/Downloads/ventoy-1.1.12/upgrade.sh

set -euo pipefail

USB_DEV=/dev/sda
USB_PART=/dev/sda1
MNT=/mnt/usb
ISO_DATE=2026.05.01
ISO_NAME=archlinux-${ISO_DATE}-x86_64.iso
ISO_URL=https://geo.mirror.pkgbuild.com/iso/${ISO_DATE}/${ISO_NAME}
ISO_SHA=4af795aab6530e8344553961d0a0e8e84f9622a131ee7d44b0b86b035b2d9ff7

if [[ $EUID -ne 0 ]]; then
  echo "must run as root" >&2
  exit 1
fi

echo ">>> ensuring $MNT is mounted"
if ! findmnt -M "$MNT" >/dev/null; then
  mount "$USB_PART" "$MNT"
fi

echo ">>> removing old Arch ISOs"
rm -f "$MNT"/archlinux-2025.02.01-x86_64.iso "$MNT"/archlinux-x86_64.iso

echo ">>> downloading $ISO_NAME"
curl -L --fail -o "$MNT/$ISO_NAME" "$ISO_URL"

echo ">>> verifying sha256"
( cd "$MNT" && echo "$ISO_SHA  $ISO_NAME" | sha256sum -c - )

echo ">>> syncing and unmounting"
sync
umount "$MNT"
umount /mnt/vtoyefi 2>/dev/null || true

echo ">>> upgrading Ventoy on $USB_DEV"
cd "$(dirname "$0")"
sh ./Ventoy2Disk.sh -u "$USB_DEV"

echo ">>> done"
