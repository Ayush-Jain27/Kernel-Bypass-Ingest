#!/usr/bin/env bash
# Build the Linux image for the AUP-ZU3 with Buildroot.
#
# The Buildroot tree is disposable and lives outside this repository. Everything
# board specific lives in linux/ and is copied into that tree before building,
# so the tree can be deleted and recreated at will.
#
# Usage:
#   ./linux/build.sh [path-to-buildroot]     default: ~/kbi/buildroot
#
# Run this from a native Linux filesystem. Building on /mnt/c under WSL is
# painfully slow because Buildroot creates a very large number of small files.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
br="${1:-$HOME/kbi/buildroot}"
board="$br/board/aup-zu3"

if [ ! -f "$br/Makefile" ]; then
    echo "No Buildroot tree at $br" >&2
    echo "  git clone --depth 1 -b 2026.02.3 https://gitlab.com/buildroot.org/buildroot.git $br" >&2
    exit 1
fi

echo "==> staging board files into $board"
mkdir -p "$board/dts"
cp "$repo_root/linux/board/aup-zu3/psu_init_gpl."[ch] "$board/"
cp "$repo_root/linux/board/aup-zu3/post-build.sh"     "$board/"
cp "$repo_root/linux/board/aup-zu3/post-image.sh"     "$board/"
cp "$repo_root/linux/board/aup-zu3/genimage.cfg"      "$board/"
cp "$repo_root/linux/dts/"*.dts "$repo_root/linux/dts/"*.dtsi "$board/dts/"
chmod +x "$board/post-build.sh" "$board/post-image.sh"

cp "$repo_root/linux/configs/kbi_aup_zu3_defconfig" "$br/configs/"

echo "==> configuring"
make -C "$br" kbi_aup_zu3_defconfig

echo "==> building with -j$(nproc)"
time make -C "$br" -j"$(nproc)"

echo
echo "==> images in $br/output/images"
ls -la "$br/output/images"
echo
echo "Write the card with:  sudo dd if=$br/output/images/sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync"
echo "Check the device node with lsblk first. This destroys everything on that card."
